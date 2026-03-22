-- ============================================================
-- Operations Scheduling Tool - Standalone PostgreSQL Schema
-- For use WITHOUT Supabase (self-hosted PostgreSQL 13+)
--
-- Changes from Supabase version:
--   - extensions.uuid_generate_v4() → gen_random_uuid()
--   - auth.users FK removed from user_profiles
--   - password_hash + last_login added to user_profiles
--   - RLS policies removed (auth enforced at API layer)
--   - TABLESPACE pg_default kept (standard PostgreSQL)
-- ============================================================

-- ============================================================
-- SHARED TRIGGER FUNCTIONS
-- ============================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- TEAMS
-- ============================================================

CREATE TABLE IF NOT EXISTS teams (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT teams_pkey PRIMARY KEY (id),
  CONSTRAINT teams_name_key UNIQUE (name)
);

CREATE INDEX IF NOT EXISTS idx_teams_name ON teams USING btree (name);

CREATE OR REPLACE FUNCTION update_teams_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_teams_updated_at ON teams;
CREATE TRIGGER trigger_update_teams_updated_at
  BEFORE UPDATE ON teams
  FOR EACH ROW EXECUTE FUNCTION update_teams_updated_at();

-- ============================================================
-- USER PROFILES
-- Replaces Supabase's auth.users + user_profiles combo.
-- id is now a standalone UUID (no longer FK to auth.users).
-- password_hash stores bcrypt hash of the user's password.
-- ============================================================

CREATE TABLE IF NOT EXISTS user_profiles (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  username text NOT NULL,
  email text NOT NULL,
  password_hash text NOT NULL,
  full_name text,
  team_id uuid,
  is_super_admin boolean DEFAULT false,
  is_admin boolean DEFAULT false,
  is_display_user boolean DEFAULT false,
  is_active boolean DEFAULT true,
  last_login timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_profiles_pkey PRIMARY KEY (id),
  CONSTRAINT user_profiles_username_key UNIQUE (username),
  CONSTRAINT user_profiles_email_key UNIQUE (email),
  CONSTRAINT user_profiles_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams (id) ON DELETE SET NULL,
  CONSTRAINT check_user_profile_username_not_empty CHECK (TRIM(both FROM username) <> ''),
  CONSTRAINT check_user_profile_username_length CHECK (length(username) <= 100),
  CONSTRAINT check_user_profile_email_format CHECK (
    email ~~ '%@%' AND email ~~ '%.%' AND length(email) >= 5
  )
);

CREATE INDEX IF NOT EXISTS idx_user_profiles_email ON user_profiles USING btree (email);
CREATE INDEX IF NOT EXISTS idx_user_profiles_username ON user_profiles USING btree (username);
CREATE INDEX IF NOT EXISTS idx_user_profiles_team ON user_profiles USING btree (team_id);
CREATE INDEX IF NOT EXISTS idx_user_profiles_admin ON user_profiles USING btree (is_super_admin);
CREATE INDEX IF NOT EXISTS idx_user_profiles_display ON user_profiles USING btree (is_display_user);

DROP TRIGGER IF EXISTS trigger_update_user_profiles_updated_at ON user_profiles;
CREATE TRIGGER trigger_update_user_profiles_updated_at
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- SHIFTS
-- ============================================================

CREATE TABLE IF NOT EXISTS shifts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  start_time time without time zone NOT NULL,
  end_time time without time zone NOT NULL,
  break_1_start time without time zone,
  break_1_end time without time zone,
  break_2_start time without time zone,
  break_2_end time without time zone,
  lunch_start time without time zone,
  lunch_end time without time zone,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  team_id uuid,
  CONSTRAINT shifts_pkey PRIMARY KEY (id),
  CONSTRAINT shifts_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams (id) ON DELETE CASCADE,
  CONSTRAINT check_shift_time_range CHECK (end_time != start_time),  /* allows overnight (e.g. 22:00-06:30) */
  CONSTRAINT check_shift_break_times CHECK (
    (break_1_start IS NULL AND break_1_end IS NULL)
    OR (break_1_start IS NOT NULL AND break_1_end IS NOT NULL AND break_1_end > break_1_start)
  ),
  CONSTRAINT check_shift_break_2_times CHECK (
    (break_2_start IS NULL AND break_2_end IS NULL)
    OR (break_2_start IS NOT NULL AND break_2_end IS NOT NULL AND break_2_end > break_2_start)
  ),
  CONSTRAINT check_shift_lunch_times CHECK (
    (lunch_start IS NULL AND lunch_end IS NULL)
    OR (lunch_start IS NOT NULL AND lunch_end IS NOT NULL AND lunch_end > lunch_start)
  )
);

