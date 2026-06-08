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
| Auth | JWT (HttpOnly cookies, 8hr expiry), bcryptjs passwords |
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
│   ├── display.vue            # Read-only TV display, auto-refresh every 2 min
│   ├── settings.vue           # User settings, password change, team settings, request rules
│   ├── pto-calendar.vue       # PTO calendar (week/month views) + request approval workflow
│   ├── schedule/
│   │   ├── [date].vue         # Schedule editor with 15-min grid, dashboards, KPI strip
│   │   └── tomorrow.vue       # Create schedule: copy previous day, Automated Builder, or manual
│   └── admin/
│       ├── users.vue          # User/team CRUD (super admin only)
│       ├── business-rules.vue # Staffing targets grid (headcount per job function per hour)
│       └── cleanup.vue        # Data archival, export, retention management
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
│   ├── schedule/
│   │   ├── AssignmentModal.vue       # Create/edit assignment with validation
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
│   ├── useSchedule.ts             # Shifts, assignments, daily targets, batch ops, cleanup
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
│   └── useAIScheduleBuilder.ts    # deterministic schedule generation (scarce-first fill + surplus deploy)
├── server/
│   ├── plugins/
│   │   └── bootstrap.ts          # On-boot self-setup: schema + migrations + first admin
│   ├── api/
│   │   ├── auth/              # login, logout, me (get/put), change-password, forgot/reset-password
│   │   ├── schedule/          # [date].get/delete, assignments CRUD, batch, copy, replace, export
│   │   ├── employees/         # CRUD + training endpoints
│   │   ├── job-functions/     # CRUD
│   │   ├── shifts/            # CRUD
│   │   ├── staffing-targets/  # GET (by team), POST (bulk upsert), [id].delete
│   │   ├── daily-targets/     # Get by date, upsert
│   │   ├── target-hours/      # Get/save default target hours
│   │   ├── business-rules/    # CRUD (legacy)
│   │   ├── preferred-assignments/ # CRUD
│   │   ├── pto/               # Get by date, create, delete
│   │   ├── pto-calendar/      # Aggregated calendar view (PTO + approved/pending requests)
│   │   ├── schedule-requests/ # Unified request CRUD with auto-approval engine + admin override
│   │   ├── shift-swaps/       # Get by date, create, delete
│   │   ├── teams/             # CRUD
│   │   ├── team-settings/     # Per-team key/value settings (request-rule limits)
│   │   ├── team-blocked-dates/ # Per-team blocked dates CRUD
│   │   ├── admin/
│   │   │   ├── users/         # CRUD, reset password, toggle status
│   │   │   └── cleanup/       # Stats, run, log
│   │   └── health.get.ts      # Health check endpoint
│   ├── middleware/
│   │   ├── auth.ts            # Reads JWT cookie, populates event.context.user
│   │   ├── cookie-security.ts # Security response headers
│   │   └── rate-limit.ts      # Per-IP rate limiting (200/min default, stricter for auth)
│   └── utils/
│       ├── db.ts              # PostgreSQL pool (singleton), query(), transaction()
│       ├── jwt.ts             # signToken (8hr), verifyToken, COOKIE_NAME
│       ├── authorize.ts       # requireAuth, requireAdmin, requireSuperAdmin, getTeamFilter
│       └── email.ts           # SMTP email via nodemailer
├── middleware/
│   └── auth.global.ts         # Client-side route guard (redirect to /login if unauthenticated)
├── utils/
│   ├── timeSlots.ts           # 15-min slot generation, break detection
│   └── validationRules.ts     # Assignment validation (training, overlap, duration)
├── types/
│   └── database.types.ts      # TypeScript DB types (skeleton)
├── sql-schema/                # PostgreSQL table definitions + triggers + migrations
│   ├── setup.sql              # Full schema bootstrap (applied once on empty DB)
│   └── migrations/            # 001–008 incremental migrations (idempotent)
├── scripts/
│   ├── seed-first-user.js     # Creates initial admin user
│   └── seed-test-data1.js     # Seeds sample data
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
  │     ├── preferred_assignments ←→ job_functions (priority, is_required, AM/PM split)
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
schedule_assignments_archive / daily_targets_archive (retention, 30-day cutoff)
cleanup_log (archival run audit)
```

### Key Tables

| Table | Purpose |
|-------|---------|
| **teams** | Multi-tenant root. name (unique). |
| **user_profiles** | email, username, password_hash, full_name, team_id, is_super_admin, is_admin, is_display_user, is_active, last_login, **employee_id** (optional FK to employees) |
| **password_reset_tokens** | user_id, token_hash, expires_at, used_at (self-service reset) |
| **employees** | first_name, last_name, is_active, shift_id (FK), team_id |
| **job_functions** | name, color_code (#hex), productivity_rate, unit_of_measure, custom_unit, sort_order, **lunch_coverage_required**, **break_coverage_required**, **exclude_from_targets**, **max_headcount** (per-hour ceiling for the builder, NULL=unlimited), **surplus_overflow** (preferred surplus sink), team_id |
| **shifts** | name, start/end time, break_1/break_2/lunch start/end times, is_active, team_id |
| **schedule_assignments** | employee_id, job_function_id, shift_id, schedule_date, assignment_order, start_time, end_time, team_id |
| **employee_training** | employee_id, job_function_id (junction; unique pair) |
| **staffing_targets** | job_function_id, hour_start, headcount, is_active, team_id (primary input to Automated Builder) |
| **preferred_assignments** | employee_id, job_function_id, is_required, priority, **am_job_function_id**, **pm_job_function_id** |
| **pto_days** | employee_id, pto_date, optional start_time/end_time, pto_type (`full_day`/`partial`/`leave_early`/`arrive_late`), notes. `arrive_late` rows store `start_time='00:00:00'`, `end_time=arrival` so the builder clips the morning. No CHECK on pto_type (free text). |
| **schedule_requests** | employee_id, request_type, status, request_date, start/end_time, original/requested_shift_id, approval_rule_results (JSONB), admin_override, rejection_reason, approved_by, submitted_by, created_pto_id, created_swap_id |
| **shift_swaps** | employee_id, swap_date (unique per employee), original_shift_id, swapped_shift_id |
| **daily_targets** | schedule_date, job_function_id, target_units (unique per date+function+team) |
| **target_hours** | job_function_id, target_hours (default per function+team) |
| **team_settings** | team_id, setting_key, setting_value (per-team request-rule limits) |
| **team_blocked_dates** | team_id, blocked_date, reason (auto-rejects requests on that date) |
| **business_rules** | job_function_name, time_slot_start/end, min/max_staff, priority, fan_out (legacy) |
| **cleanup_log** | archival run audit (counts, cutoff_date, success, error_message) |

> All data tables carry a `team_id`. Most tables auto-update `updated_at` via the `update_updated_at_column()` trigger (some use per-table equivalents).

### Database Triggers & Functions

**Triggers** (enforced on write):
- **validate_assignment_time_conflict** — prevents employee double-booking on the same date (overlapping times)
- **validate_assignment_training** — ensures the employee is trained for the assigned function; for `Meter N` it accepts training on the specific child *or* the parent `Meter`, matched within the job function's own `team_id`
- **validate_shift_swap_date** — prevents swaps for past dates
- **update_updated_at_column** (and per-table variants) — auto-update timestamps

**Stored functions** (called explicitly by the app, *not* triggers):
- **cleanup_old_schedules_with_logging()** — archives assignments + daily targets older than 30 days into the `_archive` tables and writes a `cleanup_log` row (invoked by the admin cleanup API)
- **get_cleanup_stats()** — aggregate archival stats for the cleanup page
- **update_employee_training(employee_id, job_function_ids[], team_id)** — replaces an employee's training set in one call

---

## Authentication & Authorization

### Auth Flow
1. User logs in via `/login` → POST `/api/auth/login` → constant-time bcrypt verify → `last_login` updated → JWT set as HttpOnly cookie (`sameSite=strict`, `secure` in production, 8hr maxAge)
2. Every server request → `server/middleware/auth.ts` reads the cookie → verifies JWT → populates `event.context.user`
3. Client middleware (`middleware/auth.global.ts`) redirects unauthenticated users to `/login`. **Display-only (kiosk) users are redirected to `/display` on login and locked there** — the middleware bounces them back to `/display` from any other route.
4. Public routes: `/login`, `/display`, `/reset-password`

The login endpoint always runs a bcrypt comparison (against a dummy hash when the email is unknown) so response timing doesn't leak whether an account exists.

### JWT payload
The signed token carries: `id`, `email`, `username`, `full_name`, `team_id`, `is_admin`, `is_super_admin`, `is_display_user`, `is_active`, `employee_id`. Because `team_id` and roles come from the signed token, they can't be spoofed by the client. (Changing a user's team/role requires re-login to take effect.)

### Role Hierarchy
| Role | Capabilities |
|------|-------------|
| **Super Admin** | All data across all teams, user/team management, cleanup |
| **Admin** | Team-scoped data + approvals; **cannot** create users / reset passwords (super-admin only) |
| **User** | Team-scoped data, schedule viewing/editing |
| **Display User** | Kiosk account: locked to `/display` (today's schedule, read-only) + can submit time-off/schedule-change requests via the display form. Settable as "Display Only" in the user-management role dropdown. |

See `ROLES.md` for the full permission matrix.

### Multi-Tenancy
- Every data table has a `team_id` column
- **Reads** use `getTeamFilter(user)` → `null` for super admins (no filter, see all teams), `user.team_id` for everyone else. API queries append `WHERE team_id = $X` for non-super-admins.
- **Writes** use `getWriteTeamId(user)` → always the user's own `team_id`, **including super admins**. A new record is stamped with the creating user's team so the rest of that team can see it.
  - This split matters: a super admin's *reads* span all teams, but their *saves* land in their own assigned team. A super admin changes which team their saves target by changing their own team assignment in Settings. **Never stamp writes with `getTeamFilter` — for a super admin it returns `null` and orphans the row (no team can see it).** This was the cause of the "team lead can't see what the super admin set up" bug; fixed in migration 009 + the `getWriteTeamId` switch across write endpoints.
  - `team-settings` and `team-blocked-dates` writes require a team and reject the request if the user has none.
- **Orphaned `team_id = NULL` rows are a real hazard.** Rows created before team stamping (or by a migration that didn't match the install's team name — see migration 009) stay invisible to normal team-scoped reads but get **unioned in by any super-admin read** (`getTeamFilter = null`), polluting aggregate views and especially the **Automated Builder** (duplicate/inflated demand). Fixing them is a **per-install data repair**, not a shipped migration — on a single-team install you can adopt NULL rows into that team and dedup; on a multi-team install you must scope NULL rows to the correct team by hand. Do this directly against the target DB (backup first, single transaction), never as an auto-applied migration that blindly stamps NULL → one team.
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

### Automated Schedule Builder (`useAIScheduleBuilder.ts`)

A deterministic, dependency-free algorithm (not an LLM, no solver). Core design principle: **per-hour staffing targets are a MINIMUM, not a cap.** After targets are met, remaining available labor is deployed so workers aren't left idle; surplus above target is reported (not suppressed). Each employee's day is built from break-free availability **windows** (derived from AM = shift start→lunch, PM = lunch→shift end, minus breaks), and the builder favors **long contiguous, low-switch** assignments (≈1–4 functions/person/day).

> Redesigned June 2026, replacing the original "two-halves demand-cap greedy" (which capped at demand and left large idle gaps + understated coverage). If you're touching this, read `buildSchedule()` end-to-end.

**Inputs:**
- Active employees (with `shift_id` and training records)
- Job functions, incl. "Meter" parent/child relationships, coverage flags, and surplus controls **`max_headcount`** (per-hour ceiling, NULL = unlimited) + **`surplus_overflow`** (preferred sink flag)
- Shifts (start/end + lunch_start/lunch_end + break_1/break_2 windows)
- `staffing_targets` (headcount per job function per hour — the per-hour MINIMUM target)
- `preferred_assignments` (with `is_required` lock flag and optional AM/PM split via `am_job_function_id` / `pm_job_function_id`)
- `pto_days` for the target date (full-day and partial-day)

**Algorithm flow** (`buildSchedule()`):

1. **STEP 0 — Employee prep:** active employees with shifts + training; compute AM/PM blocks; build `trainedFunctionIds`.
2. **PTO application:** full-day PTO removes the employee; partial-day clips AM/PM blocks (invalidating <30-min fragments).
3. **Break carve-out:** split each block around `break_1`/`break_2` into availability windows, dropping sub-30-min fragments.
4. **Meter fan-out expansion:** parent functions with numbered children distribute headcount evenly across children (numeric sort; duplicate names deduped to oldest).
5. **Target & coverage matrices:** `target[jfId][hour] = headcount` (overwrite, not sum — `(jfId,hour)` is unique per the data model); a running `covered[jfId][hour]` counter; plus `maxHeadcount[jfId]` and an `overflowFns` set.
6. **STEP 1 — Required pins:** `is_required` employees locked to their function (AM/PM-specific), split around breaks; counted into `covered`. `resolveMeterChild()` picks the best Meter variant.
7. **PASS 1 — scarce-first target fill:** functions processed in order of `trainedSupply ÷ totalDemand` ascending (hard-to-staff roles like Help desk claim their few trained people first). For each function's first contiguous **unmet, fillable** run (`covered < target` AND `covered < max`), pick the best trained employee/block: score = block length + stickiness + preferred bonus − (other trained functions × weight). Respects `capRoom`. Repeats until no fillable candidate remains.
8. **STEP 2.5 — Lunch/break coverage pass:** for `lunch_coverage_required`/`break_coverage_required` functions, insert a coverer for the primary's lunch/break window (greedy longest-overlap, skipping coverers on their own break). Coverage assignments do **not** count toward target coverage. Unfillable coverage → warning.
9. **PASS 2 — surplus fill:** deploy any remaining availability so nobody's idle. Priority per window: (a) **still-under-target** functions first (meeting targets beats overflow), else (b) **overflow-flagged** functions (the surplus sink), else (c) continue an existing function. Soft cap of `MAX_FUNCTIONS = 4` distinct functions/person; per-hour `max_headcount` always respected (a fully-capped worker is left idle).
10. **PASS 3 — merge:** merge touching same-employee, same-function blocks into one segment (collapses break-split fragments).
11. **STEP 3 — gaps & over-target:** from final `covered` vs `target`: `covered < target` → gap (warning); `covered > target` → over-target surplus (skipped for `exclude_from_targets` functions, whose required pins would otherwise read as "over" a zero target).

**Outputs:** `{ schedule, warnings, errors, gaps, overTarget }`. `applyAISchedule()` maps function names → IDs and calls `replaceScheduleForDate()` (transactional delete+insert).

**Entry point:** `pages/schedule/tomorrow.vue` → `generateAISchedule(date)`; the user reviews the proposed schedule, gaps, and a "Staffed Above Target" (over-target) summary in a modal before it's written.

**Validation harness:** `scripts/sim-builder.mjs` (local-only, dev DB creds) replays real DB inputs through an equivalent algorithm and prints quality metrics (idle hours, functions/person, gaps, over-target, fixable-gap detector). Use it to validate target/training/cap changes before relying on a build. Keep its logic in sync with `buildSchedule()`.

> **Builder gotcha — super-admin reads span all teams.** The builder fetches its inputs via the normal team-scoped APIs, which for a **super admin** use `getTeamFilter = null` → it reads **every team's** employees/targets/training at once. With one team that's fine; with multiple teams a super admin would build a cross-team schedule. Also beware **orphaned `team_id = NULL` rows** (created before team stamping): a super admin's build unions them in, inflating/duplicating demand. (A local install hit exactly this — see the consolidation note under Multi-Tenancy.)

### Schedule Requests & Auto-Approval Engine

`schedule_requests` is a unified pipeline for `leave_early`, `pto_full_day`, `pto_partial`, `shift_swap`, `leave_on_time`, and `arrive_late` (the `request_type` CHECK constraint enumerates these — a new type needs a migration; see 011). When a request is submitted (`POST /api/schedule-requests`), an auto-approval engine runs **inside a transaction** and instantly sets status to `approved` or `rejected`:

> **`leave_on_time`** (decline overtime) is informational: it runs only the 24h-advance + date-not-blocked rules, counts 0 PTO hours, and creates **no** downstream record. **`arrive_late`** (late start) runs the full rule set, counts a flat ~2h toward the daily PTO-hours limit (like `leave_early`), and on approval materializes a `pto_days` row (`start='00:00:00'`, `end=arrival`, `pto_type='arrive_late'`) so the builder clips the employee's morning. Both the POST engine and the admin-override PUT materialize identically.

**Rules evaluated** (a request is approved only if all applicable rules pass):
- **24h advance notice** — request_date must be ≥ 24h out (hardcoded)
- **Max leave-early per employee per day** — `team_settings.max_leave_early_per_employee_per_day` (default 1)
- **Max shift-change per employee per day** — `max_shift_change_per_employee_per_day` (default 1)
- **Max PTO hours per day, team-wide** — `max_pto_hours_per_day` (default 8); full-day counts 8h, leave-early 2h, partial = span
- **Max shift swaps per day, team-wide** — `max_shift_swaps_per_day` (default 3)
- **Date not blocked** — for PTO/leave-early, checks `team_blocked_dates`; if blocked, the stored `reason` becomes the rejection message

The per-rule pass/fail map is stored in `approval_rule_results` (JSONB) and a human-readable `rejection_reason` is built from failed rules. On **approval**, the engine materializes the downstream record — a `pto_days` row (for PTO/leave-early) or a `shift_swaps` row — and stores its UUID in `created_pto_id` / `created_swap_id`.

Admins can still override a decision via `PUT /api/schedule-requests/:id` with `admin_override`, which materializes/removes the downstream record accordingly.

### PTO Calendar (`pages/pto-calendar.vue`)

Week or month calendar view combining two sources:
- `pto_days` — approved/committed PTO (full-day or partial-day)
- `schedule_requests` — unified request table (filtered/deduped against already-materialized `pto_days`)

**Data flow:**
1. Page loads `/api/pto-calendar?date_from=...&date_to=...` which joins employee names and returns `{ pto_days, requests }`
2. Deduplicates requests whose `created_pto_id` already appears as a `pto_days` entry
3. Color-codes entries: green = approved, yellow = pending
4. Admins see a pending-request panel with approve/reject buttons → `PUT /api/schedule-requests/:id` with `admin_override`

**Integration with the Automated Builder:** the builder fetches `/api/pto/[date]` (reads `pto_days`, not pending requests) so only approved PTO affects schedule generation.

### Staffing Status Thresholds
- **Critical** — <80% of required hours
- **Understaffed** — 80–95% of required hours
- **Adequate** — 95–105% of required hours
- **Overstaffed** — >105% of required hours

### Validation Rules (enforced client + DB)
- Employee must be trained for the assigned job function (DB trigger, Meter-aware)
- Assignment duration must be ≥ 30 minutes (DB CHECK constraint)
- No overlapping assignments for the same employee on the same date (DB trigger)

### Data Archival
- Schedule assignments and daily targets older than 30 days are moved to `_archive` tables by `cleanup_old_schedules_with_logging()`
- Managed via the admin cleanup page with Excel export before archival; each run logged to `cleanup_log`

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
| 009-backfill-orphaned-team-data | one-time data repair: adopts NULL-team rows into the `domestic` team (see Multi-Tenancy). No-op on fresh installs; runs once via a `_data_backfills` marker. **Note:** hardcodes the `domestic` team name — a no-op on installs whose team is named otherwise (e.g. `Default Team`), so orphaned NULL rows can persist there. |
| 010-add-job-function-surplus-controls | `job_functions.max_headcount` (per-hour ceiling) + `surplus_overflow` (preferred surplus sink) — drive the Automated Builder's PASS 2. Additive/idempotent; multi-team safe. |
| 011-add-request-types | extends `schedule_requests_request_type_check` to add `leave_on_time` + `arrive_late`. Drop+recreate constraint (idempotent); multi-team safe. |

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

**Last Updated**: June 2026
