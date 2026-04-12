-- Add coverage requirement flags to job_functions
-- Drives the Automated Schedule Builder's lunch/break coverage pass.
-- When true, the builder will try to find another trained, available employee
-- to cover the primary employee's lunch/break for that job function.

ALTER TABLE job_functions
  ADD COLUMN IF NOT EXISTS lunch_coverage_required boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS break_coverage_required boolean NOT NULL DEFAULT false;
