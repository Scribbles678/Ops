-- Per-hour headcount targets for the Automated Schedule Builder.
CREATE TABLE IF NOT EXISTS staffing_targets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_function_id uuid NOT NULL REFERENCES job_functions(id) ON DELETE CASCADE,
  hour_start time WITHOUT TIME ZONE NOT NULL,
  headcount integer NOT NULL DEFAULT 0,
  is_active boolean DEFAULT true,
  team_id uuid REFERENCES teams(id) ON DELETE CASCADE,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT staffing_targets_unique UNIQUE (job_function_id, hour_start, team_id),
  CONSTRAINT check_headcount_positive CHECK (headcount >= 0)
);

CREATE INDEX IF NOT EXISTS idx_staffing_targets_team ON staffing_targets(team_id);
