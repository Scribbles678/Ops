# Multi-Tenant & Team Isolation Documentation

Complete guide to multi-tenant architecture, team isolation, and setup procedures.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Team Isolation Implementation](#team-isolation-implementation)
4. [Setup & Configuration](#setup--configuration)
5. [Data Isolation Rules](#data-isolation-rules)
6. [Management & Administration](#management--administration)

---

## Overview

The Operations Scheduling Tool supports **multi-tenant architecture** with complete team-based data isolation. Each team (department) has isolated data, and users can only see and manage data from their assigned team.

### Key Features

- ✅ **Multiple teams** (departments) with isolated data
- ✅ **Email-based login** (standard authentication)
- ✅ **Super admin role** for managing users and teams
- ✅ **Admin-only user creation** (no public sign-up)
- ✅ **Database-level enforcement** (RLS policies)
- ✅ **Automatic team assignment** for new records

---

## Architecture

### Database Structure

```
teams (table)
├── id (UUID)
├── name (text) - "Department 1", "Department 2", etc.
├── created_at
└── updated_at

user_profiles (table)
├── id (UUID) - from auth.users
├── username (text) - unique username
├── team_id (UUID) - links to teams
├── is_super_admin (boolean)
├── is_admin (boolean)
├── is_display_user (boolean)
├── full_name (text) - optional
└── created_at

All existing tables have:
├── team_id (UUID) - links to teams table
└── RLS policies filter by team_id
```

### Data Isolation

Each team has isolated:
- Employees
- Job functions
- Training records
- Schedules
- Shifts
- Business rules
- PTO records
- Shift swaps
- Preferred assignments
- Everything!

---

## Team Isolation Implementation

### How It Works

1. **User Assignment**
   - Each user is assigned to a team (`team_id` in `user_profiles`)
   - Super Admins can see all teams (no `team_id` restriction)
   - Regular users are restricted to their team's data

2. **Data Filtering**
   - All queries automatically filter by `team_id`
   - Client-side filtering in composables
   - Database-level filtering via RLS policies

3. **Automatic Team Assignment**
   - New records automatically get the user's `team_id`
   - Super Admins can specify `team_id` when creating records
   - Cannot create records for other teams (unless Super Admin)

### Implementation Status

#### ✅ Fully Implemented

- **Database Schema**: All tables have `team_id` columns
- **RLS Policies**: All tables have RLS policies that filter by `team_id`
- **Composables with Team Filtering**:
  - `useEmployees.ts` - Employees ✅
  - `useSchedule.ts` - Shifts ✅, Schedule Assignments ✅
  - `useJobFunctions.ts` - Job Functions ✅
  - `usePTO.ts` - PTO days ✅
  - `useShiftSwaps.ts` - Shift swaps ✅
  - `useBusinessRules.ts` - Business rules ✅
  - `usePreferredAssignments.ts` - Preferred assignments ✅
  - `useEmployees.ts` - Training functions ✅
  - `useSchedule.ts` - Daily targets ✅

### Pattern Used

All composables follow this pattern:

```typescript
const { getCurrentTeamId, isSuperAdmin } = useTeam()

// For queries
const teamId = isSuperAdmin.value ? null : await getCurrentTeamId()
if (teamId) {
  query = query.eq('team_id', teamId)
}

// For creates
const teamId = isSuperAdmin.value ? specifiedTeamId : await getCurrentTeamId()
const newRecord = {
  ...data,
  team_id: teamId
}
```

---

## Setup & Configuration

### Step 1: Run Database Schema

1. Go to your Supabase dashboard
2. Navigate to **SQL Editor**
3. Run the following schema files in order:

   **First, create core tables:**
   - Run `sql-schema/teams.sql` to create the teams table
   - Run `sql-schema/user_profiles.sql` to create the user profiles table
   
   **Then, create all other tables:**
   - Run each table schema file from `sql-schema/` folder:
     - `employees.sql`
     - `job_functions.sql`
     - `shifts.sql`
     - `schedule_assignments.sql`
     - `daily_targets.sql`
     - And all other table files
   
   **Finally, set up security:**
   - Run `sql-schema/rls-policies.sql` to set up Row Level Security (RLS) policies for team isolation
   
   **Note**: If you're adding multi-tenant support to an existing database, you'll need to:
   - Add `team_id` columns to existing tables (if not already present)
   - Update existing data to assign `team_id` values
   - Run the RLS policies to enforce team isolation

### Step 2: Create Your First Super Admin

You need to manually create the first super admin user:

**Method 1: Via Supabase Dashboard (Recommended)**

1. Go to Supabase Dashboard → **Authentication** → **Users**
2. Click **"Add user"** → **"Create new user"**
3. Set:
   - Email: `admin@internal.local` (or your choice)
   - Password: (choose a secure password)
   - Auto Confirm: **ON**
4. Click **"Create user"**
5. Copy the **User ID** (UUID)
6. Run this SQL (replace `USER_ID_HERE` with the actual UUID):

```sql
INSERT INTO user_profiles (id, username, is_super_admin, is_active)
VALUES ('USER_ID_HERE', 'admin', true, true);
```

### Step 3: Create Teams

1. Log in as the super admin (using the email address you created)
2. Click **"User Management"** on the home page
3. Click **"+ Create Team"**
4. Create your teams (e.g., "Department 1", "Department 2", etc.)

### Step 4: Create Users

1. In **User Management**, click **"+ Create User"**
2. Fill in:
   - Email address (e.g., `john.doe@company.com`)
   - Password (min 6 characters)
   - Full Name (optional)
   - Team (select from dropdown)
   - Super Admin (checkbox - only for additional super admins)
3. Click **"Create User"**

Users can now log in with their email address and password.

### Step 5: Assign Existing Data to Teams

If you have existing data, you'll need to assign it to teams:

```sql
-- First, get your team ID:
SELECT id, name FROM teams;

-- Then assign employees (replace TEAM_ID_HERE):
UPDATE employees 
SET team_id = 'TEAM_ID_HERE' 
WHERE team_id IS NULL;

-- Repeat for other tables:
UPDATE job_functions SET team_id = 'TEAM_ID_HERE' WHERE team_id IS NULL;
UPDATE shifts SET team_id = 'TEAM_ID_HERE' WHERE team_id IS NULL;
UPDATE schedule_assignments SET team_id = 'TEAM_ID_HERE' WHERE team_id IS NULL;
-- ... etc for all tables
```

### Step 6: Environment Variables

Add the service role key to your `.env` file (for user creation):

```bash
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key  # Get this from Supabase Dashboard > Settings > API
```

**Important:** The service role key should NEVER be exposed to the client. It's only used server-side in `/server/api/admin/users/create.ts`.

---

## Data Isolation Rules

### For Regular Users

- All queries are automatically filtered by their `team_id`
- All create operations automatically set `team_id` from their profile
- Users can only see and manage data for their own team
- Cannot access other teams' data (enforced by RLS)

### For Admins

- Can see and manage data from their assigned team
- Can manage users in their assigned team
- Cannot see or manage other teams' data
- Cannot create new teams

### For Super Admins

- All queries return data from all teams (`team_id` filter is `null`)
- Super admins can specify `team_id` when creating records (optional)
- Super admins can see and manage data across all teams
- Can create and manage teams
- Can assign users to any team

### Database-Level Protection (RLS)

Row Level Security (RLS) policies provide the primary security layer:

- Policies use `get_user_team_id()` function to filter data
- Even if client-side filtering is bypassed, database will enforce team isolation
- Super admins explicitly bypass RLS policies (by design)

**Example RLS Policy:**
```sql
CREATE POLICY "Users can view own team employees" 
ON employees FOR SELECT 
USING (
  team_id IN (
    SELECT team_id FROM user_profiles WHERE id = auth.uid()
  )
  OR EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE id = auth.uid() AND is_super_admin = true
  )
);
```

---

## Management & Administration

### Creating Teams

**Via Admin Interface:**
1. Log in as Super Admin
2. Go to User Management
3. Click "+ Create Team"
4. Enter team name
5. Save

**Via SQL:**
```sql
INSERT INTO teams (name) VALUES ('Department Name');
```

### Assigning Users to Teams

**Via Admin Interface:**
1. Go to User Management
2. Find user and click "Edit"
3. Select team from dropdown
4. Save

**Via SQL:**
```sql
UPDATE user_profiles 
SET team_id = 'team-uuid-here' 
WHERE id = 'user-uuid-here';
```

### Moving Data Between Teams

**For Super Admins:**
1. Update `team_id` in the database
2. Data will immediately appear for the new team
3. Old team will no longer see the data

**Example:**
```sql
-- Move employee to different team
UPDATE employees 
SET team_id = 'new-team-uuid' 
WHERE id = 'employee-uuid';
```

### Viewing All Teams' Data (Super Admin)

Super Admins can:
- See all teams' data in the UI
- Filter by team (if UI supports it)
- Create records for any team
- Manage users across all teams

---

## Email-Based Authentication

### How It Works

- Users log in with their **email address** (e.g., "john.doe@company.com")
- Passwords are hashed and stored securely by Supabase
- Email is validated on the client side before submission
- Username is automatically derived from email (part before '@') for display purposes

### Implementation

```typescript
// Login (pages/login.vue)
const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
if (!emailRegex.test(email.value)) {
  error.value = 'Please enter a valid email address'
  return
}

await supabase.auth.signInWithPassword({
  email: email.value.trim().toLowerCase(),
  password: password.value
})
```

### User Creation

When creating users via the admin interface:

- Admin enters **email address** (required)
- Password is set (minimum 6 characters)
- Username is automatically derived from email: `email.split('@')[0]`
- Both email and username are stored in `user_profiles` table

```typescript
// User creation (server/api/admin/users/create.ts)
const username = email.split('@')[0] // Use part before @ as username
await supabaseAdmin.from('user_profiles').insert({
  id: authData.user.id,
  username: username.trim().toLowerCase(),
  email: email.trim().toLowerCase(), // Store email for easy lookup
  ...
})
```

### Benefits

- ✅ Standard email-based authentication
- ✅ Works seamlessly with Supabase Auth
- ✅ Secure password hashing
- ✅ Individual user accounts
- ✅ Username automatically derived for display

---

## Troubleshooting

### "Account not found" error

**Possible Causes:**
- User profile wasn't created
- Username/email mismatch

**Solutions:**
- Create user profile via User Management
- Verify email address is correct and matches the auth account

### "Account is inactive" error

**Possible Causes:**
- User was deactivated

**Solutions:**
- Reactivate user via User Management

### Can't see any data

**Possible Causes:**
- User not assigned to a team
- Data not assigned to team
- RLS policies not active

**Solutions:**
- Check that your user has a `team_id` assigned
- Verify RLS policies are active
- Check that data has `team_id` set

### Can't create users

**Possible Causes:**
- Service role key not set
- Not logged in as super admin
- API errors

**Solutions:**
- Verify `SUPABASE_SERVICE_ROLE_KEY` is set in `.env`
- Check that you're logged in as a super admin
- Check browser console for errors

### Cross-team data visible

**Possible Causes:**
- User is Super Admin (by design)
- RLS policies not working
- Client-side filtering not applied

**Solutions:**
- Verify user's role in Settings
- Check RLS policies are active
- Verify composables are filtering by team

---

## Best Practices

1. **Always Assign Teams**
   - Users without a team cannot access team-specific data
   - Always assign users to appropriate teams
   - Super Admins can be team-less (see all teams)

2. **Team Naming**
   - Use clear, descriptive team names
   - Consider department or location names
   - Keep names consistent

3. **Data Migration**
   - Assign existing data to teams before enabling isolation
   - Use SQL updates for bulk assignments
   - Verify data is assigned correctly

4. **Super Admin Management**
   - Minimize number of Super Admins
   - Use Admin role for team managers
   - Regular review of admin access

5. **Testing**
   - Test with regular users (should only see their team)
   - Test with super admins (should see all teams)
   - Test cross-team access (should be blocked)

---

## Next Steps

- Review [ROLES.md](./ROLES.md) for role-based access control
- See [AUTHENTICATION.md](./AUTHENTICATION.md) for authentication setup
- Check [SECURITY.md](./SECURITY.md) for security best practices

---

**Last Updated**: January 2025

