-- Fix Issue 4.2: Public Database Access
-- This migration removes all public access policies and ensures all tables require authentication
-- Run this SQL in your Supabase SQL Editor

-- ============================================
-- STEP 1: Drop ALL old public access policies
-- ============================================

-- Employees
DROP POLICY IF EXISTS "Enable read access for all users" ON employees;
DROP POLICY IF EXISTS "Enable insert for all users" ON employees;
DROP POLICY IF EXISTS "Enable update for all users" ON employees;
DROP POLICY IF EXISTS "Enable delete for all users" ON employees;

-- Job Functions
DROP POLICY IF EXISTS "Enable read access for all users" ON job_functions;
DROP POLICY IF EXISTS "Enable insert for all users" ON job_functions;
DROP POLICY IF EXISTS "Enable update for all users" ON job_functions;
DROP POLICY IF EXISTS "Enable delete for all users" ON job_functions;

-- Employee Training
DROP POLICY IF EXISTS "Enable read access for all users" ON employee_training;
DROP POLICY IF EXISTS "Enable insert for all users" ON employee_training;
DROP POLICY IF EXISTS "Enable update for all users" ON employee_training;
DROP POLICY IF EXISTS "Enable delete for all users" ON employee_training;

-- Shifts
DROP POLICY IF EXISTS "Enable read access for all users" ON shifts;
DROP POLICY IF EXISTS "Enable insert for all users" ON shifts;
DROP POLICY IF EXISTS "Enable update for all users" ON shifts;
DROP POLICY IF EXISTS "Enable delete for all users" ON shifts;

-- Schedule Assignments
DROP POLICY IF EXISTS "Enable read access for all users" ON schedule_assignments;
DROP POLICY IF EXISTS "Enable insert for all users" ON schedule_assignments;
DROP POLICY IF EXISTS "Enable update for all users" ON schedule_assignments;
DROP POLICY IF EXISTS "Enable delete for all users" ON schedule_assignments;

-- Daily Targets
DROP POLICY IF EXISTS "Enable read access for all users" ON daily_targets;
DROP POLICY IF EXISTS "Enable insert for all users" ON daily_targets;
DROP POLICY IF EXISTS "Enable update for all users" ON daily_targets;
DROP POLICY IF EXISTS "Enable delete for all users" ON daily_targets;

-- PTO Days
DROP POLICY IF EXISTS "Enable read access for all users" ON pto_days;
DROP POLICY IF EXISTS "Enable insert for all users" ON pto_days;
DROP POLICY IF EXISTS "Enable update for all users" ON pto_days;
DROP POLICY IF EXISTS "Enable delete for all users" ON pto_days;

-- Shift Swaps
DROP POLICY IF EXISTS "Enable read access for all users" ON shift_swaps;
DROP POLICY IF EXISTS "Enable insert for all users" ON shift_swaps;
DROP POLICY IF EXISTS "Enable update for all users" ON shift_swaps;
DROP POLICY IF EXISTS "Enable delete for all users" ON shift_swaps;

-- Business Rules
DROP POLICY IF EXISTS "Enable read access for all users" ON business_rules;
DROP POLICY IF EXISTS "Enable insert for all users" ON business_rules;
DROP POLICY IF EXISTS "Enable update for all users" ON business_rules;
DROP POLICY IF EXISTS "Enable delete for all users" ON business_rules;

-- Preferred Assignments (if exists)
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'preferred_assignments') THEN
    DROP POLICY IF EXISTS "Enable read access for all users" ON preferred_assignments;
    DROP POLICY IF EXISTS "Enable insert access for all users" ON preferred_assignments;
    DROP POLICY IF EXISTS "Enable update access for all users" ON preferred_assignments;
    DROP POLICY IF EXISTS "Enable delete access for all users" ON preferred_assignments;
  END IF;
END $$;

-- Archive Tables
DROP POLICY IF EXISTS "Enable read access for all users" ON schedule_assignments_archive;
DROP POLICY IF EXISTS "Enable read access for all users" ON daily_targets_archive;