CREATE INDEX IF NOT EXISTS idx_shifts_team ON shifts USING btree (team_id);

-- ============================================================
-- JOB FUNCTIONS
-- ============================================================

CREATE TABLE IF NOT EXISTS job_functions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  color_code text NOT NULL DEFAULT '#3B82F6',
  productivity_rate integer,
  is_active boolean DEFAULT true,
  sort_order integer DEFAULT 0,
  unit_of_measure text,
  custom_unit text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  team_id uuid,
  CONSTRAINT job_functions_pkey PRIMARY KEY (id),
  CONSTRAINT job_functions_name_team_key UNIQUE (name, team_id),
  CONSTRAINT job_functions_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams (id) ON DELETE CASCADE,
  CONSTRAINT check_job_function_color_format CHECK (color_code ~ '^#[0-9A-Fa-f]{6}$'),
  CONSTRAINT check_job_function_productivity_rate CHECK (productivity_rate IS NULL OR productivity_rate >= 0),
  CONSTRAINT check_job_function_name_length CHECK (length(name) <= 100),
  CONSTRAINT check_job_function_name_not_empty CHECK (TRIM(both FROM name) <> '')
);

CREATE INDEX IF NOT EXISTS idx_job_functions_team ON job_functions USING btree (team_id);

DROP TRIGGER IF EXISTS update_job_functions_updated_at ON job_functions;
CREATE TRIGGER update_job_functions_updated_at
  BEFORE UPDATE ON job_functions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- EMPLOYEES
-- ============================================================

CREATE TABLE IF NOT EXISTS employees (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  first_name text NOT NULL,
  last_name text NOT NULL,
  is_active boolean DEFAULT true,
  shift_id uuid,
  team_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT employees_pkey PRIMARY KEY (id),
  CONSTRAINT employees_shift_id_fkey FOREIGN KEY (shift_id) REFERENCES shifts (id) ON DELETE SET NULL,
  CONSTRAINT employees_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams (id) ON DELETE CASCADE,
  CONSTRAINT check_employee_name_length CHECK (
    length(first_name) <= 100 AND length(last_name) <= 100
  ),
  CONSTRAINT check_employee_names_not_empty CHECK (
    TRIM(both FROM first_name) <> '' AND TRIM(both FROM last_name) <> ''
  )
);

CREATE INDEX IF NOT EXISTS idx_employees_active ON employees USING btree (is_active);
CREATE INDEX IF NOT EXISTS idx_employees_shift_id ON employees USING btree (shift_id);
CREATE INDEX IF NOT EXISTS idx_employees_team ON employees USING btree (team_id);

DROP TRIGGER IF EXISTS update_employees_updated_at ON employees;
CREATE TRIGGER update_employees_updated_at
  BEFORE UPDATE ON employees
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- EMPLOYEE TRAINING
-- ============================================================

CREATE TABLE IF NOT EXISTS employee_training (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL,
  job_function_id uuid NOT NULL,
  team_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT employee_training_pkey PRIMARY KEY (id),
  CONSTRAINT employee_training_employee_id_job_function_id_key UNIQUE (employee_id, job_function_id),
  CONSTRAINT employee_training_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE,
  CONSTRAINT employee_training_job_function_id_fkey FOREIGN KEY (job_function_id) REFERENCES job_functions (id) ON DELETE CASCADE,
  CONSTRAINT employee_training_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams (id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_employee_training_employee ON employee_training USING btree (employee_id);
CREATE INDEX IF NOT EXISTS idx_employee_training_function ON employee_training USING btree (job_function_id);
CREATE INDEX IF NOT EXISTS idx_employee_training_team ON employee_training USING btree (team_id);

-- ============================================================
-- SCHEDULE ASSIGNMENTS
-- ============================================================

CREATE OR REPLACE FUNCTION validate_assignment_time_conflict()
RETURNS TRIGGER AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM schedule_assignments
    WHERE employee_id = NEW.employee_id
      AND schedule_date = NEW.schedule_date
      AND id <> COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid)
      AND start_time < NEW.end_time
      AND end_time > NEW.start_time
  ) THEN
    RAISE EXCEPTION 'Employee is already scheduled during this time period';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION validate_assignment_training()
