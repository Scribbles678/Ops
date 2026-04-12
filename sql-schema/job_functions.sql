-- Job Functions Table
-- Current schema definition

-- Paste your CREATE TABLE statement here:
create table public.job_functions (
  id uuid not null default extensions.uuid_generate_v4 (),
  name text not null,
  color_code text not null default '#3B82F6'::text,
  productivity_rate integer null,
  is_active boolean null default true,
  sort_order integer null default 0,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  unit_of_measure text null,
  custom_unit text null,
  team_id uuid null,
  exclude_from_targets boolean not null default false,
  lunch_coverage_required boolean not null default false,
  break_coverage_required boolean not null default false,
  constraint job_functions_pkey primary key (id),
  constraint job_functions_name_key unique (name),
  constraint job_functions_team_id_fkey foreign KEY (team_id) references teams (id) on delete CASCADE,
  constraint check_job_function_color_format check ((color_code ~ '^#[0-9A-Fa-f]{6}$'::text)),
  constraint check_job_function_productivity_rate check (
    (
      (productivity_rate is null)
      or (productivity_rate >= 0)
    )
  ),
  constraint check_job_function_name_length check ((length(name) <= 100)),
  constraint check_job_function_name_not_empty check (
    (
      TRIM(
        both
        from
          name
      ) <> ''::text
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_job_functions_team on public.job_functions using btree (team_id) TABLESPACE pg_default;

create trigger update_job_functions_updated_at BEFORE
update on job_functions for EACH row
execute FUNCTION update_updated_at_column ();
