-- Daily Targets Table
-- Current schema definition

-- Paste your CREATE TABLE statement here:
create table public.daily_targets (
  id uuid not null default extensions.uuid_generate_v4 (),
  schedule_date date not null,
  job_function_id uuid not null,
  target_units integer not null,
  notes text null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  team_id uuid null,
  constraint daily_targets_pkey primary key (id),
  constraint daily_targets_schedule_date_job_function_id_key unique (schedule_date, job_function_id),
  constraint daily_targets_job_function_id_fkey foreign KEY (job_function_id) references job_functions (id) on delete CASCADE,
  constraint daily_targets_team_id_fkey foreign KEY (team_id) references teams (id) on delete CASCADE,
  constraint check_daily_targets_units check ((target_units >= 0))
) TABLESPACE pg_default;

create index IF not exists idx_daily_targets_date on public.daily_targets using btree (schedule_date) TABLESPACE pg_default;

create index IF not exists idx_daily_targets_team on public.daily_targets using btree (team_id) TABLESPACE pg_default;

create trigger update_daily_targets_updated_at BEFORE
update on daily_targets for EACH row
execute FUNCTION update_updated_at_column ();
