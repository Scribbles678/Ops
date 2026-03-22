-- Row Level Security (RLS) Policies
-- All current RLS policies for all tables

-- ============================================
-- BUSINESS_RULES
-- ============================================

CREATE POLICY "Super admins can view all business rules" ON business_rules
    FOR SELECT
    USING (is_super_admin());

CREATE POLICY "Users can view own team business rules" ON business_rules
    FOR SELECT
    USING ((team_id = get_user_team_id()));

CREATE POLICY "Users can insert own team business rules" ON business_rules
    FOR INSERT
    WITH CHECK ((team_id = get_user_team_id()));

CREATE POLICY "Users can update own team business rules" ON business_rules
    FOR UPDATE
    USING ((team_id = get_user_team_id()))
    WITH CHECK ((team_id = get_user_team_id()));

CREATE POLICY "Users can delete own team business rules" ON business_rules
    FOR DELETE
    USING ((team_id = get_user_team_id()));

CREATE POLICY "Super admins can manage all business rules" ON business_rules
    FOR ALL
    USING (is_super_admin());

-- ============================================
-- CLEANUP_LOG
-- ============================================

-- Note: cleanup_log and cleanup_status are marked as "Unrestricted" in Supabase
-- They may not have RLS policies or may have permissive policies

-- ============================================
-- CLEANUP_STATUS
-- ============================================

-- Note: cleanup_log and cleanup_status are marked as "Unrestricted" in Supabase
-- They may not have RLS policies or may have permissive policies

-- ============================================
-- DAILY_TARGETS
-- ============================================

CREATE POLICY "Super admins can view all daily targets" ON daily_targets
    FOR SELECT
    USING (is_super_admin());

CREATE POLICY "Users can view own team daily targets" ON daily_targets
    FOR SELECT
    USING ((team_id = get_user_team_id()));

CREATE POLICY "Users can insert own team daily targets" ON daily_targets
    FOR INSERT
    WITH CHECK ((team_id = get_user_team_id()));

CREATE POLICY "Users can update own team daily targets" ON daily_targets
    FOR UPDATE
    USING ((team_id = get_user_team_id()))
    WITH CHECK ((team_id = get_user_team_id()));

CREATE POLICY "Users can delete own team daily targets" ON daily_targets
    FOR DELETE
    USING ((team_id = get_user_team_id()));

CREATE POLICY "Super admins can manage all daily targets" ON daily_targets
    FOR ALL
    USING (is_super_admin());

-- ============================================
-- DAILY_TARGETS_ARCHIVE
-- ============================================

CREATE POLICY "Super admins can view all archived targets" ON daily_targets_archive
    FOR SELECT
    USING (is_super_admin());

CREATE POLICY "Users can view own team archived targets" ON daily_targets_archive
    FOR SELECT
    USING ((team_id = get_user_team_id()));

-- ============================================
-- EMPLOYEE_TRAINING
-- ============================================

CREATE POLICY "Super admins can view all employee training" ON employee_training
    FOR SELECT
    USING (is_super_admin());

CREATE POLICY "Users can view own team employee training" ON employee_training
    FOR SELECT
    USING ((team_id = get_user_team_id()));

CREATE POLICY "Users can insert own team employee training" ON employee_training
    FOR INSERT
    WITH CHECK ((team_id = get_user_team_id()));

CREATE POLICY "Users can update own team employee training" ON employee_training
    FOR UPDATE
    USING ((team_id = get_user_team_id()))
    WITH CHECK ((team_id = get_user_team_id()));

CREATE POLICY "Users can delete own team employee training" ON employee_training
    FOR DELETE
    USING ((team_id = get_user_team_id()));

CREATE POLICY "Super admins can manage all employee training" ON employee_training
    FOR ALL
    USING (is_super_admin());

-- ============================================
-- EMPLOYEES
-- ============================================

CREATE POLICY "Display users can view active employees" ON employees
    FOR SELECT
    USING ((is_display_user() AND (is_active = true)));

CREATE POLICY "Super admins can view all employees" ON employees
    FOR SELECT
    USING (is_super_admin());

CREATE POLICY "Users can view own team employees" ON employees
    FOR SELECT
    USING ((team_id = get_user_team_id()));

CREATE POLICY "Users can insert own team employees" ON employees
    FOR INSERT
    WITH CHECK ((team_id = get_user_team_id()));

CREATE POLICY "Users can update own team employees" ON employees
    FOR UPDATE
    USING ((team_id = get_user_team_id()))
    WITH CHECK ((team_id = get_user_team_id()));

CREATE POLICY "Users can delete own team employees" ON employees
    FOR DELETE
    USING ((team_id = get_user_team_id()));

CREATE POLICY "Super admins can manage all employees" ON employees
    FOR ALL
    USING (is_super_admin());

-- ============================================
-- JOB_FUNCTIONS
-- ============================================

CREATE POLICY "Display users can view job functions" ON job_functions
    FOR SELECT
    USING (is_display_user());

