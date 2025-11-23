-- Assign Existing Data to "Domestic" Team - PART 2C
-- Run this SQL in your Supabase SQL Editor AFTER Part 2B completes
-- This part handles: optional tables (business_rules, preferred_assignments)

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
  
  RAISE NOTICE '✅ Part 2C Complete: Optional tables updated. Team ID: %', domestic_team_id;
END $$;
