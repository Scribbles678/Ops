-- Fix Infinite Recursion in Admin Role RLS Policies
-- The new policies are causing recursion because subqueries in policies trigger RLS
-- Run this to fix the recursion issue

-- Step 1: Create a SECURITY DEFINER function to get user's team_id (bypasses RLS)
CREATE OR REPLACE FUNCTION get_user_team_id()
RETURNS UUID AS $$
  SELECT team_id FROM user_profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Step 2: Ensure is_admin() function is SECURITY DEFINER to bypass RLS
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
  SELECT COALESCE(
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()),
    false
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Step 3: Ensure is_super_admin() function is SECURITY DEFINER (should already be, but ensure it)
CREATE OR REPLACE FUNCTION is_super_admin()
RETURNS BOOLEAN AS $$
  SELECT COALESCE(
    (SELECT is_super_admin FROM user_profiles WHERE id = auth.uid()),
    false
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Step 4: Drop and recreate the SELECT policy to avoid recursion
DROP POLICY IF EXISTS "Users can view own profile or team" ON user_profiles;

CREATE POLICY "Users can view own profile or team" 
ON user_profiles FOR SELECT 
USING (
  -- User can see their own profile (direct check, no recursion)
  auth.uid() = id
  OR
  -- Super admins can see all profiles (function is SECURITY DEFINER, no recursion)
  is_super_admin()
  OR
  -- Admins can see users in their own team
  -- Use get_user_team_id() function (SECURITY DEFINER) to avoid recursion
  (
    is_admin()
    AND team_id = get_user_team_id()
    AND team_id IS NOT NULL
  )
);

-- Step 5: Fix the UPDATE policy to use the function as well
DROP POLICY IF EXISTS "Users can update own profile or team" ON user_profiles;

CREATE POLICY "Users can update own profile or team" 
ON user_profiles FOR UPDATE 
USING (
  -- User can update their own profile
  auth.uid() = id
  OR
  -- Super admins can update all profiles
  is_super_admin()
  OR
  -- Admins can update users in their own team
  (
    is_admin()
    AND team_id = get_user_team_id()
    AND team_id IS NOT NULL
    AND id != auth.uid() -- Admins cannot update themselves
  )
)
WITH CHECK (
  -- User updating themselves - allowed (trigger will prevent role/team changes)
  auth.uid() = id
  OR
  -- Super admins can update anything
  is_super_admin()
  OR
  -- Admins can update users in their team
  -- Note: The trigger will prevent admins from changing roles/teams
  (
    is_admin()
    AND team_id = get_user_team_id()
    AND team_id IS NOT NULL
  )
);

-- Step 6: Verify functions are SECURITY DEFINER
SELECT 
  proname as function_name,
  prosecdef as is_security_definer
FROM pg_proc
WHERE proname IN ('is_admin', 'is_super_admin', 'get_user_team_id')
AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

