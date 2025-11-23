-- Issue 4.4: Add Server-Side Input Validation
-- Option 3: CHECK Constraints + Triggers
-- 
-- IMPORTANT: Run check-existing-data-before-validation.sql FIRST to identify any data that needs fixing
-- This script will FAIL if existing data violates the new constraints
--
-- This script adds:
-- 1. CHECK constraints for basic validations (time ranges, durations, positive numbers, etc.)
-- 2. Triggers for complex business rules (training validation, time conflicts, etc.)
-- 3. Length limits on text fields

-- ============================================
-- PART 1: ADD LENGTH LIMITS TO TEXT FIELDS
-- ============================================

-- Employees: Limit name lengths
DO $$ 
BEGIN
  -- Add length limits if columns don't already have them
  -- Note: PostgreSQL doesn't support ALTER COLUMN to change TEXT to VARCHAR with length
  -- So we'll enforce this via CHECK constraints instead
  NULL; -- Placeholder - we'll use CHECK constraints below
END $$;

-- ============================================
-- PART 2: CHECK CONSTRAINTS FOR BASIC VALIDATIONS
-- ============================================

-- ============================================
-- 2.1 schedule_assignments CHECK constraints
-- ============================================

-- Ensure end_time is after start_time
ALTER TABLE schedule_assignments
DROP CONSTRAINT IF EXISTS check_schedule_assignment_time_range;

ALTER TABLE schedule_assignments
ADD CONSTRAINT check_schedule_assignment_time_range
CHECK (end_time > start_time);

-- Ensure duration is at least 30 minutes
ALTER TABLE schedule_assignments
DROP CONSTRAINT IF EXISTS check_schedule_assignment_min_duration;

ALTER TABLE schedule_assignments
ADD CONSTRAINT check_schedule_assignment_min_duration
CHECK (
  EXTRACT(EPOCH FROM (end_time - start_time)) / 60 >= 30
);

-- Ensure assignment_order is positive
ALTER TABLE schedule_assignments
DROP CONSTRAINT IF EXISTS check_schedule_assignment_order_positive;

ALTER TABLE schedule_assignments
ADD CONSTRAINT check_schedule_assignment_order_positive
CHECK (assignment_order > 0);

-- ============================================
-- 2.2 shifts CHECK constraints
-- ============================================

-- Ensure shift end_time is after start_time
ALTER TABLE shifts
DROP CONSTRAINT IF EXISTS check_shift_time_range;

ALTER TABLE shifts
ADD CONSTRAINT check_shift_time_range
CHECK (end_time > start_time);

-- Ensure break times are valid (if provided)
ALTER TABLE shifts
DROP CONSTRAINT IF EXISTS check_shift_break_times;

ALTER TABLE shifts
ADD CONSTRAINT check_shift_break_times
CHECK (
  (break_1_start IS NULL AND break_1_end IS NULL) OR
  (break_1_start IS NOT NULL AND break_1_end IS NOT NULL AND break_1_end > break_1_start)
);

ALTER TABLE shifts
DROP CONSTRAINT IF EXISTS check_shift_break_2_times;

ALTER TABLE shifts
ADD CONSTRAINT check_shift_break_2_times
CHECK (
  (break_2_start IS NULL AND break_2_end IS NULL) OR
  (break_2_start IS NOT NULL AND break_2_end IS NOT NULL AND break_2_end > break_2_start)
);

ALTER TABLE shifts
DROP CONSTRAINT IF EXISTS check_shift_lunch_times;

ALTER TABLE shifts
ADD CONSTRAINT check_shift_lunch_times
CHECK (
  (lunch_start IS NULL AND lunch_end IS NULL) OR
  (lunch_start IS NOT NULL AND lunch_end IS NOT NULL AND lunch_end > lunch_start)
);

-- ============================================
-- 2.3 business_rules CHECK constraints
-- ============================================

-- Ensure time slot end is after start
ALTER TABLE business_rules
DROP CONSTRAINT IF EXISTS check_business_rule_time_slot;

ALTER TABLE business_rules
ADD CONSTRAINT check_business_rule_time_slot
CHECK (time_slot_end > time_slot_start);

-- Ensure staff counts are valid
ALTER TABLE business_rules
DROP CONSTRAINT IF EXISTS check_business_rule_staff_counts;

ALTER TABLE business_rules
ADD CONSTRAINT check_business_rule_staff_counts
CHECK (
  (min_staff IS NULL OR min_staff >= 0) AND
  (max_staff IS NULL OR max_staff >= 0) AND
  (min_staff IS NULL OR max_staff IS NULL OR max_staff >= min_staff)
);

-- Ensure block_size_minutes is non-negative
ALTER TABLE business_rules
DROP CONSTRAINT IF EXISTS check_business_rule_block_size;

ALTER TABLE business_rules
ADD CONSTRAINT check_business_rule_block_size
CHECK (block_size_minutes >= 0);

-- ============================================
-- 2.4 pto_days CHECK constraints
-- ============================================

