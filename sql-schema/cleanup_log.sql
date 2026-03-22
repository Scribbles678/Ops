-- Cleanup Log Table
-- Current schema definition

-- Paste your CREATE TABLE statement here:

create table public.cleanup_log (
  id uuid not null default extensions.uuid_generate_v4 (),
  cleanup_date timestamp with time zone null default now(),
  archived_assignments integer null default 0,
  archived_targets integer null default 0,
  cutoff_date date null,
  success boolean null default true,
  error_message text null,
  constraint cleanup_log_pkey primary key (id)
) TABLESPACE pg_default;