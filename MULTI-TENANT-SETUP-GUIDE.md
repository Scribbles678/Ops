# Multi-Tenant Setup Guide

This guide will help you set up the multi-tenant system with username-based authentication and team isolation.

## Overview

The app now supports:
- **Multiple teams** (departments) with isolated data
- **Username-based login** (no email required)
- **Super admin role** for managing users and teams
- **Admin-only user creation** (no public sign-up)

## Step 1: Run Database Migration

1. Go to your Supabase dashboard
2. Navigate to **SQL Editor**
3. Copy the entire contents of `sql-schema/multi-tenant-setup.sql`
4. Paste and run it in the SQL Editor

This will:
- Create `teams` and `user_profiles` tables
- Add `team_id` to all existing tables
- Set up Row Level Security (RLS) policies for team isolation
- Create helper functions for team management

## Step 2: Create Your First Super Admin

You need to manually create the first super admin user. Run this SQL in Supabase SQL Editor:

```sql
-- Replace these values with your desired username and password
DO $$
DECLARE
  v_username TEXT := 'admin';  -- Change this
  v_password TEXT := 'your-secure-password';  -- Change this
  v_email TEXT;
  v_user_id UUID;
BEGIN
  -- Create email from username
  v_email := v_username || '@internal.local';
  
  -- Create auth user
  v_user_id := auth.uid();  -- This won't work directly, use Supabase Auth API instead
  
  -- For now, use Supabase Dashboard:
  -- 1. Go to Authentication > Users
  -- 2. Click "Add user" > "Create new user"
  -- 3. Email: admin@internal.local
  -- 4. Password: your-secure-password
  -- 5. Auto Confirm: ON
  -- 6. Copy the User ID
  
  -- Then run this (replace USER_ID_HERE with the actual UUID):
  -- INSERT INTO user_profiles (id, username, is_super_admin, is_active)
  -- VALUES ('USER_ID_HERE', 'admin', true, true);
END $$;
```

**Easier Method:**
1. Go to Supabase Dashboard → **Authentication** → **Users**
2. Click **"Add user"** → **"Create new user"**
3. Set:
   - Email: `admin@internal.local`
   - Password: (choose a secure password)
   - Auto Confirm: **ON**
4. Click **"Create user"**
5. Copy the **User ID** (UUID)
6. Run this SQL (replace `USER_ID_HERE` with the actual UUID):

```sql
INSERT INTO user_profiles (id, username, is_super_admin, is_active)
VALUES ('USER_ID_HERE', 'admin', true, true);
```

## Step 3: Create Teams

1. Log in as the super admin (username: `admin`)
2. Click **"User Management"** on the home page
3. Click **"+ Create Team"**
4. Create your teams (e.g., "Department 1", "Department 2", etc.)

## Step 4: Create Users

1. In **User Management**, click **"+ Create User"**
2. Fill in:
   - Username (e.g., `john.doe`)
   - Password (min 6 characters)
   - Full Name (optional)
   - Team (select from dropdown)
   - Super Admin (checkbox - only for additional super admins)
3. Click **"Create User"**

Users can now log in with their username and password.

## Step 5: Assign Existing Data to Teams

If you have existing data, you'll need to assign it to teams:

```sql
-- Example: Assign all employees to a specific team
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

## Step 6: Environment Variables

Add the service role key to your `.env` file (for user creation):

```bash
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key  # Get this from Supabase Dashboard > Settings > API
```

**Important:** The service role key should NEVER be exposed to the client. It's only used server-side in `/server/api/admin/users/create.ts`.

## How It Works

### Authentication
- Users log in with **username** (not email)
- Internally, usernames are converted to `username@internal.local` for Supabase Auth
- Passwords are hashed and stored securely by Supabase

### Team Isolation
- Each user belongs to one team
- All data (employees, schedules, etc.) is filtered by `team_id`
- Users can only see/modify data from their team
- Super admins can see all teams' data

### Row Level Security (RLS)
- Database policies automatically filter queries by `team_id`
- Super admins bypass team filters (see everything)
- Regular users are restricted to their team's data

## Troubleshooting

### "Account not found" error
- User profile wasn't created. Create it via User Management.

### "Account is inactive" error
- User was deactivated. Reactivate via User Management.

### Can't see any data
- Check that your user has a `team_id` assigned
- Verify RLS policies are active
- Check that data has `team_id` set

### Can't create users
- Verify `SUPABASE_SERVICE_ROLE_KEY` is set in `.env`
- Check that you're logged in as a super admin
- Check browser console for errors

## Next Steps

- Teams can be added later as needed
- You can assign users to different teams
- Super admins can manage everything
- Regular users are isolated to their team

