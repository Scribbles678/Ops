# Operations Scheduling Tool

A web-based scheduling application for distribution center operations. Built with Nuxt 4, Vue 3, PostgreSQL, and Tailwind CSS. Runs as a Docker container with no external service dependencies.

## Features

- **Daily Schedule Management** - Visual grid editor for employee assignments with 15-minute granularity
- **Automated Schedule Builder** - Generates optimized schedules from staffing targets, employee training, and required assignments using a two-halves algorithm (AM/PM blocks per employee)
- **Staffing Targets** - Set target headcount per job function per hour in a simple grid UI
- **Employee Training Matrix** - Track which employees are trained for which job functions, with auto-save
- **Required Assignments** - Lock specific employees to specific functions daily
- **PTO Management** - Mark employees as off for specific dates, with hours tracking
- **Shift Swap Tracking** - Record and manage shift swaps between employees
- **Copy Schedule** - Duplicate a previous day's schedule to a new date
- **Display Mode** - Full-screen TV view with auto-refresh for floor visibility
- **Multi-Tenant Teams** - Data isolation by team with role-based access
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
| `/display` | TV display mode (read-only, auto-refresh) |
| `/settings` | User settings and password management |
| `/admin/business-rules` | Staffing targets grid + required assignments |
| `/admin/users` | User account management |
| `/admin/cleanup` | Database cleanup utilities |

## Project Structure

```
scheduling-app-v2/
├── components/
│   ├── details/              # Job function, shift, employee editors
│   ├── schedule/             # Schedule grid, shift groups, assignment cards
│   └── training/             # Training matrix components
├── composables/              # Shared reactive logic
│   ├── useAIScheduleBuilder.ts   # Automated schedule generation algorithm
│   ├── useAuth.ts                # JWT authentication
│   ├── useEmployees.ts           # Employee CRUD + training
│   ├── useJobFunctions.ts        # Job function CRUD
│   ├── useSchedule.ts            # Schedule assignments CRUD
│   ├── useStaffingTargets.ts     # Staffing targets CRUD
│   ├── useBusinessRules.ts       # Legacy business rules
│   ├── usePreferredAssignments.ts # Required/preferred assignments
│   ├── usePTO.ts                 # PTO management
│   ├── useShiftSwaps.ts          # Shift swap tracking
│   ├── useLaborCalculations.ts   # Hours/staffing calculations
│   └── useTeam.ts                # Team management
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
| `employees` | Employee records (name, shift, active status) |
| `job_functions` | Job roles with colors and settings |
| `training_assignments` | Which employees are trained for which functions |
| `shifts` | Shift definitions with break/lunch times |
| `schedule_assignments` | Daily employee-to-function assignments |
| `staffing_targets` | Target headcount per function per hour |
| `preferred_assignments` | Required/preferred employee-function pairings |
| `pto_days` | PTO records by employee and date |
| `shift_swaps` | Shift swap records |
| `daily_targets` | Daily production targets |
| `business_rules` | Legacy staffing rules (replaced by staffing_targets) |

## Automated Schedule Builder

The builder uses a **two-halves algorithm**:

1. Each employee's day is split into AM (shift start to lunch) and PM (lunch to shift end) based on their shift's lunch times
2. Required employees are assigned their locked function for both halves
3. Remaining employees are assigned by demand — functions with highest unmet staffing targets get filled first
4. Most-constrained employees (fewest training options) are assigned first to avoid dead ends
5. Any unassigned halves get Flex
6. Gaps (unfilled targets) are reported as warnings, never errors

Input: staffing targets (headcount per function per hour) + employee training + required assignments + shift lunch times

## Deployment

See [docs/RANCHER-DEPLOYMENT.md](docs/RANCHER-DEPLOYMENT.md) for production deployment instructions on Rancher/Kubernetes.

## Validation Rules

- Employees can only be assigned to functions they're trained for (enforced by DB trigger)
- Assignment duration must be at least 30 minutes (enforced by DB constraint)
- Assignments must fall within shift boundaries
- Multi-tenant data isolation via `team_id` on all tables

## License

Internal use. All rights reserved.
