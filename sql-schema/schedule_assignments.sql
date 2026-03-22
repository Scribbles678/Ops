-- Schedule Assignments Table
-- Current schema definition

-- Paste your CREATE TABLE statement here:
create table public.schedule_assignments (
  id uuid not null default extensions.uuid_generate_v4 (),
  employee_id uuid not null,
  job_function_id uuid not null,
  shift_id uuid not null,
  schedule_date date not null,
  assignment_order integer null default 1,
  start_time time without time zone not null,
  end_time time without time zone not null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  team_id uuid null,
  constraint schedule_assignments_pkey primary key (id),
  constraint schedule_assignments_team_id_fkey foreign KEY (team_id) references teams (id) on delete CASCADE,
  constraint schedule_assignments_employee_id_fkey foreign KEY (employee_id) references employees (id) on delete CASCADE,
  constraint schedule_assignments_job_function_id_fkey foreign KEY (job_function_id) references job_functions (id) on delete CASCADE,
  constraint schedule_assignments_shift_id_fkey foreign KEY (shift_id) references shifts (id) on delete CASCADE,
  constraint check_schedule_assignment_time_range check ((end_time > start_time)),
  constraint check_schedule_assignment_order_positive check ((assignment_order > 0)),
  constraint check_schedule_assignment_min_duration check (
    (
      (
        EXTRACT(
          epoch
          from
            (end_time - start_time)
        ) / (60)::numeric
      ) >= (30)::numeric
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_schedule_date on public.schedule_assignments using btree (schedule_date) TABLESPACE pg_default;

create index IF not exists idx_schedule_employee on public.schedule_assignments using btree (employee_id) TABLESPACE pg_default;

create index IF not exists idx_schedule_assignments_team on public.schedule_assignments using btree (team_id) TABLESPACE pg_default;

create trigger trigger_validate_assignment_time_conflict BEFORE INSERT
or
update on schedule_assignments for EACH row
execute FUNCTION validate_assignment_time_conflict ();

create trigger trigger_validate_assignment_training BEFORE INSERT
or
update on schedule_assignments for EACH row
execute FUNCTION validate_assignment_training ();

create trigger update_schedule_assignments_updated_at BEFORE
update on schedule_assignments for EACH row
execute FUNCTION update_updated_at_column ();
