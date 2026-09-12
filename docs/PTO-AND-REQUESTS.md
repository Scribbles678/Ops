# PTO, Requests & Availability

The second of the two focus areas (the other is [SCHEDULE-BUILDER.md](./SCHEDULE-BUILDER.md)).

**The one rule for working in this area:** every number about PTO hours comes from
`server/utils/ptoHours.ts`. Nothing else may compute it. This area has already been
broken twice by the same mistake — two places implementing one rule and drifting
apart — so treat a second implementation as a bug, not a shortcut.

---

## The shared modules (use these, do not reimplement)

| Module | Owns |
|---|---|
| `server/utils/ptoHours.ts` | How many paid hours an absence costs. Business-day math. Per-weekday caps. |
| `server/utils/ptoUsage.ts` | How many hours a team has already committed on a date, in total (`getUsedHoursByDate`) or itemised by source (`getUsedHoursBreakdownByDate`). |
| `server/utils/requestRules.ts` | `evaluateRequest()` — the auto-approval rule engine. |
| `utils/ptoDisplay.ts` | How a `pto_days` row should be READ and DISPLAYED (client + server). |
| `utils/requestDisplay.ts` | How a `schedule_requests` row is LABELLED (type name, "leaves 4:00 PM"). The PTO calendar and the request modal both use it. |

### Why they exist

**`ptoHours.ts`** — the auto-approval rule and the "Week Availability" strip used to
compute hours independently. They drifted, so the displayed hours-remaining
disagreed with what approval actually allowed. Both now route through these helpers.

**`requestRules.ts`** — the real submit (`POST /api/schedule-requests`) and the dry
run (`POST /api/schedule-requests/preview`) share one implementation, so a preview
can never promise something the submit then refuses. A preview is still only a
point-in-time answer: another admin can consume the day's budget in between, and the
submit re-runs the rules and remains the authority.

**`ptoDisplay.ts`** — the storage conventions are not self-describing:

| `pto_type` | `start_time` | `end_time` |
|---|---|---|
| `partial` | start of absence | end of absence |
| `leave_early` | when they LEAVE | **NULL** |
| `arrive_late` | `'00:00:00'` | when they ARRIVE |
| `full_day` | NULL | NULL |
| `call_in` | NULL | NULL (unplanned) |

Read literally, `leave_early` renders as "4:02 PM –" and `arrive_late` as
"12:00 AM – 9:38 AM". Two of the four types are wrong. Anything displaying PTO —
the calendar, the kiosk display board, anything new — must go through
`describePto` / `ptoTimeLabel` / `ptoTypeLabel` / `subtractPto`.

`ptoTypeLabel` ("Full Day", "Call-In", …) moved here in Aug 2026 because the PTO
calendar had kept its own copy of the map and it had already drifted — `call_in`
was missing, so a called-in employee rendered as the raw string `call_in` on the
board. Same failure mode as the availability strip, same fix: one implementation.

---

## The hours model

An absence consumes the **paid scheduled hours it removes**: the shift span minus
the unpaid lunch, clipped to the absence window. Paid 15-minute breaks stay in. For
the standard 8.5h-span / 30m-lunch shift a full day is exactly 8.0h.

| request type | hours charged |
|---|---|
| `pto_full_day` | paid minutes of the whole shift |
| `pto_partial` | paid minutes inside `[start, end)` |
| `leave_early` | paid minutes from `start` to shift end |
| `arrive_late` | paid minutes from shift start to arrival |
| `leave_on_time`, `shift_swap` | 0 |

**The 2-hour flat rate is a fallback, not the rule.** `leave_early` and
`arrive_late` fall back to a flat 2h *only* when the employee has no shift on file,
rather than guessing. Older docs described the flat rate as the model — it is not.

`HOUR_CONSUMING_TYPES = ['pto_full_day', 'pto_partial', 'leave_early', 'arrive_late']`.

