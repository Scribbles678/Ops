-- Fix RLS Policies for Cleanup Functions
-- The cleanup function needs to be able to INSERT into archive tables
-- Run this SQL in your Supabase SQL Editor

-- Step 1: Add team_id columns to archive tables (for consistency with multi-tenant setup)
ALTER TABLE schedule_assignments_archive ADD COLUMN IF NOT EXISTS team_id UUID REFERENCES teams(id) ON DELETE SET NULL;
ALTER TABLE daily_targets_archive ADD COLUMN IF NOT EXISTS team_id UUID REFERENCES teams(id) ON DELETE SET NULL;

-- Create indexes for team_id in archive tables
CREATE INDEX IF NOT EXISTS idx_schedule_archive_team ON schedule_assignments_archive(team_id);
CREATE INDEX IF NOT EXISTS idx_daily_targets_archive_team ON daily_targets_archive(team_id);

-- Step 2: Update RLS policies for archive tables
-- Drop existing policies
DROP POLICY IF EXISTS "Enable read access for all users" ON schedule_assignments_archive;
DROP POLICY IF EXISTS "Super admins can view all archived schedules" ON schedule_assignments_archive;
DROP POLICY IF EXISTS "Users can view own team archived schedules" ON schedule_assignments_archive;
DROP POLICY IF EXISTS "Enable read access for all users" ON daily_targets_archive;
DROP POLICY IF EXISTS "Super admins can view all archived targets" ON daily_targets_archive;
DROP POLICY IF EXISTS "Users can view own team archived targets" ON daily_targets_archive;

-- Create new policies that respect team isolation
-- Super admins can see all archived data
CREATE POLICY "Super admins can view all archived schedules" 
ON schedule_assignments_archive FOR SELECT 
USING (is_super_admin());

-- Users can see their team's archived data
CREATE POLICY "Users can view own team archived schedules" 
ON schedule_assignments_archive FOR SELECT 
USING (team_id = get_user_team_id());

-- Super admins can see all archived targets
CREATE POLICY "Super admins can view all archived targets" 
ON daily_targets_archive FOR SELECT 
USING (is_super_admin());

-- Users can see their team's archived targets
CREATE POLICY "Users can view own team archived targets" 
ON daily_targets_archive FOR SELECT 
USING (team_id = get_user_team_id());

-- Step 3: Drop existing cleanup functions to allow return type changes
DROP FUNCTION IF EXISTS cleanup_old_schedules_with_logging() CASCADE;
DROP FUNCTION IF EXISTS cleanup_old_schedules() CASCADE;

-- Step 4: Allow cleanup function to INSERT into archive tables
-- The function needs SECURITY DEFINER to bypass RLS when inserting
-- This is safe because the function only archives old data, not user-created data

-- Step 5: Create cleanup function to be SECURITY DEFINER and include team_id
-- Note: Only archives schedule assignments, not daily targets
CREATE OR REPLACE FUNCTION cleanup_old_schedules_with_logging()
RETURNS TABLE(
    archived_assignments INTEGER,
    cleanup_date TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
    cutoff_date DATE;
    assignments_count INTEGER := 0;
    result RECORD;
BEGIN
    -- Set cutoff date to 7 days ago
    cutoff_date := CURRENT_DATE - INTERVAL '7 days';
    
    BEGIN
        -- Archive old schedule assignments (including team_id)
        WITH archived AS (
            INSERT INTO schedule_assignments_archive (
                id, employee_id, job_function_id, shift_id, schedule_date,
                assignment_order, start_time, end_time, created_at, updated_at, archived_at, team_id
            )
            SELECT 
                id, employee_id, job_function_id, shift_id, schedule_date,
                assignment_order, start_time, end_time, created_at, updated_at, NOW(), team_id
            FROM schedule_assignments 
            WHERE schedule_date < cutoff_date
            RETURNING id
        )
        SELECT COUNT(*) INTO assignments_count FROM archived;
        
        -- Delete archived schedule assignments from main table
        DELETE FROM schedule_assignments 
        WHERE schedule_date < cutoff_date;
        
        -- Log successful cleanup (targets_count is 0 since we don't archive daily targets)
        PERFORM log_cleanup(assignments_count, 0, cutoff_date, true);
        
        -- Return cleanup statistics
        RETURN QUERY SELECT 
            assignments_count,
            NOW();
    EXCEPTION
        WHEN OTHERS THEN
            -- Log error
            PERFORM log_cleanup(0, 0, cutoff_date, false, SQLERRM);
            -- Re-raise the exception
            RAISE;
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 6: Also create the non-logging version for consistency
-- Note: Only archives schedule assignments, not daily targets
CREATE OR REPLACE FUNCTION cleanup_old_schedules()
RETURNS TABLE(
    archived_assignments INTEGER,
    cleanup_date TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
    cutoff_date DATE;
    assignments_count INTEGER := 0;
BEGIN
    -- Set cutoff date to 7 days ago
    cutoff_date := CURRENT_DATE - INTERVAL '7 days';
    
    -- Archive old schedule assignments (including team_id)
    WITH archived AS (
        INSERT INTO schedule_assignments_archive (
            id, employee_id, job_function_id, shift_id, schedule_date,
            assignment_order, start_time, end_time, created_at, updated_at, archived_at, team_id
        )
        SELECT 
            id, employee_id, job_function_id, shift_id, schedule_date,
            assignment_order, start_time, end_time, created_at, updated_at, NOW(), team_id
        FROM schedule_assignments 
        WHERE schedule_date < cutoff_date
        RETURNING id
    )
    SELECT COUNT(*) INTO assignments_count FROM archived;
    
    -- Delete archived schedule assignments from main table
    DELETE FROM schedule_assignments 
    WHERE schedule_date < cutoff_date;
    
    -- Return cleanup statistics
    RETURN QUERY SELECT 
        assignments_count,
        NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 7: Grant execute permissions
GRANT EXECUTE ON FUNCTION cleanup_old_schedules() TO authenticated;
GRANT EXECUTE ON FUNCTION cleanup_old_schedules_with_logging() TO authenticated;

-- Step 8: Verify the changes
SELECT 
    'Functions updated successfully!' as status,
    proname as function_name,
    prosecdef as is_security_definer
FROM pg_proc
WHERE proname IN ('cleanup_old_schedules', 'cleanup_old_schedules_with_logging')
AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

