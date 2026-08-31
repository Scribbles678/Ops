# Project Context: Operations Scheduling Tool (scheduling-app-v2)

## Overview

A distribution center scheduling application for managing employee work assignments across shifts, job functions, and time slots. Multi-tenant system with team-based data isolation and role-based access control. Deployed self-hosted (Docker / Rancher-Kubernetes) with no third-party service dependencies.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Nuxt 4 (SPA mode, SSR disabled) |
| Frontend | Vue 3 with composables for state management |
| Styling | Tailwind CSS |
| Server | Nitro (file-based API routes with method suffixes) |
| Database | PostgreSQL 16 (direct `pg` library, no ORM) |
| Auth | JWT (HttpOnly cookies, 8hr expiry; 30d self-renewing for display/kiosk accounts), bcryptjs passwords |
| Email | Nodemailer (SMTP) for password resets (optional) |
| Export | xlsx for Excel export |
| Deployment | Docker Compose / Rancher (Kubernetes) / Netlify |

---

## Directory Structure

```
scheduling-app-v2/
├── app.vue                    # Root component (renders <NuxtPage />)
├── nuxt.config.ts             # Nuxt config (SSR off, Tailwind, runtime config)
├── pages/
│   ├── index.vue              # Dashboard/home with navigation cards
│   ├── login.vue              # Email/password login
│   ├── reset-password.vue     # Two-step password reset (request + token)
│   ├── training.vue           # Employee training matrix (checkboxes per job function)
│   ├── details.vue            # Tabbed config: job functions, shifts, employees, productivity
│   ├── display.vue            # Read-only wall/iPad board, auto-refresh every 2 min.
│   │                          #   Sized for DISTANCE reading, not a desktop dashboard.
│   │                          #   Chip text colour comes from measured WCAG contrast
│   │                          #   (getTextColor) - see the note under Display Board.
│   ├── settings.vue           # User settings, password change, team settings, request rules
│   ├── pto-calendar.vue       # PTO calendar (week/month views) + request approval workflow
│   ├── schedule/
│   │   ├── [date].vue         # Schedule editor with 15-min grid, dashboards, KPI strip
│   │   └── tomorrow.vue       # Create schedule: 4 cards (copy previous day, Automated
│   │                          #   Builder, manual, Rules & Targets) + Coverage Preview
│   └── admin/
│       └── business-rules.vue # Staffing targets grid (headcount per job function per hour).
│                          #   Hour columns are derived from the team's ACTIVE SHIFTS,
│                          #   plus any hour that still carries a target (shaded, so a
│                          #   stale row stays clearable). Never hardcode the range.
│                              # NOTE: users.vue and cleanup.vue were DELETED. User
│                              #   management lives inline in settings.vue; the
│                              #   Database Cleanup feature was removed (migration 014).
├── components/
│   ├── details/                      # ⚠ LEGACY / UNUSED — none of these *Tab.vue
│   │   │                             #   components are referenced. The Details page
│   │   │                             #   (pages/details.vue) is monolithic: the Job
│   │   │                             #   Functions / Shifts / etc. editors are inline
│   │   │                             #   in that file. Edit pages/details.vue, NOT these.
│   │   ├── EmployeesTab.vue          # (unused)
│   │   ├── JobFunctionsTab.vue       # (unused) — real job-function editor is inline in pages/details.vue
│   │   ├── ProductivityRatesTab.vue  # (unused)
│   │   ├── ShiftManagementTab.vue    # (unused)
│   │   └── ShiftsTab.vue             # (unused)
│   ├── employee/
│   │   └── Overview.vue              # Employee Overview dashboard (hours/function, PTO,
│   │                                 #   rolling error chart, performance notes)
│   ├── schedule/
│   │   ├── AssignmentModal.vue       # Create/edit assignment with validation
│   │   ├── CoveragePreview.vue       # Pre-build coverage grid on Create Schedule
│   │   ├── HorizontalSchedule.vue    # Horizontal timeline view
│   │   ├── LaborHoursPanel.vue       # Scheduled vs required hours per job function
│   │   ├── ScheduleGrid15Min.vue     # Dense 15-min grid editor (rows=employees, cols=time)
│   │   ├── ShiftBasedSchedule.vue    # Shift-oriented schedule view
│   │   └── ShiftGroupedSchedule.vue  # Grouped by shift schedule view
│   └── schedule-requests/
│       ├── RequestFormModal.vue      # Submit PTO/leave-early/shift-swap request
│       └── RequestResultBanner.vue   # Shows auto-approval/rejection result
├── composables/
│   ├── useAuth.ts                 # JWT auth: login, logout, fetchCurrentUser, changePassword
│   ├── useEmployees.ts            # Employee CRUD + training data management
│   ├── useJobFunctions.ts         # Job function CRUD + meter grouping helpers
│   ├── useSchedule.ts             # Shifts, assignments, daily targets, batch ops
│   ├── useLaborCalculations.ts    # Hours math, staffing status, time formatting
│   ├── useBusinessRules.ts        # Legacy business rule CRUD (superseded by staffing targets)
│   ├── useStaffingTargets.ts      # Staffing targets CRUD (headcount per function per hour)
│   ├── usePreferredAssignments.ts # Employee-job function preferences/requirements (AM/PM aware)
│   ├── usePTO.ts                  # PTO record management
│   ├── useScheduleRequests.ts     # Unified PTO/leave-early/shift-swap request workflow
│   ├── useShiftSwaps.ts           # Shift swap management
│   ├── useTeam.ts                 # Team CRUD + super admin checks
│   ├── useTeamSettings.ts         # Per-team settings (request-rule limits)
│   ├── useTeamBlockedDates.ts     # Per-team blocked dates for request auto-rejection
│   └── useScheduleBuilderV2.ts    # THE schedule builder — drives utils/scheduleEngineV2/
│                                 #   (a V1 engine was deleted Aug 2026; the "V2"
│                                 #    in the name is history, not a choice)
├── server/
│   ├── plugins/
│   │   └── bootstrap.ts          # On-boot self-setup: schema + migrations + first admin
│   ├── api/
│   │   ├── auth/              # login, logout, me (get/put), change-password, forgot/reset-password
│   │   ├── schedule/          # [date].get/delete, assignments CRUD, batch, copy, replace,
│   │   │                      #   export, coverage-preview
│   │   ├── employees/         # CRUD + training endpoints + [id]/overview
│   │   ├── job-functions/     # CRUD
│   │   ├── shifts/            # CRUD
│   │   ├── staffing-targets/  # GET (by team), POST (bulk upsert), [id].delete
│   │   ├── daily-targets/     # Get by date, upsert
│   │   ├── target-hours/      # Get/save default target hours
│   │   ├── business-rules/    # CRUD (legacy)
│   │   ├── preferred-assignments/ # CRUD
│   │   ├── pto/               # Get by date, create, delete, availability
│   │   ├── pto-calendar/      # Aggregated calendar view (PTO + approved/pending requests)
│   │   ├── schedule-requests/ # Unified request CRUD, auto-approval engine, preview (dry run)
│   │   ├── performance/       # errors/ + notes/ CRUD (picking errors, review notes)
│   │   ├── shift-swaps/       # Get by date, create, delete
│   │   ├── teams/             # CRUD
│   │   ├── team-settings/     # Per-team key/value settings (request-rule limits)
│   │   ├── team-blocked-dates/ # Per-team blocked dates CRUD
│   │   ├── admin/
│   │   │   └── users/         # CRUD, reset password, toggle status
│   │   └── health.get.ts      # Health check endpoint
│   ├── middleware/
│   │   ├── auth.ts            # Reads JWT cookie, populates event.context.user
│   │   ├── cookie-security.ts # Security response headers
│   │   └── rate-limit.ts      # Per-IP rate limiting (200/min default, stricter for auth)
│   └── utils/
│       ├── db.ts              # PostgreSQL pool (singleton), query(), transaction()
│       ├── jwt.ts             # signToken (8hr; 30d for display users), verifyToken, sessionMaxAge, COOKIE_NAME
│       ├── authorize.ts       # requireAuth/Admin/SuperAdmin, getTeamFilter (READS),
│       │                      #   getWriteTeamId (WRITES) — see Multi-Tenancy
│       ├── ptoHours.ts        # SINGLE SOURCE for PTO-hour accounting + business days
│       ├── ptoUsage.ts        # Team hours already committed per date (dedupes requests/pto_days)
│       ├── requestRules.ts    # evaluateRequest() — the auto-approval rule engine
│       └── email.ts           # SMTP email via nodemailer
├── middleware/
│   └── auth.global.ts         # Client-side route guard (redirect to /login if unauthenticated)
├── utils/
│   ├── timeSlots.ts           # 15-min slot generation, break detection
│   ├── validationRules.ts     # Assignment validation (training, overlap, duration)
│   ├── ptoDisplay.ts          # SINGLE SOURCE for reading/displaying a pto_days row
│   └── scheduleEngineV2/      # THE schedule engine — pure, DB-free, unit-testable
│       ├── types.ts           #   constants + weights (ENGINE_MIN 30 vs DB_MIN 15)
│       ├── slots.ts           #   96-slot time helpers
│       ├── prepare.ts         #   Phase A — DB rows -> slot model
│       └── engine.ts          #   Phases B-H — pins, feasibility, fill, surplus, gaps
├── types/
│   └── database.types.ts      # TypeScript DB types (skeleton)
├── sql-schema/                # PostgreSQL table definitions + triggers + migrations
│   ├── setup.sql              # Full schema bootstrap (applied once on empty DB)
│   └── migrations/            # 001–018 incremental migrations (idempotent; no 009 — deleted)
├── scripts/
│   ├── seed-first-user.js     # Creates initial admin user
│   ├── seed-test-data1.js     # Seeds sample data
│   ├── sim-builder.mjs        # Engine harness — bundles the REAL engines with esbuild
│   │                          #   and replays real DB rows. Read-only. See TESTING.md
│   └── ui-smoke.mjs           # Browser smoke test — drives Edge/Chrome, fails on any
│                              #   JS error, screenshots every screen to scripts/.smoke/
└── docs/                      # Project documentation
```

