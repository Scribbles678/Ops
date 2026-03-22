-- Migration: Fix Meter parent lookup in validate_assignment_training
-- Use job function's team_id instead of assignment's team_id when looking up parent "Meter".
-- Fixes: "Employee is not trained for this job function (Meter or Meter N)" when employee
-- is trained on parent Meter but assignment has team_id=null (super admin).
--
-- Run against existing databases. No data changes - function logic only.

CREATE OR REPLACE FUNCTION validate_assignment_training()
RETURNS TRIGGER AS $$
DECLARE
  jf_name text;
  jf_team_id uuid;
  meter_parent_id uuid;
BEGIN
  SELECT name, team_id INTO jf_name, jf_team_id FROM job_functions WHERE id = NEW.job_function_id;

  IF jf_name ~ '^Meter [0-9]+$' THEN
    SELECT id INTO meter_parent_id FROM job_functions
      WHERE name = 'Meter' AND (team_id IS NOT DISTINCT FROM jf_team_id)
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

  IF NOT EXISTS (
    SELECT 1 FROM employee_training
    WHERE employee_id = NEW.employee_id AND job_function_id = NEW.job_function_id
  ) THEN
    RAISE EXCEPTION 'Employee is not trained for this job function';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
