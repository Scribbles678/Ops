# Operations Scheduling Tool

A web-based scheduling application for distribution center operations. Built with Nuxt 4, Vue 3, PostgreSQL, and Tailwind CSS. Runs as a Docker container with no external service dependencies.

## Features

- **Daily Schedule Management** - Visual grid editor for employee assignments with 15-minute granularity
- **Automated Schedule Builder** - Generates the day from staffing targets, training, shifts, required assignments, approved PTO and shift swaps. Deterministic (no LLM, no solver): 96 x 15-minute slots, a cost function over every candidate, pre-flight feasibility, per-gap explanations, and a business-priority matrix (`staffing_priority`) deciding which functions go short first. Targets are a minimum, so surplus labour is deployed (with per-function caps and overflow sinks) rather than parked. Two placement engines share the pipeline: the slot engine, and **Builder V2**, which keeps each person on one job for each stretch between breaks
- **Training & Coverage Preview** - Heatmap on Create Schedule: spare trained people for every job, every hour, before you build
- **Employee Overview** - Per-employee page: hours by function, PTO usage, attendance points (half or full, per date), rolling picking-error trend, and performance notes for reviews
- **Change Log** - Read-only audit of every manual change to a person's record (request approvals/rejections/deletions, hand-entered time off, attendance points, notes, errors) with who did it — for Supervisors, on the PTO Calendar and the Employee Overview
- **Staffing Targets** - Set target headcount per job function per hour in a grid UI
- **Coverage Requirements** - By default a hole during a 15-minute break or lunch is not treated as a gap; flag the few job functions that must stay covered through them and the builder pulls cross-shift people onto them and flags what it cannot cover
- **Employee Training Matrix** - Track which employees are trained for which job functions, with auto-save
- **Required Assignments** - Pin specific employees to specific functions for explicit time blocks (legacy AM/PM rows honoured by splitting at lunch)
- **PTO Calendar** - Week/month calendar of approved time off, with per-day hours itemised by source (approved / call-in / manual) and an admin override workflow
- **Schedule Requests** - Unified pipeline for PTO (full/partial), leave-early, leave-on-time, arrive-late and shift swaps, decided instantly by a rule engine (business-day notice, per-week limits, team PTO-hour caps by weekday, blocked dates)
- **Shift Swap Tracking** - Record and manage shift swaps between employees
- **Copy Schedule** - Replace a target day with today's schedule, trimmed around that day's time off and leaving swapped people off by name
- **Staff self-service** - From the kiosk, an employee types their UPI to see their own requests and whether they were approved
- **Display Mode** - Wall-mounted iPad/TV board of today's schedule, auto-refreshing every 2 min, sized for reading at a distance
- **Multi-Tenant Teams** - Data isolation by team enforced on every request via the signed `team_id`; an account with no team is refused all data
- **Authentication** - JWT-based auth with HttpOnly cookies; four exclusive roles (Super Admin, Supervisor, Team Lead / Coordinator, Kiosk) — an account with no role can do nothing

## Tech Stack

- **Frontend**: Nuxt 4 / Vue 3 / Tailwind CSS
- **Backend**: Nitro server (file-based API routes with method suffixes)
- **Database**: PostgreSQL 16 (direct `pg` library, no ORM)
- **Auth**: Custom JWT with bcrypt password hashing
- **Deployment**: Docker (multi-stage build), Kubernetes/Rancher ready

## Quick Start (Local Development)

### Using Docker Compose (recommended)

```bash
# Start the app + database
docker compose up -d

# First time only: seed the admin user
docker compose run --rm seed

# Open in browser
open http://localhost:3000
```

Default login: `admin@example.com` / `admin123`

### Manual Setup

```bash
# Prerequisites: Node.js 20+, PostgreSQL 16+

# Install dependencies
npm install

# Set up environment
cp .env.example .env
# Edit .env with your DATABASE_URL and JWT_SECRET

# Run the database schema
psql $DATABASE_URL -f sql-schema/setup.sql

# Seed the first admin user
node scripts/seed-first-user.js

# Start dev server
npm run dev
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection string | `postgresql://postgres:postgres@localhost:5432/scheduling` |
| `DATABASE_SSL` | Enable SSL for DB connection | `false` |
| `JWT_SECRET` | Secret for signing auth tokens (32+ chars) | `dev-secret-...` (change in production) |
| `NODE_ENV` | `development` or `production` | `development` |

## Pages & Routes

