-- Shifts Table
-- Current schema definition

-- Paste your CREATE TABLE statement here:
create table public.shifts (
  id uuid not null default extensions.uuid_generate_v4 (),
  name text not null,
  start_time time without time zone not null,
  end_time time without time zone not null,
  break_1_start time without time zone null,
  break_1_end time without time zone null,
  break_2_start time without time zone null,
  break_2_end time without time zone null,
  lunch_start time without time zone null,
  lunch_end time without time zone null,
  is_active boolean null default true,
  created_at timestamp with time zone null default now(),
  team_id uuid null,
  constraint shifts_pkey primary key (id),
  constraint shifts_team_id_fkey foreign KEY (team_id) references teams (id) on delete CASCADE,
  constraint check_shift_break_2_times check (
    (
      (
        (break_2_start is null)
        and (break_2_end is null)
      )
      or (
        (break_2_start is not null)
        and (break_2_end is not null)
        and (break_2_end > break_2_start)
      )
    )
  ),
  constraint check_shift_break_times check (
    (
      (
        (break_1_start is null)
        and (break_1_end is null)
      )
      or (
        (break_1_start is not null)
        and (break_1_end is not null)
        and (break_1_end > break_1_start)
      )
    )
  ),
  constraint check_shift_lunch_times check (
    (
      (
        (lunch_start is null)
        and (lunch_end is null)
      )
      or (
        (lunch_start is not null)
        and (lunch_end is not null)
        and (lunch_end > lunch_start)
      )
    )
  ),
  constraint check_shift_time_range check ((end_time > start_time))
) TABLESPACE pg_default;

create index IF not exists idx_shifts_team on public.shifts using btree (team_id) TABLESPACE pg_default;
