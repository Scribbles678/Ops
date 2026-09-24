-- 023 — Training target for job functions
--
-- WHY: Team Setup → Training Matrix shows, for each job and hour, how many people
-- trained on that job are on shift. The team wants a goal to hold that against:
-- the fewest trained people it wants on shift in any hour the job is worked.
-- Hours below it show red.
--
-- Informational only. The schedule builder never reads it.
--
-- NULL = no target set, which is every existing row, so this migration changes
-- nothing until someone types a number.
--
-- Re-run safe.

ALTER TABLE job_functions
  ADD COLUMN IF NOT EXISTS training_target integer;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'check_job_function_training_target'
  ) THEN
    ALTER TABLE job_functions
      ADD CONSTRAINT check_job_function_training_target
      CHECK (training_target IS NULL OR training_target >= 0);
  END IF;
END $$;
