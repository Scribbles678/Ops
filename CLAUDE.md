# CLAUDE.md

Guidance for working in this repo. Keep this file tight and high-signal; put depth in `docs/`.

## What this is

A self-hosted, multi-tenant **distribution-center workforce scheduling app** (internal tool, Abbott-branded). Nuxt 4 SPA + Nitro API + PostgreSQL 16. Deployed on Rancher/Kubernetes.

**Read `docs/CONTEXT.md` first** — it's the canonical technical reference (architecture, data model, auth, the Automated Builder, deployment). Also: `docs/ROLES.md` (permissions), `docs/RANCHER-DEPLOYMENT.md` (deploy).

## Commands

```bash
npm run dev      # local dev server (localhost:3000)
npm run build    # production build — ALSO your typecheck (there is no test suite)
docker compose up -d   # app + Postgres locally; app self-bootstraps schema + admin
```

There is **no automated test framework**. Verify changes by: (1) `npm run build` for type/compile safety, (2) manual testing in `npm run dev`, (3) for SQL/migrations, run against a throwaway Postgres (see below).

## Architecture essentials

- **Nuxt 4, SSR disabled** (`ssr: false`). Pages in `pages/`, shared logic in `composables/`, server in `server/`.
- **Nitro file-based API**, method-suffixed: `server/api/<resource>/index.get.ts`, `[id].put.ts`, etc.
- **Raw `pg`, no ORM.** All SQL is hand-written, parameterized (`$1, $2…`). Pool + `query()` + `transaction()` in `server/utils/db.ts`.
- **Auth:** custom JWT in an HttpOnly cookie. `server/middleware/auth.ts` populates `event.context.user`; routes gate with `requireAuth` / `requireAdmin` / `requireSuperAdmin` from `server/utils/authorize.ts`.
- **Frontend talks to the API via `$fetch`** inside composables; components stay thin.

## ⚠️ Multi-tenancy: the #1 gotcha

Every data table has `team_id`. There are **two different helpers and they are NOT interchangeable**:

- **Reads** → `getTeamFilter(user)`: `null` for super admins (see ALL teams), else `user.team_id`. Used in `WHERE team_id = $X`.
- **Writes** → `getWriteTeamId(user)`: ALWAYS `user.team_id`, super admins included. Used to STAMP `team_id` on new rows.

**Never stamp an INSERT with `getTeamFilter`** — for a super admin it returns `null`, which orphans the row (no team can see it; only super admins read `NULL` rows). This exact mistake caused a real "team lead can't see what was set up" bug. When you add a new write endpoint, use `getWriteTeamId`. When you add a read/scope filter, use `getTeamFilter`.

`team-settings` and `team-blocked-dates` writes require a team and 400 if the user has none.

## Database & migrations

- **Self-bootstrapping** (`server/plugins/bootstrap.ts`): on boot, under a Postgres advisory lock, it applies `sql-schema/setup.sql` if the schema is absent, then every `sql-schema/migrations/*.sql` in filename order, then seeds the first super admin if `user_profiles` is empty.
- **Every migration must be idempotent** (`CREATE ... IF NOT EXISTS`, `ADD COLUMN IF NOT EXISTS`, `ON CONFLICT`, guarded `DO` blocks). They re-run on every deploy.
- **Adding a migration:** create `sql-schema/migrations/NNN-short-name.sql` (next number, zero-padded). It ships in the image and auto-applies on next deploy — no manual SQL.
- **Validate SQL before shipping** (a bad migration crashloops the pod). Quick harness:
  ```bash
  docker run -d --name t -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=scheduling -p 55432:5432 postgres:16-alpine
  # then pipe setup.sql + each migration through: docker exec -i t psql -v ON_ERROR_STOP=1 -U postgres -d scheduling
  ```
- **DB triggers enforce invariants** (don't duplicate the check, but know they'll reject bad writes): employee must be trained for the assigned function (Meter-parent aware), no overlapping assignments per employee/day, assignment ≥ 30 min, no past-dated shift swaps.

## Domain notes that bite

- **"Meter" job functions:** a parent `Meter` fans out to children `Meter 1`, `Meter 2`, … Training on parent `Meter` qualifies for any `Meter N`. Matched by name regex `/^Meter [0-9]+$/`, scoped to the function's `team_id`. The builder AND the `validate_assignment_training` trigger both implement this.
- **Automated Schedule Builder** (`composables/useAIScheduleBuilder.ts`, ~900 lines): deterministic (not an LLM), "two-halves" (AM/PM per employee). Pipeline: prep → PTO clipping → break carve-out → Meter fan-out → required assignments → most-constrained-first greedy fill against per-hour `staffing_targets` → lunch/break coverage pass → gap report. Output reviewed in a modal, then written via transactional delete+insert (`/api/schedule/replace`). **Full step-by-step is in `docs/CONTEXT.md` — read it before changing the builder.**

## Conventions

- Match surrounding style; Tailwind for styling. Abbott brand colors are in `docs/README.md`.
- Reference code as `path:line`.
- Don't touch or print secrets (`.env`, DB dumps in the repo root).
- This is a **production app at work**; changes ship via git → GitHub org → ARC runner → Rancher (pipeline still being finalized). Be deliberate with anything that mutates data on deploy (i.e. migrations).

## Keeping docs honest

When you change architecture, the data model, or the builder, update `docs/CONTEXT.md` (and `README.md` if user-facing) in the same change. The docs are meant to stay authoritative.
