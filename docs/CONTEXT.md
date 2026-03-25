# Project Context: Operations Scheduling Tool (scheduling-app-v2)

## Overview

A distribution center scheduling application for managing employee work assignments across shifts, job functions, and time slots. Multi-tenant system with team-based data isolation and role-based access control.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Nuxt 4 (SPA mode, SSR disabled) |
| Frontend | Vue 3 with composables for state management |
| Styling | Tailwind CSS |
| Database | PostgreSQL 16 |
| Auth | JWT (HttpOnly cookies, 8hr expiry), bcryptjs passwords |
| Email | Nodemailer (SMTP) for password resets |
| Export | xlsx for Excel export |
| Deployment | Docker Compose / Netlify |

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
│   ├── details.vue            # Tabbed config: job functions, shifts, cleanup, target hours
│   ├── display.vue            # Read-only TV display, auto-refresh every 2 min
│   ├── settings.vue           # User settings + super admin user/team management
│   ├── schedule/
│   │   ├── [date].vue         # Schedule editor with 15-min grid, dashboards, KPI strip
│   │   └── tomorrow.vue       # Create schedule: copy, AI generate, or manual
│   └── admin/
│       ├── users.vue          # User/team CRUD (super admin only)
│       ├── business-rules.vue # AI staffing rules per job function/time slot
│       └── cleanup.vue        # Data archival, export, retention management
├── components/
│   ├── details/
│   │   ├── EmployeesTab.vue          # Employee CRUD list
│   │   ├── JobFunctionsTab.vue       # Job function CRUD with color picker
│   │   ├── ProductivityRatesTab.vue  # Productivity rate/unit editing
│   │   ├── ShiftManagementTab.vue    # Shift CRUD with break/lunch times
│   │   └── ShiftsTab.vue            # Read-only shift display
│   └── schedule/
│       ├── AssignmentModal.vue       # Create/edit assignment with validation
│       ├── HorizontalSchedule.vue    # Horizontal timeline view
│       ├── LaborHoursPanel.vue       # Scheduled vs required hours per job function
│       ├── ScheduleGrid15Min.vue     # Dense 15-min grid editor (rows=employees, cols=time)
│       ├── ShiftBasedSchedule.vue    # Shift-oriented schedule view
│       └── ShiftGroupedSchedule.vue  # Grouped by shift schedule view
├── composables/
│   ├── useAuth.ts                 # JWT auth: login, logout, fetchCurrentUser, changePassword
│   ├── useEmployees.ts            # Employee CRUD + training data management
│   ├── useJobFunctions.ts         # Job function CRUD + meter grouping helpers
│   ├── useSchedule.ts             # Shifts, assignments, daily targets, batch ops, cleanup
│   ├── useLaborCalculations.ts    # Hours math, staffing status, time formatting
│   ├── useBusinessRules.ts        # Business rule CRUD + sorting
│   ├── usePreferredAssignments.ts # Employee-job function preferences/requirements
│   ├── usePTO.ts                  # PTO record management
│   ├── useShiftSwaps.ts           # Shift swap management
│   ├── useTeam.ts                 # Team CRUD + super admin checks
│   └── useAIScheduleBuilder.ts    # ~1060 lines: algorithmic schedule generation
├── server/
│   ├── api/
│   │   ├── auth/              # login, logout, me, change-password, forgot/reset-password
│   │   ├── schedule/          # [date].get, assignments CRUD, batch, copy, replace, export
│   │   ├── employees/         # CRUD + training endpoints
│   │   ├── job-functions/     # CRUD
│   │   ├── shifts/            # CRUD
│   │   ├── daily-targets/     # Get by date, upsert
│   │   ├── target-hours/      # Get/save default target hours
│   │   ├── business-rules/    # CRUD
│   │   ├── preferred-assignments/ # CRUD
│   │   ├── pto/               # Get by date, create, delete
│   │   ├── shift-swaps/       # Get by date, create, delete
│   │   ├── teams/             # CRUD
│   │   ├── staffing-drafts/   # (empty, placeholder)
│   │   ├── admin/
│   │   │   ├── users/         # CRUD, reset password, toggle status
│   │   │   └── cleanup/       # Stats, run, log
│   │   └── health.get.ts      # Health check endpoint
│   ├── middleware/
│   │   ├── auth.ts            # Reads JWT cookie, populates event.context.user
│   │   ├── cookie-security.ts # X-Content-Type-Options, X-XSS-Protection headers
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
├── scripts/
│   ├── seed-first-user.js     # Creates initial admin user
│   └── seed-test-data1.js     # Seeds sample data
└── docs/                      # Project documentation
```

---

## Data Model

### Core Relationships

```
teams (multi-tenant root)
  ├── user_profiles (auth users, role-based)
  ├── employees
  │     ├── employee_training ←→ job_functions (many-to-many)
  │     ├── preferred_assignments ←→ job_functions (with priority + is_required)
  │     ├── pto_days
  │     └── shift_swaps (original_shift ↔ swapped_shift)
  ├── shifts (with break/lunch times)
  ├── job_functions (color, productivity rate, sort order)
  ├── schedule_assignments (employee + job_function + shift + date + time range)
  ├── daily_targets (per date per job function)
  ├── target_hours (default hours per job function)
  └── business_rules (staffing requirements per job function/time slot)
