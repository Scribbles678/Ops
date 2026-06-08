-- Add two request types to schedule_requests: 'leave_on_time' (decline overtime —
-- informational, no downstream record) and 'arrive_late' (late start — materializes a
-- pto_days clip of the morning). Idempotent: drop and recreate the CHECK constraint.
ALTER TABLE schedule_requests DROP CONSTRAINT IF EXISTS schedule_requests_request_type_check;
ALTER TABLE schedule_requests ADD CONSTRAINT schedule_requests_request_type_check
  CHECK (request_type IN (
    'leave_early', 'pto_full_day', 'pto_partial', 'shift_swap',
    'leave_on_time', 'arrive_late'
  ));