RETURNS TRIGGER AS $$
DECLARE
  jf_name text;
  meter_parent_id uuid;
BEGIN
  -- Get job function name for the assignment
  SELECT name INTO jf_name FROM job_functions WHERE id = NEW.job_function_id;

  -- Meter N: accept training on specific Meter N OR on parent "Meter"
  IF jf_name ~ '^Meter [0-9]+$' THEN
    SELECT id INTO meter_parent_id FROM job_functions
      WHERE name = 'Meter' AND (team_id IS NOT DISTINCT FROM NEW.team_id)
      LIMIT 1;
    IF EXISTS (
      SELECT 1 FROM employee_training
      WHERE employee_id = NEW.employee_id
        AND (job_function_id = NEW.job_function_id
             OR (meter_parent_id IS NOT NULL AND job_function_id = meter_parent_id))
    ) THEN
      RETURN NEW;
    END IF;
    RAISE EXCEPTION 'Employee is not trained for this job function (Meter or %)', jf_name;
  END IF;

  -- Default: exact match
  IF NOT EXISTS (
    SELECT 1 FROM employee_training
    WHERE employee_id = NEW.employee_id AND job_function_id = NEW.job_function_id
  ) THEN
    RAISE EXCEPTION 'Employee is not trained for this job function';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS schedule_assignments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL,
  job_function_id uuid NOT NULL,
  shift_id uuid NOT NULL,
  schedule_date date NOT NULL,
  assignment_order integer DEFAULT 1,
  start_time time without time zone NOT NULL,
  end_time time without time zone NOT NULL,
  team_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT schedule_assignments_pkey PRIMARY KEY (id),
  CONSTRAINT schedule_assignments_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams (id) ON DELETE CASCADE,
  CONSTRAINT schedule_assignments_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE,
  CONSTRAINT schedule_assignments_job_function_id_fkey FOREIGN KEY (job_function_id) REFERENCES job_functions (id) ON DELETE CASCADE,
  CONSTRAINT schedule_assignments_shift_id_fkey FOREIGN KEY (shift_id) REFERENCES shifts (id) ON DELETE CASCADE,
  CONSTRAINT check_schedule_assignment_time_range CHECK (end_time > start_time),
  CONSTRAINT check_schedule_assignment_order_positive CHECK (assignment_order > 0),
  CONSTRAINT check_schedule_assignment_min_duration CHECK (
    (EXTRACT(epoch FROM (end_time - start_time)) / 60) >= 30
  )
);

CREATE INDEX IF NOT EXISTS idx_schedule_date ON schedule_assignments USING btree (schedule_date);
CREATE INDEX IF NOT EXISTS idx_schedule_employee ON schedule_assignments USING btree (employee_id);
CREATE INDEX IF NOT EXISTS idx_schedule_assignments_team ON schedule_assignments USING btree (team_id);

DROP TRIGGER IF EXISTS trigger_validate_assignment_time_conflict ON schedule_assignments;
CREATE TRIGGER trigger_validate_assignment_time_conflict
  BEFORE INSERT OR UPDATE ON schedule_assignments
  FOR EACH ROW EXECUTE FUNCTION validate_assignment_time_conflict();

DROP TRIGGER IF EXISTS trigger_validate_assignment_training ON schedule_assignments;
CREATE TRIGGER trigger_validate_assignment_training
  BEFORE INSERT OR UPDATE ON schedule_assignments
  FOR EACH ROW EXECUTE FUNCTION validate_assignment_training();

DROP TRIGGER IF EXISTS update_schedule_assignments_updated_at ON schedule_assignments;
CREATE TRIGGER update_schedule_assignments_updated_at
  BEFORE UPDATE ON schedule_assignments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- SCHEDULE ASSIGNMENTS ARCHIVE
-- ============================================================

