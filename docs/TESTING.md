# Testing & Verification

There is **no unit test suite**. Verification here is four tiers, each catching a
class of problem the one above it cannot. Use the smallest tier that covers your
change, then say in your report which tiers you ran and which you skipped.

| Tier | Command | Catches |
|---|---|---|
| 1. Build + type check | `npm run build`, then `vue-tsc` (below) | broken imports and syntax; type errors |
| 2. Engine harness | `node scripts/sim-builder.mjs <date>` | schedule quality regressions |
| 3. Browser smoke | `node scripts/ui-smoke.mjs` | render failures, JS errors, wrong-looking screens |
| 4. Migration harness | throwaway Postgres (below) | a migration that crashloops the pod |

**A build passing means nothing rendered correctly.** The banner bug of Aug 2026 —
a perfectly generated schedule reporting "Schedule could not be generated" — compiled
cleanly and was only ever visible in tier 3.

---

## Tier 1 — build, then type check

**`npm run build` does not check types.** Nuxt strips them without checking unless
`typeCheck` is set, and it is not, so a build passes with type errors in it. Check
types separately; nothing needs installing, `npx` fetches the tools:

```bash
npx --yes -p typescript@5.9 -p vue-tsc@3 vue-tsc --noEmit -p .nuxt/tsconfig.app.json
npx --yes -p typescript@5.9 -p vue-tsc@3 vue-tsc --noEmit -p .nuxt/tsconfig.server.json
```

The code is **not** type-clean: about 220 errors in the app and 4 on the server
already exist (Sep 2026), almost all "possibly undefined" from strict index access.
So judge a change by its **own** errors: filter the output to the files you touched,
and any flagged line that exists unchanged in `git show HEAD:<file>` was there before.
The counts should not go up.

---

## Tier 2 — the engine harness (`scripts/sim-builder.mjs`)

Replays **real database rows** through the **real engine** and prints quality
metrics. Read-only; it never writes a schedule.

```bash
node scripts/sim-builder.mjs 2026-08-03                    # the first team
node scripts/sim-builder.mjs 2026-08-03 --team "Site B"    # a specific team
```

It bundles `utils/scheduleEngineV2/` with esbuild and calls the engine directly.
**It contains no scheduling logic of its own** — that is the entire point of its
current shape. Because `prepare()` sorts its own inputs, the harness builds exactly
the schedule the app would (checked row for row against a real build). Before Sep
2026 it loaded rows unordered, and the engine breaks ties by order, so it disagreed
with the app on 10+ people's days.

> Until Aug 2026 this file held a hand-written *copy* of the algorithm. It
> drifted, so engine changes were being judged against code that was never
> shipped. If you ever find yourself re-implementing engine logic here to make a
> number come out, stop: fix the engine or fix the metric.

Availability, demand and Meter fan-out come from the engine's own `prepare()`, so
the scoreboard cannot disagree with it about who was actually free.

It reads **one team**, matching how the app scopes a build.

### Reading the output

```
===== Automated Schedule Builder =====
assignments: 176 | on-clock 307.0h | assigned 306.8h | IDLE 0.3h
distinct functions/person: {"1":23,"2":14,"3":5} | employees with no work: 0
UNMET 20.3h  |  OVER-target 35.0h  |  break/lunch holes not counted: 30.3h
  unmet by function: Help desk 8.0h, Runner 3.8h, Pick 3.5h, Projects 2.0h, speedcell 1.5h, RT-pick 1.5h
  over by function:  RT-pick 8.3h, Locus 7.0h, X4 6.8h, Conveyor 6.5h, speedcell 2.8h, EM9 1.8h, Pick 1.5h, Help desk 0.5h
FIXABLE unmet (a trained person was free and idle): 0.0h  <-- the engine's own misses
BOUNCING: 11 of 164 stretches between breaks carry more than one function | people who switch mid-stretch: 11
    e.g. Smith, Barbara 07:00-08:45: startup 07:00-08:00 > Locus 08:00-08:45
  gaps: 14 | feasibility issues: 1 | things to fix: 0 | notes: 0
```

(2026-09-03 on the dev data, Sep 2026.)

- **IDLE** — on-clock hours nobody was given work for. Should be at or near zero.
- **UNMET** — target headcount-hours not covered, counting only shortfalls the
  floor cares about: a hole during a break or lunch window is reported separately
  as **not counted**. What is left is mostly *not* the engine's fault: targets
  outside shift hours, or simply too few bodies.
- **FIXABLE** — the number that matters. Unmet demand at a moment when a trained
  person was free and unassigned. That is the engine genuinely missing something.
  **Non-zero fixable is a bug; a large UNMET with zero fixable is a short floor.**
- **OVER-target** — expected, not an error. Targets are a minimum, and surplus
  labour is deployed rather than parked.
- **distinct functions/person** — the readability of someone's day. Drifting
  toward 3-4 for everyone means the schedule got choppier.
- **BOUNCING** — stretches between breaks (the free grid straight out of
  `prepare()`) that carry more than one function: someone moved to a different job
  mid-stretch. It runs 7-10% of stretches on the dev data (11-16 people a day); a
  change that raises it makes the floor's day choppier.

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

**"things to fix"** echoes the `actions` from `prepare()` and the engine — the same
items the build-result window leads with. Each `FIX:` line ends with `[where]`, the
page the window links to for it. A non-zero count means a person must change
something in the app (missing training, an unassigned shift, a stale target cell),
not that the engine misbehaved.

