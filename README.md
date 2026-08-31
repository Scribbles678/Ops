# Operations Scheduling Tool

A web-based scheduling application for distribution center operations. Built with Nuxt 4, Vue 3, PostgreSQL, and Tailwind CSS. Runs as a Docker container with no external service dependencies.

## Features

- **Daily Schedule Management** - Visual grid editor for employee assignments with 15-minute granularity
- **Automated Schedule Builder** - Generates schedules from staffing targets, training, and required assignments. Deterministic (no LLM, no solver): scarce-first fill that treats targets as a minimum, deploys surplus labor (with per-function caps and overflow sinks), and integrates PTO + a lunch/break coverage pass
- **Schedule Builder V2 (Beta)** - Parallel 15-minute-resolution engine with a cost function, per-gap explanations, pre-flight feasibility, and a business-priority matrix (`staffing_priority`) that decides which functions go short first
- **Coverage Preview** - Read-at-a-glance grid on Create Schedule showing trained headcount vs demand before you build
- **Employee Overview** - Per-employee dashboard: hours by function, PTO usage, rolling picking-error trend, and performance notes for reviews
- **Staffing Targets** - Set target headcount per job function per hour in a grid UI
- **Coverage Requirements** - Flag job functions that need lunch/break coverage so the builder keeps the station continuously staffed
- **Employee Training Matrix** - Track which employees are trained for which job functions, with auto-save
- **Required Assignments** - Lock specific employees to specific functions daily (AM/PM-specific supported)
- **PTO Calendar** - Week/month calendar combining approved PTO and pending requests; admin approval workflow
- **Schedule Requests** - Unified request pipeline for PTO (full/partial), leave-early, and shift swaps with an auto-approval rule engine (per-day limits, team PTO-hour caps, blocked dates)
- **Shift Swap Tracking** - Record and manage shift swaps between employees
- **Copy Schedule** - Duplicate a previous day's schedule to a new date
- **Display Mode** - Full-screen TV view with auto-refresh (every 2 min)
- **Multi-Tenant Teams** - Data isolation by team enforced at the API layer via JWT `team_id`
- **Authentication** - JWT-based auth with HttpOnly cookies, role hierarchy (Super Admin, Admin, User, Display)

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
| `/training` | Employee training matrix (auto-saves) |
| `/details` | Manage job functions, shifts, and employees |
| `/pto-calendar` | PTO calendar (week/month) + request approval workflow |
| `/display` | TV display mode (read-only, auto-refresh every 2 min) |
| `/settings` | User settings, password, and team settings |
| `/admin/business-rules` | Staffing targets grid (headcount per function per hour) |

## Project Structure

```
scheduling-app-v2/
├── components/
│   ├── details/              # Job function, shift, employee editors
│   ├── schedule/             # Schedule grid, shift groups, assignment cards
│   └── schedule-requests/    # Request form modal + auto-approval result banner
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
│       └── email.ts          # Email utilities
├── utils/
│   ├── ptoDisplay.ts         # Single source for reading/displaying a pto_days row
│   └── scheduleEngineV2/     # The schedule engine (types, slots, prepare, engine)
├── sql-schema/
│   ├── setup.sql             # Full database schema (applied once on empty DB)
│   ├── migrations/           # 001–018 incremental migrations (applied on boot; no 009)
│   └── ...                   # Individual table schemas for reference
├── scripts/
│   ├── seed-first-user.js    # Create initial admin account
│   ├── seed-test-data1.js    # Optional test data
│   ├── sim-builder.mjs       # Engine harness (real engines, real data, quality metrics)
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
| `user_profiles` | User accounts with roles, password hashes, optional employee link |
| `password_reset_tokens` | Self-service password reset tokens |
| `team_settings` | Per-team configuration (request-rule limits) |
| `team_blocked_dates` | Dates that auto-reject PTO/leave-early requests |
| `employees` | Employee records (name, shift, active status) |
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
| `business_rules` | Legacy staffing rules (replaced by staffing_targets) |

## Automated Schedule Builder

One deterministic engine (not an LLM, no solver) —
[utils/scheduleEngineV2/](utils/scheduleEngineV2/), driven by
[composables/useScheduleBuilderV2.ts](composables/useScheduleBuilderV2.ts):
96 x 15-minute slots, cost-function placement, per-gap explanations, and a
business-priority matrix.

> An earlier engine ("V1") was deleted in Aug 2026. The `V2` still in the file
> names is history, not a choice — there is nothing to switch between.

**Per-hour `staffing_targets` are a minimum, not a cap** — once targets are met,
surplus labor is deployed so workers aren't idle, and over-target staffing is
reported rather than suppressed.

Inputs: `staffing_targets` + `employee_training` + `preferred_assignments` +
`shifts` (with lunch/break times) + `job_functions` (incl. `max_headcount`,
`surplus_overflow`, `staffing_priority`) + `pto_days` for the target date.

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
