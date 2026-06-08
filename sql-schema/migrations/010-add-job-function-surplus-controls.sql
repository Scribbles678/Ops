-- Per-function surplus controls for the Automated Builder:
--   max_headcount    — ceiling on how many people may be on this function in any
--                      single hour (NULL = unlimited). Surplus fill never exceeds it.
--   surplus_overflow — when true, this function is a preferred "sink" for surplus
--                      labor after per-hour targets are met.
ALTER TABLE job_functions
  ADD COLUMN IF NOT EXISTS max_headcount integer,
  ADD COLUMN IF NOT EXISTS surplus_overflow boolean NOT NULL DEFAULT false;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'check_job_function_max_headcount'
  ) THEN
    ALTER TABLE job_functions
      ADD CONSTRAINT check_job_function_max_headcount
      CHECK (max_headcount IS NULL OR max_headcount >= 0);
  END IF;
END $$;