| Route | Description |
|-------|-------------|
| `/` | Home - navigation to all features |
| `/login` | Login page |
| `/schedule/tomorrow` | Create schedule (Copy, Automated Builder, or Manual) |
| `/schedule/[date]` | View/edit schedule for a specific date |
| `/details` | Team Setup: employees & training matrix (auto-saves), job functions, shifts, target hours (`?tab=`) |
| `/training` | Redirects to `/details?tab=employees` |
| `/pto-calendar` | PTO calendar (week/month) + request approval workflow |
| `/employee-overview` | One employee's hours, skills, attendance, review notes (`?employee=&period=`) |
| `/display` | TV display mode (read-only, auto-refresh every 2 min) |
| `/settings` | User settings, password, and team settings |
| `/admin/business-rules` | Staffing targets grid (headcount per function per hour) |

## Project Structure

```
scheduling-app-v2/
├── components/
│   ├── audit/                # ChangeLogModal — the read-only change log
│   ├── employee/             # Overview — the Employee Overview dashboard
│   ├── schedule/             # Schedule grid, shift groups, assignment cards, coverage preview
│   ├── schedule-requests/    # Request form modal (new request / check my requests) + result banner
│   └── team/                 # EmployeesTraining — the Employees & Training tab of Team Setup
├── composables/              # Shared reactive logic
│   ├── useScheduleBuilderV2.ts   # The schedule builder (drives utils/scheduleEngineV2/)
│   ├── useAuth.ts                # JWT authentication
│   ├── useEmployees.ts           # Employee CRUD + training
│   ├── useJobFunctions.ts        # Job function CRUD
│   ├── useSchedule.ts            # Schedule assignments CRUD
│   ├── useStaffingTargets.ts     # Staffing targets CRUD
│   ├── useBusinessRules.ts       # Legacy business rules
│   ├── usePreferredAssignments.ts # Required/preferred assignments
│   ├── usePTO.ts                 # PTO management
│   ├── useScheduleRequests.ts    # Unified PTO/leave-early/shift-swap requests
│   ├── useShiftSwaps.ts          # Shift swap tracking
│   ├── useLaborCalculations.ts   # Hours/staffing calculations
│   ├── useTeam.ts                # Team management
│   ├── useTeamSettings.ts        # Per-team settings (request-rule limits)
│   └── useTeamBlockedDates.ts    # Per-team blocked dates for request auto-rejection
├── pages/                    # File-based routing
│   ├── admin/                # Admin pages
│   ├── schedule/             # Schedule pages
│   └── ...
├── server/
│   ├── api/                  # Nitro API routes (method suffix convention)
│   │   ├── employees/
│   │   ├── job-functions/
│   │   ├── schedule/
│   │   ├── staffing-targets/
│   │   ├── shifts/
│   │   ├── pto/
│   │   ├── pto-calendar/
│   │   ├── schedule-requests/
│   │   ├── team-settings/
│   │   ├── team-blocked-dates/
│   │   ├── attendance-points/
│   │   ├── audit-log/
│   │   └── ...
│   ├── plugins/
│   │   └── bootstrap.ts      # On-boot self-setup: schema + migrations + first admin
│   └── utils/
│       ├── db.ts             # PostgreSQL connection pool
│       ├── authorize.ts      # Auth middleware (JWT verification)
│       ├── jwt.ts            # Token signing/verification
│       ├── ptoHours.ts       # Single source for PTO-hour accounting
│       ├── ptoUsage.ts       # Team PTO hours already committed per date
│       ├── requestRules.ts   # Auto-approval rule engine
│       ├── auditLog.ts       # logChange() — writes the change log inside the caller's transaction
│       ├── upi.ts            # Employee UPI validation
│       └── email.ts          # Email utilities
├── utils/
│   ├── roles.ts              # The four roles, defined once (server + client)
│   ├── ptoDisplay.ts         # Single source for reading/displaying a pto_days row
│   ├── requestDisplay.ts     # Single source for labelling a schedule_requests row
│   ├── localDate.ts          # "Today" as a local calendar date (never UTC)
│   └── scheduleEngineV2/     # The schedule engine (types, slots, prepare, engine + periodEngine)
├── sql-schema/
│   ├── setup.sql             # Full database schema (applied once on empty DB)
│   ├── migrations/           # 001–022 incremental migrations (applied on boot; no 009)
│   └── ...                   # Individual table schemas for reference
├── scripts/
│   ├── seed-first-user.js    # Create initial admin account
│   ├── seed-test-data.js     # 50-person demo team (local only; --reset is destructive)
│   ├── sim-builder.mjs       # Engine harness (real engine, real data, quality metrics)
│   ├── seed-pto-mock.mjs     # Mock PTO data for the calendar (local dev; --clear removes it)
│   └── ui-smoke.mjs          # Browser smoke test (screenshots + JS-error check)
├── docker-compose.yml        # Local development stack
├── Dockerfile                # Multi-stage production build
└── docs/                     # Documentation
    ├── CONTEXT.md            # Architecture, data model, auth, deployment
    ├── SCHEDULE-BUILDER.md   # Both builder engines, in depth
    ├── PTO-AND-REQUESTS.md   # PTO hours, request rules, availability
    ├── ROLES.md              # Roles, permissions matrix, team isolation
    ├── TESTING.md            # How to verify a change (four tiers, harnesses, fixtures)
    └── RANCHER-DEPLOYMENT.md # Production deployment guide
```

