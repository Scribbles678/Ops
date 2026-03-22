-- Business Rules Table
-- Current schema definition

-- Paste your CREATE TABLE statement here:

create table public.business_rules (
  id uuid not null default extensions.uuid_generate_v4 (),
  job_function_name text not null,
  time_slot_start time without time zone not null,
  time_slot_end time without time zone not null,
  min_staff integer null,
  max_staff integer null,
  block_size_minutes integer not null default 0,
  priority integer null default 0,
  is_active boolean null default true,
  notes text null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  fan_out_enabled boolean null default false,
  fan_out_prefix text null,
  team_id uuid null,
  constraint business_rules_pkey primary key (id),
  constraint business_rules_team_id_fkey foreign KEY (team_id) references teams (id) on delete CASCADE,
  constraint check_business_rule_block_size check ((block_size_minutes >= 0)),
  constraint check_business_rule_staff_counts check (
    (
      (
        (min_staff is null)
        or (min_staff >= 0)
      )
      and (
        (max_staff is null)
        or (max_staff >= 0)
      )
      and (
        (min_staff is null)
        or (max_staff is null)
        or (max_staff >= min_staff)
      )
    )
  ),
  constraint check_business_rule_time_slot check ((time_slot_end > time_slot_start))
) TABLESPACE pg_default;

create index IF not exists idx_business_rules_job_function on public.business_rules using btree (job_function_name) TABLESPACE pg_default;

create index IF not exists idx_business_rules_active on public.business_rules using btree (is_active) TABLESPACE pg_default;

create index IF not exists idx_business_rules_priority on public.business_rules using btree (priority) TABLESPACE pg_default;

create index IF not exists idx_business_rules_team on public.business_rules using btree (team_id) TABLESPACE pg_default;

create trigger update_business_rules_updated_at BEFORE
update on business_rules for EACH row
execute FUNCTION update_business_rules_updated_at ();