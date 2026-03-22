-- PTO Days Table
-- Current schema definition

-- Paste your CREATE TABLE statement here:
create table public.pto_days (
  id uuid not null default extensions.uuid_generate_v4 (),
  employee_id uuid not null,
  pto_date date not null,
  start_time time without time zone null,
  end_time time without time zone null,
  pto_type text null,
  notes text null,
  created_at timestamp with time zone null default now(),
  team_id uuid null,
  constraint pto_days_pkey primary key (id),
  constraint pto_days_employee_id_fkey foreign KEY (employee_id) references employees (id) on delete CASCADE,
  constraint pto_days_team_id_fkey foreign KEY (team_id) references teams (id) on delete CASCADE,
  constraint check_pto_time_range check (
    (
      (start_time is null)
      or (end_time is null)
      or (end_time > start_time)
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_pto_date on public.pto_days using btree (pto_date) TABLESPACE pg_default;

create index IF not exists idx_pto_employee on public.pto_days using btree (employee_id) TABLESPACE pg_default;

create index IF not exists idx_pto_days_team on public.pto_days using btree (team_id) TABLESPACE pg_default;
