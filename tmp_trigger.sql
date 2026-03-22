CREATE OR REPLACE FUNCTION validate_assignment_training()
RETURNS TRIGGER AS $$
DECLARE
  jf_name text;
  meter_parent_id uuid;
BEGIN
  -- Get job function name for the assignment
  SELECT name INTO jf_name FROM job_functions WHERE id = NEW.job_function_id;

  -- Meter N: accept training on specific Meter N OR on parent "Meter"
  IF jf_name ~ '^Meter [0-9]+$' THEN
    SELECT id INTO meter_parent_id FROM job_functions
      WHERE name = 'Meter' AND (team_id IS NOT DISTINCT FROM NEW.team_id)
      LIMIT 1;
    IF EXISTS (
      SELECT 1 FROM employee_training
      WHERE employee_id = NEW.employee_id
        AND (job_function_id = NEW.job_function_id
             OR (meter_parent_id IS NOT NULL AND job_function_id = meter_parent_id))
    ) THEN
      RETURN NEW;
    END IF;
    RAISE EXCEPTION 'Employee is not trained for this job function (Meter or %)', jf_name;
  END IF;

  -- Default: exact match
  IF NOT EXISTS (
    SELECT 1 FROM employee_training
    WHERE employee_id = NEW.employee_id AND job_function_id = NEW.job_function_id
  ) THEN
    RAISE EXCEPTION 'Employee is not trained for this job function';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