-- Ensure PTO time range is valid (if both start and end are provided)
ALTER TABLE pto_days
DROP CONSTRAINT IF EXISTS check_pto_time_range;

ALTER TABLE pto_days
ADD CONSTRAINT check_pto_time_range
CHECK (
  start_time IS NULL OR 
  end_time IS NULL OR 
  end_time > start_time
);

-- ============================================
-- 2.5 daily_targets CHECK constraints
-- ============================================

-- Ensure target_units is non-negative
ALTER TABLE daily_targets
DROP CONSTRAINT IF EXISTS check_daily_targets_units;

ALTER TABLE daily_targets
ADD CONSTRAINT check_daily_targets_units
CHECK (target_units >= 0);

-- ============================================
-- 2.6 employees CHECK constraints
-- ============================================

-- Ensure names are not empty
ALTER TABLE employees
DROP CONSTRAINT IF EXISTS check_employee_names_not_empty;

ALTER TABLE employees
ADD CONSTRAINT check_employee_names_not_empty
CHECK (
  TRIM(first_name) != '' AND 
  TRIM(last_name) != ''
);

-- Ensure names are not too long (reasonable limit)
ALTER TABLE employees
DROP CONSTRAINT IF EXISTS check_employee_name_length;

ALTER TABLE employees
ADD CONSTRAINT check_employee_name_length
CHECK (
  LENGTH(first_name) <= 100 AND 
  LENGTH(last_name) <= 100
);

-- ============================================
-- 2.7 job_functions CHECK constraints
-- ============================================

-- Ensure name is not empty
ALTER TABLE job_functions
DROP CONSTRAINT IF EXISTS check_job_function_name_not_empty;

ALTER TABLE job_functions
ADD CONSTRAINT check_job_function_name_not_empty
CHECK (TRIM(name) != '');

-- Ensure name is not too long
ALTER TABLE job_functions
DROP CONSTRAINT IF EXISTS check_job_function_name_length;

ALTER TABLE job_functions
ADD CONSTRAINT check_job_function_name_length
CHECK (LENGTH(name) <= 100);

-- Ensure color_code is valid hex format (basic check)
ALTER TABLE job_functions
DROP CONSTRAINT IF EXISTS check_job_function_color_format;

ALTER TABLE job_functions
ADD CONSTRAINT check_job_function_color_format
CHECK (
  color_code ~ '^#[0-9A-Fa-f]{6}$'
);

-- Ensure productivity_rate is non-negative (if provided)
ALTER TABLE job_functions
DROP CONSTRAINT IF EXISTS check_job_function_productivity_rate;

ALTER TABLE job_functions
ADD CONSTRAINT check_job_function_productivity_rate
CHECK (productivity_rate IS NULL OR productivity_rate >= 0);

-- ============================================
-- 2.8 user_profiles CHECK constraints
-- ============================================

-- Ensure username is not empty
ALTER TABLE user_profiles
DROP CONSTRAINT IF EXISTS check_user_profile_username_not_empty;

ALTER TABLE user_profiles
ADD CONSTRAINT check_user_profile_username_not_empty
CHECK (TRIM(username) != '');

-- Ensure username is not too long
ALTER TABLE user_profiles
DROP CONSTRAINT IF EXISTS check_user_profile_username_length;

ALTER TABLE user_profiles
ADD CONSTRAINT check_user_profile_username_length
CHECK (LENGTH(username) <= 100);

-- Ensure email format is valid (basic check)
ALTER TABLE user_profiles
DROP CONSTRAINT IF EXISTS check_user_profile_email_format;

ALTER TABLE user_profiles
ADD CONSTRAINT check_user_profile_email_format
CHECK (
  email IS NULL OR 
  email = '' OR 
  (email LIKE '%@%' AND email LIKE '%.%' AND LENGTH(email) >= 5)
);

-- ============================================
-- PART 3: TRIGGERS FOR COMPLEX BUSINESS RULES
-- ============================================

-- ============================================
-- 3.1 Function: Check employee training before assignment
-- ============================================

CREATE OR REPLACE FUNCTION validate_assignment_training()
RETURNS TRIGGER AS $$
DECLARE
  job_function_name TEXT;
  employee_team_id UUID;
  is_meter_job BOOLEAN;
  employee_has_meter_training BOOLEAN;
  employee_has_specific_training BOOLEAN;
