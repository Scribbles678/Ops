-- Draft staffing profiles for the parallel "day designer" UI.
-- Live AI still reads business_rules until publish.

CREATE TABLE IF NOT EXISTS public.staffing_day_drafts (
  id uuid NOT NULL DEFAULT gen_random_uuid (),
  team_id uuid NULL REFERENCES teams (id) ON DELETE CASCADE,
  job_function_name text NOT NULL,
  segments jsonb NOT NULL DEFAULT '[]'::jsonb,
  day_start time without time zone NULL,
  day_end time without time zone NULL,
  updated_at timestamp with time zone NULL DEFAULT now(),
  CONSTRAINT staffing_day_drafts_pkey PRIMARY KEY (id)
) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_staffing_day_drafts_team ON public.staffing_day_drafts USING btree (team_id);

-- One draft per job function per team scope (including global super-admin scope where team_id is null)
CREATE UNIQUE INDEX IF NOT EXISTS idx_staffing_drafts_scope_job
  ON public.staffing_day_drafts ((COALESCE(team_id::text, 'GLOBAL')), job_function_name);

COMMENT ON TABLE public.staffing_day_drafts IS 'JSON segments for beta day-staffing editor; publish copies to business_rules.';
