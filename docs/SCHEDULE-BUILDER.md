# Schedule Builder

The most-used feature. **One pipeline, two placement engines**, deterministic —
no LLM, no constraint solver. Launched from two cards on
`pages/schedule/tomorrow.vue`:

| Card | Engine | Places |
|---|---|---|
| Automated Schedule Builder | `engine.ts` (slot engine) | 15-minute runs, wherever a run closes the most unmet demand |
| Automated Schedule Builder V2 | `periodEngine.ts` (period engine) | one function per **stretch between breaks** — see [Period engine](#period-engine-builder-v2) |

| | |
|---|---|
| Code | `utils/scheduleEngineV2/` (pure, DB-free) + `composables/useScheduleBuilderV2.ts` |
| Time model | 96 x 15-minute slots |
| Placement | cost function scored over every candidate |
| Business priority | `job_functions.staffing_priority` |
| Explains gaps | per-gap cause + pre-flight feasibility |

Both engines share `prepare()`, required pins, the cost weights, block merging,
gap explanation and stats. Those live **once**, exported from `engine.ts`, and
the period engine imports them. Two copies of any of them is the drift this repo
keeps paying for — extend the shared function, don't fork it.

It writes through `POST /api/schedule/replace` (transactional delete + insert for
the date) and surfaces a review modal before anything is written.

> **A second engine, "V1", was deleted in Aug 2026** after the team lead confirmed
> this one schedules better. It lived in `composables/useAIScheduleBuilder.ts`,
> modelled the day in hourly buckets, and was the default for most of the app's
> life. The `V2` still in the directory and composable names is that history —
> there is nothing to compare against any more. The pre-flight "Build Schedule"
> checklist went with it; the Coverage Preview on the same page supersedes it.

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
  PTO. Modelling breaks explicitly on the grid is what makes the break cliff visible.
- `scarcity` = trained supply / total demand, per function.
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

Callers must pass it — `useScheduleBuilderV2`, `coverage-preview.get.ts` and
`scripts/sim-builder.mjs` all query `shift_swaps` for the date. PTO hour
accounting has always honoured swaps (`getEffectiveShift` in `ptoUsage.ts`); the
scheduling side now agrees with it.

**Phase B — required pins.** `preferred_assignments` with `is_required`, honouring
`preferred_assignment_blocks`. A pin whose employee lacks the training is **skipped
with a warning**, not committed — the DB trigger would reject it and fail the entire
save. (This actually happened: one bad pin failed a 204-row save at row 113.)

A row with **no blocks** uses the legacy AM/PM columns, by the same rule the Rules &
Targets page applies when it converts one on edit: AM = shift start to lunch, PM =
lunch end to shift end, both NULL = base function all day, one NULL = that half
unpinned. Until Sep 2026 `prepare()` pinned the base function all day and never
read the PM column — "X4 mornings, EM9 afternoons" ran X4 all day, and 4 of the 7
live pins on the dev data were of that shape. Pins are resolved in `prepare()` for
both engines; only `prepare()` may read those columns.

**Phase C — feasibility, before anything is assigned.** For every slot with demand,
compare against trained people actually free. Produces "19:00 needs 19, only 2
trained people are available" up front. This is the diagnostic that would have
surfaced the break cliff months earlier.

**Phase D — coverage fill.** Functions ordered `priority` then `scarcity`; within a
function, the **hardest run first** (fewest candidates), not the longest. Measured
failure this fixes: V2 used to fill the easy multi-hour runs first, committing
everyone to long blocks, then had nobody free for the 15 minutes when a whole shift
was on break. Every cell lost to the old hourly engine sat on a break or lunch
boundary. Scarcity is
re-evaluated after every single placement.

**Phase E — cliff patching.** Whatever unmet runs remain are the break/lunch cliffs.
Same `priority` then `scarcity` order.

**Phase F — surplus deployment.** Targets are a MINIMUM, not a cap. Remaining labour
goes to under-target functions, then `surplus_overflow` sinks, then continuation of
something they already do. **Zero-target functions are eligible** — in V1, anyone
trained only on such a function (TL, coordinator) got a silently empty day.

**Phase G — merge** touching same-employee/same-function blocks.

**Phase H — gaps, over-target, explanations.** Every gap gets a *cause*, not just a
flag: `no-one-trained-on-shift` / `all-trained-busy` / `capped` / `no-availability`.
This relies on an `originallyFree` snapshot taken before any assignment — without it
the engine cannot tell "everyone was on break" from "everyone was busy", because
both look identical once `free` has been consumed.

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
| `breakCover` | 100 | extra per break/lunch slot closed on a function flagged to stay covered through it |

Both engines score with these weights — `scoreCandidate()` in the slot engine and
`score()` in the period engine apply the same terms to a run or a whole period.

## Keeping a function covered through breaks and lunch

**The builder does not, by default, treat a hole during a 15-minute break or the
lunch window as a gap.** The team lead's rule: when a whole shift goes on break,
the floor does not expect Pick to be staffed for those fifteen minutes, and listing
34 such holes on every build buried the two or three a supervisor could act on.

Two checkboxes per job function (Team Setup → Job Functions → Edit) say "this one
matters enough to keep staffed through it": **Keep covered during 15-minute
breaks** (`break_coverage_required`) and **Keep covered through lunch**
(`lunch_coverage_required`). These columns existed from migration 006 but were
never read by any engine and had no live editor until Sep 2026.

How it works, in `prepare()`: every function gets a `mustCover` mask (0 inside a
break/lunch window it is *not* flagged for) and a `keepCovered` mask (1 inside a
window it *is* flagged for). Demand itself is untouched, so blocks still span the
window rather than fragmenting around it. Then:

- **Not flagged (default):** shortfalls inside the window are not scored, not
  chased by either engine, not reported as gaps, not counted by the feasibility
  check or the harness. Placement is otherwise unchanged.
- **Flagged:** those shortfalls count, and closing one earns `breakCover` on top of
  `unmet` — enough to pull a person from another shift onto that function across
  the window instead of onto something with more open slots. A shortfall that
  remains becomes a **thing to fix**, by name and time: "Help desk is set to stay
  covered during breaks, but nobody trained for it is free 09:45–10:00. Train
  someone on a different shift, or stagger that break."
- **No 15-minute blocks are created either way.** Coverage comes from someone on a
  different shift holding the function through the window.

Reality check the builder states rather than hides: at 19:00 the only people not on
break are the two on the 4pm shift, so a flagged function is coverable then only if
one of those two is trained on it.

`flexibility` is the biggest lever on a tight day: it spends specialists first and
keeps multi-skilled people free for whichever hole appears next.

---

## Period engine (Builder V2)

`utils/scheduleEngineV2/periodEngine.ts`, added Sep 2026. The team lead's
complaint about the slot engine: people are moved between job functions inside a
couple of hours. **Measured on three real days: 21 of 164 stretches between breaks
carried two functions and 15-18 people bounced**, nearly always at an hour
boundary where a target changed — the engine chasing hourly targets inside a
two-hour stretch.

**The unit of assignment is the period**: a maximal on-clock stretch between
breaks, lunch, PTO and required pins — exactly the unit a supervisor thinks in.
Each step picks the single best (person, period, function) across the whole floor
and commits the whole period.

- **Period-first, not function-first.** A first prototype walked functions in
  priority order and handed each the best period. It cost +29h unmet, because a
  priority-2 function took a 7AM person's whole first period for 45 minutes of
  need and startup, which exists only in that hour, got nobody. Choosing the best
  pair globally is within 1-3h of the slot engine.
- **One split per period, at an hour boundary, both pieces at least
  `PERIOD_MIN_STINT_MINUTES` (45).** Strict "never split" leaves startup empty
  every day: the 7AM stretch is 07:00-08:45 and startup is one hour, and a
  60-minute floor cannot cut that stretch either. At 45 the only splits left are
  that case. Set the constant to `null` for strict.
- **Phases E (cliff patching) and the surplus loop are gone.** Leftover periods
  get one function each: under-target first, then continuation of what the person
  already does, then an overflow sink, then anything they are trained on.

**Measured, 2026-09-03 (same inputs):**

| | slot engine | period engine |
|---|---|---|
| unmet | 45.0h | 46.3h |
| stretches with 2+ functions | 21 of 164 | 4 of 164 |
| people who switch mid-stretch | 15 | 4 |
| people on a single function all day | 22 | 32 |

**The trade to know about: coverage moves between functions.** Pick improves by
~5h and Runner by ~3h; **Locus goes from 1.25h short to 7.75h short.** Locus needs
one extra person for 11:00-12:00 only, and a person on Pick for the whole
10:00-12:30 stretch no longer hops over for that hour. Raising the priority weight
or scaling it per unmet slot recovered at most 1.5h of that, doubled the
switching and hurt EM9, so **no priority knob was added**. If a one-hour target
blip matters, the fix is in the Rules & Targets grid (smooth the blip to the
period), not in the engine.

The harness prints a **BOUNCING** line for both engines; that number and the
per-function A/B are what to read when touching this engine.

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

Every build ends in a review modal, structured **action-first**:

1. **Headline** - "Schedule created" plus one plain line of counts
   ("204 assignments - everyone has work - all reachable targets met"). A count is
   only spelled out when it is bad: "everyone has work" replaces "0 employees with
   no work".
2. **Things to fix** - the only part styled to demand attention. Fed by the
   engines' own `actions` list (`EngineResult.actions`, `PreparedInput.actions`),
   **never** by pattern-matching the note text.
3. **Show details** (collapsed) - gaps table, extra coverage, and informational
   notes in grey.

**Keep `actions` and `warnings` distinct when adding a message.** `actions` means a
person must change something in the app - missing training, an unassigned shift, a
stale target cell. `warnings` is context with nothing to do. Everything used to be
one yellow list, so a clean build read as a page of problems and the single item
that needed a human sat at the bottom in the same colour as the good news.

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
planning template with no date attached, so there is no PTO to apply. That means
it will disagree with the Training & Coverage Preview, which *is* dated and does
model breaks and lunch — on 2026-09-01 this grid showed +14 spare at 4PM where the
preview showed -3, because the 12pm shift takes lunch at 16:00. Both are right for
the question they answer. Send anyone asking "can we actually cover Tuesday?" to
the preview.

## Training & Coverage Preview

The panel on Create Schedule, fed by `GET /api/schedule/coverage-preview`
(`components/schedule/CoveragePreview.vue`). **One heatmap: spare trained people,
every job, every hour.**

Read a row as *is training the limit here*, not *how many people are there*. The
same person appears in every row they are trained for, so the figures do not add
up across rows and were never meant to.

The API still returns `totals` (spare people with everyone counted once, the
whole-floor check). The panel no longer renders it — the endpoint keeps it because
the engine's gap explanations use the same arithmetic.

**Everything is in people.** The panel used to open with three summary cards in
**hours** (target demand / labour available / buffer) above a grid in **people**,
and on 2026-09-01 the two disagreed: the cards read *+59h spare* while the floor
was *3 people short at 11AM*. Both were true — a day-long hours total cannot
answer an hour-by-hour question. The cards are gone; **do not reintroduce an hours
figure here.**

**Deliberately stripped to the grid** over several passes (Aug 2026): the summary
cards, two written answer lines, per-row "N spare at 8AM" labels, the band
descriptions and the whole-floor row were each removed on request. The heatmap is
the interface; resist re-adding prose around it.

**One heatmap ramp, capped at 16+.** `heatClass()` colours every cell in both
bands. The cap is deliberate: measured on real data 46% of cells sit above 16 and
the range runs to +44, so a linear ramp would spend its colour on the difference
between +18 and +44 — which nobody acts on — and flatten 0–7, where every decision
lives. Cells with no target that hour stay **off the ramp** so an absent target
never reads as data.

Every cell honours the **Hourly / Worst 15 min** toggle, and the difference is
large: on 2026-09-01 the whole-floor figure runs `+2 +3 +5 0 -3 +18 ...` hourly but
`+2 -2 -12 0 -8 +1 ...` at the worst quarter-hour. Same day, best moment versus
worst — the gap is break and lunch timing.

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
*reported*, never suppressed. A "Staffed Above Target" list in the review modal is
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
node scripts/sim-builder.mjs 2026-08-03                   # both engines, A/B'd
node scripts/sim-builder.mjs 2026-08-03 --engine period   # one engine
node scripts/sim-builder.mjs 2026-08-03 --team "Site B"   # a specific team
```

The harness replays real DB rows through the **real** engines and prints idle hours,
functions/person, unmet and over-target per function, **fixable unmet** — unmet
demand at a moment when a trained person was free and idle — and **bouncing**, the
stretches between breaks that carry more than one function. Fixable is the engine's
own miss; a large unmet with zero fixable is simply a short floor.

A/B the same date with one variable changed and confirm **zero functions made
worse**. A lower *total* unmet is not automatically better — `staffing_priority`
deliberately trades total coverage for covering the right things, so read the
per-function breakdown, not the headline.

Validate training against the `employee_training` table as the DB trigger reads it,
never against an engine's own notion of training, which cannot catch a training bug
by construction. For anything that renders, also run `node scripts/ui-smoke.mjs`.

---

**Last Updated**: September 2026
