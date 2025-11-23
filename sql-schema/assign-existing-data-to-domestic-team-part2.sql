-- Assign Existing Data to "Domestic" Team - PART 2
-- Run this SQL in your Supabase SQL Editor AFTER Part 1 completes
-- This part handles: schedule_assignments (large table), employee-linked tables, and verification

DO $$
DECLARE
  domestic_team_id UUID;
BEGIN
  -- Get the "Domestic" team ID
  SELECT id INTO domestic_team_id
  FROM teams
  WHERE name = 'Domestic'
  LIMIT 1;
  
  IF domestic_team_id IS NULL THEN
    RAISE EXCEPTION 'Domestic team not found. Please run Part 1 first.';
  END IF;
  
  -- Step 3: Update schedule_assignments (this is the large table that may take time)
  UPDATE schedule_assignments
  SET team_id = domestic_team_id
  WHERE team_id IS NULL;
  
  RAISE NOTICE 'Updated schedule_assignments: % rows', (SELECT COUNT(*) FROM schedule_assignments WHERE team_id = domestic_team_id);
  
  -- Step 4: Update employee-linked tables (these depend on employees having team_id)
  
  -- Employee Training
  -- For employee_training, we need to get team_id from the employee
  UPDATE employee_training et
  SET team_id = e.team_id
  FROM employees e
  WHERE et.employee_id = e.id
    AND et.team_id IS NULL
    AND e.team_id IS NOT NULL;
  
  -- For any remaining NULL team_id in employee_training (if employee has no team), set to Domestic
  UPDATE employee_training
  SET team_id = domestic_team_id
  WHERE team_id IS NULL;
  
  RAISE NOTICE 'Updated employee_training: % rows', (SELECT COUNT(*) FROM employee_training WHERE team_id = domestic_team_id);
  
  -- PTO Days
  -- For pto_days, we need to get team_id from the employee
  UPDATE pto_days pt
  SET team_id = e.team_id
  FROM employees e
  WHERE pt.employee_id = e.id
    AND pt.team_id IS NULL
    AND e.team_id IS NOT NULL;
  
  -- For any remaining NULL team_id in pto_days (if employee has no team), set to Domestic
  UPDATE pto_days
  SET team_id = domestic_team_id
  WHERE team_id IS NULL;
  
  RAISE NOTICE 'Updated pto_days: % rows', (SELECT COUNT(*) FROM pto_days WHERE team_id = domestic_team_id);
  
  -- Shift Swaps
  -- For shift_swaps, we need to get team_id from the employee
  UPDATE shift_swaps ss
  SET team_id = e.team_id
  FROM employees e
  WHERE ss.employee_id = e.id
    AND ss.team_id IS NULL
    AND e.team_id IS NOT NULL;
  
  -- For any remaining NULL team_id in shift_swaps (if employee has no team), set to Domestic
  UPDATE shift_swaps
  SET team_id = domestic_team_id
  WHERE team_id IS NULL;
  
  RAISE NOTICE 'Updated shift_swaps: % rows', (SELECT COUNT(*) FROM shift_swaps WHERE team_id = domestic_team_id);
  
  -- Business Rules (if table exists)
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'business_rules') THEN
    UPDATE business_rules
    SET team_id = domestic_team_id
    WHERE team_id IS NULL;
    
    RAISE NOTICE 'Updated business_rules: % rows', (SELECT COUNT(*) FROM business_rules WHERE team_id = domestic_team_id);
  END IF;
  
  -- Preferred Assignments (if table exists)
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'preferred_assignments') THEN
    -- For preferred_assignments, we need to get team_id from the employee
    UPDATE preferred_assignments pa
    SET team_id = e.team_id
    FROM employees e
    WHERE pa.employee_id = e.id
      AND pa.team_id IS NULL
      AND e.team_id IS NOT NULL;
    
    -- For any remaining NULL team_id in preferred_assignments (if employee has no team), set to Domestic
    UPDATE preferred_assignments
    SET team_id = domestic_team_id
    WHERE team_id IS NULL;
    
    RAISE NOTICE 'Updated preferred_assignments: % rows', (SELECT COUNT(*) FROM preferred_assignments WHERE team_id = domestic_team_id);
  END IF;
  
  RAISE NOTICE '✅ Part 2 Complete: All existing data has been assigned to "Domestic" team (ID: %)', domestic_team_id;
END $$;

-- Step 5: Verify the updates
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
FROM shifts
UNION ALL
SELECT 
  'schedule_assignments',
  COUNT(*),
  COUNT(*) FILTER (WHERE team_id IS NOT NULL),
  COUNT(*) FILTER (WHERE team_id IS NULL)
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

-- Step 6: Show team distribution
SELECT 
  t.name as team_name,
  COUNT(DISTINCT e.id) as employees,
  COUNT(DISTINCT jf.id) as job_functions,
  COUNT(DISTINCT s.id) as shifts,
  COUNT(DISTINCT sa.id) as schedule_assignments,
  COUNT(DISTINCT dt.id) as daily_targets,
  COUNT(DISTINCT et.id) as employee_training_records,
  COUNT(DISTINCT pt.id) as pto_days,
  COUNT(DISTINCT ss.id) as shift_swaps
FROM teams t
LEFT JOIN employees e ON e.team_id = t.id
LEFT JOIN job_functions jf ON jf.team_id = t.id
LEFT JOIN shifts s ON s.team_id = t.id
LEFT JOIN schedule_assignments sa ON sa.team_id = t.id
LEFT JOIN daily_targets dt ON dt.team_id = t.id
LEFT JOIN employee_training et ON et.team_id = t.id
LEFT JOIN pto_days pt ON pt.team_id = t.id
LEFT JOIN shift_swaps ss ON ss.team_id = t.id
GROUP BY t.id, t.name
ORDER BY t.name;