### What counts as "already off" (`ptoUsage.ts`)

Two sources, deduped:

1. approved `schedule_requests` of an hour-consuming type
2. `pto_days` rows **not** materialized by a request — manual entries and call-ins

(2) is deduped against (1) via `schedule_requests.created_pto_id`, so an approved
request and the `pto_days` row it created are never both charged. Each row is priced
against the employee's **effective shift** for that date, honouring a `shift_swap`
if one exists.

---

## Requests & auto-approval

`schedule_requests` is a unified pipeline for `leave_early`, `pto_full_day`,
`pto_partial`, `shift_swap`, `leave_on_time` and `arrive_late`. The `request_type`
CHECK constraint enumerates these — **a new type needs a migration** (see 011).

On `POST /api/schedule-requests` the engine runs **inside a transaction** and sets
status to `approved` or `rejected` immediately.

**No request is ever left `pending`.** The column defaults to `'pending'`, but the
submit endpoint is the only place the app inserts a request and it always writes a
decided status, and the override `PUT` accepts only `approved` or `rejected`. So
the calendar's "Pending Requests" panel, its yellow `pending` badge and the yellow
calendar styling are unreachable from real data — an admin reverses a decision from
the Requests table instead. Do not seed `pending` rows to "test" that panel; it
shows a state the app cannot produce.

### Rules (all applicable rules must pass)

| Rule | Setting | Default |
|---|---|---|
| Advance notice, business days | `min_business_days_notice` | 1 |
| Max shift changes per employee per week | `max_shift_change_per_employee_per_week` | 1 |
| Max leave-on-time per employee per week | `max_leave_on_time_per_employee_per_week` | 5 |
| Max PTO hours per day, team-wide | `max_pto_hours_by_dow` (JSON `mon`..`fri`), falling back to `max_pto_hours_per_day` | 8 |
| Max shift swaps per day, team-wide | `max_shift_swaps_per_day` | 3 |
| Max leave-on-time per day, team-wide | `max_leave_on_time_per_day` | *unset = no limit* |
| Max leave-early per employee per week | `max_leave_early_per_employee_per_week` | *unset = no limit* |
| Date not blocked | `team_blocked_dates` | — |

⚠ Two dead keys, `max_leave_early_per_employee_per_day` and
`max_shift_change_per_employee_per_day`, survived from when those limits were daily
rather than weekly. **Nothing reads them**, and their names sit one word away from
the real weekly rules — set one and it silently does nothing. Deleted from the dev
database Sep 2026; **still present on any install that has not had them removed.**

```sql
DELETE FROM team_settings
WHERE setting_key IN ('max_leave_early_per_employee_per_day',
                      'max_shift_change_per_employee_per_day');
```

Safe by construction: no code path reads them, so removing them cannot change
behaviour. If you add a settings key, and later replace it, delete the old one in
the same change.

**Advance notice counts full working days strictly between today and the requested
date**, weekends excluded. A Friday request for Monday is 0 business days and is
rejected at the default — this surprises people and is working as intended.

Weekends and any unset weekday fall back to the legacy single
`max_pto_hours_per_day`.

### Per-type behaviour

- **`leave_on_time`** (decline overtime) is informational: it charges 0 hours and
  creates **no** downstream record. Four rules apply — advance notice,
  date-not-blocked, the per-employee weekly cap, and the team-wide daily cap.

**Opt-in limits.** `max_leave_on_time_per_day` and
`max_leave_early_per_employee_per_week` are skipped entirely when the setting is
absent or blank, via `getOptionalSetting()` rather than `getSetting(key,
default)`. It was added after teams were already live, so a numeric default would
have started refusing requests that used to be approved on installs where nobody
changed a setting. **Any limit added from here on should follow that pattern** —
blank means no limit, and the Settings field says so.
- **`arrive_late`** runs the full rule set and, on approval, materializes a
  `pto_days` row (`start='00:00:00'`, `end=arrival`, `pto_type='arrive_late'`) so
  the builder clips the employee's morning.