BEGIN
  -- Get job function name
  SELECT name INTO job_function_name
  FROM job_functions
  WHERE id = NEW.job_function_id;
  
  IF job_function_name IS NULL THEN
    RAISE EXCEPTION 'Job function not found';
  END IF;
  
  -- Get employee's team_id
  SELECT team_id INTO employee_team_id
  FROM employees
  WHERE id = NEW.employee_id;
  
  IF employee_team_id IS NULL THEN
    RAISE EXCEPTION 'Employee not found or not assigned to a team';
  END IF;
  
  -- Check if this is a meter job function
  is_meter_job := job_function_name LIKE 'Meter %';
  
  IF is_meter_job THEN
    -- For meter jobs, check if employee is trained on ANY meter in their team
    SELECT EXISTS (
      SELECT 1
      FROM employee_training et
      JOIN job_functions jf ON et.job_function_id = jf.id
      WHERE et.employee_id = NEW.employee_id
        AND jf.name LIKE 'Meter %'
        AND et.team_id = employee_team_id
        AND jf.team_id = employee_team_id
    ) INTO employee_has_meter_training;
    
    IF NOT employee_has_meter_training THEN
      RAISE EXCEPTION 'Employee is not trained on any meter job function';
    END IF;
  ELSE
    -- For non-meter jobs, check specific training (must be in same team)
    SELECT EXISTS (
      SELECT 1
      FROM employee_training et
      JOIN job_functions jf ON et.job_function_id = jf.id
      WHERE et.employee_id = NEW.employee_id
        AND et.job_function_id = NEW.job_function_id
        AND et.team_id = employee_team_id
        AND jf.team_id = employee_team_id
    ) INTO employee_has_specific_training;
    
    IF NOT employee_has_specific_training THEN
      RAISE EXCEPTION 'Employee is not trained in this job function: %', job_function_name;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 3.2 Function: Check for time conflicts
-- ============================================

CREATE OR REPLACE FUNCTION validate_assignment_time_conflict()
RETURNS TRIGGER AS $$
DECLARE
  conflict_count INTEGER;
BEGIN
  -- Check for overlapping assignments for the same employee on the same date
  SELECT COUNT(*) INTO conflict_count
  FROM schedule_assignments
  WHERE employee_id = NEW.employee_id
    AND schedule_date = NEW.schedule_date
    AND id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::UUID)
    AND (
      -- New assignment starts during existing assignment
      (NEW.start_time >= start_time AND NEW.start_time < end_time) OR
      -- New assignment ends during existing assignment
      (NEW.end_time > start_time AND NEW.end_time <= end_time) OR
      -- New assignment completely contains existing assignment
      (NEW.start_time <= start_time AND NEW.end_time >= end_time)
    );
  
  IF conflict_count > 0 THEN
    RAISE EXCEPTION 'Employee is already assigned to another job during this time period';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 3.3 Create triggers for schedule_assignments
-- ============================================

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS trigger_validate_assignment_training ON schedule_assignments;
DROP TRIGGER IF EXISTS trigger_validate_assignment_time_conflict ON schedule_assignments;

-- Create trigger for training validation
CREATE TRIGGER trigger_validate_assignment_training
  BEFORE INSERT OR UPDATE ON schedule_assignments
  FOR EACH ROW
  EXECUTE FUNCTION validate_assignment_training();

-- Create trigger for time conflict validation
CREATE TRIGGER trigger_validate_assignment_time_conflict
  BEFORE INSERT OR UPDATE ON schedule_assignments
  FOR EACH ROW
  EXECUTE FUNCTION validate_assignment_time_conflict();

-- ============================================
-- 3.4 Function: Validate shift swap dates
-- ============================================

CREATE OR REPLACE FUNCTION validate_shift_swap_date()
RETURNS TRIGGER AS $$
BEGIN
  -- Ensure swap_date is not in the past (allow today and future)
  IF NEW.swap_date < CURRENT_DATE THEN
    RAISE EXCEPTION 'Shift swap date cannot be in the past';
  END IF;
  
  -- Ensure original_shift_id and swapped_shift_id are different
  IF NEW.original_shift_id = NEW.swapped_shift_id THEN
    RAISE EXCEPTION 'Original shift and swapped shift must be different';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for shift_swaps
DROP TRIGGER IF EXISTS trigger_validate_shift_swap_date ON shift_swaps;
CREATE TRIGGER trigger_validate_shift_swap_date
  BEFORE INSERT OR UPDATE ON shift_swaps
  FOR EACH ROW
  EXECUTE FUNCTION validate_shift_swap_date();

-- ============================================
-- PART 4: VERIFICATION QUERIES
-- ============================================

-- Verify all constraints were added
SELECT 
  conname as constraint_name,
  conrelid::regclass as table_name,
  contype as constraint_type
FROM pg_constraint
WHERE conname LIKE 'check_%'
ORDER BY conrelid::regclass::text, conname;

-- Verify all triggers were created
SELECT 
  trigger_name,
  event_object_table as table_name,
  action_timing,
  event_manipulation
FROM information_schema.triggers
WHERE trigger_name LIKE 'trigger_validate_%'
ORDER BY event_object_table, trigger_name;

-- ============================================
-- SUMMARY
-- ============================================

-- Summary message
DO $$
BEGIN
  RAISE NOTICE '✅ Server-side validation (Issue 4.4) has been successfully added!';
  RAISE NOTICE '';
  RAISE NOTICE 'Added:';
  RAISE NOTICE '  - CHECK constraints for basic validations (time ranges, durations, positive numbers, etc.)';
  RAISE NOTICE '  - Triggers for complex business rules (training validation, time conflicts, etc.)';
  RAISE NOTICE '  - Length limits on text fields';
  RAISE NOTICE '';
  RAISE NOTICE 'The database will now reject invalid data even if client-side validation is bypassed.';
END $$;

