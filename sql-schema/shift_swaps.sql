-- Shift Swaps Table
-- Current schema definition

-- Paste your CREATE TABLE statement here:
create table public.shift_swaps (
  id uuid not null default extensions.uuid_generate_v4 (),
  employee_id uuid not null,
  swap_date date not null,
  original_shift_id uuid not null,
  swapped_shift_id uuid not null,
  notes text null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  team_id uuid null,
  constraint shift_swaps_pkey primary key (id),
  constraint shift_swaps_employee_id_swap_date_key unique (employee_id, swap_date),
  constraint shift_swaps_employee_id_fkey foreign KEY (employee_id) references employees (id) on delete CASCADE,
  constraint shift_swaps_original_shift_id_fkey foreign KEY (original_shift_id) references shifts (id) on delete CASCADE,
  constraint shift_swaps_swapped_shift_id_fkey foreign KEY (swapped_shift_id) references shifts (id) on delete CASCADE,
  constraint shift_swaps_team_id_fkey foreign KEY (team_id) references teams (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_shift_swaps_employee on public.shift_swaps using btree (employee_id) TABLESPACE pg_default;

create index IF not exists idx_shift_swaps_date on public.shift_swaps using btree (swap_date) TABLESPACE pg_default;

create index IF not exists idx_shift_swaps_shift on public.shift_swaps using btree (swapped_shift_id) TABLESPACE pg_default;

create index IF not exists idx_shift_swaps_team on public.shift_swaps using btree (team_id) TABLESPACE pg_default;

create trigger trigger_update_shift_swaps_updated_at BEFORE
update on shift_swaps for EACH row
execute FUNCTION update_shift_swaps_updated_at ();

create trigger trigger_validate_shift_swap_date BEFORE INSERT
or
update on shift_swaps for EACH row
execute FUNCTION validate_shift_swap_date ();
