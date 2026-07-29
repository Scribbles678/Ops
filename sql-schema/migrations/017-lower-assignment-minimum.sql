-- 017 — Lower the schedule assignment minimum from 30 to 15 minutes
--
-- WHY: coverage cliffs on the floor are 15-minute events. When a whole shift
-- breaks together (e.g. 26 of 28 people at 19:00-19:15), the only way to cover
-- the hole is a 15-minute assignment. The 30-minute floor made that impossible
-- at the database level, regardless of which engine produced the schedule.
--
-- This LOOSENS the constraint, so nothing that was previously valid becomes
-- invalid — V1, the copy-schedule path and manual edits all keep working
-- unchanged. V1's own app logic still declines to emit sub-30 blocks; only the
-- V2 engine deliberately produces them, and only to patch a cliff.
--
-- The floor is deliberately NOT removed: it is the last line of defence against
-- an engine bug writing thousands of 1-minute rows. 15 minutes matches the
-- schedule grid's own granularity.
--
-- To roll back, restore the 30 in the CHECK below and re-run. Rolling back will
-- FAIL if any 15-29 minute assignments already exist — delete those first.
--
-- Re-run safe (the bootstrap plugin applies every migration on each startup).

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'check_schedule_assignment_min_duration'
      AND conrelid = 'schedule_assignments'::regclass
  ) THEN
    ALTER TABLE schedule_assignments
      DROP CONSTRAINT check_schedule_assignment_min_duration;
  END IF;

  ALTER TABLE schedule_assignments
    ADD CONSTRAINT check_schedule_assignment_min_duration
    CHECK ((EXTRACT(EPOCH FROM (end_time - start_time)) / 60::numeric) >= 15::numeric);
END $$;

-- Verify:
--   SELECT pg_get_constraintdef(oid) FROM pg_constraint
--   WHERE conname = 'check_schedule_assignment_min_duration';
