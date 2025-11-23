-- Assign Existing Data to "Domestic" Team - PART 2A
-- Run this SQL in your Supabase SQL Editor AFTER Part 1 completes
-- This part handles: schedule_assignments (large table) - UPDATED IN BATCHES

DO $$
DECLARE
  domestic_team_id UUID;
  batch_size INTEGER := 1000;
  updated_count INTEGER;
  total_updated INTEGER := 0;
BEGIN
  -- Get the "Domestic" team ID
  SELECT id INTO domestic_team_id
  FROM teams
  WHERE name = 'Domestic'
  LIMIT 1;
  
  IF domestic_team_id IS NULL THEN
    RAISE EXCEPTION 'Domestic team not found. Please run Part 1 first.';
  END IF;
  
  RAISE NOTICE 'Starting batch updates for schedule_assignments...';
  
  -- Update schedule_assignments in batches to avoid timeout
  LOOP
    -- Update a batch of schedule_assignments
    UPDATE schedule_assignments
    SET team_id = domestic_team_id
    WHERE team_id IS NULL
      AND id IN (
        SELECT id 
        FROM schedule_assignments 
        WHERE team_id IS NULL 
        LIMIT batch_size
      );
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    total_updated := total_updated + updated_count;
    
    RAISE NOTICE 'Updated batch: % rows (total so far: %)', updated_count, total_updated;
    
    -- Exit loop if no more rows to update
    EXIT WHEN updated_count = 0;
    
    -- Small delay to prevent overwhelming the database
    PERFORM pg_sleep(0.1);
  END LOOP;
  
  RAISE NOTICE '✅ Part 2A Complete: Updated % total schedule_assignments to Domestic team (ID: %)', total_updated, domestic_team_id;
END $$;

-- Verify schedule_assignments update
SELECT 
  'schedule_assignments' as table_name,
  COUNT(*) as total_rows,
  COUNT(*) FILTER (WHERE team_id IS NOT NULL) as rows_with_team,
  COUNT(*) FILTER (WHERE team_id IS NULL) as rows_without_team
FROM schedule_assignments;

