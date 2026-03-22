-- User Profiles Table
-- Current schema definition

-- Paste your CREATE TABLE statement here:
create table public.user_profiles (
  id uuid not null,
  username text not null,
  team_id uuid null,
  full_name text null,
  is_super_admin boolean null default false,
  is_active boolean null default true,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  email text null,
  is_admin boolean null default false,
  is_display_user boolean null default false,
  constraint user_profiles_pkey primary key (id),
  constraint user_profiles_username_key unique (username),
  constraint user_profiles_id_fkey foreign KEY (id) references auth.users (id) on delete CASCADE,
  constraint user_profiles_team_id_fkey foreign KEY (team_id) references teams (id) on delete set null,
  constraint check_user_profile_username_not_empty check (
    (
      TRIM(
        both
        from
          username
      ) <> ''::text
    )
  ),
  constraint check_user_profile_username_length check ((length(username) <= 100)),
  constraint check_user_profile_email_format check (
    (
      (email is null)
      or (email = ''::text)
      or (
        (email ~~ '%@%'::text)
        and (email ~~ '%.%'::text)
        and (length(email) >= 5)
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_user_profiles_display on public.user_profiles using btree (is_display_user) TABLESPACE pg_default;

create index IF not exists idx_user_profiles_username on public.user_profiles using btree (username) TABLESPACE pg_default;

create index IF not exists idx_user_profiles_team on public.user_profiles using btree (team_id) TABLESPACE pg_default;

create index IF not exists idx_user_profiles_admin on public.user_profiles using btree (is_super_admin) TABLESPACE pg_default;

create index IF not exists idx_user_profiles_email on public.user_profiles using btree (email) TABLESPACE pg_default;

create trigger prevent_user_profile_privilege_changes_trigger BEFORE
update on user_profiles for EACH row
execute FUNCTION prevent_user_profile_privilege_changes ();

create trigger trigger_prevent_user_profile_privilege_changes BEFORE
update on user_profiles for EACH row
execute FUNCTION prevent_user_profile_privilege_changes ();

create trigger trigger_update_user_profiles_updated_at BEFORE
update on user_profiles for EACH row
execute FUNCTION update_updated_at_column ();
