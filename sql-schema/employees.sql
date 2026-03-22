-- Employees Table
-- Current schema definition

-- Paste your CREATE TABLE statement here:
create table public.employees (
  id uuid not null default extensions.uuid_generate_v4 (),
  first_name text not null,
  last_name text not null,
  is_active boolean null default true,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  shift_id uuid null,
  team_id uuid null,
  constraint employees_pkey primary key (id),
  constraint employees_shift_id_fkey foreign KEY (shift_id) references shifts (id) on delete set null,
  constraint employees_team_id_fkey foreign KEY (team_id) references teams (id) on delete CASCADE,
  constraint check_employee_name_length check (
    (
      (length(first_name) <= 100)
      and (length(last_name) <= 100)
    )
  ),
  constraint check_employee_names_not_empty check (
    (
      (
        TRIM(
          both
          from
            first_name
        ) <> ''::text
      )
      and (
        TRIM(
          both
          from
            last_name
        ) <> ''::text
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_employees_active on public.employees using btree (is_active) TABLESPACE pg_default;

create index IF not exists idx_employees_shift_id on public.employees using btree (shift_id) TABLESPACE pg_default;

create index IF not exists idx_employees_team on public.employees using btree (team_id) TABLESPACE pg_default;

create trigger update_employees_updated_at BEFORE
update on employees for EACH row
execute FUNCTION update_updated_at_column ();
