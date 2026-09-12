-- 020 — Employee UPI
--
-- employees.upi: the employee's numeric identifier, typed at the kiosk to look up
-- their own requests (a soft gate — it is an identifier, not a secret). Digits
-- only, unique within a team, optional: an employee without one simply cannot
-- look themselves up until a supervisor adds it in Team Setup.
--
-- Additive and idempotent; multi-team safe. Safe to re-run.

ALTER TABLE employees
  ADD COLUMN IF NOT EXISTS upi text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'check_employee_upi_digits'
  ) THEN
    ALTER TABLE employees
      ADD CONSTRAINT check_employee_upi_digits
      CHECK (upi IS NULL OR upi ~ '^[0-9]{1,20}$');
  END IF;
END $$;

-- Unique per team, ignoring NULLs (most rows have no UPI yet).
CREATE UNIQUE INDEX IF NOT EXISTS idx_employees_team_upi
  ON employees (team_id, upi) WHERE upi IS NOT NULL;

COMMENT ON COLUMN employees.upi IS
  'Numeric employee identifier. Typed at the kiosk to look up own requests. Unique within a team.';
