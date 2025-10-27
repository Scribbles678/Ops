-- Database Cleanup and Archiving System
-- Run this SQL in your Supabase SQL Editor

-- 1. Create archive table for old schedule assignments
CREATE TABLE IF NOT EXISTS schedule_assignments_archive (
    id UUID PRIMARY KEY,
    employee_id UUID NOT NULL,
    job_function_id UUID NOT NULL,
    shift_id UUID NOT NULL,
    schedule_date DATE NOT NULL,
    assignment_order INTEGER DEFAULT 1,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    archived_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Create archive table for old daily targets
CREATE TABLE IF NOT EXISTS daily_targets_archive (
    id UUID PRIMARY KEY,
    schedule_date DATE NOT NULL,
    job_function_id UUID NOT NULL,
    target_units INTEGER NOT NULL,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    archived_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Create indexes for archive tables
CREATE INDEX IF NOT EXISTS idx_schedule_archive_date ON schedule_assignments_archive(schedule_date);
CREATE INDEX IF NOT EXISTS idx_schedule_archive_employee ON schedule_assignments_archive(employee_id);
CREATE INDEX IF NOT EXISTS idx_daily_targets_archive_date ON daily_targets_archive(schedule_date);

-- 4. Enable RLS on archive tables
ALTER TABLE schedule_assignments_archive ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_targets_archive ENABLE ROW LEVEL SECURITY;

-- 5. Create policies for archive tables (read-only for most users)
CREATE POLICY "Enable read access for all users" ON schedule_assignments_archive FOR SELECT USING (true);
CREATE POLICY "Enable read access for all users" ON daily_targets_archive FOR SELECT USING (true);

-- 6. Create cleanup function for schedule assignments
CREATE OR REPLACE FUNCTION cleanup_old_schedules()
RETURNS TABLE(
    archived_assignments INTEGER,
    archived_targets INTEGER,
    cleanup_date TIMESTAMP
) AS $$
DECLARE
    cutoff_date DATE;
    assignments_count INTEGER := 0;
    targets_count INTEGER := 0;
BEGIN
    -- Set cutoff date to 1 month ago
    cutoff_date := CURRENT_DATE - INTERVAL '1 month';
    
    -- Archive old schedule assignments
    WITH archived AS (
        INSERT INTO schedule_assignments_archive (
            id, employee_id, job_function_id, shift_id, schedule_date,
            assignment_order, start_time, end_time, created_at, updated_at, archived_at
        )
        SELECT 
            id, employee_id, job_function_id, shift_id, schedule_date,
            assignment_order, start_time, end_time, created_at, updated_at, NOW()
        FROM schedule_assignments 
        WHERE schedule_date < cutoff_date
        RETURNING id
    )
    SELECT COUNT(*) INTO assignments_count FROM archived;
    
    -- Delete archived schedule assignments from main table
    DELETE FROM schedule_assignments 
    WHERE schedule_date < cutoff_date;
    
    -- Archive old daily targets
    WITH archived AS (
        INSERT INTO daily_targets_archive (
            id, schedule_date, job_function_id, target_units, notes,
            created_at, updated_at, archived_at
        )
        SELECT 
            id, schedule_date, job_function_id, target_units, notes,
            created_at, updated_at, NOW()
        FROM daily_targets 
        WHERE schedule_date < cutoff_date
        RETURNING id
    )
    SELECT COUNT(*) INTO targets_count FROM archived;
    
    -- Delete archived daily targets from main table
    DELETE FROM daily_targets 
    WHERE schedule_date < cutoff_date;
    
    -- Return cleanup statistics
    RETURN QUERY SELECT 
        assignments_count,
        targets_count,
        NOW();
END;
$$ LANGUAGE plpgsql;

-- 7. Create function to get cleanup statistics
CREATE OR REPLACE FUNCTION get_cleanup_stats()
RETURNS TABLE(
    total_assignments INTEGER,
    total_archived_assignments INTEGER,
    assignments_to_cleanup INTEGER,
    total_targets INTEGER,
    total_archived_targets INTEGER,
    targets_to_cleanup INTEGER,
    oldest_schedule_date DATE,
    newest_schedule_date DATE
) AS $$
DECLARE
    cutoff_date DATE;
BEGIN
    cutoff_date := CURRENT_DATE - INTERVAL '1 month';
    
    RETURN QUERY
    SELECT 
        (SELECT COUNT(*)::INTEGER FROM schedule_assignments),
        (SELECT COUNT(*)::INTEGER FROM schedule_assignments_archive),
        (SELECT COUNT(*)::INTEGER FROM schedule_assignments WHERE schedule_date < cutoff_date),
        (SELECT COUNT(*)::INTEGER FROM daily_targets),
        (SELECT COUNT(*)::INTEGER FROM daily_targets_archive),
        (SELECT COUNT(*)::INTEGER FROM daily_targets WHERE schedule_date < cutoff_date),
        (SELECT MIN(schedule_date) FROM schedule_assignments),
        (SELECT MAX(schedule_date) FROM schedule_assignments);
END;
$$ LANGUAGE plpgsql;

-- 8. Create function to manually run cleanup (for testing)
CREATE OR REPLACE FUNCTION run_cleanup_now()
RETURNS TABLE(
    archived_assignments INTEGER,
    archived_targets INTEGER,
    cleanup_date TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY SELECT * FROM cleanup_old_schedules();
END;
$$ LANGUAGE plpgsql;

-- 9. Create a view for monitoring cleanup status
CREATE OR REPLACE VIEW cleanup_status AS
SELECT 
    'Current Schedules' as table_name,
    COUNT(*) as record_count,
    MIN(schedule_date) as oldest_date,
    MAX(schedule_date) as newest_date
FROM schedule_assignments
UNION ALL
SELECT 
    'Archived Schedules' as table_name,
    COUNT(*) as record_count,
    MIN(schedule_date) as oldest_date,
    MAX(schedule_date) as newest_date
FROM schedule_assignments_archive
UNION ALL
SELECT 
    'Current Targets' as table_name,
    COUNT(*) as record_count,
    MIN(schedule_date) as oldest_date,
    MAX(schedule_date) as newest_date
FROM daily_targets
UNION ALL
SELECT 
    'Archived Targets' as table_name,
    COUNT(*) as record_count,
    MIN(schedule_date) as oldest_date,
    MAX(schedule_date) as newest_date
FROM daily_targets_archive;

-- 10. Grant necessary permissions
GRANT EXECUTE ON FUNCTION cleanup_old_schedules() TO authenticated;
GRANT EXECUTE ON FUNCTION get_cleanup_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION run_cleanup_now() TO authenticated;
GRANT SELECT ON cleanup_status TO authenticated;

-- 11. Create a log table for cleanup operations
CREATE TABLE IF NOT EXISTS cleanup_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cleanup_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    archived_assignments INTEGER DEFAULT 0,
    archived_targets INTEGER DEFAULT 0,
    cutoff_date DATE,
    success BOOLEAN DEFAULT true,
    error_message TEXT
);

-- 12. Create function to log cleanup operations
CREATE OR REPLACE FUNCTION log_cleanup(
    p_archived_assignments INTEGER,
    p_archived_targets INTEGER,
    p_cutoff_date DATE,
    p_success BOOLEAN DEFAULT true,
    p_error_message TEXT DEFAULT NULL
)
RETURNS void AS $$
BEGIN
    INSERT INTO cleanup_log (
        archived_assignments, archived_targets, cutoff_date, success, error_message
    ) VALUES (
        p_archived_assignments, p_archived_targets, p_cutoff_date, p_success, p_error_message
    );
END;
$$ LANGUAGE plpgsql;

-- 13. Update cleanup function to include logging
CREATE OR REPLACE FUNCTION cleanup_old_schedules_with_logging()
RETURNS TABLE(
    archived_assignments INTEGER,
    archived_targets INTEGER,
    cleanup_date TIMESTAMP
) AS $$
DECLARE
    cutoff_date DATE;
    assignments_count INTEGER := 0;
    targets_count INTEGER := 0;
    result RECORD;
BEGIN
    -- Set cutoff date to 1 month ago
    cutoff_date := CURRENT_DATE - INTERVAL '1 month';
    
    BEGIN
        -- Archive old schedule assignments
        WITH archived AS (
            INSERT INTO schedule_assignments_archive (
                id, employee_id, job_function_id, shift_id, schedule_date,
                assignment_order, start_time, end_time, created_at, updated_at, archived_at
            )
            SELECT 
                id, employee_id, job_function_id, shift_id, schedule_date,
                assignment_order, start_time, end_time, created_at, updated_at, NOW()
            FROM schedule_assignments 
            WHERE schedule_date < cutoff_date
            RETURNING id
        )
        SELECT COUNT(*) INTO assignments_count FROM archived;
        
        -- Delete archived schedule assignments from main table
        DELETE FROM schedule_assignments 
        WHERE schedule_date < cutoff_date;
        
        -- Archive old daily targets
        WITH archived AS (
            INSERT INTO daily_targets_archive (
                id, schedule_date, job_function_id, target_units, notes,
                created_at, updated_at, archived_at
            )
            SELECT 
                id, schedule_date, job_function_id, target_units, notes,
                created_at, updated_at, NOW()
            FROM daily_targets 
            WHERE schedule_date < cutoff_date
            RETURNING id
        )
        SELECT COUNT(*) INTO targets_count FROM archived;
        
        -- Delete archived daily targets from main table
        DELETE FROM daily_targets 
        WHERE schedule_date < cutoff_date;
        
        -- Log successful cleanup
        PERFORM log_cleanup(assignments_count, targets_count, cutoff_date, true);
        
        -- Return cleanup statistics
        RETURN QUERY SELECT 
            assignments_count,
            targets_count,
            NOW();
            
    EXCEPTION WHEN OTHERS THEN
        -- Log failed cleanup
        PERFORM log_cleanup(0, 0, cutoff_date, false, SQLERRM);
        
        -- Re-raise the exception
        RAISE;
    END;
END;
$$ LANGUAGE plpgsql;

-- 14. Grant permissions for logging
GRANT EXECUTE ON FUNCTION log_cleanup(INTEGER, INTEGER, DATE, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION cleanup_old_schedules_with_logging() TO authenticated;
GRANT SELECT ON cleanup_log TO authenticated;
