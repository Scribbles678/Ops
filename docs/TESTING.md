# Testing & Verification

There is **no unit test suite**. Verification here is four tiers, each catching a
class of problem the one above it cannot. Use the smallest tier that covers your
change, then say in your report which tiers you ran and which you skipped.

| Tier | Command | Catches |
|---|---|---|
| 1. Typecheck | `npm run build` | type errors, broken imports, syntax |
| 2. Engine harness | `node scripts/sim-builder.mjs <date>` | schedule quality regressions |
| 3. Browser smoke | `node scripts/ui-smoke.mjs` | render failures, JS errors, wrong-looking screens |
| 4. Migration harness | throwaway Postgres (below) | a migration that crashloops the pod |

**A build passing means nothing rendered correctly.** The banner bug of Aug 2026 —
a perfectly generated schedule reporting "Schedule could not be generated" — compiled
cleanly and was only ever visible in tier 3.

---

## Tier 2 — the engine harness (`scripts/sim-builder.mjs`)

Replays **real database rows** through the **real engine** and prints quality
metrics. Read-only; it never writes a schedule.

```bash
node scripts/sim-builder.mjs 2026-08-03                  # first team
node scripts/sim-builder.mjs 2026-08-03 --team "Site B"  # a specific team
```

It bundles `utils/scheduleEngineV2/` with esbuild and calls it directly. **It
contains no scheduling logic of its own** — that is the entire point of its
current shape.

> Until Aug 2026 this file held a hand-written *copy* of the algorithm. It
> drifted, so engine changes were being judged against code that was never
> shipped. If you ever find yourself re-implementing engine logic here to make a
> number come out, stop: fix the engine or fix the metric.

Availability, demand and Meter fan-out come from the engine's own `prepare()`, so
the scoreboard cannot disagree with it about who was actually free.

It reads **one team**, matching how the app scopes a build.

### Reading the output

```
assignments: 203 | on-clock 356.0h | assigned 356.0h | IDLE 0.0h
distinct functions/person: {"1":33,"2":16} | employees with no work: 0
UNMET 30.5h  |  OVER-target 62.8h
FIXABLE unmet (a trained person was free and idle): 0.0h  <-- the engine's own misses
  gaps: 40 | feasibility issues: 14 | things to fix: 0 | notes: 0
```

- **IDLE** — on-clock hours nobody was given work for. Should be at or near zero.
- **UNMET** — target headcount-hours not covered. Mostly *not* the engine's fault:
  break cliffs, targets outside shift hours, or simply too few bodies.
- **FIXABLE** — the number that matters. Unmet demand at a moment when a trained
  person was free and unassigned. That is the engine genuinely missing something.
  **Non-zero fixable is a bug; a large UNMET with zero fixable is a short floor.**
- **OVER-target** — expected, not an error. Targets are a minimum, and surplus
  labour is deployed rather than parked.
- **distinct functions/person** — the readability of someone's day. Drifting
  toward 3-4 for everyone means the schedule got choppier.

### Judging an engine change

Run the same date before and after, and compare. Only one variable at a time.

- **Zero functions made worse** is the bar. The tail of the per-function breakdown
  is where a change quietly robs one function to pay another.
- A lower total UNMET is not automatically better: `staffing_priority` deliberately
  trades total coverage for covering the *right* things. Check *which* functions
  went short, not just the total.
- Real example: on 2026-08-03 a priority change raised total unmet by ~1.8h while
  moving the shortfall onto **Projects** (priority 5, the designated absorber) and
  off **X4** and **EM9** (priority 2). That is the priority system working, and the
  headline number alone would have called it a regression.

Validate training against the `employee_training` table as the DB trigger reads
it, never against the engine's own notion of training — that cannot catch a
training bug by construction.

**"things to fix"** echoes the engine's `actions` list — the same items the review
modal leads with. A non-zero count means a person must change something in the app
(missing training, an unassigned shift, a stale target cell), not that the engine
misbehaved.

---

## Tier 3 — the browser smoke test (`scripts/ui-smoke.mjs`)

Drives the real app in a real browser, screenshots every main screen, and **fails
on any uncaught or console JavaScript error**.

```bash
npm i --no-save playwright-core          # one-time, see below
node scripts/ui-smoke.mjs                                  # defaults to :3000
node scripts/ui-smoke.mjs --base http://localhost:3001     # if dev fell back a port
node scripts/ui-smoke.mjs --build --date 2026-09-01        # also RUNS a build
```