-- Target Hours (if exists)
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'target_hours') THEN
    DROP POLICY IF EXISTS "Enable all access for all users" ON target_hours;
    DROP POLICY IF EXISTS "Allow all operations on target_hours for authenticated users" ON target_hours;
  END IF;
END $$;

-- ============================================
-- STEP 2: Ensure helper functions exist
-- ============================================

-- Function to get user's team_id (SECURITY DEFINER to bypass RLS)
CREATE OR REPLACE FUNCTION get_user_team_id()
RETURNS UUID AS $$
  SELECT team_id FROM user_profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Function to check if user is super admin (SECURITY DEFINER to bypass RLS)
CREATE OR REPLACE FUNCTION is_super_admin()
RETURNS BOOLEAN AS $$
  SELECT COALESCE(
    (SELECT is_super_admin FROM user_profiles WHERE id = auth.uid()),
    false
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Function to check if user is admin (SECURITY DEFINER to bypass RLS)
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
  SELECT COALESCE(
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()),
    false
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ============================================
-- STEP 3: Verify authenticated policies exist for all tables
-- If they don't exist, create them
-- ============================================

-- Note: The multi-tenant-setup.sql should have already created these policies,
-- but we'll verify and create them if missing to ensure complete coverage

-- Employees policies (verify/create)
DO $$
BEGIN
  -- Check if authenticated policies exist
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'employees' 
    AND policyname = 'Super admins can view all employees'
  ) THEN
    CREATE POLICY "Super admins can view all employees" 
    ON employees FOR SELECT 
    USING (is_super_admin());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'employees' 
    AND policyname = 'Users can view own team employees'
  ) THEN
    CREATE POLICY "Users can view own team employees" 
    ON employees FOR SELECT 
    USING (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'employees' 
    AND policyname = 'Super admins can manage all employees'
  ) THEN
    CREATE POLICY "Super admins can manage all employees" 
    ON employees FOR ALL 
    USING (is_super_admin());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'employees' 
    AND policyname = 'Users can insert own team employees'
  ) THEN
    CREATE POLICY "Users can insert own team employees" 
    ON employees FOR INSERT 
    WITH CHECK (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'employees' 
    AND policyname = 'Users can update own team employees'
  ) THEN
    CREATE POLICY "Users can update own team employees" 
    ON employees FOR UPDATE 
    USING (team_id = get_user_team_id() AND auth.uid() IS NOT NULL)
    WITH CHECK (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'employees' 
    AND policyname = 'Users can delete own team employees'
  ) THEN
    CREATE POLICY "Users can delete own team employees" 
    ON employees FOR DELETE 
    USING (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
  END IF;
END $$;

-- Job Functions policies (verify/create)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'job_functions' 
    AND policyname = 'Super admins can view all job functions'
  ) THEN
    CREATE POLICY "Super admins can view all job functions" 
    ON job_functions FOR SELECT 
    USING (is_super_admin());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'job_functions' 
    AND policyname = 'Users can view own team job functions'
  ) THEN
    CREATE POLICY "Users can view own team job functions" 
    ON job_functions FOR SELECT 
    USING (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'job_functions' 
    AND policyname = 'Super admins can manage all job functions'
  ) THEN
    CREATE POLICY "Super admins can manage all job functions" 
    ON job_functions FOR ALL 
    USING (is_super_admin());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'job_functions' 
    AND policyname = 'Users can insert own team job functions'
  ) THEN
    CREATE POLICY "Users can insert own team job functions" 
    ON job_functions FOR INSERT 
    WITH CHECK (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'job_functions' 
    AND policyname = 'Users can update own team job functions'
  ) THEN
    CREATE POLICY "Users can update own team job functions" 
    ON job_functions FOR UPDATE 
    USING (team_id = get_user_team_id() AND auth.uid() IS NOT NULL)
    WITH CHECK (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'job_functions' 
    AND policyname = 'Users can delete own team job functions'
  ) THEN
    CREATE POLICY "Users can delete own team job functions" 
    ON job_functions FOR DELETE 
    USING (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
  END IF;
END $$;

-- Shifts policies (verify/create)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'shifts' 
    AND policyname = 'Super admins can view all shifts'
  ) THEN
    CREATE POLICY "Super admins can view all shifts" 
    ON shifts FOR SELECT 
    USING (is_super_admin());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'shifts' 
    AND policyname = 'Users can view own team shifts'
  ) THEN
    CREATE POLICY "Users can view own team shifts" 
    ON shifts FOR SELECT 
    USING (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'shifts' 
    AND policyname = 'Super admins can manage all shifts'
  ) THEN
    CREATE POLICY "Super admins can manage all shifts" 
    ON shifts FOR ALL 
    USING (is_super_admin());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'shifts' 
    AND policyname = 'Users can insert own team shifts'
  ) THEN
    CREATE POLICY "Users can insert own team shifts" 
    ON shifts FOR INSERT 
    WITH CHECK (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'shifts' 
    AND policyname = 'Users can update own team shifts'
  ) THEN
    CREATE POLICY "Users can update own team shifts" 
    ON shifts FOR UPDATE 
    USING (team_id = get_user_team_id() AND auth.uid() IS NOT NULL)
    WITH CHECK (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'shifts' 
    AND policyname = 'Users can delete own team shifts'
  ) THEN
    CREATE POLICY "Users can delete own team shifts" 
    ON shifts FOR DELETE 
    USING (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
  END IF;
END $$;

-- Schedule Assignments policies (verify/create)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'schedule_assignments' 
    AND policyname = 'Super admins can view all schedule assignments'
  ) THEN
    CREATE POLICY "Super admins can view all schedule assignments" 
    ON schedule_assignments FOR SELECT 
    USING (is_super_admin());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'schedule_assignments' 
    AND policyname = 'Users can view own team schedule assignments'
  ) THEN
    CREATE POLICY "Users can view own team schedule assignments" 
    ON schedule_assignments FOR SELECT 
    USING (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'schedule_assignments' 
    AND policyname = 'Super admins can manage all schedule assignments'
  ) THEN
    CREATE POLICY "Super admins can manage all schedule assignments" 
    ON schedule_assignments FOR ALL 
    USING (is_super_admin());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'schedule_assignments' 
    AND policyname = 'Users can insert own team schedule assignments'
  ) THEN
    CREATE POLICY "Users can insert own team schedule assignments" 
    ON schedule_assignments FOR INSERT 
    WITH CHECK (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'schedule_assignments' 
    AND policyname = 'Users can update own team schedule assignments'
  ) THEN
    CREATE POLICY "Users can update own team schedule assignments" 
    ON schedule_assignments FOR UPDATE 
    USING (team_id = get_user_team_id() AND auth.uid() IS NOT NULL)
    WITH CHECK (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'schedule_assignments' 
    AND policyname = 'Users can delete own team schedule assignments'
  ) THEN
    CREATE POLICY "Users can delete own team schedule assignments" 
    ON schedule_assignments FOR DELETE 
    USING (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
  END IF;
END $$;

-- Daily Targets policies (verify/create)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'daily_targets' 
    AND policyname = 'Super admins can view all daily targets'
  ) THEN
    CREATE POLICY "Super admins can view all daily targets" 
    ON daily_targets FOR SELECT 
    USING (is_super_admin());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'daily_targets' 
    AND policyname = 'Users can view own team daily targets'
  ) THEN
    CREATE POLICY "Users can view own team daily targets" 
    ON daily_targets FOR SELECT 
    USING (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'daily_targets' 
    AND policyname = 'Super admins can manage all daily targets'
  ) THEN
    CREATE POLICY "Super admins can manage all daily targets" 
    ON daily_targets FOR ALL 
    USING (is_super_admin());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'daily_targets' 
    AND policyname = 'Users can insert own team daily targets'
  ) THEN
    CREATE POLICY "Users can insert own team daily targets" 
    ON daily_targets FOR INSERT 
    WITH CHECK (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'daily_targets' 
    AND policyname = 'Users can update own team daily targets'
  ) THEN
    CREATE POLICY "Users can update own team daily targets" 
    ON daily_targets FOR UPDATE 
    USING (team_id = get_user_team_id() AND auth.uid() IS NOT NULL)
    WITH CHECK (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'daily_targets' 
    AND policyname = 'Users can delete own team daily targets'
  ) THEN
    CREATE POLICY "Users can delete own team daily targets" 
    ON daily_targets FOR DELETE 
    USING (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
  END IF;
END $$;

-- Employee Training policies (verify/create)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'employee_training' 
    AND policyname = 'Super admins can view all employee training'
  ) THEN
    CREATE POLICY "Super admins can view all employee training" 
    ON employee_training FOR SELECT 
    USING (is_super_admin());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'employee_training' 
    AND policyname = 'Users can view own team employee training'
  ) THEN
    CREATE POLICY "Users can view own team employee training" 
    ON employee_training FOR SELECT 
    USING (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'employee_training' 
    AND policyname = 'Super admins can manage all employee training'
  ) THEN
    CREATE POLICY "Super admins can manage all employee training" 
    ON employee_training FOR ALL 
    USING (is_super_admin());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'employee_training' 
    AND policyname = 'Users can insert own team employee training'
  ) THEN
    CREATE POLICY "Users can insert own team employee training" 
    ON employee_training FOR INSERT 
    WITH CHECK (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'employee_training' 
    AND policyname = 'Users can update own team employee training'
  ) THEN
    CREATE POLICY "Users can update own team employee training" 
    ON employee_training FOR UPDATE 
    USING (team_id = get_user_team_id() AND auth.uid() IS NOT NULL)
    WITH CHECK (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'employee_training' 
    AND policyname = 'Users can delete own team employee training'
  ) THEN
    CREATE POLICY "Users can delete own team employee training" 
    ON employee_training FOR DELETE 
    USING (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
  END IF;
END $$;

-- PTO Days policies (verify/create)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'pto_days' 
    AND policyname = 'Super admins can view all pto days'
  ) THEN
    CREATE POLICY "Super admins can view all pto days" 
    ON pto_days FOR SELECT 
    USING (is_super_admin());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'pto_days' 
    AND policyname = 'Users can view own team pto days'
  ) THEN
    CREATE POLICY "Users can view own team pto days" 
    ON pto_days FOR SELECT 
    USING (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'pto_days' 
    AND policyname = 'Super admins can manage all pto days'
  ) THEN
    CREATE POLICY "Super admins can manage all pto days" 
    ON pto_days FOR ALL 
    USING (is_super_admin());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'pto_days' 
    AND policyname = 'Users can insert own team pto days'
  ) THEN
    CREATE POLICY "Users can insert own team pto days" 
    ON pto_days FOR INSERT 
    WITH CHECK (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'pto_days' 
    AND policyname = 'Users can update own team pto days'
  ) THEN
    CREATE POLICY "Users can update own team pto days" 
    ON pto_days FOR UPDATE 
    USING (team_id = get_user_team_id() AND auth.uid() IS NOT NULL)
    WITH CHECK (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'pto_days' 
    AND policyname = 'Users can delete own team pto days'
  ) THEN
    CREATE POLICY "Users can delete own team pto days" 
    ON pto_days FOR DELETE 
    USING (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
  END IF;
END $$;

-- Shift Swaps policies (verify/create)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'shift_swaps' 
    AND policyname = 'Super admins can view all shift swaps'
  ) THEN
    CREATE POLICY "Super admins can view all shift swaps" 
    ON shift_swaps FOR SELECT 
    USING (is_super_admin());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'shift_swaps' 
    AND policyname = 'Users can view own team shift swaps'
  ) THEN
    CREATE POLICY "Users can view own team shift swaps" 
    ON shift_swaps FOR SELECT 
    USING (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'shift_swaps' 
    AND policyname = 'Super admins can manage all shift swaps'
  ) THEN
    CREATE POLICY "Super admins can manage all shift swaps" 
    ON shift_swaps FOR ALL 
    USING (is_super_admin());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'shift_swaps' 
    AND policyname = 'Users can insert own team shift swaps'
  ) THEN
    CREATE POLICY "Users can insert own team shift swaps" 
    ON shift_swaps FOR INSERT 
    WITH CHECK (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'shift_swaps' 
    AND policyname = 'Users can update own team shift swaps'
  ) THEN
    CREATE POLICY "Users can update own team shift swaps" 
    ON shift_swaps FOR UPDATE 
    USING (team_id = get_user_team_id() AND auth.uid() IS NOT NULL)
    WITH CHECK (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'shift_swaps' 
    AND policyname = 'Users can delete own team shift swaps'
  ) THEN
    CREATE POLICY "Users can delete own team shift swaps" 
    ON shift_swaps FOR DELETE 
    USING (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
  END IF;
END $$;

-- Business Rules policies (verify/create)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'business_rules') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies 
      WHERE tablename = 'business_rules' 
      AND policyname = 'Super admins can view all business rules'
    ) THEN
      CREATE POLICY "Super admins can view all business rules" 
      ON business_rules FOR SELECT 
      USING (is_super_admin());
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pg_policies 
      WHERE tablename = 'business_rules' 
      AND policyname = 'Users can view own team business rules'
    ) THEN
      CREATE POLICY "Users can view own team business rules" 
      ON business_rules FOR SELECT 
      USING (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pg_policies 
      WHERE tablename = 'business_rules' 
      AND policyname = 'Super admins can manage all business rules'
    ) THEN
      CREATE POLICY "Super admins can manage all business rules" 
      ON business_rules FOR ALL 
      USING (is_super_admin());
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pg_policies 
      WHERE tablename = 'business_rules' 
      AND policyname = 'Users can insert own team business rules'
    ) THEN
      CREATE POLICY "Users can insert own team business rules" 
      ON business_rules FOR INSERT 
      WITH CHECK (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pg_policies 
      WHERE tablename = 'business_rules' 
      AND policyname = 'Users can update own team business rules'
    ) THEN
      CREATE POLICY "Users can update own team business rules" 
      ON business_rules FOR UPDATE 
      USING (team_id = get_user_team_id() AND auth.uid() IS NOT NULL)
      WITH CHECK (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pg_policies 
      WHERE tablename = 'business_rules' 
      AND policyname = 'Users can delete own team business rules'
    ) THEN
      CREATE POLICY "Users can delete own team business rules" 
      ON business_rules FOR DELETE 
      USING (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
    END IF;
  END IF;
END $$;

-- Preferred Assignments policies (verify/create)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'preferred_assignments') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies 
      WHERE tablename = 'preferred_assignments' 
      AND policyname = 'Super admins can view all preferred assignments'
    ) THEN
      CREATE POLICY "Super admins can view all preferred assignments" 
      ON preferred_assignments FOR SELECT 
      USING (is_super_admin());
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pg_policies 
      WHERE tablename = 'preferred_assignments' 
      AND policyname = 'Users can view own team preferred assignments'
    ) THEN
      CREATE POLICY "Users can view own team preferred assignments" 
      ON preferred_assignments FOR SELECT 
      USING (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pg_policies 
      WHERE tablename = 'preferred_assignments' 
      AND policyname = 'Super admins can manage all preferred assignments'
    ) THEN
      CREATE POLICY "Super admins can manage all preferred assignments" 
      ON preferred_assignments FOR ALL 
      USING (is_super_admin());
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pg_policies 
      WHERE tablename = 'preferred_assignments' 
      AND policyname = 'Users can insert own team preferred assignments'
    ) THEN
      CREATE POLICY "Users can insert own team preferred assignments" 
      ON preferred_assignments FOR INSERT 
      WITH CHECK (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pg_policies 
      WHERE tablename = 'preferred_assignments' 
      AND policyname = 'Users can update own team preferred assignments'
    ) THEN
      CREATE POLICY "Users can update own team preferred assignments" 
      ON preferred_assignments FOR UPDATE 
      USING (team_id = get_user_team_id() AND auth.uid() IS NOT NULL)
      WITH CHECK (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pg_policies 
      WHERE tablename = 'preferred_assignments' 
      AND policyname = 'Users can delete own team preferred assignments'
    ) THEN
      CREATE POLICY "Users can delete own team preferred assignments" 
      ON preferred_assignments FOR DELETE 
      USING (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
    END IF;
  END IF;
END $$;

-- ============================================
-- STEP 4: Display Mode - Add public read-only access for /display route
-- ============================================
-- Note: Display mode is currently public. We have two options:
-- Option A: Keep it public (add read-only policy for unauthenticated users)
-- Option B: Make it authenticated (simpler, more secure)
-- 
-- For now, we'll add a public read-only policy for display mode
-- This allows the /display page to work without authentication
-- If you want to require auth for display mode, we can remove this section

-- Public read-only access for display mode (today's schedule only)
-- This allows the /display page to show today's schedule without authentication
DROP POLICY IF EXISTS "Display mode can view today's schedule" ON schedule_assignments;
CREATE POLICY "Display mode can view today's schedule" 
ON schedule_assignments FOR SELECT 
USING (
  schedule_date = CURRENT_DATE
  AND auth.uid() IS NULL  -- Only for unauthenticated users
);

DROP POLICY IF EXISTS "Display mode can view today's employees" ON employees;
CREATE POLICY "Display mode can view today's employees" 
ON employees FOR SELECT 
USING (
  is_active = true
  AND auth.uid() IS NULL  -- Only for unauthenticated users
);

DROP POLICY IF EXISTS "Display mode can view today's shifts" ON shifts;
CREATE POLICY "Display mode can view today's shifts" 
ON shifts FOR SELECT 
USING (
  is_active = true
  AND auth.uid() IS NULL  -- Only for unauthenticated users
);

DROP POLICY IF EXISTS "Display mode can view today's job functions" ON job_functions;
CREATE POLICY "Display mode can view today's job functions" 
ON job_functions FOR SELECT 
USING (auth.uid() IS NULL);  -- Only for unauthenticated users

-- ============================================
-- STEP 5: Fix target_hours table (if exists)
-- ============================================
-- Target hours should be team-aware and require authentication
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'target_hours') THEN
    -- Check if target_hours has team_id column, if not, add it
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'target_hours' 
      AND column_name = 'team_id'
    ) THEN
      ALTER TABLE target_hours ADD COLUMN team_id UUID REFERENCES teams(id) ON DELETE CASCADE;
      CREATE INDEX IF NOT EXISTS idx_target_hours_team ON target_hours(team_id);
      
      -- Backfill team_id from job_functions for existing records
      UPDATE target_hours th
      SET team_id = jf.team_id
      FROM job_functions jf
      WHERE th.job_function_id = jf.id
        AND th.team_id IS NULL;
    END IF;

    -- Create authenticated policies for target_hours
    DROP POLICY IF EXISTS "Super admins can view all target hours" ON target_hours;
    CREATE POLICY "Super admins can view all target hours" 
    ON target_hours FOR SELECT 
    USING (is_super_admin());

    DROP POLICY IF EXISTS "Users can view own team target hours" ON target_hours;
    CREATE POLICY "Users can view own team target hours" 
    ON target_hours FOR SELECT 
    USING (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);

    DROP POLICY IF EXISTS "Super admins can manage all target hours" ON target_hours;
    CREATE POLICY "Super admins can manage all target hours" 
    ON target_hours FOR ALL 
    USING (is_super_admin());

    DROP POLICY IF EXISTS "Users can insert own team target hours" ON target_hours;
    CREATE POLICY "Users can insert own team target hours" 
    ON target_hours FOR INSERT 
    WITH CHECK (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);

    DROP POLICY IF EXISTS "Users can update own team target hours" ON target_hours;
    CREATE POLICY "Users can update own team target hours" 
    ON target_hours FOR UPDATE 
    USING (team_id = get_user_team_id() AND auth.uid() IS NOT NULL)
    WITH CHECK (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);

    DROP POLICY IF EXISTS "Users can delete own team target hours" ON target_hours;
    CREATE POLICY "Users can delete own team target hours" 
    ON target_hours FOR DELETE 
    USING (team_id = get_user_team_id() AND auth.uid() IS NOT NULL);
  END IF;
END $$;

-- ============================================
-- STEP 6: Verification
-- ============================================
-- Run these queries to verify no public policies remain:

-- Check for any remaining public policies (excluding display mode)
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE (qual::text LIKE '%true%' OR with_check::text LIKE '%true%')
  AND policyname NOT LIKE 'Display mode%'
ORDER BY tablename, policyname;

-- This should return no rows (except for display mode policies which are intentionally public for unauthenticated users)

