-- 019 — Attendance points
--
-- One row per point assigned to an employee: half a point or a full point, on a
-- date, with an optional note. Summed per period on the Employee Overview page.
--
-- ADMIN-ONLY at the API layer (requireAdmin on every route), like the performance
-- tables from 015: this is disciplinary material about named people.
--
-- Authorship (created_by) is ON DELETE SET NULL rather than CASCADE: deleting a
-- user account must never silently erase the points they assigned.
--
-- Additive and idempotent; multi-team safe. Safe to re-run.

BEGIN;

CREATE TABLE IF NOT EXISTS attendance_points (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL,
  point_date date NOT NULL DEFAULT CURRENT_DATE,
  points numeric(2,1) NOT NULL,
  notes text,
  team_id uuid,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT attendance_points_pkey PRIMARY KEY (id),
  CONSTRAINT attendance_points_employee_fkey
    FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE,
  CONSTRAINT attendance_points_team_fkey
    FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE,
  CONSTRAINT attendance_points_author_fkey
    FOREIGN KEY (created_by) REFERENCES user_profiles(id) ON DELETE SET NULL,
  -- Half a point or a full point. Nothing else.
  CONSTRAINT check_attendance_points_value CHECK (points IN (0.5, 1.0)),
  CONSTRAINT check_attendance_points_notes_length CHECK (notes IS NULL OR length(notes) <= 2000)
);

CREATE INDEX IF NOT EXISTS idx_attendance_points_employee ON attendance_points (employee_id);
CREATE INDEX IF NOT EXISTS idx_attendance_points_date     ON attendance_points (point_date);
CREATE INDEX IF NOT EXISTS idx_attendance_points_team     ON attendance_points (team_id);

-- Reuse the shared updated_at trigger function already defined in setup.sql.
DROP TRIGGER IF EXISTS update_attendance_points_updated_at ON attendance_points;
CREATE TRIGGER update_attendance_points_updated_at
  BEFORE UPDATE ON attendance_points
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMIT;
