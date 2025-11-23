-- Assign Existing Data to "Domestic" Team - PART 1
-- Run this SQL in your Supabase SQL Editor FIRST
-- This part handles: team creation, employees, job_functions, shifts, and daily_targets

-- Step 1: Get or create the "Domestic" team
DO $$
DECLARE
  domestic_team_id UUID;
BEGIN
  -- Try to get existing "Domestic" team
  SELECT id INTO domestic_team_id
  FROM teams
  WHERE name = 'Domestic'
  LIMIT 1;
  
  -- If team doesn't exist, create it
  IF domestic_team_id IS NULL THEN
    INSERT INTO teams (name)
    VALUES ('Domestic')
    RETURNING id INTO domestic_team_id;
    
    RAISE NOTICE 'Created "Domestic" team with ID: %', domestic_team_id;
  ELSE
    RAISE NOTICE 'Found existing "Domestic" team with ID: %', domestic_team_id;
  END IF;
  
  -- Step 2: Update smaller tables with NULL team_id to Domestic team_id
  
  -- Employees (must be first, as other tables depend on it)
  UPDATE employees
  SET team_id = domestic_team_id
  WHERE team_id IS NULL;
  
  RAISE NOTICE 'Updated employees: % rows', (SELECT COUNT(*) FROM employees WHERE team_id = domestic_team_id);
  
  -- Job Functions
  UPDATE job_functions
  SET team_id = domestic_team_id
  WHERE team_id IS NULL;
  
  RAISE NOTICE 'Updated job_functions: % rows', (SELECT COUNT(*) FROM job_functions WHERE team_id = domestic_team_id);
  
  -- Shifts
  UPDATE shifts
  SET team_id = domestic_team_id
  WHERE team_id IS NULL;
  
  RAISE NOTICE 'Updated shifts: % rows', (SELECT COUNT(*) FROM shifts WHERE team_id = domestic_team_id);
  
  -- Daily Targets
  UPDATE daily_targets
  SET team_id = domestic_team_id
  WHERE team_id IS NULL;
  
  RAISE NOTICE 'Updated daily_targets: % rows', (SELECT COUNT(*) FROM daily_targets WHERE team_id = domestic_team_id);
  
  RAISE NOTICE '✅ Part 1 Complete: Core tables updated. Team ID: %', domestic_team_id;
END $$;

