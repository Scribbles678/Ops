-- Schedule Assignments Archive Table
-- Current schema definition

-- Paste your CREATE TABLE statement here:
create table public.schedule_assignments_archive (
  id uuid not null,
  employee_id uuid not null,
  job_function_id uuid not null,
  shift_id uuid not null,
  schedule_date date not null,
  assignment_order integer null default 1,
  start_time time without time zone not null,
  end_time time without time zone not null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  archived_at timestamp with time zone null default now(),
  team_id uuid null,
  constraint schedule_assignments_archive_pkey primary key (id),
  constraint schedule_assignments_archive_team_id_fkey foreign KEY (team_id) references teams (id) on delete set null
) TABLESPACE pg_default;

create index IF not exists idx_schedule_archive_date on public.schedule_assignments_archive using btree (schedule_date) TABLESPACE pg_default;

create index IF not exists idx_schedule_archive_employee on public.schedule_assignments_archive using btree (employee_id) TABLESPACE pg_default;

create index IF not exists idx_schedule_archive_team on public.schedule_assignments_archive using btree (team_id) TABLESPACE pg_default;
