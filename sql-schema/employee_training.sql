-- Employee Training Table (Junction Table)
-- Current schema definition

-- Paste your CREATE TABLE statement here:
create table public.employee_training (
  id uuid not null default extensions.uuid_generate_v4 (),
  employee_id uuid not null,
  job_function_id uuid not null,
  created_at timestamp with time zone null default now(),
  team_id uuid null,
  constraint employee_training_pkey primary key (id),
  constraint employee_training_employee_id_job_function_id_key unique (employee_id, job_function_id),
  constraint employee_training_employee_id_fkey foreign KEY (employee_id) references employees (id) on delete CASCADE,
  constraint employee_training_job_function_id_fkey foreign KEY (job_function_id) references job_functions (id) on delete CASCADE,
  constraint employee_training_team_id_fkey foreign KEY (team_id) references teams (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_employee_training_employee on public.employee_training using btree (employee_id) TABLESPACE pg_default;

create index IF not exists idx_employee_training_function on public.employee_training using btree (job_function_id) TABLESPACE pg_default;

create index IF not exists idx_employee_training_team on public.employee_training using btree (team_id) TABLESPACE pg_default;
