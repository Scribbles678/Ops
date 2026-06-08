---
description: scheduling-app-v2 project context, architecture, and coding standards
alwaysApply: true
---
# CLAUDE.md — Operations Scheduling Tool

Guidance for working in this repo. Keep this file tight and high-signal; put depth in `docs/`.
**When architecture, the data model, or the builder changes, update this file and `docs/CONTEXT.md` in the same change.**

## What this is

A self-hosted, multi-tenant **distribution-center workforce scheduling app** (internal tool, Abbott-branded). Nuxt 4 SPA + Nitro API + PostgreSQL 16, single container + Postgres. Deployed on Rancher/Kubernetes. Treat it as a production app at work — real schedules depend on it.

**Read `docs/CONTEXT.md` first** — canonical technical reference (architecture, data model, auth, the Automated Builder, deployment). Also: `docs/ROLES.md` (permissions), `docs/RANCHER-DEPLOYMENT.md` (deploy).

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
| Server / TS / composable / type change | `npm run build` (this is the typecheck — there is no test suite) |
| SQL / new migration | Apply `setup.sql` + every migration against a throwaway Postgres (harness below). A bad migration crashloops the pod on deploy. |
| UI / page / component | `npm run dev`, exercise the actual screen; don't reflexively run a full build for a copy tweak |
| Anything writing rows | Confirm `team_id` is stamped via `getWriteTeamId` and the right team can read it back |

There is **no SSH/PM2 and no automated tests** here. Changes reach prod only via git → GitHub org → ARC runner → Rancher (pipeline still being finalized). Never claim something is "verified in prod" you didn't run.

*These guidelines are working if: fewer unrequested changes in diffs, fewer rewrites from overcomplication, and clarifying questions arrive before implementation rather than after a bad deploy.*

---

## Commands

```bash
npm run dev      # local dev server (localhost:3000)
npm run build    # production build — ALSO your typecheck
docker compose up -d   # app + Postgres locally; app self-bootstraps schema + admin
```

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

- **Reads** → `getTeamFilter(user)`: `null` for super admins (see ALL teams), else `user.team_id`. Used in `WHERE team_id = $X`.
- **Writes** → `getWriteTeamId(user)`: ALWAYS `user.team_id`, super admins included. Used to STAMP `team_id` on new rows.

**Never stamp an INSERT with `getTeamFilter`** — for a super admin it returns `null`, orphaning the row (only super admins read `NULL` rows). This exact mistake caused a real "team lead can't see what was set up" bug. New write endpoint → `getWriteTeamId`. New read/scope filter → `getTeamFilter`. `team-settings` and `team-blocked-dates` writes require a team and 400 without one.

## Database & migrations

- **Self-bootstrapping** (`server/plugins/bootstrap.ts`): on boot, under a Postgres advisory lock, applies `sql-schema/setup.sql` if absent, then every `sql-schema/migrations/*.sql` in filename order, then seeds the first super admin if `user_profiles` is empty.
- **Every migration must be idempotent** (`CREATE/ALTER ... IF NOT EXISTS`, `ON CONFLICT`, guarded `DO` blocks) — they re-run on every deploy.
- **Adding a migration:** create `sql-schema/migrations/NNN-short-name.sql` (next zero-padded number). Ships in the image, auto-applies next deploy — no manual SQL. **Schema-first:** the migration that adds a column must ship in the same image as the code that writes it.
- **Data-mutating migrations are high-stakes** (they run on every boot and a failure crashloops the pod). Guard one-time data changes with a marker so they can't re-run, and validate on the throwaway Postgres first.
- **DB triggers enforce invariants** — know they'll reject bad writes: employee must be trained for the assigned function (Meter-parent aware), no overlapping assignments per employee/day, assignment ≥ 30 min, no past-dated shift swaps.

## Domain notes that bite

- **"Meter" job functions:** parent `Meter` fans out to children `Meter 1`, `Meter 2`, …; training on parent `Meter` qualifies for any `Meter N`. Matched by regex `/^Meter [0-9]+$/`, scoped to the function's `team_id`. Implemented in BOTH the builder and the `validate_assignment_training` trigger — keep them in sync.
- **Automated Schedule Builder** (`composables/useAIScheduleBuilder.ts`, ~900 lines): deterministic (not an LLM), "two-halves" (AM/PM per employee). Pipeline: prep → PTO clipping → break carve-out → Meter fan-out → required assignments → most-constrained-first greedy fill against per-hour `staffing_targets` → lunch/break coverage pass → gap report. Output reviewed in a modal, then written via transactional delete+insert (`/api/schedule/replace`). **Read the full step-by-step in `docs/CONTEXT.md` before changing it.**

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
