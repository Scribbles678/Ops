-- Stored Procedure for Updating Employee Training
-- This function runs in a database transaction, making it atomic and reliable
-- Run this SQL in your Supabase SQL Editor

CREATE OR REPLACE FUNCTION update_employee_training(
  p_employee_id UUID,
  p_job_function_ids UUID[]
)
RETURNS BOOLEAN AS $$
DECLARE
  v_count INTEGER;
  v_inserted_count INTEGER;
BEGIN
  -- Validate inputs
  IF p_employee_id IS NULL THEN
    RAISE EXCEPTION 'Employee ID cannot be null';
  END IF;

  -- Delete all existing training records for this employee
  DELETE FROM employee_training 
  WHERE employee_id = p_employee_id;
  
  GET DIAGNOSTICS v_count = ROW_COUNT;
  
  -- Insert new training records if any provided
  IF array_length(p_job_function_ids, 1) > 0 THEN
    -- Validate that all job function IDs exist
    SELECT COUNT(*) INTO v_count
    FROM job_functions
    WHERE id = ANY(p_job_function_ids);
    
    IF v_count != array_length(p_job_function_ids, 1) THEN
      RAISE EXCEPTION 'One or more job function IDs are invalid';
    END IF;
    
    -- Insert new training records
    -- Using DISTINCT to handle any duplicates in the array
    INSERT INTO employee_training (employee_id, job_function_id)
    SELECT DISTINCT p_employee_id, unnest(p_job_function_ids)
    ON CONFLICT (employee_id, job_function_id) DO NOTHING;
    
    GET DIAGNOSTICS v_inserted_count = ROW_COUNT;
  ELSE
    v_inserted_count := 0;
  END IF;
  
  -- Return success
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users (or public for now)
GRANT EXECUTE ON FUNCTION update_employee_training(UUID, UUID[]) TO anon, authenticated;

-- Add comment
COMMENT ON FUNCTION update_employee_training(UUID, UUID[]) IS 
'Atomically updates employee training by deleting all existing records and inserting new ones. Returns TRUE on success.';

