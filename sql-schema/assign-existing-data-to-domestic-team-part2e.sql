-- Assign Existing Data to "Domestic" Team - PART 2E
-- Run this SQL in your Supabase SQL Editor AFTER Part 2D completes
-- This part handles: Verification queries for schedule and employee-linked tables

-- Verification Query 2: Schedule and employee-linked tables
SELECT 
  'schedule_assignments' as table_name,
  COUNT(*) as total_rows,
  COUNT(*) FILTER (WHERE team_id IS NOT NULL) as rows_with_team,
  COUNT(*) FILTER (WHERE team_id IS NULL) as rows_without_team
FROM schedule_assignments
UNION ALL
SELECT 
  'daily_targets',
  COUNT(*),
  COUNT(*) FILTER (WHERE team_id IS NOT NULL),
  COUNT(*) FILTER (WHERE team_id IS NULL)
FROM daily_targets
UNION ALL
SELECT 
  'employee_training',
  COUNT(*),
  COUNT(*) FILTER (WHERE team_id IS NOT NULL),
  COUNT(*) FILTER (WHERE team_id IS NULL)
FROM employee_training
UNION ALL
SELECT 
  'pto_days',
  COUNT(*),
  COUNT(*) FILTER (WHERE team_id IS NOT NULL),
  COUNT(*) FILTER (WHERE team_id IS NULL)
FROM pto_days
UNION ALL
SELECT 
  'shift_swaps',
  COUNT(*),
  COUNT(*) FILTER (WHERE team_id IS NOT NULL),
  COUNT(*) FILTER (WHERE team_id IS NULL)
FROM shift_swaps
ORDER BY table_name;

