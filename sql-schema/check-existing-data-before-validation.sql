-- Check Existing Data for Validation Violations
-- Run this BEFORE adding constraints to identify any data that needs fixing
-- This script will NOT modify data, only report issues

-- ============================================
-- 1. CHECK schedule_assignments for violations
-- ============================================

-- Check for invalid time ranges (end_time <= start_time)
SELECT 
  'schedule_assignments' as table_name,
  'Invalid time range (end_time <= start_time)' as issue,
  COUNT(*) as violation_count
FROM schedule_assignments
WHERE end_time <= start_time;

-- Show examples of invalid time ranges
SELECT 
  id,
  employee_id,
  schedule_date,
  start_time,
  end_time,
  'End time must be after start time' as issue
FROM schedule_assignments
WHERE end_time <= start_time
LIMIT 10;

-- Check for assignments shorter than 30 minutes
SELECT 
  'schedule_assignments' as table_name,
  'Duration less than 30 minutes' as issue,
  COUNT(*) as violation_count
FROM schedule_assignments
WHERE (EXTRACT(EPOCH FROM (end_time - start_time)) / 60) < 30;

-- Show examples of short assignments
SELECT 
  id,
  employee_id,
  schedule_date,
  start_time,
  end_time,
  ROUND(EXTRACT(EPOCH FROM (end_time - start_time)) / 60) as duration_minutes,
  'Assignment must be at least 30 minutes' as issue
FROM schedule_assignments
WHERE (EXTRACT(EPOCH FROM (end_time - start_time)) / 60) < 30
LIMIT 10;

-- ============================================
-- 2. CHECK shifts for violations
-- ============================================

-- Check for invalid shift time ranges
SELECT 
  'shifts' as table_name,
  'Invalid shift time range (end_time <= start_time)' as issue,
  COUNT(*) as violation_count
FROM shifts
WHERE end_time <= start_time;

-- Show examples
SELECT 
  id,
  name,
  start_time,
  end_time,
  'End time must be after start time' as issue
FROM shifts
WHERE end_time <= start_time;

-- Check for invalid break times
SELECT 
  'shifts' as table_name,
  'Invalid break time range' as issue,
  COUNT(*) as violation_count
FROM shifts
WHERE (break_1_start IS NOT NULL AND break_1_end IS NOT NULL AND break_1_end <= break_1_start)
   OR (break_2_start IS NOT NULL AND break_2_end IS NOT NULL AND break_2_end <= break_2_start)
   OR (lunch_start IS NOT NULL AND lunch_end IS NOT NULL AND lunch_end <= lunch_start);

-- ============================================
-- 3. CHECK business_rules for violations
-- ============================================

-- Check for invalid time slot ranges
SELECT 
  'business_rules' as table_name,
  'Invalid time slot range (end <= start)' as issue,
  COUNT(*) as violation_count
FROM business_rules
WHERE time_slot_end <= time_slot_start;

-- Check for invalid staff counts
SELECT 
  'business_rules' as table_name,
  'Invalid staff counts (max < min or negative)' as issue,
  COUNT(*) as violation_count
FROM business_rules
WHERE (min_staff IS NOT NULL AND min_staff < 0)
   OR (max_staff IS NOT NULL AND max_staff < 0)
   OR (min_staff IS NOT NULL AND max_staff IS NOT NULL AND max_staff < min_staff);

-- Check for negative block_size_minutes
SELECT 
  'business_rules' as table_name,
  'Negative block_size_minutes' as issue,
  COUNT(*) as violation_count
FROM business_rules
WHERE block_size_minutes < 0;

-- ============================================
-- 4. CHECK pto_days for violations
-- ============================================

-- Check for invalid PTO time ranges (if both start and end are provided)
SELECT 
  'pto_days' as table_name,
  'Invalid PTO time range (end_time <= start_time)' as issue,
  COUNT(*) as violation_count
FROM pto_days
WHERE start_time IS NOT NULL 
  AND end_time IS NOT NULL 
  AND end_time <= start_time;

-- ============================================
-- 5. CHECK daily_targets for violations
-- ============================================

-- Check for negative target_units
SELECT 
  'daily_targets' as table_name,
  'Negative target_units' as issue,
  COUNT(*) as violation_count
FROM daily_targets
WHERE target_units < 0;

-- ============================================
-- 6. CHECK employees for violations
-- ============================================

-- Check for empty names
SELECT 
  'employees' as table_name,
  'Empty first_name or last_name' as issue,
  COUNT(*) as violation_count
FROM employees
WHERE TRIM(first_name) = '' OR TRIM(last_name) = '';

-- Check for very long names (potential issues)
SELECT 
  'employees' as table_name,
  'Very long names (> 100 chars)' as issue,
  COUNT(*) as violation_count
FROM employees
WHERE LENGTH(first_name) > 100 OR LENGTH(last_name) > 100;

-- ============================================
-- 7. CHECK job_functions for violations
-- ============================================

-- Check for empty names
SELECT 
  'job_functions' as table_name,
  'Empty name' as issue,
  COUNT(*) as violation_count
FROM job_functions
WHERE TRIM(name) = '';

-- Check for very long names
SELECT 
  'job_functions' as table_name,
  'Very long names (> 100 chars)' as issue,
  COUNT(*) as violation_count
FROM job_functions
WHERE LENGTH(name) > 100;

-- ============================================
-- 8. CHECK user_profiles for violations
-- ============================================

-- Check for invalid email formats (basic check)
SELECT 
  'user_profiles' as table_name,
  'Invalid email format (missing @)' as issue,
  COUNT(*) as violation_count
FROM user_profiles
WHERE email IS NOT NULL 
  AND email != ''
  AND email NOT LIKE '%@%';

-- Check for empty usernames
SELECT 
  'user_profiles' as table_name,
  'Empty username' as issue,
  COUNT(*) as violation_count
FROM user_profiles
WHERE TRIM(username) = '';

-- ============================================
-- SUMMARY
-- ============================================

-- Summary of all violations
SELECT 
  'SUMMARY' as report_type,
  'Total violations found across all tables' as message,
  (
    (SELECT COUNT(*) FROM schedule_assignments WHERE end_time <= start_time) +
    (SELECT COUNT(*) FROM schedule_assignments WHERE (EXTRACT(EPOCH FROM (end_time - start_time)) / 60) < 30) +
    (SELECT COUNT(*) FROM shifts WHERE end_time <= start_time) +
    (SELECT COUNT(*) FROM business_rules WHERE time_slot_end <= time_slot_start) +
    (SELECT COUNT(*) FROM business_rules WHERE (min_staff IS NOT NULL AND min_staff < 0) OR (max_staff IS NOT NULL AND max_staff < 0) OR (min_staff IS NOT NULL AND max_staff IS NOT NULL AND max_staff < min_staff)) +
    (SELECT COUNT(*) FROM business_rules WHERE block_size_minutes < 0) +
    (SELECT COUNT(*) FROM pto_days WHERE start_time IS NOT NULL AND end_time IS NOT NULL AND end_time <= start_time) +
    (SELECT COUNT(*) FROM daily_targets WHERE target_units < 0) +
    (SELECT COUNT(*) FROM employees WHERE TRIM(first_name) = '' OR TRIM(last_name) = '') +
    (SELECT COUNT(*) FROM job_functions WHERE TRIM(name) = '') +
    (SELECT COUNT(*) FROM user_profiles WHERE email IS NOT NULL AND email != '' AND email NOT LIKE '%@%') +
    (SELECT COUNT(*) FROM user_profiles WHERE TRIM(username) = '')
  ) as total_violations;

