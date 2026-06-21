-- Time-blocked required assignments: a required assignment can pin an employee to
-- different job functions across the day in explicit start/end time blocks (replacing
-- the lunch-anchored AM/PM model). Additive only — existing am/pm rows keep working;
-- the builder reads blocks when present and falls back to am/pm otherwise.
CREATE TABLE IF NOT EXISTS preferred_assignment_blocks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  preferred_assignment_id uuid NOT NULL REFERENCES preferred_assignments(id) ON DELETE CASCADE,
  start_time time without time zone NOT NULL,
  end_time time without time zone NOT NULL,
  job_function_id uuid NOT NULL REFERENCES job_functions(id) ON DELETE CASCADE,
  team_id uuid REFERENCES teams(id) ON DELETE CASCADE,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT check_pab_time_range CHECK (end_time > start_time)
);

CREATE INDEX IF NOT EXISTS idx_pab_assignment ON preferred_assignment_blocks(preferred_assignment_id);
CREATE INDEX IF NOT EXISTS idx_pab_team ON preferred_assignment_blocks(team_id);