CREATE POLICY "Super admins can view all job functions" ON job_functions
    FOR SELECT
    USING (is_super_admin());

CREATE POLICY "Users can view own team job functions" ON job_functions
    FOR SELECT
    USING ((team_id = get_user_team_id()));

CREATE POLICY "Users can insert own team job functions" ON job_functions
    FOR INSERT
    WITH CHECK ((team_id = get_user_team_id()));

CREATE POLICY "Users can update own team job functions" ON job_functions
    FOR UPDATE
    USING ((team_id = get_user_team_id()))
    WITH CHECK ((team_id = get_user_team_id()));

CREATE POLICY "Users can delete own team job functions" ON job_functions
    FOR DELETE
    USING ((team_id = get_user_team_id()));

CREATE POLICY "Super admins can manage all job functions" ON job_functions
    FOR ALL
    USING (is_super_admin());

-- ============================================
-- PREFERRED_ASSIGNMENTS
-- ============================================

CREATE POLICY "Super admins can view all preferred assignments" ON preferred_assignments
    FOR SELECT
    USING (is_super_admin());

CREATE POLICY "Users can view own team preferred assignments" ON preferred_assignments
    FOR SELECT
    USING (((team_id = get_user_team_id()) AND (auth.uid() IS NOT NULL)));

CREATE POLICY "Users can insert own team preferred assignments" ON preferred_assignments
    FOR INSERT
    WITH CHECK (((team_id = get_user_team_id()) AND (auth.uid() IS NOT NULL)));

CREATE POLICY "Users can update own team preferred assignments" ON preferred_assignments
    FOR UPDATE
    USING (((team_id = get_user_team_id()) AND (auth.uid() IS NOT NULL)))
    WITH CHECK (((team_id = get_user_team_id()) AND (auth.uid() IS NOT NULL)));

CREATE POLICY "Users can delete own team preferred assignments" ON preferred_assignments
    FOR DELETE
    USING (((team_id = get_user_team_id()) AND (auth.uid() IS NOT NULL)));

CREATE POLICY "Super admins can manage all preferred assignments" ON preferred_assignments
    FOR ALL
    USING (is_super_admin());

-- ============================================
-- PTO_DAYS
-- ============================================

CREATE POLICY "Display users can view today's PTO" ON pto_days
    FOR SELECT
    USING ((is_display_user() AND (pto_date = CURRENT_DATE)));

CREATE POLICY "Super admins can view all pto days" ON pto_days
    FOR SELECT
    USING (is_super_admin());

CREATE POLICY "Users can view own team pto days" ON pto_days
    FOR SELECT
    USING ((team_id = get_user_team_id()));

CREATE POLICY "Users can insert own team pto days" ON pto_days
    FOR INSERT
    WITH CHECK ((team_id = get_user_team_id()));

CREATE POLICY "Users can update own team pto days" ON pto_days
    FOR UPDATE
    USING ((team_id = get_user_team_id()))
    WITH CHECK ((team_id = get_user_team_id()));

CREATE POLICY "Users can delete own team pto days" ON pto_days
    FOR DELETE
    USING ((team_id = get_user_team_id()));

CREATE POLICY "Super admins can manage all pto days" ON pto_days
    FOR ALL
    USING (is_super_admin());

-- ============================================
-- SCHEDULE_ASSIGNMENTS
-- ============================================

CREATE POLICY "Display users can view today's schedule assignments" ON schedule_assignments
    FOR SELECT
    USING ((is_display_user() AND (schedule_date = CURRENT_DATE)));

CREATE POLICY "Super admins can view all schedule assignments" ON schedule_assignments
    FOR SELECT
    USING (is_super_admin());

CREATE POLICY "Users can view own team schedule assignments" ON schedule_assignments
    FOR SELECT
    USING ((team_id = get_user_team_id()));

CREATE POLICY "Users can insert own team schedule assignments" ON schedule_assignments
    FOR INSERT
    WITH CHECK ((team_id = get_user_team_id()));

CREATE POLICY "Users can update own team schedule assignments" ON schedule_assignments
    FOR UPDATE
    USING ((team_id = get_user_team_id()))
    WITH CHECK ((team_id = get_user_team_id()));

CREATE POLICY "Users can delete own team schedule assignments" ON schedule_assignments
    FOR DELETE
    USING ((team_id = get_user_team_id()));

CREATE POLICY "Super admins can manage all schedule assignments" ON schedule_assignments
    FOR ALL
    USING (is_super_admin());

-- ============================================
-- SCHEDULE_ASSIGNMENTS_ARCHIVE
-- ============================================

CREATE POLICY "Super admins can view all archived schedules" ON schedule_assignments_archive
    FOR SELECT
    USING (is_super_admin());

CREATE POLICY "Users can view own team archived schedules" ON schedule_assignments_archive
    FOR SELECT
    USING ((team_id = get_user_team_id()));

-- ============================================
-- SHIFT_SWAPS
-- ============================================