Screenshots go to `scripts/.smoke/` (gitignored). **Look at them.** Half the value
is seeing what a supervisor sees; the pass/fail line only proves nothing threw.

`--build` actually generates and **saves** a schedule for `--date`. Point it at a
date you don't mind replacing.

`playwright-core` is deliberately **not** in `package.json`. It is a local dev tool
and has no business being installed during the production image build. It drives
an already-installed Edge or Chrome, so no browser download happens either.

If `npm run dev` reports a port other than 3000 (it falls back when something else
holds the port — a stale `docker compose` app, for instance), pass `--base`.

### What to check by hand afterwards

The smoke test proves screens render; it does not know what they *should* say.
After a change, open the affected screen and confirm the numbers are right. For
multi-tenancy work specifically, log in as a second team's user and confirm you
see that team's data and nothing else.

---

## Tier 4 — migrations

A bad migration crashloops the pod on deploy, so validate before shipping:

```bash
docker run -d --name t -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=scheduling \
  -p 55432:5432 postgres:16-alpine
# pipe setup.sql, then every migration in filename order, through:
docker exec -i t psql -v ON_ERROR_STOP=1 -U postgres -d scheduling
docker rm -f t
```

Migrations re-run on **every** boot, so re-run them twice against the same
database and confirm the second pass is clean. See `CONTEXT.md` for the ledger.

---

## Mock data

`scripts/seed-pto-mock.mjs` fills the PTO calendar with two weeks of realistic
absences so the page can be judged with content in it (`--clear` removes exactly
what it wrote — every row is tagged `[mock]`). See `PTO-AND-REQUESTS.md`.

---

## Multi-tenancy checks

Team isolation is invisible with one team, so the dev database keeps a **second
team ("Site B")** and non-super-admin logins as fixtures:

| Login | Role | Team |
|---|---|---|
| `admin@example.com` / `admin123` | super admin | Default Team |
| `siteb.admin@example.com` / `testpass123` | admin | Site B |
| `tenant.test@example.com` / `testpass123` | user | Default Team |

Site B deliberately has a job function named **`Pick`**, colliding with Default
Team's, because job functions are matched by name on the builder's save path —
a collision is exactly what would break a cross-team build.

Any change touching `team_id`, `getTeamFilter`, `getWriteTeamId` or the builder
should confirm:

1. A super admin sees only their **current** team's data (switch in Settings).
2. A team's admin sees only that team's data and cannot change team.
3. A build writes only rows whose employee, job function and `team_id` all belong
   to one team:

```sql
SELECT (SELECT name FROM teams WHERE id = sa.team_id)  AS row_team,
       (SELECT name FROM teams WHERE id = e.team_id)   AS employee_team,
       (SELECT name FROM teams WHERE id = j.team_id)   AS function_team,
       count(*)
FROM schedule_assignments sa
JOIN employees e     ON e.id = sa.employee_id
JOIN job_functions j ON j.id = sa.job_function_id
WHERE sa.schedule_date = 'YYYY-MM-DD'
GROUP BY 1,2,3;
```

One row, all three columns the same team. Anything else is a leak.

### Before deploying a team-scoping change to work

Orphaned `team_id = NULL` rows are invisible to every team-scoped read, so on an
install that still has them the data appears to **vanish**. Count them on the
target database first, and repair them by hand — never as a shipped migration:

```sql
SELECT 'employees', count(*) FROM employees WHERE team_id IS NULL
UNION ALL SELECT 'schedule_assignments', count(*) FROM schedule_assignments WHERE team_id IS NULL
UNION ALL SELECT 'staffing_targets', count(*) FROM staffing_targets WHERE team_id IS NULL
UNION ALL SELECT 'employee_training', count(*) FROM employee_training WHERE team_id IS NULL
UNION ALL SELECT 'user_profiles', count(*) FROM user_profiles WHERE team_id IS NULL;
```

A team-less **user** is now refused all data (403) — check that list too, and
assign a team before deploying, especially for a kiosk/display account.

---

## The local dev database

```
postgresql://postgres:postgres@localhost:5433/scheduling   (docker: scheduling-app-v2-db-1)
```

`npm run dev` is the source of truth locally. The `docker compose` **app** service
builds an image from source and can be stale — if it is running it also holds port
3000, which silently pushes the dev server to 3001. `docker compose stop app` if
you aren't deliberately testing the container.

---

**Last Updated**: August 2026
