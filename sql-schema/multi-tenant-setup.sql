-- Multi-Tenant Setup for Operations Scheduling Tool
-- Run this SQL in your Supabase SQL Editor

-- ============================================
-- 1. TEAMS TABLE (Create table first, policies later)
-- ============================================
CREATE TABLE IF NOT EXISTS teams (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for team lookups
CREATE INDEX IF NOT EXISTS idx_teams_name ON teams(name);

-- Enable RLS (but don't create policies yet - they reference user_profiles)
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 2. USER PROFILES TABLE (Create before teams policies)
-- ============================================
CREATE TABLE IF NOT EXISTS user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT NOT NULL UNIQUE,
  email TEXT, -- Added for email-based login
  team_id UUID REFERENCES teams(id) ON DELETE SET NULL,
  full_name TEXT,
  is_super_admin BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_user_profiles_username ON user_profiles(username);
CREATE INDEX IF NOT EXISTS idx_user_profiles_email ON user_profiles(email);
CREATE INDEX IF NOT EXISTS idx_user_profiles_team ON user_profiles(team_id);
CREATE INDEX IF NOT EXISTS idx_user_profiles_admin ON user_profiles(is_super_admin);

-- Enable RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- RLS Policies for user_profiles
-- Users can view their own profile
CREATE POLICY "Users can view own profile" 
ON user_profiles FOR SELECT 
USING (auth.uid() = id);

-- Super admins can view all profiles (using function to avoid recursion)
CREATE POLICY "Super admins can view all profiles" 
ON user_profiles FOR SELECT 
USING (
  is_super_admin()
);

-- Users can update their own profile (limited fields)
-- Note: We can't prevent field changes in WITH CHECK, so we'll use a trigger or handle in application
CREATE POLICY "Users can update own profile" 
ON user_profiles FOR UPDATE 
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Super admins can manage all profiles (using function to avoid recursion)
CREATE POLICY "Super admins can insert profiles" 
ON user_profiles FOR INSERT 
WITH CHECK (
  is_super_admin()
);

CREATE POLICY "Super admins can update all profiles" 
ON user_profiles FOR UPDATE 
USING (
  is_super_admin()
);

CREATE POLICY "Super admins can delete profiles" 
ON user_profiles FOR DELETE 
USING (
  is_super_admin()
);

-- ============================================
-- 3. TEAMS TABLE POLICIES (Now that user_profiles exists)
-- ============================================
-- RLS Policies for teams
-- Super admins can see all teams
-- Regular users can see their own team
CREATE POLICY "Super admins can view all teams" 
ON teams FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE id = auth.uid() 
    AND is_super_admin = true
  )
);

CREATE POLICY "Users can view own team" 
ON teams FOR SELECT 
USING (
  id IN (
    SELECT team_id FROM user_profiles WHERE id = auth.uid()
  )
);

-- Super admins can manage teams
CREATE POLICY "Super admins can insert teams" 
ON teams FOR INSERT 
WITH CHECK (
  EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE id = auth.uid() 
    AND is_super_admin = true
  )
);

CREATE POLICY "Super admins can update teams" 
ON teams FOR UPDATE 
USING (
  EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE id = auth.uid() 
    AND is_super_admin = true
  )
);

CREATE POLICY "Super admins can delete teams" 
ON teams FOR DELETE 
USING (
  EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE id = auth.uid() 
    AND is_super_admin = true
  )
);

-- ============================================
-- 4. ADD team_id TO ALL EXISTING TABLES
-- ============================================

