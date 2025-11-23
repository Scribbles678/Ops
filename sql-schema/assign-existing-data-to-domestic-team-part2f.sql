-- Assign Existing Data to "Domestic" Team - PART 2F
-- Run this SQL in your Supabase SQL Editor AFTER Part 2E completes
-- This part handles: Final team distribution summary (simplified)

-- Step 6: Show team distribution (core tables only)
SELECT 
  t.name as team_name,
  COUNT(DISTINCT e.id) as employees,
  COUNT(DISTINCT jf.id) as job_functions,
  COUNT(DISTINCT s.id) as shifts,
  COUNT(DISTINCT sa.id) as schedule_assignments,
  COUNT(DISTINCT et.id) as employee_training_records
FROM teams t
LEFT JOIN employees e ON e.team_id = t.id
LEFT JOIN job_functions jf ON jf.team_id = t.id
LEFT JOIN shifts s ON s.team_id = t.id
LEFT JOIN schedule_assignments sa ON sa.team_id = t.id
LEFT JOIN employee_training et ON et.team_id = t.id
GROUP BY t.id, t.name
ORDER BY t.name;

