# Schedule Builder

The most-used feature. **One engine**, deterministic — no LLM, no constraint
solver. Launched from the **Automated Schedule Builder** card on
`pages/schedule/tomorrow.vue`.

| | |
|---|---|
| Code | `utils/scheduleEngineV2/` (pure, DB-free: `prepare.ts` then `engine.ts`) + `composables/useScheduleBuilderV2.ts` |
| Time model | 96 x 15-minute slots |
| Placement | cost function scored over every candidate |
| Business priority | `job_functions.staffing_priority` |
| Explains gaps | a reason per gap, shown in the review modal |

It writes through `POST /api/schedule/replace` (transactional delete + insert for
the date), then shows a review modal. **If the date already has a schedule, the
page asks first** — "Replace the existing schedule? … already has 177
assignments … replaces all of them, including any changes made by hand" — and Copy
Today's Schedule asks the same. Until Sep 2026 both replaced the day without a
word, so one click could wipe a hand-edited day. The check reads
`GET /api/schedule/[date]` directly and stops if that fails, because
`fetchScheduleForDate` turns a failed lookup into an empty list, and "empty" there
would mean "overwrite without asking".

> **Two other engines have come and gone.** "V1" (`composables/useAIScheduleBuilder.ts`,
> hourly buckets) was deleted in Aug 2026 after the team lead confirmed this one
> schedules better; the pre-flight "Build Schedule" checklist went with it (its
> successor, a dated coverage preview, was removed in Sep 2026). A "period engine" (`periodEngine.ts`, the
> "Automated Schedule Builder V2" card) was added in Sep 2026 and removed later
> that month — see [Why the period engine was removed](#why-the-period-engine-was-removed).
> The `V2` still in the directory and composable names is that history.

---

## Why the 15-minute model

The engine it replaced modelled coverage in hourly buckets. Measured on real data:
at 19:00, 26 of 28 people take their break in the same quarter-hour. Coverage
collapses for one 15-minute slot and recovers — averaged over the hour it looks
fine, so an hourly engine cannot see the hole, and a 30-minute floor could not have
filled it.

This engine works at 15-minute **resolution** while still optimising for
**contiguity**. Resolution is not the same as output granularity — see the two
floors below.

---

## The two minimums (do not "tidy" these to match)

In `utils/scheduleEngineV2/types.ts`:

```ts
ENGINE_MIN_BLOCK_MINUTES = 30   // shortest block the BUILDER emits
DB_MIN_BLOCK_MINUTES     = 15   // shortest block a HUMAN can save (migration 017)
```

The gap between them is the feature. The team lead found auto-generated 15-minute
assignments created more hand-correction than they saved, so the builder only ever
emits half-hour blocks or longer — but a supervisor can still make 15-minute tweaks
by hand after a build. `PREFERRED_MIN_MINUTES` (30) is currently equal to the engine
floor, so its short-block penalty is inert; it stays wired up so shorter blocks can
be re-enabled by lowering `ENGINE_MIN_BLOCK_MINUTES` alone.

---

## The pipeline

**Phase A — `prepare.ts`** turns DB rows into the slot model.

- Meter parent/child training resolution and target fan-out (carried over from the
  retired engine — those rules were correct, only the time model changed).
- Availability grid per employee: shift span, minus lunch, minus both breaks, minus
  every absence that day. Modelling breaks explicitly on the grid is what makes the
  break cliff visible. Absences are read through `describePto()`
  (`utils/ptoDisplay.ts`), the same reading the display board and Copy use. Until
  Sep 2026 `prepare()` kept one `pto_days` row per person and read it itself, so an
  arrive-late plus a leave-early on the same day honoured only one of them, and an
  untyped row the board shows as "off all day" was scheduled all day. Callers pass
  every row: `ptoByEmployee` is `employeeId -> row[]`.
- `scarcity` = trained supply / total demand, per function. Computed once per build.
- **Canonical order.** `prepare()` sorts employees (last name, first name), job
  functions (sort order, name) and required assignments itself. The engine breaks
  ties in favour of whoever comes first, so until Sep 2026 the order rows happened
  to be fetched in changed the schedule — the harness and the app disagreed on 10+
  people's days for the same data. Code-unit comparison, not `localeCompare`, so
  the browser and Node agree; it matches the byte-order `ORDER BY` the API returns,
  so live schedules did not change when it was added.
- `priority` from `job_functions.staffing_priority` (1 = fill first ... 5 = drop
  first, default 3).
- **Shift-envelope clip.** Demand outside the union of all active shifts' hours is
  dropped, because nobody can be on the clock then. Two ways the grid asks for the
  impossible: a stale row surviving a shift change (a 06:00 target after the 6am
  shift retired), and an hourly row over-extending a real target (20:00 covers
  20:00-21:00, but the last shift ends 20:30). Only a target whose **whole hour**
  falls outside the envelope is warned about — that is a stale row someone can go
  delete. The **Rules & Targets** grid builds its hour columns from the same active
  shifts, so it no longer offers hours nobody works; an hour that still carries a
  target keeps its column (shaded amber) so a stale row stays visible and clearable
  rather than being hidden by the very fix that flags it. A row that merely runs past the last shift is a storage-granularity
  artifact, not fixable from the grid, and warning about it on every build would
  just train people to skip warnings.

**Shift swaps.** `prepare()` resolves each employee's **effective shift** for the
date — `swappedShiftByEmployee[id] ?? employee.shift_id` — and the resulting
`EngineEmployee.shiftId` is what the write path stamps on the assignment.

Until Aug 2026 the builder read `employee.shift_id` only. A swapped person was
scheduled against the hours they were **not** working, and their rows carried the
original `shift_id`; the display board groups swapped people by the *swapped*
shift, so it then dropped their work and showed them present with an empty day.
Reproduced: an 8AM→12pm swap put the employee in the 12pm group with 0 of 4
assignments visible.

Callers must pass it — `useScheduleBuilderV2` and `scripts/sim-builder.mjs` both
query `shift_swaps` for the date. PTO hour
accounting has always honoured swaps (`getEffectiveShift` in `ptoUsage.ts`); the
scheduling side now agrees with it.

**Phase B — required pins.** `preferred_assignments` with `is_required`, honouring
`preferred_assignment_blocks`. **Each block uses its own `job_function_id`.** Until
Sep 2026 every block was pinned to the row's base function — which the Rules &
Targets form sets to the first block's — so "X4 08:00–12:30, EM9 13:00–16:30" ran
X4 all day. That was the team lead's "the builder doesn't factor in required
assignments": the form saves every pin as blocks, so every pin with more than one
function was affected.

A pin whose employee lacks the training is **skipped with a warning**, not
committed — the DB trigger would reject it and fail the entire save. (This actually
happened: one bad pin failed a 204-row save at row 113.)

**A block that cannot be placed is reported, never dropped silently.** It becomes a
thing to fix, naming the person, the function and the time, when it:

- is outside their shift that day (typically a shift swap),
- falls entirely in a break or lunch,
- is on an inactive job function,
- is under 30 minutes once breaks and time off are taken out, or
- overlaps another of their required assignments (the earlier-starting one wins).

A block during approved time off is skipped quietly; there is nothing to fix.
`prepare()` reports the first three (it knows shifts and breaks), the engine the
last two (it owns the 30-minute rule).

A row with **no blocks** uses the legacy AM/PM columns, by the same rule the Rules &
Targets page applies when it converts one on edit: AM = shift start to lunch, PM =
lunch end to shift end, both NULL = base function all day, one NULL = that half
unpinned. Until Sep 2026 `prepare()` pinned the base function all day and never
read the PM column — "X4 mornings, EM9 afternoons" ran X4 all day, and 4 of the 7
live pins on the dev data were of that shape. Pins are resolved in `prepare()`; only
`prepare()` may read those columns.

**Phase C — feasibility, before anything is assigned.** For every slot with demand,
compare against trained people actually free. Produces "19:00 needs 19, only 2
trained people are available" up front. It is returned as `EngineResult.feasibility`
and counted by the harness, but the review modal does not list it: each gap's
reason covers it.

**Phase D — coverage fill.** Functions ordered `priority` then `scarcity`; within a
function, the **hardest run first** (fewest candidates), not the longest. Measured
failure this fixes: V2 used to fill the easy multi-hour runs first, committing
everyone to long blocks, then had nobody free for the 15 minutes when a whole shift
was on break. Every cell lost to the old hourly engine sat on a break or lunch
boundary. After every single placement the scan restarts from the top, so priority
is **strict**: a function is filled as far as it can be before a lower-priority one
gets anybody. Scarcity is fixed for the build and only orders functions that share
a priority.

**Phase E — removed (Sep 2026).** It "patched cliffs" with the same candidates and
the same 30-minute floor as phase D, so once D had stopped it could never place
anything (0 blocks on every measured day). The letters are kept so older notes
still line up.

**Phase F — surplus deployment.** Targets are a MINIMUM, not a cap. Remaining labour
goes to under-target functions, then `surplus_overflow` sinks, then continuation of
something they already do. **Zero-target functions are eligible** — in V1, anyone
trained only on such a function (TL, coordinator) got a silently empty day.

**Phase G — merge** touching same-employee/same-function blocks.

**Phase H — gaps, over-target, explanations.** Every gap gets a *cause*, not just a
flag: `floor-short` (more work than people on the floor — no schedule can fix it) /
`no-one-trained` (nobody on the team is trained for the job; also raised as a thing
to fix) / `no-one-trained-on-shift` / `all-trained-busy` / `capped` /
`no-availability`. Until Sep 2026 the first two shared the third's name, so "nobody
is trained for this at all" was hidden inside the unavoidable total.
This relies on an `originallyFree` snapshot taken before any assignment — without it
the engine cannot tell "everyone was on break" from "everyone was busy", because
both look identical once `free` has been consumed. Each gap and over-target run
carries both its peak (`shortfall` / `surplus`: most people short or over at once)
and `hours` (every 15 minutes of it added up) — the review modal shows hours.

### The cost function

`scoreCandidate()` in `engine.ts` is the single place every trade-off lives. Higher
is better; `-Infinity` is inadmissible. Default weights:

| weight | value | effect |
|---|---|---|
| `unmet` | 100 | reward per unmet slot closed |
| `adjacent` | 80 | extend a block of the same function |
| `newFunction` | 60 | cost of adding a function they aren't on |
| `priority` | 45 | business priority (see below) |
| `functionCount` | 40 | squared cost per function beyond `comfortableFunctions` (2) |
| `scarce` | 30 | favour hard-to-staff functions while their people are free |
| `preferred` | 25 | preferred-assignment bonus |
| `waste` | 25 | cost per slot consumed that was ALREADY covered |
| `shortBlock` | 4 | per minute below `PREFERRED_MIN_MINUTES` (inert today) |
| `flexibility` | 3 | per function the employee is trained on |

`flexibility` is the biggest lever on a tight day: it spends specialists first and
keeps multi-skilled people free for whichever hole appears next.

## Break and lunch holes are not gaps

**The builder does not treat a hole during a 15-minute break or the lunch window as
a gap.** The team lead's rule: when a whole shift goes on break, the floor does not
expect Pick to be staffed for those fifteen minutes, and listing 34 such holes on
every build buried the two or three a supervisor could act on.

How it works, in `prepare()`: one `mustCover` mask, shared by every function, is 0
inside any active shift's break or lunch window. Shortfalls there are not scored,
not chased by the engine, not reported as gaps, and not counted by the feasibility
check or the harness (which prints them as "break/lunch holes not counted").
Demand itself is untouched, so blocks still span the window rather than
fragmenting around it.

History: for part of Sep 2026 each job had **Keep covered during 15-minute breaks**
and **Keep covered through lunch** checkboxes (`break_coverage_required` /
`lunch_coverage_required`, migration 006) that made its holes count and rewarded
closing them. Measured on the dev data (Help desk at priority 1, 2 and 3, flag on
vs off), they never covered one more break or lunch slot, so they were removed
from the form and the engine. The columns are still in the database; nothing
reads them.

## Job function settings the builder uses

Team Setup → Job Functions → Edit holds only settings that change a build:
**Staffing priority** (below), **Max people at once** (`max_headcount`: phases D and
F stop adding people at that number; required assignments are placed regardless),
**Send spare people here first** (`surplus_overflow`: phase F's preferred sink) and
**Active** (inactive jobs are left out of the build and the targets grid).

Removed from the form in Sep 2026, columns left in place and unread:
**Productivity rate / unit of measure** (nothing used them), **Exclude from
staffing targets grid** (`exclude_from_targets`: it only hid the job's row — any
targets the job already had were still staffed, just no longer visible; every
active job now gets a row), and the two keep-covered boxes above. The update
route only writes a nullable column the form actually sends, so saving the form
leaves these columns as they are.

---

## Why the period engine was removed

A second placement engine (`periodEngine.ts`, the "Automated Schedule Builder V2"
card) ran for most of Sep 2026. It answered the team lead's complaint that this
engine moves people between jobs inside a couple of hours, by giving each person
one function per stretch between breaks.

The team lead judged its schedules worse, and the numbers agree. Ten dev days, same
inputs, measured before removal:

| | this engine (kept) | period engine |
|---|---|---|
| unmet, all functions | 239h | 240h |
| unmet on priority 1–2 functions | **34h** | **96h** |
| unmet on priority 3 functions | 171h | 115h |
| people changing job mid-stretch | 136 | 40 |

Total coverage was a tie, but the period engine let the functions the floor ranks
highest go short: priority was only a score term there, where this engine fills in
strict priority order. It also ignored `surplus_overflow` (it checked "keep doing
what they already do" first, and almost everyone already had a function).

**The trade that came back with it:** this engine moves 11–16 people a day to a
different job mid-stretch, nearly always at an hour boundary where a target
changes. The harness's **BOUNCING** line measures it. If that becomes the complaint
again, fix it inside this engine without giving up strict priority.

## Business priority (`staffing_priority`, migration 018)

Set per job function in **Team Setup -> Job Functions -> Edit**. 1 = Critical (fill
first) ... 5 = Optional (drop first), default 3 = Normal.

Priority *leads* the fill order; scarcity breaks ties inside a priority band, so
genuinely hard-to-staff roles are still protected relative to their peers.

**Why it was needed.** Scarcity is a supply heuristic, not a business one. Measured:
Projects (14 trained / 10 demand = 1.40) looks scarcer than EM9 (49 / 28 = 1.75), so
a short day staffed Projects and left EM9 under target — the opposite of what the
floor wants, because Projects is work that can wait.

**The counter-intuitive part, measured on 2026-08-03:** demoting Projects to 5 did
*nothing* for EM9. Projects released its people, but they flowed to whichever
priority-3 function was scarcest (X4), not to EM9. **Priority is a ranking, not a
transfer** — to move labour *into* a function you must promote that function, not
just demote another.

There is no free coverage. Ranking EM9 to 1 fixed EM9 (26 -> 4 unmet) and made
Conveyor the new victim (12 -> 25); ranking Conveyor too fixed it (-> 3) and pushed
the shortfall onto Pick. **Rank the handful you actually care about and leave one or
two genuine slack functions at 4-5 as designated absorbers.** Expect total unmet to
rise slightly when you force allocation — that is the trade, and it is correct if
the ranked function matters more than the total.

---

## The review modal

Every build ends in one short result window (`pages/schedule/tomorrow.vue`), shaped
by `generateV2Schedule()` into a `BuildOutcome` so the page only renders. Sep 2026
redesign — the team lead found the old one wordy: a table repeating the same
sentence per row, an explanatory paragraph per section, and a "Show details" toggle.
Now, most urgent first, with nothing hidden:

1. **Headline** - "Schedule saved" and one line: "Tue, Sep 29 · 41 people scheduled ·
   1 off all day". Zeros are left out; "N with no work" appears, in amber, only when
   it is not zero.
2. **Things to fix** - the only part styled to demand attention. One short sentence
   each, plus a link to where it is fixed (Rules & Targets, Required Assignments,
   Employees & Training, Job Functions, Shifts). Fed by the engine's own `actions`
   (`EngineResult.actions`, `PreparedInput.actions`), **never** by pattern-matching
   message text.
3. **Still short** (total hours) - one row per job and reason: its time windows on
   one line, "(2 people)" only where more than one was missing, and a few-word reason
   ("everyone trained was on other work"). Then one muted **Whole floor** row: the
   hours no schedule could cover, as merged windows. Or "Every target is covered."
4. **Extra coverage** (total hours) - chips per job, no explanation.

✕ closes and stays on the page (to fix something and build again); **View
schedule** opens the day that was built, even if the date picker has moved since.

**A build that produced nothing** shows "Schedule not built · nothing was saved" and
the reasons in red, each linked. That includes **a failed load**: every input is
checked, and if employees, shifts, targets, training, required assignments, shift
swaps or time off cannot be loaded, nothing is built. The shared loaders turn a
failed request into an empty list, so this used to read as "No active shifts found",
or quietly build without anyone's required assignments or time off.

Every figure is **headcount-hours**, every 15 minutes added up. Until Sep 2026 the
extra-coverage chips added up each stretch's *peak* number of extra people and
labelled it hours, and the summary line did the same with shortfalls — it read
"about 3.8 hours" on a day that was 17.5 hours short.

**Keep `actions` and `warnings` distinct when adding a message.** `actions` means a
person must change something in the app - missing training, an unassigned shift, a
stale target cell - and each is `{ message, fix }`, where `fix` (`FixPlace`) is the
page the window links to. `warnings` is context with nothing to do, and shows as a
small grey line; almost nothing uses it any more (the off-all-day count is now a
number, `PreparedInput.offAllDay`). Everything used to be one yellow list, so a
clean build read as a page of problems and the single item that needed a human sat
at the bottom in the same colour as the good news.

Write messages for a supervisor at a site that did not build this app: no
"headcount-hours", "surplus deployed", "pin" or "shortfall". Use
`EngineEmployee.displayName` ("First Last") in a sentence; `name` is "Last, First"
and is for lists and the grid.

## Staffing Targets grid (Rules & Targets)

`pages/admin/business-rules.vue`. Hour columns come from the team's **active
shifts** (never hardcode the range — see the note in `CONTEXT.md`), and the table
foots with a per-hour summary:

- **Targeted** — the column total, computed from the *inputs* rather than the saved
  rows, so the effect of an edit shows before you save.
- **On shift** — people whose shift covers any part of that hour.
- **Spare** — the difference; red when negative, amber at zero.

**On shift ignores time off, breaks and lunch, on purpose.** This grid is a
planning template with no date attached, so there is no PTO to apply. A specific
day can be tighter: on 2026-09-01 this grid showed +14 spare at 4PM while the day
itself was 3 short, because the 12pm shift takes lunch at 16:00. A build's result
window shows the day as it really is. The "On shift" hour rule is
`utils/shiftHours.ts`, shared with Team Setup → Training Matrix.

## The dated coverage preview (removed Sep 2026)

Create Schedule used to carry a "Training & Coverage Preview": for one date, spare
trained people per job and hour after time off, breaks and lunch
(`GET /api/schedule/coverage-preview`, which ran the engine's `prepare()`). It moved
to Team Setup and then, at Michael's request, became the **Training Matrix** — a
static view of training depth from regular shifts, with a per-job training target
([CONTEXT.md](./CONTEXT.md#training-matrix-team-setup)). The endpoint went with it;
nothing in the builder used either. Lessons for any dated view that comes back:

- **Keep it in people, not hours.** A day-long hours total read *+59h spare* on
  2026-09-01 while the floor was *3 people short at 11AM*.
- **Show the worst 15 minutes beside the hourly figure.** The same day ran
  `+2 +3 +5 0 -3 +18 ...` hourly but `+2 -2 -12 0 -8 +1 ...` at the worst
  quarter-hour; break and lunch cliffs are invisible otherwise.

## Reading a build result

Most "gaps" are not the builder's fault. Attribution of the 141 missed
slot-headcount on a real 2026-08-03 build, before the shift-envelope clip:

| cause | share |
|---|---|
| target set outside any shift | 21% |
| whole-floor break/lunch cliff | 24% |
| floor genuinely short of bodies | 42% |
| pinned coordinator, unmovable | 13% |
| **builder placing someone wrong** | **0%** |

Assigned headcount equalled on-clock headcount at all 96 slots — zero idle labour.
Before treating a gap as an engine bug, check whether anyone was actually available.

**Operational fixes usually beat engine changes.** Staggering the 09:45 and 19:00
breaks is worth ~31 slot-headcount on a typical day and is the only thing that helps
a function whose shortfall sits entirely inside a break cliff — no priority setting
can reach it.

---

## Gotchas that bite

**Builds are scoped to one team** (since Aug 2026). The builder fetches inputs through
the normal team-scoped APIs, and `getTeamFilter` now returns the caller's own team for
everyone, super admins included. A super admin builds for a different site by switching
team in Settings.

Before that fix a super admin read **every team's** employees, targets and training at
once and then wrote the result into their own team. With two sites that either failed
the whole save (job functions are matched by NAME, so a shared name like "Pick" resolved
to the wrong team's record and the training trigger rejected it) or silently put another
site's people on this site's board (when the name existed at only one site). Orphaned
`team_id = NULL` rows are no longer unioned in either.

**Targets are a MINIMUM, not a cap.** Surplus above target is deployed and
*reported*, never suppressed. The "Extra coverage" chips in the review modal are
expected output, not an error.

**Three DB triggers can reject a save**, and one bad row fails the whole
transaction: training (Meter-parent aware), no overlapping assignments per
employee/day, and duration >= 15 minutes (migration 017; was 30).

**`scripts/sim-builder.mjs` used to contain a *duplicate* of the algorithm** and
drifted from it, so engine changes were judged against code that was never shipped.
It now bundles the real source with esbuild and calls it, and holds no scheduling
logic of its own. Keep it that way: if a metric needs engine logic, the logic
belongs in the engine.

---

## Validating a change

**→ Full guide: [TESTING.md](./TESTING.md).** The short version:

```bash
node scripts/sim-builder.mjs 2026-08-03                   # the first team
node scripts/sim-builder.mjs 2026-08-03 --team "Site B"   # a specific team
```

The harness replays real DB rows through the **real** engine and prints idle hours,
functions/person, unmet and over-target per function, **fixable unmet** — unmet
demand at a moment when a trained person was free and idle — and **bouncing**, the
stretches between breaks that carry more than one function. Fixable is the engine's
own miss; a large unmet with zero fixable is simply a short floor. Because
`prepare()` fixes the input order, it builds exactly the schedule the app would —
checked row for row against a real build in Sep 2026.

Run the same date before and after the change and confirm **zero functions made
worse**. A lower *total* unmet is not automatically better — `staffing_priority`
deliberately trades total coverage for covering the right things, so read the
per-function breakdown, not the headline.

Validate training against the `employee_training` table as the DB trigger reads it,
never against an engine's own notion of training, which cannot catch a training bug
by construction. For anything that renders, also run `node scripts/ui-smoke.mjs`.

---

**Last Updated**: September 2026