-- Employees
ALTER TABLE employees ADD COLUMN IF NOT EXISTS team_id UUID REFERENCES teams(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_employees_team ON employees(team_id);

-- Job Functions
ALTER TABLE job_functions ADD COLUMN IF NOT EXISTS team_id UUID REFERENCES teams(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_job_functions_team ON job_functions(team_id);

-- Shifts
ALTER TABLE shifts ADD COLUMN IF NOT EXISTS team_id UUID REFERENCES teams(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_shifts_team ON shifts(team_id);

-- Schedule Assignments
ALTER TABLE schedule_assignments ADD COLUMN IF NOT EXISTS team_id UUID REFERENCES teams(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_schedule_assignments_team ON schedule_assignments(team_id);

-- Daily Targets
ALTER TABLE daily_targets ADD COLUMN IF NOT EXISTS team_id UUID REFERENCES teams(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_daily_targets_team ON daily_targets(team_id);

-- Employee Training
ALTER TABLE employee_training ADD COLUMN IF NOT EXISTS team_id UUID REFERENCES teams(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_employee_training_team ON employee_training(team_id);

-- PTO Days
ALTER TABLE pto_days ADD COLUMN IF NOT EXISTS team_id UUID REFERENCES teams(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_pto_days_team ON pto_days(team_id);

-- Shift Swaps
ALTER TABLE shift_swaps ADD COLUMN IF NOT EXISTS team_id UUID REFERENCES teams(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_shift_swaps_team ON shift_swaps(team_id);

-- Business Rules
ALTER TABLE business_rules ADD COLUMN IF NOT EXISTS team_id UUID REFERENCES teams(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_business_rules_team ON business_rules(team_id);

-- Preferred Assignments (if exists)
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'preferred_assignments') THEN
    ALTER TABLE preferred_assignments ADD COLUMN IF NOT EXISTS team_id UUID REFERENCES teams(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_preferred_assignments_team ON preferred_assignments(team_id);
  END IF;
END $$;

-- ============================================
-- 6. UPDATE RLS POLICIES FOR TEAM ISOLATION
-- ============================================

-- Function to get user's team_id
CREATE OR REPLACE FUNCTION get_user_team_id()
RETURNS UUID AS $$
  SELECT team_id FROM user_profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER;

-- Function to check if user is super admin (SECURITY DEFINER to avoid RLS recursion)
CREATE OR REPLACE FUNCTION is_super_admin()
RETURNS BOOLEAN AS $$
  SELECT COALESCE(
    (SELECT is_super_admin FROM user_profiles WHERE id = auth.uid()),
    false
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ============================================
-- EMPLOYEES TABLE POLICIES
-- ============================================
DROP POLICY IF EXISTS "Enable read access for all users" ON employees;
DROP POLICY IF EXISTS "Enable insert for all users" ON employees;
DROP POLICY IF EXISTS "Enable update for all users" ON employees;
DROP POLICY IF EXISTS "Enable delete for all users" ON employees;

-- Super admins can see all
CREATE POLICY "Super admins can view all employees" 
ON employees FOR SELECT 
USING (is_super_admin());

-- Users can see their team's employees
CREATE POLICY "Users can view own team employees" 
ON employees FOR SELECT 
USING (team_id = get_user_team_id());

-- Super admins can manage all
CREATE POLICY "Super admins can manage all employees" 
ON employees FOR ALL 
USING (is_super_admin());

-- Users can manage their team's employees
CREATE POLICY "Users can insert own team employees" 
ON employees FOR INSERT 
WITH CHECK (team_id = get_user_team_id());

CREATE POLICY "Users can update own team employees" 
ON employees FOR UPDATE 
USING (team_id = get_user_team_id())
WITH CHECK (team_id = get_user_team_id());

CREATE POLICY "Users can delete own team employees" 
ON employees FOR DELETE 
USING (team_id = get_user_team_id());

-- ============================================
-- JOB FUNCTIONS TABLE POLICIES
-- ============================================
DROP POLICY IF EXISTS "Enable read access for all users" ON job_functions;
DROP POLICY IF EXISTS "Enable insert for all users" ON job_functions;
DROP POLICY IF EXISTS "Enable update for all users" ON job_functions;
DROP POLICY IF EXISTS "Enable delete for all users" ON job_functions;

CREATE POLICY "Super admins can view all job functions" 
ON job_functions FOR SELECT 
USING (is_super_admin());

CREATE POLICY "Users can view own team job functions" 
ON job_functions FOR SELECT 
USING (team_id = get_user_team_id());

CREATE POLICY "Super admins can manage all job functions" 
ON job_functions FOR ALL 
USING (is_super_admin());

CREATE POLICY "Users can insert own team job functions" 
ON job_functions FOR INSERT 
WITH CHECK (team_id = get_user_team_id());

CREATE POLICY "Users can update own team job functions" 
ON job_functions FOR UPDATE 
USING (team_id = get_user_team_id())
WITH CHECK (team_id = get_user_team_id());

CREATE POLICY "Users can delete own team job functions" 
ON job_functions FOR DELETE 
USING (team_id = get_user_team_id());

-- ============================================
-- SHIFTS TABLE POLICIES
-- ============================================
DROP POLICY IF EXISTS "Enable read access for all users" ON shifts;
DROP POLICY IF EXISTS "Enable insert for all users" ON shifts;
DROP POLICY IF EXISTS "Enable update for all users" ON shifts;
DROP POLICY IF EXISTS "Enable delete for all users" ON shifts;

CREATE POLICY "Super admins can view all shifts" 
ON shifts FOR SELECT 
USING (is_super_admin());

CREATE POLICY "Users can view own team shifts" 
ON shifts FOR SELECT 
USING (team_id = get_user_team_id());

CREATE POLICY "Super admins can manage all shifts" 
ON shifts FOR ALL 
USING (is_super_admin());

CREATE POLICY "Users can insert own team shifts" 
ON shifts FOR INSERT 
WITH CHECK (team_id = get_user_team_id());

CREATE POLICY "Users can update own team shifts" 
ON shifts FOR UPDATE 
USING (team_id = get_user_team_id())
WITH CHECK (team_id = get_user_team_id());

CREATE POLICY "Users can delete own team shifts" 
ON shifts FOR DELETE 
USING (team_id = get_user_team_id());

-- ============================================
-- SCHEDULE ASSIGNMENTS TABLE POLICIES
-- ============================================
DROP POLICY IF EXISTS "Enable read access for all users" ON schedule_assignments;
DROP POLICY IF EXISTS "Enable insert for all users" ON schedule_assignments;
DROP POLICY IF EXISTS "Enable update for all users" ON schedule_assignments;
DROP POLICY IF EXISTS "Enable delete for all users" ON schedule_assignments;

CREATE POLICY "Super admins can view all schedule assignments" 
ON schedule_assignments FOR SELECT 
USING (is_super_admin());

CREATE POLICY "Users can view own team schedule assignments" 
ON schedule_assignments FOR SELECT 
USING (team_id = get_user_team_id());

CREATE POLICY "Super admins can manage all schedule assignments" 
ON schedule_assignments FOR ALL 
USING (is_super_admin());

CREATE POLICY "Users can insert own team schedule assignments" 
ON schedule_assignments FOR INSERT 
WITH CHECK (team_id = get_user_team_id());

CREATE POLICY "Users can update own team schedule assignments" 
ON schedule_assignments FOR UPDATE 
USING (team_id = get_user_team_id())
WITH CHECK (team_id = get_user_team_id());

CREATE POLICY "Users can delete own team schedule assignments" 
ON schedule_assignments FOR DELETE 
USING (team_id = get_user_team_id());

-- ============================================
-- DAILY TARGETS TABLE POLICIES
-- ============================================
DROP POLICY IF EXISTS "Enable read access for all users" ON daily_targets;
DROP POLICY IF EXISTS "Enable insert for all users" ON daily_targets;
DROP POLICY IF EXISTS "Enable update for all users" ON daily_targets;
DROP POLICY IF EXISTS "Enable delete for all users" ON daily_targets;

CREATE POLICY "Super admins can view all daily targets" 
ON daily_targets FOR SELECT 
USING (is_super_admin());

CREATE POLICY "Users can view own team daily targets" 
ON daily_targets FOR SELECT 
USING (team_id = get_user_team_id());

CREATE POLICY "Super admins can manage all daily targets" 
ON daily_targets FOR ALL 
USING (is_super_admin());

CREATE POLICY "Users can insert own team daily targets" 
ON daily_targets FOR INSERT 
WITH CHECK (team_id = get_user_team_id());

CREATE POLICY "Users can update own team daily targets" 
ON daily_targets FOR UPDATE 
USING (team_id = get_user_team_id())
WITH CHECK (team_id = get_user_team_id());

CREATE POLICY "Users can delete own team daily targets" 
ON daily_targets FOR DELETE 
USING (team_id = get_user_team_id());

-- ============================================
-- EMPLOYEE TRAINING TABLE POLICIES
-- ============================================
DROP POLICY IF EXISTS "Enable read access for all users" ON employee_training;
DROP POLICY IF EXISTS "Enable insert for all users" ON employee_training;
DROP POLICY IF EXISTS "Enable update for all users" ON employee_training;
DROP POLICY IF EXISTS "Enable delete for all users" ON employee_training;

CREATE POLICY "Super admins can view all employee training" 
ON employee_training FOR SELECT 
USING (is_super_admin());

CREATE POLICY "Users can view own team employee training" 
ON employee_training FOR SELECT 
USING (team_id = get_user_team_id());

CREATE POLICY "Super admins can manage all employee training" 
ON employee_training FOR ALL 
USING (is_super_admin());

CREATE POLICY "Users can insert own team employee training" 
ON employee_training FOR INSERT 
WITH CHECK (team_id = get_user_team_id());

CREATE POLICY "Users can update own team employee training" 
ON employee_training FOR UPDATE 
USING (team_id = get_user_team_id())
WITH CHECK (team_id = get_user_team_id());

CREATE POLICY "Users can delete own team employee training" 
ON employee_training FOR DELETE 
USING (team_id = get_user_team_id());

-- ============================================
-- PTO DAYS TABLE POLICIES
-- ============================================
DROP POLICY IF EXISTS "Enable read access for all users" ON pto_days;
DROP POLICY IF EXISTS "Enable insert for all users" ON pto_days;
DROP POLICY IF EXISTS "Enable update for all users" ON pto_days;
DROP POLICY IF EXISTS "Enable delete for all users" ON pto_days;

CREATE POLICY "Super admins can view all pto days" 
ON pto_days FOR SELECT 
USING (is_super_admin());

CREATE POLICY "Users can view own team pto days" 
ON pto_days FOR SELECT 
USING (team_id = get_user_team_id());

CREATE POLICY "Super admins can manage all pto days" 
ON pto_days FOR ALL 
USING (is_super_admin());

CREATE POLICY "Users can insert own team pto days" 
ON pto_days FOR INSERT 
WITH CHECK (team_id = get_user_team_id());

CREATE POLICY "Users can update own team pto days" 
ON pto_days FOR UPDATE 
USING (team_id = get_user_team_id())
WITH CHECK (team_id = get_user_team_id());

CREATE POLICY "Users can delete own team pto days" 
ON pto_days FOR DELETE 
USING (team_id = get_user_team_id());

-- ============================================
-- SHIFT SWAPS TABLE POLICIES
-- ============================================
DROP POLICY IF EXISTS "Enable read access for all users" ON shift_swaps;
DROP POLICY IF EXISTS "Enable insert for all users" ON shift_swaps;
DROP POLICY IF EXISTS "Enable update for all users" ON shift_swaps;
DROP POLICY IF EXISTS "Enable delete for all users" ON shift_swaps;

CREATE POLICY "Super admins can view all shift swaps" 
ON shift_swaps FOR SELECT 
USING (is_super_admin());

CREATE POLICY "Users can view own team shift swaps" 
ON shift_swaps FOR SELECT 
USING (team_id = get_user_team_id());

CREATE POLICY "Super admins can manage all shift swaps" 
ON shift_swaps FOR ALL 
USING (is_super_admin());

CREATE POLICY "Users can insert own team shift swaps" 
ON shift_swaps FOR INSERT 
WITH CHECK (team_id = get_user_team_id());

CREATE POLICY "Users can update own team shift swaps" 
ON shift_swaps FOR UPDATE 
USING (team_id = get_user_team_id())
WITH CHECK (team_id = get_user_team_id());

CREATE POLICY "Users can delete own team shift swaps" 
ON shift_swaps FOR DELETE 
USING (team_id = get_user_team_id());

-- ============================================
-- BUSINESS RULES TABLE POLICIES
-- ============================================
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'business_rules') THEN
    DROP POLICY IF EXISTS "Enable read access for all users" ON business_rules;
    DROP POLICY IF EXISTS "Enable insert for all users" ON business_rules;
    DROP POLICY IF EXISTS "Enable update for all users" ON business_rules;
    DROP POLICY IF EXISTS "Enable delete for all users" ON business_rules;

    CREATE POLICY "Super admins can view all business rules" 
    ON business_rules FOR SELECT 
    USING (is_super_admin());

    CREATE POLICY "Users can view own team business rules" 
    ON business_rules FOR SELECT 
    USING (team_id = get_user_team_id());

    CREATE POLICY "Super admins can manage all business rules" 
    ON business_rules FOR ALL 
    USING (is_super_admin());

    CREATE POLICY "Users can insert own team business rules" 
    ON business_rules FOR INSERT 
    WITH CHECK (team_id = get_user_team_id());

    CREATE POLICY "Users can update own team business rules" 
    ON business_rules FOR UPDATE 
    USING (team_id = get_user_team_id())
    WITH CHECK (team_id = get_user_team_id());

    CREATE POLICY "Users can delete own team business rules" 
    ON business_rules FOR DELETE 
    USING (team_id = get_user_team_id());
  END IF;
END $$;

-- ============================================
-- TRIGGER: Auto-create user profile on signup
-- ============================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Note: User profile will be created by admin, not automatically
  -- This function is here for future use if needed
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- TRIGGER: Update updated_at timestamps
-- ============================================
CREATE OR REPLACE FUNCTION update_teams_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_teams_updated_at
  BEFORE UPDATE ON teams
  FOR EACH ROW
  EXECUTE FUNCTION update_teams_updated_at();

-- Trigger to prevent users from changing their own is_super_admin or team_id
CREATE OR REPLACE FUNCTION prevent_user_profile_privilege_changes()
RETURNS TRIGGER AS $$
BEGIN
  -- If user is not a super admin, prevent changes to is_super_admin and team_id
  IF NOT EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE id = auth.uid() 
    AND is_super_admin = true
  ) THEN
    -- Regular users cannot change these fields
    IF OLD.is_super_admin IS DISTINCT FROM NEW.is_super_admin THEN
      RAISE EXCEPTION 'Cannot change is_super_admin field';
    END IF;
    IF OLD.team_id IS DISTINCT FROM NEW.team_id THEN
      RAISE EXCEPTION 'Cannot change team_id field';
    END IF;
  END IF;
  
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_prevent_user_profile_privilege_changes
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION prevent_user_profile_privilege_changes();

-- Also create trigger for updated_at (if update_updated_at_column function exists)
-- If the function doesn't exist, it will be created by your original schema
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'update_updated_at_column') THEN
    CREATE TRIGGER trigger_update_user_profiles_updated_at
      BEFORE UPDATE ON user_profiles
      FOR EACH ROW
      EXECUTE FUNCTION update_updated_at_column();
  END IF;
END $$;

-- ============================================
-- NOTES
-- ============================================
-- 1. Teams can be added later via admin interface
-- 2. First user should be created as super admin manually
-- 3. All existing data will need team_id assigned (can be done via admin interface)
-- 4. Display mode may need special handling (consider making it team-aware or public)