CREATE POLICY "Display users can view today's shift swaps" ON shift_swaps
    FOR SELECT
    USING ((is_display_user() AND (swap_date = CURRENT_DATE)));

CREATE POLICY "Super admins can view all shift swaps" ON shift_swaps
    FOR SELECT
    USING (is_super_admin());

CREATE POLICY "Users can view own team shift swaps" ON shift_swaps
    FOR SELECT
    USING ((team_id = get_user_team_id()));

CREATE POLICY "Users can insert own team shift swaps" ON shift_swaps
    FOR INSERT
    WITH CHECK ((team_id = get_user_team_id()));

CREATE POLICY "Users can update own team shift swaps" ON shift_swaps
    FOR UPDATE
    USING ((team_id = get_user_team_id()))
    WITH CHECK ((team_id = get_user_team_id()));

CREATE POLICY "Users can delete own team shift swaps" ON shift_swaps
    FOR DELETE
    USING ((team_id = get_user_team_id()));

CREATE POLICY "Super admins can manage all shift swaps" ON shift_swaps
    FOR ALL
    USING (is_super_admin());

-- ============================================
-- SHIFTS
-- ============================================

CREATE POLICY "Display users can view active shifts" ON shifts
    FOR SELECT
    USING ((is_display_user() AND (is_active = true)));

CREATE POLICY "Super admins can view all shifts" ON shifts
    FOR SELECT
    USING (is_super_admin());

CREATE POLICY "Users can view own team shifts" ON shifts
    FOR SELECT
    USING ((team_id = get_user_team_id()));

CREATE POLICY "Users can insert own team shifts" ON shifts
    FOR INSERT
    WITH CHECK ((team_id = get_user_team_id()));

CREATE POLICY "Users can update own team shifts" ON shifts
    FOR UPDATE
    USING ((team_id = get_user_team_id()))
    WITH CHECK ((team_id = get_user_team_id()));

CREATE POLICY "Users can delete own team shifts" ON shifts
    FOR DELETE
    USING ((team_id = get_user_team_id()));

CREATE POLICY "Super admins can manage all shifts" ON shifts
    FOR ALL
    USING (is_super_admin());

-- ============================================
-- TARGET_HOURS
-- ============================================

CREATE POLICY "Super admins can view all target hours" ON target_hours
    FOR SELECT
    USING (is_super_admin());

CREATE POLICY "Users can view own team target hours" ON target_hours
    FOR SELECT
    USING (((team_id = get_user_team_id()) AND (auth.uid() IS NOT NULL)));

CREATE POLICY "Users can insert own team target hours" ON target_hours
    FOR INSERT
    WITH CHECK (((team_id = get_user_team_id()) AND (auth.uid() IS NOT NULL)));

CREATE POLICY "Users can update own team target hours" ON target_hours
    FOR UPDATE
    USING (((team_id = get_user_team_id()) AND (auth.uid() IS NOT NULL)))
    WITH CHECK (((team_id = get_user_team_id()) AND (auth.uid() IS NOT NULL)));

CREATE POLICY "Users can delete own team target hours" ON target_hours
    FOR DELETE
    USING (((team_id = get_user_team_id()) AND (auth.uid() IS NOT NULL)));

CREATE POLICY "Super admins can manage all target hours" ON target_hours
    FOR ALL
    USING (is_super_admin());

-- ============================================
-- TEAMS
-- ============================================

CREATE POLICY "Super admins can view all teams" ON teams
    FOR SELECT
    USING (is_super_admin());

CREATE POLICY "Users can view own team" ON teams
    FOR SELECT
    USING (((id = get_user_team_id()) AND (get_user_team_id() IS NOT NULL)));

CREATE POLICY "Super admins can insert teams" ON teams
    FOR INSERT
    WITH CHECK (is_super_admin());

CREATE POLICY "Super admins can update teams" ON teams
    FOR UPDATE
    USING (is_super_admin());

CREATE POLICY "Super admins can delete teams" ON teams
    FOR DELETE
    USING (is_super_admin());

-- ============================================
-- USER_PROFILES
-- ============================================

CREATE POLICY "Users can view own profile or team" ON user_profiles
    FOR SELECT
    USING (((auth.uid() = id) OR is_super_admin() OR (is_admin() AND (team_id = get_user_team_id()) AND (team_id IS NOT NULL))));

CREATE POLICY "Super admins can insert profiles" ON user_profiles
    FOR INSERT
    WITH CHECK (is_super_admin());

CREATE POLICY "Users can update own profile or team" ON user_profiles
    FOR UPDATE
    USING (((auth.uid() = id) OR is_super_admin() OR (is_admin() AND (team_id = get_user_team_id()) AND (team_id IS NOT NULL) AND (id <> auth.uid()))))
    WITH CHECK (((auth.uid() = id) OR is_super_admin() OR (is_admin() AND (team_id = get_user_team_id()) AND (team_id IS NOT NULL))));

CREATE POLICY "Super admins can delete profiles" ON user_profiles
    FOR DELETE
    USING (is_super_admin());
