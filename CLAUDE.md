---
description: scheduling-app-v2 project context, architecture, and coding standards
alwaysApply: true
---
# CLAUDE.md — Operations Scheduling Tool

Guidance for working in this repo. Keep this file tight and high-signal; put depth in `docs/`.
**When architecture, the data model, or the builder changes, update this file and the matching `docs/` file in the same change.**

## What this is

A self-hosted, multi-tenant **distribution-center workforce scheduling app** (internal tool, Abbott-branded). Nuxt 4 SPA + Nitro API + PostgreSQL 16, single container + Postgres. Deployed on Rancher/Kubernetes. Treat it as a production app at work — real schedules depend on it.

**Read `docs/CONTEXT.md` first** — architecture, data model, auth, deployment. Then, by area:

| Doc | When |
|---|---|
| `docs/CONTEXT.md` | Architecture, directory map, data model, triggers, migrations ledger, env vars |
| `docs/SCHEDULE-BUILDER.md` | **Anything touching either builder engine.** Both pipelines, the V2 cost function, `staffing_priority`, how to validate a change |
| `docs/PTO-AND-REQUESTS.md` | **Anything touching PTO, requests, availability or the Employee Overview.** The hours model and the shared modules |
| `docs/ROLES.md` | Permissions, team isolation |
| `docs/TESTING.md` | **How to verify a change.** The four tiers, the engine harness, the browser smoke test, multi-tenancy checks |
| `docs/RANCHER-DEPLOYMENT.md` | Deploying |

Each topic has exactly one home. If you find yourself restating an algorithm in a second file, link instead — the builder used to be documented in three places and all three drifted.

---

## How I should work on this codebase

**Tradeoff:** these bias toward caution over speed. For trivial tasks, use judgment. For anything touching the schedule builder, multi-tenancy/`team_id`, auth, or DB schema/migrations, follow them strictly.

### 1. Think before coding
**Don't assume. Don't hide confusion. Surface tradeoffs.**
- State assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- Before a change that ships to the deployed app, know what it touches: which endpoints, which tables, whether it needs a migration. This file + `docs/CONTEXT.md` are the map; if the map is wrong, fix it as part of the change.

### 2. Simplicity first
**Minimum code that solves the problem. Nothing speculative.**
- No features beyond what was asked. No abstractions for single-use code. No config layer/flag/env var for a one-shot fix.
- No error handling for impossible scenarios — only at boundaries (user input, the API edge, DB calls).
- If you write 200 lines and it could be 50, rewrite it. Ask: *would a senior engineer call this overcomplicated?* If yes, simplify.