> Note: schema/admin bootstrap is automatic on container boot (`server/plugins/bootstrap.ts`); the `scripts/seed-*` files are for local/manual setup only. The `npm run seed:test-data` script in `package.json` points at `seed-test-data.js`, but the file on disk is `seed-test-data1.js` — adjust the path or filename if you use it.

---

## Data Model

### Core Relationships

```
teams (multi-tenant root)
  ├── user_profiles (auth users, role-based; optional employee_id link)
  ├── team_settings (per-team request-rule configuration)
  ├── team_blocked_dates (dates that auto-reject PTO/leave-early requests)
  ├── employees
  │     ├── employee_training ←→ job_functions (many-to-many)
  │     ├── preferred_assignments ←→ job_functions (priority, is_required; legacy AM/PM split)
  │     │     └── preferred_assignment_blocks (explicit start/end time blocks — the current model)
  │     ├── pto_days
  │     ├── schedule_requests (unified: pto_full_day, pto_partial, leave_early, leave_on_time, arrive_late, shift_swap)
  │     └── shift_swaps (original_shift ↔ swapped_shift)
  ├── shifts (with break/lunch times)
  ├── job_functions (color, productivity rate, sort order, coverage flags)
  ├── schedule_assignments (employee + job_function + shift + date + time range)
  ├── staffing_targets (headcount per job function per hour — drives Automated Builder)
  ├── daily_targets (per date per job function)
  ├── target_hours (default hours per job function)
  └── business_rules (legacy staffing rules — superseded by staffing_targets)

password_reset_tokens (→ user_profiles)
schedule_assignments_archive / daily_targets_archive (frozen history; nothing writes here since migration 014)
performance_errors / performance_notes (→ employees; Employee Overview)
```

