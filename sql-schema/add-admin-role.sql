-- Add Admin Role to User Profiles
-- This implements Option 2: User + Admin + Super Admin

-- Step 1: Add is_admin column
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT false;

-- Step 2: Create index for admin lookups
CREATE INDEX IF NOT EXISTS idx_user_profiles_admin ON user_profiles(is_admin);

-- Step 3: Create function to check if user is admin (for their team)
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
  SELECT COALESCE(
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()),
    false
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Step 4: Create function to check if user is admin OR super admin
CREATE OR REPLACE FUNCTION is_admin_or_super_admin()
RETURNS BOOLEAN AS $$
  SELECT COALESCE(
    (SELECT is_admin OR is_super_admin FROM user_profiles WHERE id = auth.uid()),
    false
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Step 5: Update RLS policies to allow admins to manage users in their own team
-- First, drop existing SELECT policies that might conflict
DROP POLICY IF EXISTS "Users can view own profile" ON user_profiles;
DROP POLICY IF EXISTS "Super admins can view all profiles" ON user_profiles;

-- Create new SELECT policy that includes admin access
CREATE POLICY "Users can view own profile or team" 
ON user_profiles FOR SELECT 
USING (
  -- User can see their own profile
  auth.uid() = id
  OR
  -- Super admins can see all profiles
  is_super_admin()
  OR
  -- Admins can see users in their own team
  (
    is_admin()
    AND team_id = (SELECT team_id FROM user_profiles WHERE id = auth.uid())
    AND team_id IS NOT NULL
  )
);

-- Step 6: Admins can update users in their own team (but not change roles or team)
-- Drop existing UPDATE policies
DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;
DROP POLICY IF EXISTS "Super admins can update all profiles" ON user_profiles;

-- Create new UPDATE policy that includes admin access
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
    AND team_id = (SELECT team_id FROM user_profiles WHERE id = auth.uid())
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
    AND team_id = (SELECT team_id FROM user_profiles WHERE id = auth.uid())
    AND team_id IS NOT NULL
  )
);

-- Step 7: Only super admins can insert new user profiles
-- (This policy should already exist, but we'll ensure it's correct)
DROP POLICY IF EXISTS "Super admins can insert profiles" ON user_profiles;
CREATE POLICY "Super admins can insert profiles" 
ON user_profiles FOR INSERT 
WITH CHECK (
  is_super_admin()
);

-- Step 8: Only super admins can delete user profiles
DROP POLICY IF EXISTS "Super admins can delete profiles" ON user_profiles;
CREATE POLICY "Super admins can delete profiles" 
ON user_profiles FOR DELETE 
USING (
  is_super_admin()
);

-- Step 9: Update trigger to prevent admins from changing roles
-- (This should already exist, but we'll ensure it prevents admin role changes too)
CREATE OR REPLACE FUNCTION prevent_user_profile_privilege_changes()
RETURNS TRIGGER AS $$
BEGIN
  -- Only super admins can change is_super_admin, is_admin, or team_id
  IF NOT is_super_admin() THEN
    -- Prevent changing is_super_admin
    IF OLD.is_super_admin IS DISTINCT FROM NEW.is_super_admin THEN
      RAISE EXCEPTION 'Only super admins can change super admin status';
    END IF;
    
    -- Prevent changing is_admin (unless you're a super admin)
    IF OLD.is_admin IS DISTINCT FROM NEW.is_admin THEN
      RAISE EXCEPTION 'Only super admins can change admin status';
    END IF;
    
    -- Prevent changing team_id (unless you're a super admin)
    IF OLD.team_id IS DISTINCT FROM NEW.team_id THEN
      RAISE EXCEPTION 'Only super admins can change team assignment';
    END IF;
  END IF;
  
  -- Update updated_at timestamp
  NEW.updated_at = NOW();
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ensure trigger exists
DROP TRIGGER IF EXISTS prevent_user_profile_privilege_changes_trigger ON user_profiles;
CREATE TRIGGER prevent_user_profile_privilege_changes_trigger
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION prevent_user_profile_privilege_changes();

-- Step 10: Verify the changes
SELECT 
  'Admin role added successfully!' as status,
  COUNT(*) FILTER (WHERE is_admin = true) as admin_count,
  COUNT(*) FILTER (WHERE is_super_admin = true) as super_admin_count,
  COUNT(*) FILTER (WHERE is_admin = false AND is_super_admin = false) as user_count
FROM user_profiles;

