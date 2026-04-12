# Operations Scheduling Tool

A web-based scheduling application for distribution center operations. Built with Nuxt 4, Vue 3, PostgreSQL, and Tailwind CSS. Runs as a Docker container with no external service dependencies.

## Features

- **Daily Schedule Management** - Visual grid editor for employee assignments with 15-minute granularity
- **Daily Schedule Management** - Visual grid editor for employee assignments with 15-minute granularity
- **Automated Schedule Builder** - Generates schedules from staffing targets, training, and required assignments using a two-halves algorithm (AM/PM blocks per employee) with PTO integration
- **Staffing Targets** - Set target headcount per job function per hour in a grid UI
- **Employee Training Matrix** - Track which employees are trained for which job functions, with auto-save
- **Required Assignments** - Lock specific employees to specific functions daily
- **PTO Calendar** - Week/month calendar combining approved PTO and pending requests; admin approval workflow
- **Schedule Requests** - Unified request pipeline for PTO (full/partial), leave-early, and shift swaps
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
| `/admin/users` | User account management (super admin only) |
| `/admin/cleanup` | Database cleanup utilities |

## Project Structure

```
scheduling-app-v2/
├── components/
│   ├── details/              # Job function, shift, employee editors
│   ├── schedule/             # Schedule grid, shift groups, assignment cards
│   └── training/             # Training matrix components
├── composables/              # Shared reactive logic
│   ├── useAIScheduleBuilder.ts   # Automated schedule generation (two-halves algorithm)
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
│   └── useTeamSettings.ts        # Per-team settings
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
│   │   └── ...
│   └── utils/
│       ├── db.ts             # PostgreSQL connection pool
│       ├── authorize.ts      # Auth middleware (JWT verification)
│       ├── jwt.ts            # Token signing/verification
│       └── email.ts          # Email utilities
├── sql-schema/
│   ├── setup.sql             # Full database schema (run once)
│   ├── staffing_targets.sql  # Staffing targets table
│   └── ...                   # Individual table schemas for reference
├── scripts/
│   ├── seed-first-user.js    # Create initial admin account
│   └── seed-test-data1.js    # Optional test data
├── docker-compose.yml        # Local development stack
├── Dockerfile                # Multi-stage production build
└── docs/                     # Documentation
    ├── RANCHER-DEPLOYMENT.md # Production deployment guide
    ├── CONTEXT.md            # Technical context document
    └── ...
```

## Database Schema

Core tables:

| Table | Purpose |
|-------|---------|
| `teams` | Multi-tenant team isolation |
| `user_profiles` | User accounts with roles and password hashes |
| `team_settings` | Per-team configuration |
| `employees` | Employee records (name, shift, active status) |
| `job_functions` | Job roles with colors and settings |
| `employee_training` | Which employees are trained for which functions (junction table) |
| `shifts` | Shift definitions with break/lunch times |
| `schedule_assignments` | Daily employee-to-function assignments |
| `staffing_targets` | Target headcount per function per hour (drives Automated Builder) |
| `preferred_assignments` | Required/preferred employee-function pairings |
| `pto_days` | PTO records by employee and date |
| `schedule_requests` | Unified PTO / leave-early / shift-swap request workflow |
| `shift_swaps` | Shift swap records |
| `daily_targets` | Daily production targets |
| `target_hours` | Default target hours per job function |
| `business_rules` | Legacy staffing rules (replaced by staffing_targets) |

## Automated Schedule Builder

The builder uses a **two-halves algorithm** (see [composables/useAIScheduleBuilder.ts](composables/useAIScheduleBuilder.ts)):

1. Each employee's day is split into AM (shift start → lunch start) and PM (lunch end → shift end). An employee gets at most two assignments per day.
2. **PTO is applied first** — full-day PTO removes the employee; partial-day PTO clips AM/PM blocks and invalidates any block < 30 min.
3. **Meter fan-out** — parent functions like "Meter" distribute headcount across numbered children ("Meter 1", "Meter 2", ...).
4. **Required assignments** — employees with `is_required=true` get their locked function for both halves.
5. **Most-constrained-first greedy** — remaining employees filled by demand. Each iteration picks the employee with fewest feasible options, then the highest-scoring (function, window) pair. Preferred assignments get a scoring bonus.
6. **Gaps** — any remaining unfilled demand is reported as a warning (non-fatal).

Inputs: `staffing_targets` + `employee_training` + `preferred_assignments` + `shifts` (with lunch times) + `pto_days` for the target date.

Outputs: `{ schedule, warnings, errors, gaps }` — user reviews in a modal before approving, then `replaceScheduleForDate()` writes via a transactional delete+insert.

## Deployment

See [docs/RANCHER-DEPLOYMENT.md](docs/RANCHER-DEPLOYMENT.md) for production deployment instructions on Rancher/Kubernetes.

## Validation Rules

- Employees can only be assigned to functions they're trained for (enforced by DB trigger)
- Assignment duration must be at least 30 minutes (enforced by DB constraint)
- Assignments must fall within shift boundaries
- Multi-tenant data isolation via `team_id` on all tables

## License

Internal use. All rights reserved.