The per-rule pass/fail map is stored in `approval_rule_results` (JSONB); a
human-readable `rejection_reason` is assembled from the failed rules. On approval
the engine materializes the downstream `pto_days` or `shift_swaps` row and stores
its UUID in `created_pto_id` / `created_swap_id`.

Admins override via `PUT /api/schedule-requests/:id` with `admin_override`, which
materializes or removes the downstream record accordingly. **The POST engine and the
override PUT must materialize identically** — they are two paths to the same state.
They did not: the PUT wrote `request.request_type` straight into
`pto_days.pto_type` for anything that was not a full day, so an admin-approved
partial landed as **`pto_partial`** where the submit path writes **`partial`**.
Nothing failed loudly because `describePto()` and `hoursForPtoDay()` both have a
catch-all branch, so the row simply read as an untyped legacy record everywhere.
The mapping now lives in one table, `PTO_TYPE_FOR_REQUEST`.

⚠ **A `pto_days` row with no `pto_type` and no times is indistinguishable from a
full day**, and `display.vue` treats it as out-all-day — so a malformed row
silently removes a working person from the board. There is no CHECK constraint on
`pto_type`; if you add one, count the offending rows on each install first.

### Staff checking their own requests (the UPI lookup)

Staff have no logins; they use the kiosk. The request modal (`components/
schedule-requests/RequestFormModal.vue`, mounted on `/display` and on the PTO
calendar) has two tabs: **New request** and **Check my requests**. The second asks
for the employee's **UPI** — a numeric identifier kept on `employees.upi`
(migration 020, digits only, unique per team, set in Team Setup → Employees &
Training → Add/Edit) — and shows that person's requests: upcoming plus the last
60 days, with an Approved / Not approved chip and the rejection reason.

It is a **soft gate by design** (a UPI is an identifier, not a secret), so the
protection is placed where it matters: `POST /api/schedule-requests/lookup` does
the matching **server-side, within the caller's team**, and is rate-limited to 20
a minute per device so nobody can sit at the kiosk cycling through numbers. A
wrong number says so ("No employee with that UPI…") rather than pretending the
person has no requests — usability over hiding which numbers exist. The kiosk is
a shared screen, so leaving the tab or closing the modal forgets the lookup.

⚠ **Request-row time convention** (see `utils/requestDisplay.ts`, the one place
that labels a request): `arrive_late` stores the arrival in **`start_time`** on
the request row — the submit endpoint requires it there — while the `pto_days`
row it materialises stores it in `end_time`. Anything seeding requests by hand
must follow the request convention or the time shows as "—".

### The change log (who changed what)

People's records used to change without a trace: a request row remembers
`approved_by`, but a **deleted** request left nothing, and PTO days and call-ins
entered or removed on the schedule page never said who did it. That is the path
for quietly altering someone's time off, so since Sep 2026 every manual change is
written to **`audit_log`** (migration 022) **inside the same transaction as the
change**, by `logChange()` in `server/utils/auditLog.ts`:

| change | logged as |
|---|---|
| request approved / rejected / deleted by hand | `approve` / `reject` / `delete` on `request`, e.g. *"Deleted Max Kangas's Full Day Off for Sep 15 (was approved)"* |
| PTO day or call-in added / removed on the schedule page | `add` / `delete` on `pto_day` |
| attendance point given / removed | `add` / `delete` on `attendance_point` |
| performance note added / edited / deleted, error logged / removed | `add` / `edit` / `delete` on `performance_note` / `performance_error` |

Each entry carries the actor's id **and name as it was**, the employee's id and
name, a plain sentence composed at write time, and `before` / `after` snapshots —
so a deleted record can still be read, and a renamed or deleted account cannot
blur who did what.

