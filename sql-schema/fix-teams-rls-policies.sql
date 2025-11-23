-- Fix Teams RLS Policies to Use SECURITY DEFINER Functions
-- This prevents recursion issues when checking super admin status

-- Drop existing teams policies
DROP POLICY IF EXISTS "Super admins can view all teams" ON teams;
DROP POLICY IF EXISTS "Users can view own team" ON teams;
DROP POLICY IF EXISTS "Super admins can insert teams" ON teams;
DROP POLICY IF EXISTS "Super admins can update teams" ON teams;
DROP POLICY IF EXISTS "Super admins can delete teams" ON teams;

-- Recreate policies using SECURITY DEFINER functions (no recursion)
CREATE POLICY "Super admins can view all teams" 
ON teams FOR SELECT 
USING (
  is_super_admin()
);

CREATE POLICY "Users can view own team" 
ON teams FOR SELECT 
USING (
  id = get_user_team_id()
  AND get_user_team_id() IS NOT NULL
);

CREATE POLICY "Super admins can insert teams" 
ON teams FOR INSERT 
WITH CHECK (
  is_super_admin()
);

CREATE POLICY "Super admins can update teams" 
ON teams FOR UPDATE 
USING (
  is_super_admin()
);

CREATE POLICY "Super admins can delete teams" 
ON teams FOR DELETE 
USING (
  is_super_admin()
);