### 3. Surgical changes
**Touch only what you must. Clean up only your own mess.**
- Don't "improve" adjacent code, comments, or formatting. Don't refactor what isn't broken. Match existing style even if you'd do it differently.
- Remove imports/variables YOUR changes made unused; leave pre-existing dead code (mention it, don't delete it).
- The test: every changed line traces directly to the request.

### 4. Goal-driven execution
**Define verifiable success criteria. Loop until met.**
- "Improve the builder" → "for date X with these targets, output has zero gaps for Picking and no employee scheduled through their lunch; confirm in dev."
- For multi-step work, state a brief plan with a verify step per item. Strong criteria let you loop independently; "make it work" forces constant clarification.

### 5. Verify before done
Run the **smallest verification tier that applies**, then report what ran, what passed, and what was skipped.

| Change | Default check |
|--------|---------------|
| Server / TS / composable / type change | `npm run build` (this is the typecheck — there is no unit test suite) |
| **Either builder engine** | `node scripts/sim-builder.mjs <date>` — replays real DB rows through the real engines. Compare before/after; **zero functions made worse** is the bar |
| **UI / page / component** | `node scripts/ui-smoke.mjs` — drives the real browser, fails on any JS error, screenshots every screen. **Then look at the screenshots.** A build compiles a page that renders nonsense |
| SQL / new migration | Apply `setup.sql` + every migration against a throwaway Postgres (below). A bad migration crashloops the pod on deploy |
| Anything writing rows | Confirm `team_id` is stamped via `getWriteTeamId` and the right team can read it back |
| Anything touching `team_id` / scoping | Log in as the Site B fixtures and confirm isolation — see `docs/TESTING.md` |

**→ `docs/TESTING.md` is the full guide.** Passing `npm run build` proves only that it
compiles; it says nothing about whether the screen renders correctly or the schedule
got worse.

There is **no SSH/PM2 and no unit tests** here. Changes reach prod only via git → GitHub org → ARC runner → Rancher (pipeline still being finalized). Never claim something is "verified in prod" you didn't run.

*These guidelines are working if: fewer unrequested changes in diffs, fewer rewrites from overcomplication, and clarifying questions arrive before implementation rather than after a bad deploy.*

---

## Commands

```bash
npm run dev      # local dev server (localhost:3000, falls back to 3001 if taken)
npm run build    # production build — ALSO your typecheck
docker compose up -d   # app + Postgres locally; app self-bootstraps schema + admin

node scripts/sim-builder.mjs 2026-08-03   # engine harness: real data, real engines, quality metrics
node scripts/ui-smoke.mjs                 # browser smoke test (needs: npm i --no-save playwright-core)
```

⚠ The `docker compose` **app** service builds from source and is often stale; while it
runs it holds port 3000 and silently pushes `npm run dev` to 3001. `docker compose stop app`
unless you are deliberately testing the container.

Throwaway-Postgres harness for validating SQL/migrations before they ship:
```bash
docker run -d --name t -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=scheduling -p 55432:5432 postgres:16-alpine
# pipe setup.sql then each migration in order through:
docker exec -i t psql -v ON_ERROR_STOP=1 -U postgres -d scheduling
```

---

## Architecture essentials

- **Nuxt 4, SSR disabled** (`ssr: false`). Pages in `pages/`, shared logic in `composables/`, server in `server/`.
- **Nitro file-based API**, method-suffixed: `server/api/<resource>/index.get.ts`, `[id].put.ts`, etc.
- **Raw `pg`, no ORM.** All SQL hand-written and **parameterized** (`$1,$2…`) — never string-concatenate input into SQL. Pool + `query()` + `transaction()` in `server/utils/db.ts`.
- **Auth:** custom JWT in an HttpOnly cookie. `server/middleware/auth.ts` populates `event.context.user`; routes gate with `requireAuth` / `requireAdmin` / `requireSuperAdmin` from `server/utils/authorize.ts`.
- **Frontend talks to the API via `$fetch`** inside composables; components stay thin.

## ⚠️ Multi-tenancy: the #1 gotcha

Every data table has `team_id`. Two helpers, **not interchangeable**:

- **Reads** → `getTeamFilter(user)`: **always `user.team_id`, super admins included.** Used in `WHERE team_id = $X`. Super admins no longer read across every team — they move between teams via Settings → Change Team, which re-issues the session token so the switch applies immediately.
- **Install-wide reads** → `readsAllTeams(user)`: the *explicit* opt-out for the genuinely cross-team screens (user management). Never get an unscoped read another way.
- **No team = no data.** Both helpers throw 403 for an account with no team — reads fail closed rather than returning an unfiltered query, writes fail rather than creating a `team_id = NULL` orphan. Every account must have a team; create-user enforces it. Only super admins may change a team.
- **Writes** → `getWriteTeamId(user)`: ALWAYS `user.team_id`, super admins included. Used to STAMP `team_id` on new rows.

**Keep reads and writes on the same helper.** New write endpoint → `getWriteTeamId`. New read/scope filter → `getTeamFilter`. They now return the same team, but the names carry the intent and the split is what stops a future "reads everything, writes to one team" bug — which is exactly what broke the builder before Aug 2026.

## Database & migrations

- **Self-bootstrapping** (`server/plugins/bootstrap.ts`): on boot, under a Postgres advisory lock, applies `sql-schema/setup.sql` if absent, then every `sql-schema/migrations/*.sql` in filename order, then seeds the first super admin if `user_profiles` is empty.
- **Every migration must be idempotent** (`CREATE/ALTER ... IF NOT EXISTS`, `ON CONFLICT`, guarded `DO` blocks) — they re-run on every deploy.
- **Adding a migration:** create `sql-schema/migrations/NNN-short-name.sql` (next zero-padded number). Ships in the image, auto-applies next deploy — no manual SQL. **Schema-first:** the migration that adds a column must ship in the same image as the code that writes it.
- **Data-mutating migrations are high-stakes** (they run on every boot and a failure crashloops the pod). Guard one-time data changes with a marker so they can't re-run, and validate on the throwaway Postgres first.
- **DB triggers enforce invariants** — know they'll reject bad writes: employee must be trained for the assigned function (Meter-parent aware), no overlapping assignments per employee/day, **assignment ≥ 15 min** (migration 017; the V2 *builder* still only emits ≥ 30 min — the gap is deliberate), no past-dated shift swaps.
- **One bad row fails the whole save.** Builder output is written as a single transaction, so one untrained pin aborts all 200+ assignments. Validate before writing, don't rely on the trigger to sort it out.

## Domain notes that bite

- **"Meter" job functions:** parent `Meter` fans out to children `Meter 1`, `Meter 2`, …; training on parent `Meter` qualifies for any `Meter N`. Matched by regex `/^Meter [0-9]+$/`, scoped to the function's `team_id`. Implemented in BOTH the builder and the `validate_assignment_training` trigger — keep them in sync.
- **Automated Schedule Builder — ONE engine.** `utils/scheduleEngineV2/` (pure, DB-free) + `composables/useScheduleBuilderV2.ts`. Deterministic — no LLM, no solver. 96 x 15-minute slots, cost function, `staffing_priority`. **Per-hour `staffing_targets` are a MINIMUM, not a cap**: after targets are met surplus labour is deployed and over-target is *reported*, not suppressed. Writes via `POST /api/schedule/replace` (transactional delete+insert). **Read `docs/SCHEDULE-BUILDER.md` before changing it.**
  - A second engine ("V1", `composables/useAIScheduleBuilder.ts`) was **deleted Aug 2026** after the team lead confirmed this one schedules better. The `V2` left in the directory and composable names is history, not a choice — there is nothing to compare against. The pre-flight "Build Schedule" checklist went with it; the Coverage Preview supersedes it.
  - Builds are scoped to the caller's current team (Aug 2026). Previously they read every team and wrote to one, which put another site's people on this site's board.
  - The engine returns **`actions`** (a person must fix this) separately from **`warnings`** (context). The review modal leads with actions. Never classify by matching message text.
  - `scripts/sim-builder.mjs` bundles and calls the **real** engine. It holds no scheduling logic — keep it that way. See `docs/TESTING.md`.
- **PTO hours have exactly one implementation** — `server/utils/ptoHours.ts` (with `ptoUsage.ts` and `requestRules.ts`). The approval rule and the availability strip both route through it. They used to compute hours separately and drifted, which made the displayed "hours left" disagree with what approval allowed. `utils/ptoDisplay.ts` is the same deal for *reading* a `pto_days` row — `leave_early` stores a NULL end and `arrive_late` stores `00:00:00` as its start, so anything reading those columns literally gets two of the four types wrong. See `docs/PTO-AND-REQUESTS.md`.
- **Duplicate implementations are this repo's recurring failure mode.** The PTO strip, `ptoTimeLabel`, `sim-builder.mjs` and the two builder engines each drifted from their twin; all four have since been collapsed to one implementation. When you find one rule in two places, extract it — don't patch both.

## Code quality

1. No magic numbers — named constants.
2. Handle NULLs explicitly (especially `team_id`, optional shift/lunch/break times).
3. Error handling at boundaries only — `throw createError({ statusCode, message })` in API routes; don't guard impossible states.
4. Prefer set-based / batched DB writes over row-by-row loops where practical.
5. No stray debug `console.log` in committed code; keep intentional `console.error` for real failures.
6. Never hardcode secrets — everything via env. Don't touch or print `.env` or DB dumps in the repo root.

## When uncertain — how to check

- **Schema / a column's type?** → `sql-schema/setup.sql` + `migrations/`, or query the throwaway Postgres.
- **What an endpoint returns / how team scoping works?** → read the route in `server/api/...` + `server/utils/authorize.ts`.
- **Will this build?** → `npm run build`. **Will this migration apply?** → run it on the throwaway Postgres.
- **Is a change live?** → only after a deploy through the ARC pipeline. Local edits are not in prod.

---

## Response style

- Be precise and concise — no filler.
- Show full file paths as markdown links: `[authorize.ts:65](server/utils/authorize.ts#L65)`.
- When proposing changes: show the diff, explain the *why*, flag downstream impacts (other endpoints, the builder, migrations).
- When writing a new endpoint: include the TS interface, the Nitro route handler, and any migration SQL.
- Flag NULL / edge cases proactively.
- If uncertain about existing behavior, say so and suggest how to verify (which file, which query) — don't guess.
