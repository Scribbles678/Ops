-- Teams Table
-- Current schema definition

-- Paste your CREATE TABLE statement here:
create table public.teams (
  id uuid not null default extensions.uuid_generate_v4 (),
  name text not null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint teams_pkey primary key (id),
  constraint teams_name_key unique (name)
) TABLESPACE pg_default;

create index IF not exists idx_teams_name on public.teams using btree (name) TABLESPACE pg_default;

create trigger trigger_update_teams_updated_at BEFORE
update on teams for EACH row
execute FUNCTION update_teams_updated_at ();