### Key Tables

| Table | Purpose |
|-------|---------|
| **teams** | Multi-tenant root. name (unique). |
| **user_profiles** | email, username, password_hash, full_name, team_id, is_super_admin, is_admin, is_display_user, is_active, last_login, **employee_id** (optional FK to employees) |
| **password_reset_tokens** | user_id, token_hash, expires_at, used_at (self-service reset) |
| **employees** | first_name, last_name, is_active, shift_id (FK), team_id |
| **job_functions** | name, color_code (#hex), productivity_rate, unit_of_measure, custom_unit, sort_order, **lunch_coverage_required**, **break_coverage_required**, **exclude_from_targets**, **max_headcount** (per-hour ceiling for the builder, NULL=unlimited), **surplus_overflow** (preferred surplus sink), **staffing_priority** (1=fill first … 5=drop first, default 3; **V2 builder only**), team_id |
| **shifts** | name, start/end time, break_1/break_2/lunch start/end times, is_active, team_id |
| **schedule_assignments** | employee_id, job_function_id, shift_id, schedule_date, assignment_order, start_time, end_time, team_id |
| **employee_training** | employee_id, job_function_id (junction; unique pair) |
| **staffing_targets** | job_function_id, hour_start, headcount, is_active, team_id (primary input to Automated Builder) |
| **preferred_assignments** | employee_id, job_function_id (NOT NULL base), is_required, priority. **Current model: explicit time blocks** in `preferred_assignment_blocks` (see below). Legacy `am_job_function_id`/`pm_job_function_id` columns kept as a fallback for rows without blocks. |
| **preferred_assignment_blocks** | preferred_assignment_id (FK, cascade), start_time, end_time, job_function_id, team_id; `CHECK end_time > start_time`. A required assignment pins an employee to a function per explicit clock-time block (added migration 013). The builder uses these when present, else falls back to the legacy AM/PM columns. |
| **pto_days** | employee_id, pto_date, optional start_time/end_time, pto_type (`full_day`/`partial`/`leave_early`/`arrive_late`), notes. `arrive_late` rows store `start_time='00:00:00'`, `end_time=arrival` so the builder clips the morning. No CHECK on pto_type (free text). |
| **schedule_requests** | employee_id, request_type, status, request_date, start/end_time, original/requested_shift_id, approval_rule_results (JSONB), admin_override, rejection_reason, approved_by, submitted_by, created_pto_id, created_swap_id |
| **shift_swaps** | employee_id, swap_date (unique per employee), original_shift_id, swapped_shift_id |
| **daily_targets** | schedule_date, job_function_id, target_units (unique per date+function+team) |
| **target_hours** | job_function_id, target_hours (default per function+team) |
| **team_settings** | team_id, setting_key, setting_value (per-team request-rule limits) |
| **team_blocked_dates** | team_id, blocked_date, reason (auto-rejects requests on that date) |
| **business_rules** | job_function_name, time_slot_start/end, min/max_staff, priority, fan_out (legacy) |
| **performance_errors** | employee_id, error_date, count/detail — raw picking-error log (admin-only; drives the Employee Overview trend chart) |
| **performance_notes** | employee_id, note text, **tag** (migration 016, powers the quick-add buttons), for reviews |
| **schedule_assignments_archive** / **daily_targets_archive** | historical rows from the removed cleanup feature. **Nothing writes to these any more**, but they hold real history on installs where cleanup ran, so migration 014 deliberately did NOT drop them. The schedule CSV export reads them alongside the live tables. |

> All data tables carry a `team_id`. Most tables auto-update `updated_at` via the `update_updated_at_column()` trigger (some use per-table equivalents).

### Database Triggers & Functions

**Triggers** (enforced on write):
- **validate_assignment_time_conflict** — prevents employee double-booking on the same date (overlapping times)
- **validate_assignment_training** — ensures the employee is trained for the assigned function; for `Meter N` it accepts training on the specific child *or* the parent `Meter`, matched within the job function's own `team_id`
- **validate_shift_swap_date** — prevents swaps for past dates
- **update_updated_at_column** (and per-table variants) — auto-update timestamps

**Stored functions** (called explicitly by the app, *not* triggers):
- **update_employee_training(employee_id, job_function_ids[], team_id)** — replaces an employee's training set in one call

> `cleanup_old_schedules_with_logging()`, `get_cleanup_stats()`, `cleanup_log` and `cleanup_status` were **dropped by migration 014** along with the Database Cleanup feature.

---

## Authentication & Authorization

### Auth Flow
1. User logs in via `/login` → POST `/api/auth/login` → constant-time bcrypt verify → `last_login` updated → JWT set as HttpOnly cookie (`sameSite=strict`, `secure` in production). Expiry: **8hr** normally, **30d** for display/kiosk accounts (`sessionMaxAge()` / `signToken` key off `is_display_user`). The `/display` page slides the session by POSTing `/api/auth/refresh` on every data refresh, so a 24/7 kiosk never logs out; it also reloads + re-checks the date on visibility/focus regain (wake from sleep) and rolls over at midnight.
2. Every server request → `server/middleware/auth.ts` reads the cookie → verifies JWT → populates `event.context.user`
3. Client middleware (`middleware/auth.global.ts`) redirects unauthenticated users to `/login`. **Display-only (kiosk) users are redirected to `/display` on login and locked there** — the middleware bounces them back to `/display` from any other route.
4. Public routes: `/login`, `/display`, `/reset-password`

The login endpoint always runs a bcrypt comparison (against a dummy hash when the email is unknown) so response timing doesn't leak whether an account exists.

### JWT payload
The signed token carries: `id`, `email`, `username`, `full_name`, `team_id`, `is_admin`, `is_super_admin`, `is_display_user`, `is_active`, `employee_id`. Because `team_id` and roles come from the signed token, they can't be spoofed by the client. (Changing a user's team/role requires re-login to take effect.)

