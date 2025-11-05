-- Test the update_employee_training function
-- Run this in Supabase SQL Editor to verify it works

-- First, get an employee ID (replace with an actual employee ID from your database)
DO $$
DECLARE
  v_employee_id UUID;
  v_job_function_id UUID;
  v_result BOOLEAN;
BEGIN
  -- Get first employee
  SELECT id INTO v_employee_id FROM employees LIMIT 1;
  
  -- Get first job function
  SELECT id INTO v_job_function_id FROM job_functions LIMIT 1;
  
  RAISE NOTICE 'Testing with employee_id: %, job_function_id: %', v_employee_id, v_job_function_id;
  
  -- Test the function
  SELECT update_employee_training(
    v_employee_id,
    ARRAY[v_job_function_id]::UUID[]
  ) INTO v_result;
  
  RAISE NOTICE 'Function returned: %', v_result;
  
  -- Verify the result
  IF EXISTS (
    SELECT 1 FROM employee_training 
    WHERE employee_id = v_employee_id 
    AND job_function_id = v_job_function_id
  ) THEN
    RAISE NOTICE 'SUCCESS: Training record was created correctly';
  ELSE
    RAISE NOTICE 'ERROR: Training record was NOT created';
  END IF;
END $$;

