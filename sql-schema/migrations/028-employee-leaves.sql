-- 028: leave of absence, with dates (Oct 2026).
--
-- A person away for a while (medical, family, any longer absence) used to be
-- deactivated on Team Setup, which took them out of the schedule but also out of
-- sight, and nothing brought them back when they returned. A leave is a date range
-- instead: while it covers a day they're off all day everywhere time off is read
-- (schedule builder, schedule page, display board, copy schedule), requests for
-- those days are refused, and when it ends they're simply back. Supervisors and up
-- set it (server/api/leaves/*); end_date NULL means the return date isn't known yet.
--
-- Additive: the table starts empty, and nothing existing changes. Whether leave
-- days count toward the daily time-off limit is the team's choice (Request rules,
-- count_leave_in_pto_limit — off unless a supervisor turns it on).
CREATE TABLE IF NOT EXISTS employee_leaves (
  id          uuid        NOT NULL DEFAULT gen_random_uuid(),
  team_id     uuid        NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  employee_id uuid        NOT NULL,
  start_date  date        NOT NULL,
  end_date    date,
  notes       text,
  created_by  uuid        REFERENCES user_profiles(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT employee_leaves_pkey PRIMARY KEY (id),
  CONSTRAINT employee_leaves_dates CHECK (end_date IS NULL OR end_date >= start_date),
  CONSTRAINT employee_leaves_notes_length CHECK (notes IS NULL OR length(notes) <= 500),
  -- Same team as the employee (the 024 rule), and gone with them.
  CONSTRAINT employee_leaves_employee_id_same_team
    FOREIGN KEY (employee_id, team_id) REFERENCES employees (id, team_id) ON DELETE CASCADE
);

-- "Who is on leave between these dates" (every time-off read), and one person's leaves.
CREATE INDEX IF NOT EXISTS idx_employee_leaves_team_dates ON employee_leaves (team_id, start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_employee_leaves_employee ON employee_leaves (employee_id);

-- audit_log: accept 'leave' entries. Re-run safe like 026: acts only when the CHECK
-- doesn't already allow it, so it doesn't lock and re-scan audit_log on every boot.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'check_audit_log_entity'
      AND conrelid = 'audit_log'::regclass
      AND pg_get_constraintdef(oid) LIKE '%''leave''%'
  ) THEN
    ALTER TABLE audit_log DROP CONSTRAINT IF EXISTS check_audit_log_entity;
    ALTER TABLE audit_log ADD CONSTRAINT check_audit_log_entity
      CHECK (entity_type IN (
        'request', 'pto_day', 'attendance_point', 'performance_note', 'performance_error',
        'account', 'leave'
      ));
  END IF;
END $$;
