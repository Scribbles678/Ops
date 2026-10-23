-- Add two request types to schedule_requests: 'leave_on_time' (decline overtime —
-- informational, no downstream record) and 'arrive_late' (late start — materializes a
-- pto_days clip of the morning).
--
-- Re-run safe. Until Sep 2026 this dropped and re-created the CHECK on every boot,
-- which locks schedule_requests and re-scans it each restart; now it only acts when
-- the constraint doesn't already allow 'arrive_late'.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'schedule_requests_request_type_check'
      AND conrelid = 'schedule_requests'::regclass
      AND pg_get_constraintdef(oid) LIKE '%arrive_late%'
  ) THEN
    ALTER TABLE schedule_requests DROP CONSTRAINT IF EXISTS schedule_requests_request_type_check;
    ALTER TABLE schedule_requests ADD CONSTRAINT schedule_requests_request_type_check
      CHECK (request_type IN (
        'leave_early', 'pto_full_day', 'pto_partial', 'shift_swap',
        'leave_on_time', 'arrive_late'
      ));
  END IF;
END $$;
