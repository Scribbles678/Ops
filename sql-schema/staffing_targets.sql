-- Staffing Targets Table
-- Stores target headcount per job function per hour for schedule generation

CREATE TABLE public.staffing_targets (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  job_function_id uuid NOT NULL,
  hour_start time WITHOUT TIME ZONE NOT NULL,
  headcount integer NOT NULL DEFAULT 0,
  is_active boolean DEFAULT true,
  team_id uuid NULL,
  created_at timestamp with time zone NULL DEFAULT now(),
  updated_at timestamp with time zone NULL DEFAULT now(),
  CONSTRAINT staffing_targets_pkey PRIMARY KEY (id),
  CONSTRAINT staffing_targets_unique UNIQUE (job_function_id, hour_start, team_id),
  CONSTRAINT staffing_targets_job_function_fkey FOREIGN KEY (job_function_id) REFERENCES job_functions(id) ON DELETE CASCADE,
  CONSTRAINT staffing_targets_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE,
  CONSTRAINT check_headcount_positive CHECK (headcount >= 0)
) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_staffing_targets_team ON public.staffing_targets USING btree (team_id) TABLESPACE pg_default;
