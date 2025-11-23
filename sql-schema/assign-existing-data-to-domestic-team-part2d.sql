-- Assign Existing Data to "Domestic" Team - PART 2D
-- Run this SQL in your Supabase SQL Editor AFTER Part 2C completes
-- This part handles: Verification queries (broken into smaller chunks)

-- Verification Query 1: Core tables
SELECT 
  'employees' as table_name,
  COUNT(*) as total_rows,
  COUNT(*) FILTER (WHERE team_id IS NOT NULL) as rows_with_team,
  COUNT(*) FILTER (WHERE team_id IS NULL) as rows_without_team
FROM employees
UNION ALL
SELECT 
  'job_functions',
  COUNT(*),
  COUNT(*) FILTER (WHERE team_id IS NOT NULL),
  COUNT(*) FILTER (WHERE team_id IS NULL)
FROM job_functions
UNION ALL
SELECT 
  'shifts',
  COUNT(*),
  COUNT(*) FILTER (WHERE team_id IS NOT NULL),
  COUNT(*) FILTER (WHERE team_id IS NULL)
FROM shifts;

