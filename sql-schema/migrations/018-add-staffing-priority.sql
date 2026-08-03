-- 018 — Business priority for job functions
--
-- WHY: the builder orders work by SCARCITY (trained people ÷ demand), which
-- protects hard-to-staff roles. That is a supply heuristic, not a business one.
-- Measured example: Projects (14 trained / 10 demand = 1.40) looks scarcer than
-- EM9 (49 / 28 = 1.75), so a short day staffed Projects and left EM9 under target
-- — the opposite of what the floor wants, because Projects is work that can wait.
--
-- staffing_priority lets the floor say so explicitly:
--     1 = fill first   ... 5 = drop first
-- Priority leads; scarcity still breaks ties inside a priority band, so the
-- protection for genuinely hard-to-staff roles is kept.
--
-- Default 3 (normal) means existing behaviour is unchanged until someone sets a
-- value, so this migration cannot alter a schedule on its own.
--
-- Re-run safe.

ALTER TABLE job_functions
  ADD COLUMN IF NOT EXISTS staffing_priority integer NOT NULL DEFAULT 3;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'check_job_function_staffing_priority'
  ) THEN
    ALTER TABLE job_functions
      ADD CONSTRAINT check_job_function_staffing_priority
      CHECK (staffing_priority BETWEEN 1 AND 5);
  END IF;
END $$;

COMMENT ON COLUMN job_functions.staffing_priority IS
  'Order the automated builder fills this function when staff are short. 1 = fill first, 5 = drop first. Ties broken by how hard the function is to staff.';