To see a state of the build-result window that real data does not produce (a failed
load, missing targets, a skipped required assignment), intercept the request in
Playwright — `page.route('**/api/pto/**', (r) => r.abort())`, or `route.fulfill` with
edited JSON — instead of breaking the database.

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

### Test against a preview server, not the user's dev server

**Do not point browser tests at `npm run dev`.** It is the user's own process, it
may be on a fallback port, and it breaks in ways that look like your bug:

- The `docker compose` **app** container is usually stale and holds port 3000, so
  `npm run dev` silently lands on **3001**. A `200` from 3000 may be a months-old
  build answering you.
- **Deleting a composable leaves Vite serving a stale module graph** — the dev
  server starts returning 500s on assets until it is restarted. Seen for real when
  `useAIScheduleBuilder.ts` was removed.

Instead, build and run the production output on a spare port. It is closer to what
ships, it is yours to restart, and it cannot disturb the user:

```bash
npm run build
curl -s http://localhost:3017/api/health    # must FAIL first: the port has to be free
DATABASE_URL="postgresql://postgres:postgres@localhost:5433/scheduling" DATABASE_SSL=false JWT_SECRET="local-smoke-test-secret-at-least-32-chars-long" NODE_ENV=development PORT=3017 node .output/server/index.mjs &
# Wait until setup is done: /api/health answers 503 "starting up" until then.
curl -sf --retry 30 --retry-all-errors --retry-delay 1 http://localhost:3017/api/health

node scripts/ui-smoke.mjs --base http://localhost:3017
```

**Another Claude session may be working in this repo at the same time**, with its
own preview server. If the port was already taken, the new server logs `EADDRINUSE`
and exits, and your tests then quietly run against the other session's server. So
check the port is free first, as above, and stop only **your** server, by its port:

```powershell
Stop-Process -Id (Get-NetTCPConnection -LocalPort 3017 -State Listen).OwningProcess -Force
```

Never stop servers by matching `server/index.mjs` on the command line: that also
kills the other session's (it happened, Sep 2026). And rebuilding `.output` swaps
the files under any server already running from it, so say so before rebuilding
while another session is active.

Rebuild and restart it after every code change — it serves the built output, so it
will not hot-reload.

**Anything about sign-in or cookies: test on the machine's LAN address too**
(`http://10.x.x.x:3017`), not only `localhost`. Browsers exempt localhost from the
rule that a `Secure` cookie needs HTTPS, so localhost tests passed for months while
the second site, on plain http, could not stay signed in (Sep 2026). To test
destructive or cross-team writes, run the preview against a throwaway copy of the
dev database (`pg_dump` into a scratch Postgres), never against dev itself.

### One-off browser scripts for things the smoke test cannot answer

`ui-smoke.mjs` proves screens render. For anything measurable, write a throwaway
Playwright script in the scratchpad and read real values out of the DOM. This is
how several real bugs in this repo were found rather than guessed at:

- **Tap targets** — `boundingBox()` on the week arrows showed 20x20 against the
  44x44 that Apple's guidance and WCAG 2.5.5 both require.
- **Colour contrast** — reading `getComputedStyle` for every schedule chip and
  computing WCAG ratios showed X4 at **3.68:1**, below the 4.5:1 floor.
- **Real interaction** — `page.tap()` with `hasTouch: true` proved the arrows
  actually paged the week, not just that they existed.

Pattern:

```js
import { chromium } from 'playwright-core'
const browser = await chromium.launch({
  executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
  headless: true,
})
const page = await browser.newPage({ viewport: { width: 1500, height: 1000 } })
page.on('pageerror', (e) => console.log('PAGEERROR:', e.message))
page.on('console', (m) => { if (m.type() === 'error') console.log('CONSOLE:', m.text()) })
// log in, navigate, then measure whatever the change was supposed to affect
```

Always attach the `pageerror` / `console` listeners — a silent JS error is exactly
what a build will not catch.

**Screenshot, then actually open the image.** A pass/fail line does not tell you the
banner is red on a successful build, or that the time is clipped off a chip. Both
were found by looking.

### What to check by hand afterwards

The smoke test proves screens render; it does not know what they *should* say.
After a change, open the affected screen and confirm the numbers are right. For
multi-tenancy work specifically, log in as a second team's user and confirm you
see that team's data and nothing else.

---

## Tier 4 — migrations

A bad migration crashloops the pod on deploy, so validate before shipping:

```bash
docker run -d --name throwaway-pg -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=scheduling \
  -p 55432:5432 postgres:16-alpine
# pipe setup.sql, then every migration in filename order, through:
docker exec -i throwaway-pg psql -v ON_ERROR_STOP=1 -U postgres -d scheduling
docker rm -f throwaway-pg
```

(Docker Desktop on Windows rejects a one-letter container name, hence `throwaway-pg`.)

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
| `admin@example.com` / `admin123` | Super Admin | Default Team |
| `siteb.admin@example.com` / `testpass123` | Supervisor | Site B |
| `lead@example.com` / `testpass123` | Team Lead / Coordinator | Default Team |
| `kiosk@example.com` / `testpass123` | Kiosk | Default Team |
| `tenant.test@example.com` / `testpass123` | **no role** (tests the lock-out) | Default Team |

The kiosk account lands on `/display` and is locked there; use it to test the
request modal as staff see it, including the "Check my requests" UPI lookup.

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

**Last Updated**: September 2026
