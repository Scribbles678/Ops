-- Converge schema drift: columns that were added ad-hoc to existing databases
-- but were never captured as migrations. Required for a fresh deploy to support
-- login, AM/PM preferred assignments, and the "exclude from targets" feature.

-- user_profiles: link to employees table (optional — lets a user account be tied to an employee record)
ALTER TABLE user_profiles
  ADD COLUMN IF NOT EXISTS employee_id uuid REFERENCES employees(id) ON DELETE SET NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_profiles_employee_id
  ON user_profiles(employee_id) WHERE employee_id IS NOT NULL;

-- job_functions: "exclude from staffing targets grid" toggle used by /details UI
ALTER TABLE job_functions
  ADD COLUMN IF NOT EXISTS exclude_from_targets boolean NOT NULL DEFAULT false;

-- preferred_assignments: split AM and PM preferred functions (used by the Automated Schedule Builder)
ALTER TABLE preferred_assignments
  ADD COLUMN IF NOT EXISTS am_job_function_id uuid REFERENCES job_functions(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS pm_job_function_id uuid REFERENCES job_functions(id) ON DELETE SET NULL;
