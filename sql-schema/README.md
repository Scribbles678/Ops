# sql-schema

The database lives here. Two things in this folder are **executed**; everything else
is reference.

| Path | Role |
|---|---|
| `setup.sql` | **Executed.** Full schema bootstrap — applied once, on an empty database. |
| `migrations/*.sql` | **Executed.** Applied in filename order on every boot. |
| `<table>.sql` | Reference only. Snapshots of individual table definitions. |
| `rls-policies.sql`, `get-rls-policies*.sql` | Reference only. |
| `migrate-validate-assignment-training.sql` | Reference only — superseded by migration 005. |

## How schema changes reach production

`server/plugins/bootstrap.ts` runs on every container start. Under a Postgres
advisory lock it applies `setup.sql` if no schema exists, then **every** file in
`migrations/` in filename order, then seeds the first super admin if `user_profiles`
is empty.

There is no migration ledger table. **Every migration re-runs on every boot**, so:

1. **Every migration must be idempotent** — `CREATE/ALTER ... IF NOT EXISTS`,
   `ON CONFLICT`, guarded `DO $$ ... END $$` blocks.
2. **A failing migration crashloops the pod.** Validate before shipping.
3. **Guard one-time data changes with a marker** (the `_data_backfills` pattern used
   by migrations 012 and the deleted 009) so they cannot re-run.
4. **Schema-first:** the migration adding a column must ship in the *same image* as
   the code that writes it.

## Adding a migration

Create `migrations/NNN-short-name.sql` using the next zero-padded number. It ships
in the image and auto-applies on the next deploy — no manual SQL.

**The numbering has an intentional gap at 009.** `009-backfill-orphaned-team-data.sql`
was deleted from the repo in commit c7ed85d (Jun 2026). Do not create a new `009`.

Validate against a throwaway Postgres first:

```bash
docker run -d --name t -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=scheduling \
  -p 55432:5432 postgres:16-alpine
# pipe setup.sql, then each migration in order, through:
docker exec -i t psql -v ON_ERROR_STOP=1 -U postgres -d scheduling
```

## Current migrations

| File | Adds |
|---|---|
| 001-add-staffing-targets | `staffing_targets` |
| 002-add-schedule-requests | `schedule_requests` |
| 003-add-team-settings | `team_settings` |
| 004-add-password-reset-tokens | `password_reset_tokens` |
| 005-fix-meter-parent-lookup | fixes `validate_assignment_training` Meter parent lookup |
| 006-add-coverage-requirements | `lunch_coverage_required` / `break_coverage_required` |
| 007-add-team-blocked-dates | `team_blocked_dates` |
| 008-add-missing-columns | `user_profiles.employee_id`, `job_functions.exclude_from_targets`, AM/PM columns |
| ~~009~~ | **deleted — do not reuse this number** |
| 010-add-job-function-surplus-controls | `max_headcount`, `surplus_overflow` |
| 011-add-request-types | adds `leave_on_time` + `arrive_late` to the request-type CHECK |
| 012-explicit-half-assignments | one-time backfill, marker-guarded |
| 013-add-required-assignment-blocks | `preferred_assignment_blocks` |
| 014-remove-database-cleanup | drops the cleanup procedures + `cleanup_log`; **keeps** the `_archive` tables |
| 015-add-performance-tracking | `performance_errors`, `performance_notes` |
| 016-add-note-tag | `performance_notes.tag` |
| 017-lower-assignment-minimum | assignment CHECK 30 min → **15 min** |
| 018-add-staffing-priority | `job_functions.staffing_priority` (1–5, default 3) |

Full descriptions and rationale: [../docs/CONTEXT.md](../docs/CONTEXT.md#migrations-sql-schemamigrations).

## Triggers to know about

These reject writes at the database level — the app cannot talk them out of it, and
one bad row fails the whole transaction:

- `validate_assignment_training` — employee must be trained for the function
  (accepts training on the parent `Meter` for a `Meter N` child, matched within the
  function's own `team_id`)
- `validate_assignment_time_conflict` — no overlapping assignments per employee/day
- `check_schedule_assignment_min_duration` — assignment ≥ 15 minutes
- `validate_shift_swap_date` — no swaps for past dates
- `update_updated_at_column` and per-table variants — timestamps

## Stale tables in the reference files

Some `<table>.sql` snapshots predate current schema and are not regenerated
automatically. When a definition matters, read `setup.sql` plus the migrations, or
query the database — those are authoritative.

---

**Last Updated**: August 2026
