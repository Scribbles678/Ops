-- Preferred Assignments Table
-- Current schema definition

-- Paste your CREATE TABLE statement here:
create table public.preferred_assignments (
  id uuid not null default extensions.uuid_generate_v4 (),
  employee_id uuid not null,
  job_function_id uuid not null,
  is_required boolean null default false,
  priority integer null default 0,
  notes text null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  team_id uuid null,
  constraint preferred_assignments_pkey primary key (id),
  constraint preferred_assignments_employee_id_job_function_id_key unique (employee_id, job_function_id),
  constraint preferred_assignments_employee_id_fkey foreign KEY (employee_id) references employees (id) on delete CASCADE,
  constraint preferred_assignments_job_function_id_fkey foreign KEY (job_function_id) references job_functions (id) on delete CASCADE,
  constraint preferred_assignments_team_id_fkey foreign KEY (team_id) references teams (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_preferred_assignments_team on public.preferred_assignments using btree (team_id) TABLESPACE pg_default;

create index IF not exists idx_preferred_assignments_employee on public.preferred_assignments using btree (employee_id) TABLESPACE pg_default;

create index IF not exists idx_preferred_assignments_job_function on public.preferred_assignments using btree (job_function_id) TABLESPACE pg_default;

create index IF not exists idx_preferred_assignments_required on public.preferred_assignments using btree (is_required) TABLESPACE pg_default
where
  (is_required = true);

create trigger trigger_update_preferred_assignments_updated_at BEFORE
update on preferred_assignments for EACH row
execute FUNCTION update_preferred_assignments_updated_at ();