**Read-only, Supervisor and above.** `GET /api/audit-log` is the only route; there
is no update or delete. The **Change log** button on the PTO calendar's Requests
card shows request changes for the team; the one on the Employee Overview shows
every kind of change for the selected person. Both are `components/audit/
ChangeLogModal.vue`, paged 15 at a time with an action filter. Team Leads never
see the button and the endpoint refuses them.

Not logged: requests submitted through the form (the request row is its own
record and the rules decide it) and schedule assignments.

### Multi-day ranges

A request spanning several days where only some are available does **not** silently
auto-approve the available subset. `POST /api/schedule-requests/preview` runs the
same rules as a dry run so the UI can name the unavailable days and ask whether to
proceed with the rest or cancel the whole range.

---

## Mock data for the calendar

`scripts/seed-pto-mock.mjs` fills two weeks with a realistic spread — every
absence type, a call-in with no originating request, stacked days, rejected
requests carrying real rule reasons, an approved shift swap and a blocked date —
so the page can be judged with something in it.

```bash
node scripts/seed-pto-mock.mjs --week 2026-08-24   # seed
node scripts/seed-pto-mock.mjs --clear             # remove exactly what it wrote
```

Every row it writes is tagged `[mock]` in its notes/reason and `--clear` deletes
only those, so it cannot touch real data. It is local-dev only and is not copied
into the image.

It writes what the **real approval engine** writes: an approved absence gets both
a `schedule_requests` row and the `pto_days` row it created, linked by
`created_pto_id`. Skip that link and the calendar shows the person twice — that
link is exactly what it dedupes on.

---

## PTO Calendar (`pages/pto-calendar.vue`)

Week or month view combining two sources:

- `pto_days` — approved/committed PTO
- `schedule_requests` — deduped against requests already materialized into
  `pto_days` via `created_pto_id`

Loads `/api/pto-calendar?date_from=...&date_to=...`. Green = approved. Submission
timestamps are shown in the requests card. The yellow "pending" styling and the
admin pending panel are **dead UI** — see the note above: no code path leaves a
request pending, so they cannot render from real data. An admin reverses a decision
from the Requests table.

**Per-day hours summary.** Each day column in the week view foots with the hours
off that day, itemised: **Approved** (came through the request workflow),
**Call-ins** (`pto_days` with `pto_type = 'call_in'` and no originating request),
**Manual** (any other hand-entered `pto_days` row), then **Total**.

The three buckets exist because *approved + call-ins does not add up* — an admin
can enter a `pto_days` row directly, and rows with no `pto_type` at all exist in
real data. A two-bucket split would quietly understate the day.

These numbers come from `getUsedHoursBreakdownByDate` via `/api/pto-calendar`, and
`getUsedHoursByDate` is now a thin wrapper over it — so the total a supervisor
reads on the calendar is, by construction, the same number the approval rule
measures against the daily cap. **The component must never total hours itself.**

**Requests table.** Paged 15 rows at a time, newest first. The search box switches
its scope: with a name typed, the table shows **every request for matching people,
all dates** (`GET /api/schedule-requests?q=`, which matches first name, last name,
"First Last" and "Last, First"); cleared, it goes back to the calendar's period.
The calendar grid above never changes with the search — looking someone up is
only useful if it isn't limited to the week on screen, and the subtitle says which
scope is showing. The Employee Overview button that used to sit in the header was
removed in Sep 2026 (the overview has its own home card).

**Week Availability strip** reads `/api/pto/availability`, which runs the same
`ptoHours` / `ptoUsage` helpers as approval. If the strip and the approval decision
ever disagree again, that is the signal something bypassed the shared module.

**Builder integration:** the builder reads `/api/pto/[date]` (`pto_days` only, not
pending requests), so only approved PTO affects schedule generation.

