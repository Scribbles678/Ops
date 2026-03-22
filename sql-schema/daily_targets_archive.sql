-- Daily Targets Archive Table
-- Current schema definition

-- Paste your CREATE TABLE statement here:
create table public.daily_targets_archive (
  id uuid not null,
  schedule_date date not null,
  job_function_id uuid not null,
  target_units integer not null,
  notes text null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  archived_at timestamp with time zone null default now(),
  team_id uuid null,
  constraint daily_targets_archive_pkey primary key (id),
  constraint daily_targets_archive_team_id_fkey foreign KEY (team_id) references teams (id) on delete set null
) TABLESPACE pg_default;

create index IF not exists idx_daily_targets_archive_date on public.daily_targets_archive using btree (schedule_date) TABLESPACE pg_default;

create index IF not exists idx_daily_targets_archive_team on public.daily_targets_archive using btree (team_id) TABLESPACE pg_default;
