-- Assign Existing Data to "Domestic" Team - PART 2B
-- Run this SQL in your Supabase SQL Editor AFTER Part 2A completes
-- This part handles: employee_training, pto_days, and shift_swaps

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
  
  RAISE NOTICE '✅ Part 2B Complete: Employee-linked tables updated. Team ID: %', domestic_team_id;
END $$;