**Copy Today's Schedule** (`POST /api/schedule/copy`) trims each copied block
against the target date's absences with `describePto` + `subtractPto`, collecting
every row for an employee (arrive late *and* leave early on one day is two rows).
It kept its own reading of `start_time`/`end_time` until Sep 2026, which ignored
leave-early rows (NULL end), copied a mid-shift absence unchanged, and could emit a
sliver under the 15-minute CHECK — the same drift as the strip and the calendar.

**Cell layout.** Entries render on two lines — name, then type and time. They were
one truncated line, which clipped mid-label ("Leave Earl…") and dropped the time
entirely, leaving the most important part of a partial absence reachable only by
hovering. Month cells show at most three entries; "+N more" expands the day in
place rather than making you switch to week view to find the rest.

---

## Employee Overview

`pages/employee-overview.vue`, rendering `components/employee/Overview.vue`, served
by `GET /api/employees/[id]/overview`. A home-screen card since Sep 2026 (it was a
modal before); the PTO Calendar header and Team Setup → Employees & Training link
to it, and the per-row "Overview" button lands preselected via `?employee=`. The
period preset is `?period=` (7d / 30d / 90d / 12mo / all). Shows hours per
function, PTO usage, a rolling picking-error line chart, and performance notes.

**Performance tracking** (migrations 015, 016) is admin-only and entry is
one-at-a-time; there is no importer yet for the historical Excel error sheet.

| Table | Contents |
|---|---|
| `performance_errors` | one row per logged picking error (raw counts, not rates) |
| `performance_notes` | free-text review notes, plus `tag` (migration 016) for the quick-add buttons |
| `attendance_points` | one row per attendance point — **half or full only** (CHECK), on a date, optional note (migration 019) |

**Attendance points** (Sep 2026) are the sixth KPI tile and a list under Attendance
& requests, both admin-only like the rest of the review material. "+ Add attendance
point" opens a modal: the ½ / 1 choice first and large, then date (default today)
and an optional note. The tile is the period sum, so it follows the period toggle
like everything else; entries can be deleted through the same confirmation dialog
as errors and notes, and they appear in the CSV export.

Deleting a logged error requires a confirmation modal — these are review inputs and
must not be lost to a stray click. The error chart is a **rolling line chart** (not
a bar chart) so trends are visible, and weekends are hidden so weekday cells can be
larger.

---

## Kiosk display and partial PTO

### Display board legibility

It is a **wall-mounted iPad read from across a floor**, so it is a distance-read
board, not a dashboard. Two rules:

- **Never hardcode the chip label colour.** `getTextColor()` compares the real WCAG
  contrast of black vs white against the job function's colour and picks the winner.
  It previously used the NTSC luma formula on raw sRGB with a hard 0.5 cutoff, which
  put white on X4 (`#3B82F6`) at **3.68:1** — under the 4.5:1 floor — where black
  gives 5.71:1, and left four of fifteen colours within 0.06 of that cutoff so one
  shade change flipped the label. Comparing measured contrast has no threshold to
  sit near and stays right for any colour added later.
- **Do not composite chips over the background.** They were drawn at 90% alpha,
  which muted every colour and pushed real contrast below the measured figures.
- **Type is sized for the room**, not the browser: function 16px, time 12px,
  employee 16px, shift 18px. Anything at 9-11px is unreadable on the wall.

⚠ The board has **no auto-scroll** and 49 people is ~4 iPad screens, so most of
the floor is below the fold. Not a styling problem — it needs auto-scroll, a
compact mode, or a screen per area.

Touch targets on the kiosk (the request modal's week arrows, the close button) are
**44x44**, per Apple's guideline and WCAG 2.5.5. They were 20x20 and people missed
them. A touchscreen has no hover, so those controls need `active:` states.

---

`pages/display.vue` uses `subtractPto` from `ptoDisplay.ts` to **trim** assignments
around an absence. It previously deleted any assignment overlapping PTO outright,
which made a person who left at 4pm vanish from the whole day. Absence blocks render
as pseudo-assignments in slate `#94a3b8`.

---

**Last Updated**: September 2026