### Role Hierarchy
| Role | Capabilities |
|------|-------------|
| **Super Admin** | All data across all teams, user/team management |
| **Admin** | Team-scoped data + approvals; **cannot** create users / reset passwords (super-admin only) |
| **User** | Team-scoped data, schedule viewing/editing |
| **Display User** | Kiosk account: locked to `/display` (today's schedule, read-only) + can submit time-off/schedule-change requests via the display form. Settable as "Display Only" in the user-management role dropdown. |

See `ROLES.md` for the full permission matrix.

### Multi-Tenancy
- Every data table has a `team_id` column
- **Reads** use `getTeamFilter(user)` → **`user.team_id` for everyone, super admins included.** API queries append `WHERE team_id = $X`.
- **Install-wide reads** use `readsAllTeams(user)` — an explicit, named opt-out used only where a screen is genuinely cross-team (user management). Getting an unscoped read any other way is a bug.
- **Writes** use `getWriteTeamId(user)` → always the user's own `team_id`, **including super admins**. A new record is stamped with the creating user's team so the rest of that team can see it.
  - Reads and writes now agree: both use the caller's team. **Until Aug 2026 a super admin's reads spanned every team while their saves landed in one**, and the Automated Builder is where that bit — it read every team's employees, training and targets, then wrote the result into the super admin's own team, putting another site's people on this site's board. A super admin switches team in **Settings → Change Team**, which validates the team, updates the profile AND re-issues the session token (the team is carried in the signed JWT, so updating only the database row left the old team in the cookie until the next login).
  - `PUT /api/auth/me` is a **tenant boundary**, not a profile preference — it is admin/super-admin only. It had no role check at all, so any account, including a kiosk login, could move itself into another team.
  - **Never stamp writes with `getTeamFilter`** — use `getWriteTeamId`. Both now return the caller's team, and **both throw 403 when the account has no team**: reads fail closed (a null filter would have meant "every team") and writes fail rather than stamping `team_id = NULL` and creating a fresh orphan. A team-less account can still sign in and read `/api/auth/me` and `/api/teams`, so a super admin can assign it a team — it is not locked out of the app, only out of data.
  - **Every account must have a team.** The create-user form requires one and `POST /api/admin/users/create` rejects a request without one (validating the team exists). Only a **super admin** may change a team — their own via `PUT /api/auth/me`, anyone's via user management.
  - `team-settings` and `team-blocked-dates` writes require a team and reject the request if the user has none.
- **Orphaned `team_id = NULL` rows are a real hazard.** Rows created before team stamping (or by a migration that didn't match the install's team name — see migration 009) are invisible to every team-scoped read. Since Aug 2026 they are invisible to super admins too, so an install that still has them will see that data simply **disappear** rather than pollute aggregates. Count them per install BEFORE deploying a team-scoping change. Fixing them is a **per-install data repair**, not a shipped migration — on a single-team install you can adopt NULL rows into that team and dedup; on a multi-team install you must scope NULL rows to the correct team by hand. Do this directly against the target DB (backup first, single transaction), never as an auto-applied migration that blindly stamps NULL → one team.
- Enforcement is **API-level**, not database RLS (legacy `rls-policies.sql` is from an earlier Supabase prototype and is not used)

### Rate Limiting (in-memory, per-IP)
- Default: 200 req/min
- Admin routes: 100 req/min
- User creation: 5 req/hour
- Password reset: 3 req/hour

---

## Key Domain Concepts

### Meter Job Functions
"Meter" is a special job function category. Individual meters are named "Meter 1", "Meter 2", etc. Training on the parent "Meter" function qualifies an employee for any "Meter N" assignment. The Automated Builder and the `validate_assignment_training` DB trigger both support this parent-child relationship via name pattern matching (`/^Meter [0-9]+$/`), scoped to the function's `team_id`.

### Coverage Requirements
Job functions can be flagged `lunch_coverage_required` and/or `break_coverage_required` (set in the Details → Job Functions tab). When set, the Automated Builder runs a coverage pass that finds another trained, available employee to cover the primary employee's lunch/break window so the station stays continuously staffed.

### Exclude From Targets
Job functions flagged `exclude_from_targets` are hidden from the staffing-targets grid (used for functions that shouldn't be driven by per-hour headcount demand).

### Automated Schedule Builder

One engine: `utils/scheduleEngineV2/` (pure, DB-free) driven by
`composables/useScheduleBuilderV2.ts`. Deterministic — no LLM, no solver. Treats
per-hour `staffing_targets` as a **MINIMUM, not a cap**, and writes via
`POST /api/schedule/replace`.

A second engine ("V1", `composables/useAIScheduleBuilder.ts`) was **deleted in
Aug 2026** after the team lead confirmed this one schedules better.

**→ How to validate an engine change: [TESTING.md](./TESTING.md).**

**→ Full detail lives in [SCHEDULE-BUILDER.md](./SCHEDULE-BUILDER.md)** — pipelines,
the V2 cost function and weights, `staffing_priority`, the two block minimums, the
shift-envelope clip, gotchas, and how to validate an engine change. That document is
the single source; do not restate the algorithm here or in the root README.

### Schedule Requests, PTO & Availability

`schedule_requests` is a unified pipeline for `leave_early`, `pto_full_day`,
`pto_partial`, `shift_swap`, `leave_on_time` and `arrive_late` (the `request_type`
CHECK constraint enumerates these — a new type needs a migration; see 011). An
auto-approval engine runs inside a transaction on submit and sets `approved` or
`rejected` immediately, storing the per-rule outcome in `approval_rule_results`
(JSONB) and materializing the downstream `pto_days` / `shift_swaps` row.

**Every PTO-hours number comes from `server/utils/ptoHours.ts`. Nothing else may
compute it** — this area has been broken twice by two implementations drifting apart.

**→ Full detail lives in [PTO-AND-REQUESTS.md](./PTO-AND-REQUESTS.md)** — the shared
modules, the hours model, the rule table and settings keys, `pto_days` storage
conventions, the PTO calendar, Employee Overview and performance tracking.

### Staffing Status Thresholds
- **Critical** — <80% of required hours
- **Understaffed** — 80–95% of required hours
- **Adequate** — 95–105% of required hours
- **Overstaffed** — >105% of required hours

### Validation Rules (enforced client + DB)
- Employee must be trained for the assigned job function (DB trigger, Meter-aware)
- Assignment duration must be ≥ **15** minutes (DB CHECK constraint; lowered from 30 by migration 017 so supervisors can make manual quarter-hour tweaks). Note the V2 **builder** still only emits blocks of 30 min or longer — see [SCHEDULE-BUILDER.md](./SCHEDULE-BUILDER.md).
- No overlapping assignments for the same employee on the same date (DB trigger)

### Data Archival — REMOVED
The Database Cleanup feature (tab, page, API routes, composable and stored procedures) was deleted; migration 014 drops the procedures and `cleanup_log`. **Nothing archives automatically any more.** The `_archive` tables were deliberately kept because they hold real history on installs where cleanup once ran, and the schedule CSV export (from the schedule page) reads them alongside the live tables.

---

## Deployment & Bootstrap

The app is **self-bootstrapping** (`server/plugins/bootstrap.ts`): on every container start it acquires a Postgres advisory lock, then:
1. Applies `sql-schema/setup.sql` if no schema is present
2. Applies every `sql-schema/migrations/*.sql` in filename order (all idempotent — `IF NOT EXISTS` / `ON CONFLICT` guards)
3. Seeds the first super admin if `user_profiles` is empty, from `ADMIN_EMAIL` / `ADMIN_PASSWORD` / `ADMIN_NAME` (defaults `admin@example.com` / `admin123`)

This means **no manual SQL on deploy or update** — new migrations ship in the image and apply on next boot. See `RANCHER-DEPLOYMENT.md` for the full guide.

### Migrations (`sql-schema/migrations/`)
| File | Adds |
|------|------|
| 001-add-staffing-targets | `staffing_targets` table (Automated Builder demand) |
| 002-add-schedule-requests | `schedule_requests` unified request table |
| 003-add-team-settings | `team_settings` key/value config |
| 004-add-password-reset-tokens | `password_reset_tokens` (self-service reset) |
| 005-fix-meter-parent-lookup | fixes `validate_assignment_training` Meter parent lookup |
| 006-add-coverage-requirements | `lunch_coverage_required` / `break_coverage_required` on job_functions |
| 007-add-team-blocked-dates | `team_blocked_dates` table |
| 008-add-missing-columns | `user_profiles.employee_id`, `job_functions.exclude_from_targets`, `preferred_assignments.am/pm_job_function_id` |
| ~~009-backfill-orphaned-team-data~~ | **DELETED from the repo** (commit c7ed85d, Jun 2026). It was a one-time NULL-team backfill that hardcoded the `domestic` team name. The gap in numbering is intentional — do not create a new `009`. Orphaned `team_id = NULL` rows may still exist on installs whose team is named otherwise; see Multi-Tenancy. |
| 010-add-job-function-surplus-controls | `job_functions.max_headcount` (per-hour ceiling) + `surplus_overflow` (preferred surplus sink) — drive the Automated Builder's PASS 2. Additive/idempotent; multi-team safe. |
| 011-add-request-types | extends `schedule_requests_request_type_check` to add `leave_on_time` + `arrive_late`. Drop+recreate constraint (idempotent); multi-team safe. |
| 012-explicit-half-assignments | **one-time** backfill (guarded by `_data_backfills` marker): sets NULL `am`/`pm_job_function_id` to `job_function_id` so a NULL half can newly mean "not pinned". Preserves prior behavior; multi-team safe; never re-runs (would clobber intentional NULLs). |
| 013-add-required-assignment-blocks | `preferred_assignment_blocks` table — explicit per-block times for required assignments. Additive only (no backfill); builder reads blocks if present, else legacy AM/PM. Multi-team safe. |
| 014-remove-database-cleanup | Drops `cleanup_old_schedules_with_logging()`, `get_cleanup_stats()`, `cleanup_log`, `cleanup_status`. **Deliberately KEEPS** `schedule_assignments_archive` + `daily_targets_archive` — they hold real history and the CSV export still reads them. |
| 015-add-performance-tracking | `performance_errors` + `performance_notes` tables (admin-only picking-error log and review notes; feed the Employee Overview). |
| 016-add-note-tag | `performance_notes.tag` — powers the quick-add note buttons. |
| 017-lower-assignment-minimum | Lowers the `check_schedule_assignment_min_duration` CHECK from 30 to **15** minutes so supervisors can make manual quarter-hour tweaks. The V2 builder still only *emits* 30-min-or-longer blocks — the gap between the two floors is intentional. |
| 018-add-staffing-priority | `job_functions.staffing_priority` (integer, CHECK 1–5, default 3) — business priority for the **V2** builder. Default 3 means existing behaviour is unchanged until someone sets a value, so this migration cannot alter a schedule on its own. |

---

## Environment Variables

| Variable | Required | Purpose |
|----------|----------|---------|
| `DATABASE_URL` | yes | PostgreSQL connection string |
| `DATABASE_SSL` | no | `false` for in-cluster DB; otherwise TLS is used |
| `DATABASE_SSL_REJECT_UNAUTHORIZED` | no | `false` to allow self-signed DB certs |
| `JWT_SECRET` | yes | JWT signing secret (must be ≥ 32 chars) |
| `NODE_ENV` | recommended | `production` enables `secure` cookies |
| `APP_URL` | no | Base URL for password reset links |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` / `ADMIN_NAME` | no | First-boot admin seed (only when `user_profiles` is empty) |
| `SMTP_HOST/PORT/USER/PASS/FROM` | no | Email sending configuration (password resets) |

---

## Development

```bash
npm install          # Install dependencies
npm run dev          # Start dev server (localhost:3000)
npm run build        # Production build
npm run seed:first-user    # Create initial admin user (local/manual)
npm run seed:test-data     # Seed sample data (see note: file is seed-test-data1.js)
```

### Docker
```bash
docker compose up        # Starts app + PostgreSQL (app self-bootstraps schema + admin)
```

---

**Last Updated**: August 2026