CREATE TABLE IF NOT EXISTS schedule_assignments_archive (
  id uuid NOT NULL,
  employee_id uuid NOT NULL,
  job_function_id uuid NOT NULL,
  shift_id uuid NOT NULL,
  schedule_date date NOT NULL,
  assignment_order integer DEFAULT 1,
  start_time time without time zone NOT NULL,
  end_time time without time zone NOT NULL,
  team_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  archived_at timestamp with time zone DEFAULT now(),
  CONSTRAINT schedule_assignments_archive_pkey PRIMARY KEY (id),
  CONSTRAINT schedule_assignments_archive_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams (id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_schedule_archive_date ON schedule_assignments_archive USING btree (schedule_date);
CREATE INDEX IF NOT EXISTS idx_schedule_archive_employee ON schedule_assignments_archive USING btree (employee_id);
CREATE INDEX IF NOT EXISTS idx_schedule_archive_team ON schedule_assignments_archive USING btree (team_id);

-- ============================================================
-- DAILY TARGETS
-- ============================================================

CREATE TABLE IF NOT EXISTS daily_targets (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  schedule_date date NOT NULL,
  job_function_id uuid NOT NULL,
  target_units integer NOT NULL,
  notes text,
  team_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT daily_targets_pkey PRIMARY KEY (id),
  CONSTRAINT daily_targets_schedule_date_job_function_id_key UNIQUE (schedule_date, job_function_id, team_id),
  CONSTRAINT daily_targets_job_function_id_fkey FOREIGN KEY (job_function_id) REFERENCES job_functions (id) ON DELETE CASCADE,
  CONSTRAINT daily_targets_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams (id) ON DELETE CASCADE,
  CONSTRAINT check_daily_targets_units CHECK (target_units >= 0)
);

CREATE INDEX IF NOT EXISTS idx_daily_targets_date ON daily_targets USING btree (schedule_date);
CREATE INDEX IF NOT EXISTS idx_daily_targets_team ON daily_targets USING btree (team_id);

-- Default target hours per job function (used by details page; schedule uses daily_targets per date)
CREATE TABLE IF NOT EXISTS target_hours (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  job_function_id uuid NOT NULL,
  target_hours numeric NOT NULL DEFAULT 8,
  team_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT target_hours_pkey PRIMARY KEY (id),
  CONSTRAINT target_hours_job_function_team_key UNIQUE (job_function_id, team_id),
  CONSTRAINT target_hours_job_function_fkey FOREIGN KEY (job_function_id) REFERENCES job_functions (id) ON DELETE CASCADE,
  CONSTRAINT target_hours_team_fkey FOREIGN KEY (team_id) REFERENCES teams (id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_target_hours_team ON target_hours USING btree (team_id);

DROP TRIGGER IF EXISTS update_daily_targets_updated_at ON daily_targets;
CREATE TRIGGER update_daily_targets_updated_at
  BEFORE UPDATE ON daily_targets
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- DAILY TARGETS ARCHIVE
-- ============================================================

CREATE TABLE IF NOT EXISTS daily_targets_archive (
  id uuid NOT NULL,
  schedule_date date NOT NULL,
  job_function_id uuid NOT NULL,
  target_units integer NOT NULL,
  notes text,
  team_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  archived_at timestamp with time zone DEFAULT now(),
  CONSTRAINT daily_targets_archive_pkey PRIMARY KEY (id),
  CONSTRAINT daily_targets_archive_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams (id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_daily_targets_archive_date ON daily_targets_archive USING btree (schedule_date);
CREATE INDEX IF NOT EXISTS idx_daily_targets_archive_team ON daily_targets_archive USING btree (team_id);

-- ============================================================
-- PTO DAYS
-- ============================================================

CREATE TABLE IF NOT EXISTS pto_days (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL,
  pto_date date NOT NULL,
  start_time time without time zone,
  end_time time without time zone,
  pto_type text,
  notes text,
  team_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT pto_days_pkey PRIMARY KEY (id),
  CONSTRAINT pto_days_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE,
  CONSTRAINT pto_days_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams (id) ON DELETE CASCADE,
  CONSTRAINT check_pto_time_range CHECK (
    start_time IS NULL OR end_time IS NULL OR end_time > start_time
  )
);

CREATE INDEX IF NOT EXISTS idx_pto_date ON pto_days USING btree (pto_date);
CREATE INDEX IF NOT EXISTS idx_pto_employee ON pto_days USING btree (employee_id);
CREATE INDEX IF NOT EXISTS idx_pto_days_team ON pto_days USING btree (team_id);

-- ============================================================
-- SHIFT SWAPS
-- ============================================================

CREATE OR REPLACE FUNCTION validate_shift_swap_date()
RETURNS TRIGGER AS $$
BEGIN
  -- Prevent swaps for past dates
  IF NEW.swap_date < CURRENT_DATE THEN
    RAISE EXCEPTION 'Cannot create shift swap for a past date';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_shift_swaps_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS shift_swaps (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL,
  swap_date date NOT NULL,
  original_shift_id uuid NOT NULL,
  swapped_shift_id uuid NOT NULL,
  notes text,
  team_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT shift_swaps_pkey PRIMARY KEY (id),
  CONSTRAINT shift_swaps_employee_id_swap_date_key UNIQUE (employee_id, swap_date),
  CONSTRAINT shift_swaps_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE,
  CONSTRAINT shift_swaps_original_shift_id_fkey FOREIGN KEY (original_shift_id) REFERENCES shifts (id) ON DELETE CASCADE,
  CONSTRAINT shift_swaps_swapped_shift_id_fkey FOREIGN KEY (swapped_shift_id) REFERENCES shifts (id) ON DELETE CASCADE,
  CONSTRAINT shift_swaps_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams (id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_shift_swaps_employee ON shift_swaps USING btree (employee_id);
CREATE INDEX IF NOT EXISTS idx_shift_swaps_date ON shift_swaps USING btree (swap_date);
CREATE INDEX IF NOT EXISTS idx_shift_swaps_shift ON shift_swaps USING btree (swapped_shift_id);
CREATE INDEX IF NOT EXISTS idx_shift_swaps_team ON shift_swaps USING btree (team_id);

DROP TRIGGER IF EXISTS trigger_update_shift_swaps_updated_at ON shift_swaps;
CREATE TRIGGER trigger_update_shift_swaps_updated_at
  BEFORE UPDATE ON shift_swaps
  FOR EACH ROW EXECUTE FUNCTION update_shift_swaps_updated_at();

DROP TRIGGER IF EXISTS trigger_validate_shift_swap_date ON shift_swaps;
CREATE TRIGGER trigger_validate_shift_swap_date
  BEFORE INSERT OR UPDATE ON shift_swaps
  FOR EACH ROW EXECUTE FUNCTION validate_shift_swap_date();

-- ============================================================
-- PREFERRED ASSIGNMENTS
-- ============================================================

CREATE OR REPLACE FUNCTION update_preferred_assignments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS preferred_assignments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL,
  job_function_id uuid NOT NULL,
  is_required boolean DEFAULT false,
  priority integer DEFAULT 0,
  notes text,
  team_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT preferred_assignments_pkey PRIMARY KEY (id),
  CONSTRAINT preferred_assignments_employee_id_job_function_id_key UNIQUE (employee_id, job_function_id),
  CONSTRAINT preferred_assignments_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES employees (id) ON DELETE CASCADE,
  CONSTRAINT preferred_assignments_job_function_id_fkey FOREIGN KEY (job_function_id) REFERENCES job_functions (id) ON DELETE CASCADE,
  CONSTRAINT preferred_assignments_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams (id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_preferred_assignments_team ON preferred_assignments USING btree (team_id);
CREATE INDEX IF NOT EXISTS idx_preferred_assignments_employee ON preferred_assignments USING btree (employee_id);
CREATE INDEX IF NOT EXISTS idx_preferred_assignments_job_function ON preferred_assignments USING btree (job_function_id);
CREATE INDEX IF NOT EXISTS idx_preferred_assignments_required ON preferred_assignments USING btree (is_required) WHERE is_required = true;

DROP TRIGGER IF EXISTS trigger_update_preferred_assignments_updated_at ON preferred_assignments;
CREATE TRIGGER trigger_update_preferred_assignments_updated_at
  BEFORE UPDATE ON preferred_assignments
  FOR EACH ROW EXECUTE FUNCTION update_preferred_assignments_updated_at();

-- ============================================================
-- BUSINESS RULES
-- ============================================================

CREATE OR REPLACE FUNCTION update_business_rules_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS business_rules (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  job_function_name text NOT NULL,
  time_slot_start time without time zone NOT NULL,
  time_slot_end time without time zone NOT NULL,
  min_staff integer,
  max_staff integer,
  block_size_minutes integer NOT NULL DEFAULT 0,
  priority integer DEFAULT 0,
  is_active boolean DEFAULT true,
  notes text,
  fan_out_enabled boolean DEFAULT false,
  fan_out_prefix text,
  team_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT business_rules_pkey PRIMARY KEY (id),
  CONSTRAINT business_rules_team_id_fkey FOREIGN KEY (team_id) REFERENCES teams (id) ON DELETE CASCADE,
  CONSTRAINT check_business_rule_block_size CHECK (block_size_minutes >= 0),
  CONSTRAINT check_business_rule_time_slot CHECK (time_slot_end > time_slot_start),
  CONSTRAINT check_business_rule_staff_counts CHECK (
    (min_staff IS NULL OR min_staff >= 0)
    AND (max_staff IS NULL OR max_staff >= 0)
    AND (min_staff IS NULL OR max_staff IS NULL OR max_staff >= min_staff)
  )
);

CREATE INDEX IF NOT EXISTS idx_business_rules_job_function ON business_rules USING btree (job_function_name);
CREATE INDEX IF NOT EXISTS idx_business_rules_active ON business_rules USING btree (is_active);
CREATE INDEX IF NOT EXISTS idx_business_rules_priority ON business_rules USING btree (priority);
CREATE INDEX IF NOT EXISTS idx_business_rules_team ON business_rules USING btree (team_id);

DROP TRIGGER IF EXISTS update_business_rules_updated_at ON business_rules;
CREATE TRIGGER update_business_rules_updated_at
  BEFORE UPDATE ON business_rules
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- CLEANUP LOG
-- ============================================================

CREATE TABLE IF NOT EXISTS cleanup_log (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  cleanup_date timestamp with time zone DEFAULT now(),
  archived_assignments integer DEFAULT 0,
  archived_targets integer DEFAULT 0,
  cutoff_date date,
  success boolean DEFAULT true,
  error_message text,
  CONSTRAINT cleanup_log_pkey PRIMARY KEY (id)
);

-- ============================================================
-- CLEANUP STORED PROCEDURE
-- Replaces the Supabase RPC function cleanup_old_schedules_with_logging
-- ============================================================

CREATE OR REPLACE FUNCTION cleanup_old_schedules_with_logging()
RETURNS TABLE(archived_assignments int, archived_targets int, cutoff_date date) AS $$
DECLARE
  v_cutoff_date date := CURRENT_DATE - INTERVAL '30 days';
  v_archived_assignments int := 0;
  v_archived_targets int := 0;
BEGIN
  -- Archive old schedule assignments
  WITH moved AS (
    DELETE FROM schedule_assignments
    WHERE schedule_date < v_cutoff_date
    RETURNING *
  )
  INSERT INTO schedule_assignments_archive
    SELECT id, employee_id, job_function_id, shift_id, schedule_date,
           assignment_order, start_time, end_time, team_id,
           created_at, updated_at, NOW()
    FROM moved;

  GET DIAGNOSTICS v_archived_assignments = ROW_COUNT;

  -- Archive old daily targets
  WITH moved AS (
    DELETE FROM daily_targets
    WHERE schedule_date < v_cutoff_date
    RETURNING *
  )
  INSERT INTO daily_targets_archive
    SELECT id, schedule_date, job_function_id, target_units, notes,
           team_id, created_at, updated_at, NOW()
    FROM moved;

  GET DIAGNOSTICS v_archived_targets = ROW_COUNT;

  -- Log the cleanup
  INSERT INTO cleanup_log (archived_assignments, archived_targets, cutoff_date, success)
  VALUES (v_archived_assignments, v_archived_targets, v_cutoff_date, true);

  RETURN QUERY SELECT v_archived_assignments, v_archived_targets, v_cutoff_date;

EXCEPTION WHEN OTHERS THEN
  INSERT INTO cleanup_log (archived_assignments, archived_targets, cutoff_date, success, error_message)
  VALUES (0, 0, v_cutoff_date, false, SQLERRM);
  RAISE;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_cleanup_stats()
RETURNS TABLE(
  total_logs int,
  last_cleanup timestamp with time zone,
  total_archived_assignments bigint,
  total_archived_targets bigint
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*)::int AS total_logs,
    MAX(cleanup_date) AS last_cleanup,
    COALESCE(SUM(archived_assignments), 0) AS total_archived_assignments,
    COALESCE(SUM(archived_targets), 0) AS total_archived_targets
  FROM cleanup_log
  WHERE success = true;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- EMPLOYEE TRAINING UPDATE FUNCTION
-- Replaces the Supabase RPC function update_employee_training
-- ============================================================

CREATE OR REPLACE FUNCTION update_employee_training(
  p_employee_id uuid,
  p_job_function_ids uuid[],
  p_team_id uuid DEFAULT NULL
)
RETURNS void AS $$
BEGIN
  -- Remove training records not in the new list
  DELETE FROM employee_training
  WHERE employee_id = p_employee_id
    AND job_function_id <> ALL(p_job_function_ids);

  -- Insert new training records (ignore duplicates)
  INSERT INTO employee_training (employee_id, job_function_id, team_id)
  SELECT p_employee_id, unnest(p_job_function_ids), p_team_id
  ON CONFLICT (employee_id, job_function_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql;
