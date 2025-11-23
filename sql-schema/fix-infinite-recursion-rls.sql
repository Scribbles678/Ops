-- Fix Infinite Recursion in user_profiles RLS Policy
-- The "Super admins can view all profiles" policy causes infinite recursion
-- Run this in Supabase SQL Editor

-- Drop the problematic policy
DROP POLICY IF EXISTS "Super admins can view all profiles" ON user_profiles;

-- Create a function to check super admin status without triggering RLS
CREATE OR REPLACE FUNCTION check_is_super_admin(user_id UUID)
RETURNS BOOLEAN AS $$
  SELECT COALESCE(
    (SELECT is_super_admin FROM user_profiles WHERE id = user_id),
    false
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Recreate the policy using the function (avoids recursion)
CREATE POLICY "Super admins can view all profiles" 
ON user_profiles FOR SELECT 
USING (
  check_is_super_admin(auth.uid())
);

-- Also fix the other super admin policies that might have the same issue
DROP POLICY IF EXISTS "Super admins can insert profiles" ON user_profiles;
CREATE POLICY "Super admins can insert profiles" 
ON user_profiles FOR INSERT 
WITH CHECK (
  check_is_super_admin(auth.uid())
);

DROP POLICY IF EXISTS "Super admins can update all profiles" ON user_profiles;
CREATE POLICY "Super admins can update all profiles" 
ON user_profiles FOR UPDATE 
USING (
  check_is_super_admin(auth.uid())
);

DROP POLICY IF EXISTS "Super admins can delete profiles" ON user_profiles;
CREATE POLICY "Super admins can delete profiles" 
ON user_profiles FOR DELETE 
USING (
  check_is_super_admin(auth.uid())
);