## Database Schema

Core tables:

| Table | Purpose |
|-------|---------|
| `teams` | Multi-tenant team isolation |
| `user_profiles` | User accounts with exactly one role flag, password hashes, optional employee link |
| `password_reset_tokens` | Self-service password reset tokens |
| `team_settings` | Per-team configuration (request-rule limits) |
| `team_blocked_dates` | Dates that auto-reject PTO/leave-early requests |
| `employees` | Employee records (name, shift, active status, UPI) |
| `job_functions` | Job roles with colors, coverage flags, exclude-from-targets, headcount caps, staffing priority |
| `employee_training` | Which employees are trained for which functions (junction table) |
| `shifts` | Shift definitions with break/lunch times |
| `schedule_assignments` | Daily employee-to-function assignments |
| `schedule_assignments_archive` | Frozen history from the removed cleanup feature (read by CSV export) |
| `staffing_targets` | Target headcount per function per hour (drives Automated Builder) |
| `preferred_assignments` | Required/preferred employee-function pairings (AM/PM-aware) |
| `pto_days` | PTO records by employee and date |
| `schedule_requests` | Unified PTO / leave-early / shift-swap workflow with auto-approval |
| `shift_swaps` | Shift swap records |
| `daily_targets` | Daily production targets |
| `daily_targets_archive` | Frozen history from the removed cleanup feature |
| `target_hours` | Default target hours per job function |
| `performance_errors` | Picking-error log (admin-only; drives the Employee Overview trend) |
| `performance_notes` | Review notes with quick-add tags |
| `attendance_points` | Half or full attendance points per employee per date |
| `audit_log` | The change log: who changed what, when, with a plain summary and before/after snapshots (append-only) |
| `business_rules` | Legacy staffing rules (replaced by staffing_targets) |

## Automated Schedule Builder

One deterministic pipeline (not an LLM, no solver) —
[utils/scheduleEngineV2/](utils/scheduleEngineV2/), driven by
[composables/useScheduleBuilderV2.ts](composables/useScheduleBuilderV2.ts):
96 x 15-minute slots, cost-function placement, per-gap explanations, and a
business-priority matrix — with two placement engines the Create Schedule page
offers as two cards: the slot engine, and the period engine ("Builder V2") that
keeps each person on one job per stretch between breaks.

> An earlier engine ("V1") was deleted in Aug 2026. The `V2` still in the file
> names is history, not a choice — there is nothing to switch between.

**Per-hour `staffing_targets` are a minimum, not a cap** — once targets are met,
surplus labor is deployed so workers aren't idle, and over-target staffing is
reported rather than suppressed.

Inputs: `staffing_targets` + `employee_training` + `preferred_assignments` +
`shifts` (with lunch/break times) + `job_functions` (incl. `max_headcount`,
`surplus_overflow`, `staffing_priority`) + `pto_days` and `shift_swaps` for the
target date.

Outputs: `{ schedule, actions, warnings, errors, gaps, overTarget }` — reviewed in a
modal that leads with `actions` (things a person must fix), then written via a
transactional delete + insert.

**Full algorithm detail: [docs/SCHEDULE-BUILDER.md](docs/SCHEDULE-BUILDER.md).**

## Deployment

See [docs/RANCHER-DEPLOYMENT.md](docs/RANCHER-DEPLOYMENT.md) for production deployment instructions on Rancher/Kubernetes.

## Validation Rules

- Employees can only be assigned to functions they're trained for (enforced by DB trigger)
- Assignment duration must be at least 15 minutes (enforced by DB constraint). The builder itself only generates blocks of 30 minutes or longer; the shorter floor exists so supervisors can make manual quarter-hour tweaks
- Assignments must fall within shift boundaries
- Multi-tenant data isolation via `team_id` on all tables

## License

Internal use. All rights reserved.
