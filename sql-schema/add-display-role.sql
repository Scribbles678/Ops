-- Add Display Role for TV Screens
-- This creates a read-only role that can only view today's schedule
-- Run this SQL in your Supabase SQL Editor

-- ============================================
-- STEP 1: Add is_display_user column to user_profiles
-- ============================================
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS is_display_user BOOLEAN DEFAULT false;

-- Create index for display user lookups
CREATE INDEX IF NOT EXISTS idx_user_profiles_display ON user_profiles(is_display_user);

-- ============================================
-- STEP 2: Create helper function to check if user is display user
-- ============================================
CREATE OR REPLACE FUNCTION is_display_user()
RETURNS BOOLEAN AS $$
  SELECT COALESCE(
    (SELECT is_display_user FROM user_profiles WHERE id = auth.uid()),
    false
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ============================================
-- STEP 3: Remove public display mode policies
-- ============================================
DROP POLICY IF EXISTS "Display mode can view today's schedule" ON schedule_assignments;
DROP POLICY IF EXISTS "Display mode can view today's employees" ON employees;
DROP POLICY IF EXISTS "Display mode can view today's shifts" ON shifts;
DROP POLICY IF EXISTS "Display mode can view today's job functions" ON job_functions;

-- ============================================
-- STEP 4: Create authenticated display user policies
-- ============================================
-- Display users can only view today's schedule (read-only, no write access)

-- Schedule Assignments (today only)
CREATE POLICY "Display users can view today's schedule assignments" 
ON schedule_assignments FOR SELECT 
USING (
  is_display_user()
  AND schedule_date = CURRENT_DATE
);

-- Employees (active only, for today's schedule)
CREATE POLICY "Display users can view active employees" 
ON employees FOR SELECT 
USING (
  is_display_user()
  AND is_active = true
);

-- Shifts (active only)
CREATE POLICY "Display users can view active shifts" 
ON shifts FOR SELECT 
USING (
  is_display_user()
  AND is_active = true
);

-- Job Functions (for displaying schedule)
CREATE POLICY "Display users can view job functions" 
ON job_functions FOR SELECT 
USING (is_display_user());

-- PTO Days (today only, to show who's off)
CREATE POLICY "Display users can view today's PTO" 
ON pto_days FOR SELECT 
USING (
  is_display_user()
  AND pto_date = CURRENT_DATE
);

-- Shift Swaps (today only)
CREATE POLICY "Display users can view today's shift swaps" 
ON shift_swaps FOR SELECT 
USING (
  is_display_user()
  AND swap_date = CURRENT_DATE
);

-- ============================================
-- STEP 5: Update user_profiles policies to allow super admins to manage display users
-- ============================================
-- Super admins can already view/manage all profiles (existing policies handle this)
-- No changes needed here

-- ============================================
-- NOTES
-- ============================================
-- To create a display user:
-- 1. Create user in Supabase Auth (email/password)
-- 2. Create profile in user_profiles with is_display_user = true
-- 3. Optionally assign to a specific team (team_id) if you want team-specific displays
-- 4. Display user can only view today's schedule - no write access
-- 5. Display user cannot access any other routes (middleware will redirect to /display)

-- Example SQL to create a display user:
-- INSERT INTO user_profiles (id, username, email, is_display_user, is_active, team_id)
-- VALUES (
--   'auth-user-uuid-here',  -- UUID from auth.users
--   'display-tv-1',
--   'display@yourcompany.com',
--   true,
--   true,
--   'team-uuid-here'  -- Optional: specific team, or NULL for all teams
-- );