```

### Key Tables

| Table | Purpose |
|-------|---------|
| **employees** | first_name, last_name, is_active, shift_id (FK), team_id |
| **job_functions** | name, color_code (#hex), productivity_rate, unit_of_measure, sort_order, team_id |
| **shifts** | name, start/end time, break_1/break_2/lunch start/end times, team_id |
| **schedule_assignments** | employee_id, job_function_id, shift_id, schedule_date, start_time, end_time, team_id |
| **employee_training** | employee_id, job_function_id (junction table) |
| **business_rules** | job_function_name, time_slot_start/end, min/max_staff, priority, fan_out_enabled/prefix |
| **preferred_assignments** | employee_id, job_function_id, is_required, priority |
| **pto_days** | employee_id, pto_date, optional start/end time, pto_type |
| **shift_swaps** | employee_id, swap_date, original_shift_id, swapped_shift_id |
| **daily_targets** | schedule_date, job_function_id, target_units |
| **target_hours** | job_function_id, target_hours (default) |
| **user_profiles** | email, username, password_hash, full_name, team_id, is_super_admin, is_admin, is_display_user, is_active |

### Database Triggers

- **validate_assignment_time_conflict** — prevents employee double-booking on same date
- **validate_assignment_training** — ensures employee is trained for assigned job function (supports Meter parent matching)
- **validate_shift_swap_date** — prevents swaps for past dates
- **update_updated_at_column** — auto-updates timestamps on most tables
- **cleanup_old_schedules_with_logging** — archives schedules older than 30 days

---

## Authentication & Authorization

### Auth Flow
1. User logs in via `/login` → POST `/api/auth/login` → bcrypt verify → JWT set as HttpOnly cookie
2. Every server request → `server/middleware/auth.ts` reads cookie → verifies JWT → populates `event.context.user`
3. Client middleware (`middleware/auth.global.ts`) redirects unauthenticated users to `/login`
4. Public routes: `/login`, `/display`, `/reset-password`

### Role Hierarchy
| Role | Capabilities |
|------|-------------|
| **Super Admin** | All data across all teams, user/team management, cleanup |
| **Admin** | Team-scoped data, settings modification |
| **User** | Team-scoped data, schedule viewing/editing |
| **Display User** | Read-only display mode access |

### Multi-Tenancy
- Every data table has a `team_id` column
- `getTeamFilter(user)` returns `null` for super admins (see all), `user.team_id` for others
- API queries append `WHERE team_id = $X` for non-super-admin users

### Rate Limiting (in-memory)
- Default: 200 req/min
- Admin routes: 100 req/min
- User creation: 5 req/hour
- Password reset: 3 req/hour

---

## Key Domain Concepts

### Meter Job Functions
"Meter" is a special job function category. Individual meters are named "Meter 1", "Meter 2", etc. Training on the parent "Meter" function qualifies an employee for any "Meter N" assignment. The AI builder and database triggers both support this parent-child relationship via name pattern matching.

### AI Schedule Builder (`useAIScheduleBuilder.ts`)
Algorithm flow:
1. **Validate** — checks data exists (employees, shifts, job functions, business rules)
2. **Fetch** — loads employees, training, shifts, rules, preferred assignments
3. **Expand** — fan-out rules (e.g., "Meter" → "Meter 1" through "Meter N")
4. **Process** — assigns Startup to 6am employees, processes rules by priority, respects required/preferred assignments, checks training + availability + shift coverage
5. **Fill** — break coverage for Locus/X4, consolidate 15-min slots into 2-4hr blocks, fill gaps with "Flex"
6. **Apply** — saves to DB in batches of 200 via `createAssignmentsBatch`

### Staffing Status Thresholds
- **Critical** — <80% of required hours
- **Understaffed** — 80-95% of required hours
- **Adequate** — 95-105% of required hours
- **Overstaffed** — >105% of required hours

### Validation Rules (enforced client + DB)
- Employee must be trained for the assigned job function
- Assignment duration must be >= 30 minutes
- No overlapping assignments for the same employee on the same date

### Data Archival
- Schedule assignments and daily targets older than 30 days are moved to `_archive` tables
- Managed via admin cleanup page with Excel export before archival

---

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `DATABASE_URL` | PostgreSQL connection string |
| `DATABASE_SSL` | SSL mode (false for local dev) |
| `JWT_SECRET` | JWT signing secret (32+ chars) |
| `APP_URL` | Base URL for password reset links |
| `SMTP_HOST/PORT/USER/PASS/FROM` | Email sending configuration |
| `NODE_ENV` | Environment (development/production) |

---

## Development

```bash
npm install          # Install dependencies
npm run dev          # Start dev server (localhost:3000)
npm run build        # Production build
npm run seed:first-user    # Create initial admin user
npm run seed:test-data     # Seed sample data
```

### Docker
```bash
docker-compose up        # Starts app + PostgreSQL
docker-compose run seed  # Seeds first admin user
```

---

**Last Updated**: March 2025
