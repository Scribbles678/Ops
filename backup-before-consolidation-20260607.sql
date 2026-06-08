--
-- PostgreSQL database dump
--

-- Dumped from database version 16.13
-- Dumped by pg_dump version 17.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: cleanup_old_schedules_with_logging(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.cleanup_old_schedules_with_logging() RETURNS TABLE(archived_assignments integer, archived_targets integer, cutoff_date date)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.cleanup_old_schedules_with_logging() OWNER TO postgres;

--
-- Name: get_cleanup_stats(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_cleanup_stats() RETURNS TABLE(total_logs integer, last_cleanup timestamp with time zone, total_archived_assignments bigint, total_archived_targets bigint)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.get_cleanup_stats() OWNER TO postgres;

--
-- Name: update_business_rules_updated_at(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_business_rules_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_business_rules_updated_at() OWNER TO postgres;

--
-- Name: update_employee_training(uuid, uuid[], uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_employee_training(p_employee_id uuid, p_job_function_ids uuid[], p_team_id uuid DEFAULT NULL::uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.update_employee_training(p_employee_id uuid, p_job_function_ids uuid[], p_team_id uuid) OWNER TO postgres;

--
-- Name: update_preferred_assignments_updated_at(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_preferred_assignments_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_preferred_assignments_updated_at() OWNER TO postgres;

--
-- Name: update_shift_swaps_updated_at(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_shift_swaps_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_shift_swaps_updated_at() OWNER TO postgres;

--
-- Name: update_teams_updated_at(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_teams_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_teams_updated_at() OWNER TO postgres;

--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_updated_at_column() OWNER TO postgres;

--
-- Name: validate_assignment_time_conflict(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.validate_assignment_time_conflict() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.validate_assignment_time_conflict() OWNER TO postgres;

--
-- Name: validate_assignment_training(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.validate_assignment_training() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE
  jf_name text;
  jf_team_id uuid;
  meter_parent_id uuid;
BEGIN
  SELECT name, team_id INTO jf_name, jf_team_id FROM job_functions WHERE id = NEW.job_function_id;

  IF jf_name ~ '^Meter [0-9]+$' THEN
    SELECT id INTO meter_parent_id FROM job_functions
      WHERE name = 'Meter' AND (team_id IS NOT DISTINCT FROM jf_team_id)
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

  IF NOT EXISTS (
    SELECT 1 FROM employee_training
    WHERE employee_id = NEW.employee_id AND job_function_id = NEW.job_function_id
  ) THEN
    RAISE EXCEPTION 'Employee is not trained for this job function';
  END IF;
  RETURN NEW;
END;
$_$;


ALTER FUNCTION public.validate_assignment_training() OWNER TO postgres;

--
-- Name: validate_shift_swap_date(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.validate_shift_swap_date() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- Prevent swaps for past dates
  IF NEW.swap_date < CURRENT_DATE THEN
    RAISE EXCEPTION 'Cannot create shift swap for a past date';
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.validate_shift_swap_date() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: _data_backfills; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public._data_backfills (
    key text NOT NULL,
    applied_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public._data_backfills OWNER TO postgres;

--
-- Name: business_rules; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.business_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    job_function_name text NOT NULL,
    time_slot_start time without time zone NOT NULL,
    time_slot_end time without time zone NOT NULL,
    min_staff integer,
    max_staff integer,
    block_size_minutes integer DEFAULT 0 NOT NULL,
    priority integer DEFAULT 0,
    is_active boolean DEFAULT true,
    notes text,
    fan_out_enabled boolean DEFAULT false,
    fan_out_prefix text,
    team_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT check_business_rule_block_size CHECK ((block_size_minutes >= 0)),
    CONSTRAINT check_business_rule_staff_counts CHECK ((((min_staff IS NULL) OR (min_staff >= 0)) AND ((max_staff IS NULL) OR (max_staff >= 0)) AND ((min_staff IS NULL) OR (max_staff IS NULL) OR (max_staff >= min_staff)))),
    CONSTRAINT check_business_rule_time_slot CHECK ((time_slot_end > time_slot_start))
);


ALTER TABLE public.business_rules OWNER TO postgres;

--
-- Name: cleanup_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cleanup_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    cleanup_date timestamp with time zone DEFAULT now(),
    archived_assignments integer DEFAULT 0,
    archived_targets integer DEFAULT 0,
    cutoff_date date,
    success boolean DEFAULT true,
    error_message text
);


ALTER TABLE public.cleanup_log OWNER TO postgres;

--
-- Name: daily_targets; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.daily_targets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    schedule_date date NOT NULL,
    job_function_id uuid NOT NULL,
    target_units integer NOT NULL,
    notes text,
    team_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT check_daily_targets_units CHECK ((target_units >= 0))
);


ALTER TABLE public.daily_targets OWNER TO postgres;

--
-- Name: daily_targets_archive; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.daily_targets_archive (
    id uuid NOT NULL,
    schedule_date date NOT NULL,
    job_function_id uuid NOT NULL,
    target_units integer NOT NULL,
    notes text,
    team_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    archived_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.daily_targets_archive OWNER TO postgres;

--
-- Name: employee_training; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.employee_training (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    employee_id uuid NOT NULL,
    job_function_id uuid NOT NULL,
    team_id uuid,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.employee_training OWNER TO postgres;

--
-- Name: employees; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.employees (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    first_name text NOT NULL,
    last_name text NOT NULL,
    is_active boolean DEFAULT true,
    shift_id uuid,
    team_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT check_employee_name_length CHECK (((length(first_name) <= 100) AND (length(last_name) <= 100))),
    CONSTRAINT check_employee_names_not_empty CHECK (((TRIM(BOTH FROM first_name) <> ''::text) AND (TRIM(BOTH FROM last_name) <> ''::text)))
);


ALTER TABLE public.employees OWNER TO postgres;

--
-- Name: job_functions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.job_functions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    color_code text DEFAULT '#3B82F6'::text NOT NULL,
    productivity_rate integer,
    is_active boolean DEFAULT true,
    sort_order integer DEFAULT 0,
    unit_of_measure text,
    custom_unit text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    team_id uuid,
    exclude_from_targets boolean DEFAULT false NOT NULL,
    lunch_coverage_required boolean DEFAULT false NOT NULL,
    break_coverage_required boolean DEFAULT false NOT NULL,
    CONSTRAINT check_job_function_color_format CHECK ((color_code ~ '^#[0-9A-Fa-f]{6}$'::text)),
    CONSTRAINT check_job_function_name_length CHECK ((length(name) <= 100)),
    CONSTRAINT check_job_function_name_not_empty CHECK ((TRIM(BOTH FROM name) <> ''::text)),
    CONSTRAINT check_job_function_productivity_rate CHECK (((productivity_rate IS NULL) OR (productivity_rate >= 0)))
);


ALTER TABLE public.job_functions OWNER TO postgres;

--
-- Name: password_reset_tokens; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.password_reset_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    token_hash text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    used_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.password_reset_tokens OWNER TO postgres;

--
-- Name: preferred_assignments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.preferred_assignments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    employee_id uuid NOT NULL,
    job_function_id uuid NOT NULL,
    is_required boolean DEFAULT false,
    priority integer DEFAULT 0,
    notes text,
    team_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    am_job_function_id uuid,
    pm_job_function_id uuid
);


ALTER TABLE public.preferred_assignments OWNER TO postgres;

--
-- Name: pto_days; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pto_days (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    employee_id uuid NOT NULL,
    pto_date date NOT NULL,
    start_time time without time zone,
    end_time time without time zone,
    pto_type text,
    notes text,
    team_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT check_pto_time_range CHECK (((start_time IS NULL) OR (end_time IS NULL) OR (end_time > start_time)))
);


ALTER TABLE public.pto_days OWNER TO postgres;

--
-- Name: schedule_assignments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.schedule_assignments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
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
    CONSTRAINT check_schedule_assignment_min_duration CHECK (((EXTRACT(epoch FROM (end_time - start_time)) / (60)::numeric) >= (30)::numeric)),
    CONSTRAINT check_schedule_assignment_order_positive CHECK ((assignment_order > 0)),
    CONSTRAINT check_schedule_assignment_time_range CHECK ((end_time > start_time))
);


ALTER TABLE public.schedule_assignments OWNER TO postgres;

--
-- Name: schedule_assignments_archive; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.schedule_assignments_archive (
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
    archived_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.schedule_assignments_archive OWNER TO postgres;

--
-- Name: schedule_requests; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.schedule_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    employee_id uuid NOT NULL,
    team_id uuid,
    request_type character varying(30) NOT NULL,
    status character varying(20) DEFAULT 'pending'::character varying NOT NULL,
    request_date date NOT NULL,
    start_time time without time zone,
    end_time time without time zone,
    original_shift_id uuid,
    requested_shift_id uuid,
    approval_rule_results jsonb,
    approved_by uuid,
    admin_override boolean DEFAULT false,
    rejection_reason text,
    created_pto_id uuid,
    created_swap_id uuid,
    notes text,
    submitted_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT schedule_requests_request_type_check CHECK (((request_type)::text = ANY ((ARRAY['leave_early'::character varying, 'pto_full_day'::character varying, 'pto_partial'::character varying, 'shift_swap'::character varying])::text[]))),
    CONSTRAINT schedule_requests_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'approved'::character varying, 'rejected'::character varying])::text[])))
);


ALTER TABLE public.schedule_requests OWNER TO postgres;

--
-- Name: shift_swaps; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.shift_swaps (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    employee_id uuid NOT NULL,
    swap_date date NOT NULL,
    original_shift_id uuid NOT NULL,
    swapped_shift_id uuid NOT NULL,
    notes text,
    team_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.shift_swaps OWNER TO postgres;

--
-- Name: shifts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.shifts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
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
    CONSTRAINT check_shift_break_2_times CHECK ((((break_2_start IS NULL) AND (break_2_end IS NULL)) OR ((break_2_start IS NOT NULL) AND (break_2_end IS NOT NULL) AND (break_2_end > break_2_start)))),
    CONSTRAINT check_shift_break_times CHECK ((((break_1_start IS NULL) AND (break_1_end IS NULL)) OR ((break_1_start IS NOT NULL) AND (break_1_end IS NOT NULL) AND (break_1_end > break_1_start)))),
    CONSTRAINT check_shift_lunch_times CHECK ((((lunch_start IS NULL) AND (lunch_end IS NULL)) OR ((lunch_start IS NOT NULL) AND (lunch_end IS NOT NULL) AND (lunch_end > lunch_start)))),
    CONSTRAINT check_shift_time_range CHECK ((end_time <> start_time))
);


ALTER TABLE public.shifts OWNER TO postgres;

--
-- Name: staffing_targets; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.staffing_targets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    job_function_id uuid NOT NULL,
    hour_start time without time zone NOT NULL,
    headcount integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true,
    team_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT check_headcount_positive CHECK ((headcount >= 0))
);


ALTER TABLE public.staffing_targets OWNER TO postgres;

--
-- Name: target_hours; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.target_hours (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    job_function_id uuid NOT NULL,
    target_hours numeric DEFAULT 8 NOT NULL,
    team_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.target_hours OWNER TO postgres;

--
-- Name: team_blocked_dates; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.team_blocked_dates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    team_id uuid NOT NULL,
    blocked_date date NOT NULL,
    reason text,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.team_blocked_dates OWNER TO postgres;

--
-- Name: team_settings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.team_settings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    team_id uuid NOT NULL,
    setting_key character varying(100) NOT NULL,
    setting_value text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.team_settings OWNER TO postgres;

--
-- Name: teams; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.teams (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.teams OWNER TO postgres;

--
-- Name: user_profiles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_profiles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
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
    employee_id uuid,
    CONSTRAINT check_user_profile_email_format CHECK (((email ~~ '%@%'::text) AND (email ~~ '%.%'::text) AND (length(email) >= 5))),
    CONSTRAINT check_user_profile_username_length CHECK ((length(username) <= 100)),
    CONSTRAINT check_user_profile_username_not_empty CHECK ((TRIM(BOTH FROM username) <> ''::text))
);


ALTER TABLE public.user_profiles OWNER TO postgres;

--
-- Data for Name: _data_backfills; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public._data_backfills (key, applied_at) FROM stdin;
\.


--
-- Data for Name: business_rules; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.business_rules (id, job_function_name, time_slot_start, time_slot_end, min_staff, max_staff, block_size_minutes, priority, is_active, notes, fan_out_enabled, fan_out_prefix, team_id, created_at, updated_at) FROM stdin;
50c6d04a-2a93-4de3-ad87-3cd6977fb694	DG Pick	10:00:00	20:30:00	1	1	0	0	t	\N	f	\N	\N	2026-03-24 21:45:03.120098+00	2026-03-24 21:45:03.120098+00
e26e85bb-fadd-4d5c-80fb-daedab59e5da	Runner	10:00:00	12:00:00	1	1	0	0	t	\N	f	\N	\N	2026-03-24 21:45:24.286481+00	2026-03-24 21:45:24.286481+00
2cac13e6-cb9b-4d24-a5ae-a9b8dcbd02e2	Runner	12:00:00	20:30:00	2	2	0	0	t	\N	f	\N	\N	2026-03-24 21:45:46.592792+00	2026-03-24 21:45:46.592792+00
b31523a4-806f-4776-8eed-9bd4fc613f6a	DG	12:00:00	18:30:00	1	1	0	0	t	\N	f	\N	\N	2026-03-24 21:46:47.103174+00	2026-03-24 21:46:47.103174+00
fb906593-4aa1-4a68-af73-3871e5cbec2b	Pick	08:00:00	20:30:00	1	1	0	0	t	\N	f	\N	\N	2026-03-24 21:47:38.783919+00	2026-03-24 21:47:38.783919+00
c1a49740-5ea9-49e2-ade9-f66c945fa4a3	Pick	10:00:00	19:00:00	2	2	0	0	t	\N	f	\N	\N	2026-03-24 21:48:32.31526+00	2026-03-24 21:48:32.31526+00
2ef83d03-6fe6-4ac8-bef5-981eca423deb	Pick	12:00:00	18:00:00	1	1	0	0	t	\N	f	\N	\N	2026-03-24 21:49:08.926507+00	2026-03-24 21:49:08.926507+00
1a276f01-d2a6-4214-9b62-6469efa9a404	startup	06:00:00	20:00:00	1	1	0	0	t	\N	f	\N	\N	2026-03-24 21:49:29.423753+00	2026-03-24 21:49:29.423753+00
884777b5-10d8-418a-bc62-5ea3140393b1	RT-pick	08:00:00	20:30:00	1	1	0	0	t	\N	f	\N	\N	2026-03-24 21:56:29.911622+00	2026-03-24 21:56:29.911622+00
9d564b10-db3e-4180-8469-17d543a72cb4	RT-pick	10:00:00	19:00:00	2	2	0	0	t	\N	f	\N	\N	2026-03-24 21:57:00.820937+00	2026-03-24 21:57:00.820937+00
bdbc58e8-2728-4e24-b289-f963b24787a5	RT-pick	12:00:00	18:00:00	1	1	0	0	t	\N	f	\N	\N	2026-03-24 21:57:24.00312+00	2026-03-24 21:57:24.00312+00
588d6d05-4b2d-40dd-872b-51cdc6df6b74	speedcell	10:00:00	18:30:00	2	2	0	0	t	\N	f	\N	\N	2026-03-24 21:57:42.650558+00	2026-03-24 21:57:42.650558+00
983d0499-7d35-4894-86fc-bff58adcad78	Locus	08:00:00	19:00:00	2	2	0	0	t	\N	f	\N	\N	2026-03-24 21:59:12.653002+00	2026-03-24 21:59:12.653002+00
51620dbd-b853-49a8-aec7-beb78c7a6200	Locus	08:00:00	09:00:00	2	2	0	0	t	\N	f	\N	\N	2026-03-24 21:59:56.113219+00	2026-03-24 21:59:56.113219+00
\.


--
-- Data for Name: cleanup_log; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cleanup_log (id, cleanup_date, archived_assignments, archived_targets, cutoff_date, success, error_message) FROM stdin;
\.


--
-- Data for Name: daily_targets; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.daily_targets (id, schedule_date, job_function_id, target_units, notes, team_id, created_at, updated_at) FROM stdin;
1025cf04-5ef3-4d6c-b62e-c5aa6409ebba	2026-03-22	436d7827-0da9-42c1-b1bb-8745a68abb54	8	\N	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.319904+00	2026-03-22 15:24:07.319904+00
17de09ce-ddd8-4e9f-98ce-2756813342a3	2026-03-22	f149d680-6b63-40cf-9b1c-5e9d97096f1c	8	\N	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.322119+00	2026-03-22 15:24:07.322119+00
9d63ee31-b7c6-4a24-b9ab-2fbf4a163614	2026-03-22	54a2e013-7933-4ba6-bff4-eb07adb05f7e	8	\N	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.323999+00	2026-03-22 15:24:07.323999+00
3a65ec2e-4963-4376-b5da-8ef48c0a4220	2026-03-22	20c634be-77b2-4a73-9f6e-93bedc05b658	8	\N	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.325807+00	2026-03-22 15:24:07.325807+00
\.


--
-- Data for Name: daily_targets_archive; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.daily_targets_archive (id, schedule_date, job_function_id, target_units, notes, team_id, created_at, updated_at, archived_at) FROM stdin;
\.


--
-- Data for Name: employee_training; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.employee_training (id, employee_id, job_function_id, team_id, created_at) FROM stdin;
11b7ff99-89f1-4ac1-80cc-1d1724e49029	d3b977c5-78be-43bd-b2df-9c6ad004ec64	f01032bd-4de9-40ff-953c-d8a2ddc937f5	\N	2026-03-22 19:29:26.952027+00
29b5524f-1d57-42b2-a0d8-9d39b77e80e7	83ec0c51-d0aa-4a2b-95b4-155b87738cb4	fb4fe76d-c487-4dc4-9de4-69a28896bc93	\N	2026-03-25 10:02:22.750818+00
8610bc12-9c39-4665-b115-9c116ec79759	7cc683f3-2ea9-40dd-94d9-2af83d2723da	eecdcfc1-afe3-4fea-b614-8a121ba07575	\N	2026-04-12 14:45:02.029998+00
3f1d6f4c-dcd4-4a1a-bde7-15b33ef1f689	7cc683f3-2ea9-40dd-94d9-2af83d2723da	255ce056-e234-417c-8d6a-db745e4bc729	\N	2026-04-12 14:45:02.029998+00
bd558904-6048-4481-b753-557394b2e6e3	9b8c599c-b1ae-4a02-b2e2-eae82615b1c5	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-07 23:58:58.266012+00
9c2fa290-e0d0-4a96-94e4-07ef10d09a4a	9b8c599c-b1ae-4a02-b2e2-eae82615b1c5	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-07 23:58:58.266012+00
7747aed0-75e4-45d7-b564-06981143aac0	5d89f5b8-1d05-487b-946b-8708e0290a8f	9a8a5181-bdc8-4431-9a0a-14f52be82896	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-07 23:59:01.960913+00
50dc229d-7eb8-4e92-ae68-099c333196a1	4d24bf6a-dfc4-46a4-a41d-ecb6e8ad6be4	f91d0839-8da7-4d33-bec1-7b6563b445ad	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-07 23:59:03.585064+00
0b58c94a-094c-414f-9d29-943d7b272257	86772cf3-dfaa-4db2-9d2d-e2bdb4241d6c	9a8a5181-bdc8-4431-9a0a-14f52be82896	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-07 23:59:05.992307+00
e5205ef8-a837-4617-88c7-07234e7b582f	86772cf3-dfaa-4db2-9d2d-e2bdb4241d6c	eecdcfc1-afe3-4fea-b614-8a121ba07575	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-07 23:59:05.992307+00
e7b55fc1-5d48-4b13-afab-6e9f84567e1e	9b8c599c-b1ae-4a02-b2e2-eae82615b1c5	9a8a5181-bdc8-4431-9a0a-14f52be82896	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-07 23:59:08.681742+00
feeb8239-2799-4d23-9450-09d61826627a	9b8c599c-b1ae-4a02-b2e2-eae82615b1c5	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-07 23:59:08.681742+00
60eb3372-a062-43d0-8596-0b50929353d9	3f8de0d0-ef55-4067-ad87-a7310b3cdaf5	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-07 23:59:12.317599+00
0a6533bd-9875-4e9b-80ac-35e7bffa0cf9	3f8de0d0-ef55-4067-ad87-a7310b3cdaf5	eecdcfc1-afe3-4fea-b614-8a121ba07575	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-07 23:59:12.317599+00
26a88d68-9b55-41cf-ae25-6559c3c56c34	3f8de0d0-ef55-4067-ad87-a7310b3cdaf5	255ce056-e234-417c-8d6a-db745e4bc729	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-07 23:59:12.317599+00
fc71b13b-d0fc-483e-8f21-950afa72563c	14e6a58a-9286-479d-af56-fb4f1cc680dc	f91d0839-8da7-4d33-bec1-7b6563b445ad	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-07 23:59:18.576194+00
5917c053-6ebb-4aea-b062-c5a69f5ee970	14e6a58a-9286-479d-af56-fb4f1cc680dc	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-07 23:59:18.576194+00
688fe495-4bfc-4103-b46d-3d4c7daf7aa3	14e6a58a-9286-479d-af56-fb4f1cc680dc	931a427a-ae31-4c47-a234-0345209e2b31	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-07 23:59:18.576194+00
f4937181-a251-43cf-a7c9-33a7748e7b88	91e5fbf6-b35e-489d-8bec-d77e32facc25	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-07 23:59:21.180912+00
20a4470e-c325-4790-98e5-fad2e81b79f5	91e5fbf6-b35e-489d-8bec-d77e32facc25	eecdcfc1-afe3-4fea-b614-8a121ba07575	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-07 23:59:21.180912+00
99416291-40c5-4496-9f0a-52322ff0d52f	30b6df55-a118-4b1b-8df1-c5663a701ed2	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-07 23:59:23.271379+00
8477f0f0-8e17-4cad-902a-1dbfea05eaf0	d3b977c5-78be-43bd-b2df-9c6ad004ec64	9a8a5181-bdc8-4431-9a0a-14f52be82896	\N	2026-03-22 20:09:42.184822+00
4987d67b-e19a-4152-9a87-bcf5c97f9927	df1d7a4b-33db-4bd9-855b-a6d8f97360a1	9a8a5181-bdc8-4431-9a0a-14f52be82896	\N	2026-03-22 20:09:44.279895+00
d4eb9632-0b0d-4165-acfb-020df4243438	c451eb0a-6299-4de1-8928-fe10fc43c789	9a8a5181-bdc8-4431-9a0a-14f52be82896	\N	2026-03-22 20:09:47.723142+00
09102413-d92a-47ea-82b6-359d5c8c35f9	9854d7dc-b664-4d8f-af15-348b20920345	9a8a5181-bdc8-4431-9a0a-14f52be82896	\N	2026-03-22 20:09:49.738971+00
531772c5-fada-4118-9849-c936fa128cf9	ea762152-a4ba-4f83-b58c-8e8129348e5b	9a8a5181-bdc8-4431-9a0a-14f52be82896	\N	2026-03-22 20:09:51.790934+00
7bd98043-f182-4f83-94a4-8ac934597313	6d1605d8-2318-40ad-b5a9-03feab324fd2	9a8a5181-bdc8-4431-9a0a-14f52be82896	\N	2026-03-22 20:09:55.475158+00
4e0d2529-ca31-4e53-ae1f-526b9f632400	05a758ae-a3b8-401f-a768-a948669f601b	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	\N	2026-03-22 20:10:13.665192+00
76075948-f0cf-43c3-bcd5-80efd1b05216	05a758ae-a3b8-401f-a768-a948669f601b	fb4fe76d-c487-4dc4-9de4-69a28896bc93	\N	2026-03-22 20:10:13.665192+00
70ed97fe-5759-4b0d-8cfc-22ba1007ff1b	9c7a22c6-f3ee-4fe2-9955-26c400fd0ace	931a427a-ae31-4c47-a234-0345209e2b31	\N	2026-03-22 20:10:19.93395+00
09d9e39c-a336-482b-9707-0f25ad1746a3	e506fe75-0df4-48ea-ac85-17b42f896982	931a427a-ae31-4c47-a234-0345209e2b31	\N	2026-03-22 20:10:23.473814+00
8a942cb4-5f78-46d9-b592-5dfcc235c54f	60da7298-fdb8-41f4-ba2d-eff14314ac52	931a427a-ae31-4c47-a234-0345209e2b31	\N	2026-03-22 20:10:30.003433+00
7e253287-8f95-4d02-8a69-443c95ebf590	ed254dbb-5433-4617-9a20-f642fada5d3c	931a427a-ae31-4c47-a234-0345209e2b31	\N	2026-03-22 20:10:33.109664+00
6a08f455-db12-4cb2-a8d3-00ec242d2e0c	eafc9a41-ffe5-4cce-ac7b-9e7b0e274d8f	931a427a-ae31-4c47-a234-0345209e2b31	\N	2026-03-22 20:10:35.373831+00
b455d5e7-ff53-4841-a5a6-68cbe6b00e2e	5e44115d-118e-4dd5-80c6-30b0bc1260dd	931a427a-ae31-4c47-a234-0345209e2b31	\N	2026-03-22 20:10:40.609629+00
8a6a6671-03ca-43aa-a61d-4d1d4b3f824a	6a5611b1-a04b-43d0-8c35-a810d393a0aa	931a427a-ae31-4c47-a234-0345209e2b31	\N	2026-03-22 20:10:44.609667+00
db5f8f73-3e2d-45be-b194-c2cd31d12ba8	10b8fd36-5de5-42ad-8c4a-a8a4494274ad	931a427a-ae31-4c47-a234-0345209e2b31	\N	2026-03-22 20:10:46.844591+00
c691e4b5-49a0-42e0-9ef0-d81ca5b0d35c	30b6df55-a118-4b1b-8df1-c5663a701ed2	931a427a-ae31-4c47-a234-0345209e2b31	\N	2026-03-22 20:10:48.62057+00
d9375835-d4c3-48cf-be7a-732f4e516f44	0c3290ed-2e07-4bb2-aee3-c89339f6914f	931a427a-ae31-4c47-a234-0345209e2b31	\N	2026-03-22 20:10:51.424558+00
d4d91666-dfa1-446f-93e0-3d7988f13ba2	8c25fe94-99d4-44dd-9652-efe248083bb9	931a427a-ae31-4c47-a234-0345209e2b31	\N	2026-03-22 20:10:54.028559+00
50f5b230-3cfe-457e-b04e-0393f7807f6c	0328b5d2-f6e5-43e9-912e-d775bb7ea114	54a2e013-7933-4ba6-bff4-eb07adb05f7e	\N	2026-04-12 14:51:55.353313+00
6714182e-6f15-416c-b3cd-49870fe6b52a	0328b5d2-f6e5-43e9-912e-d775bb7ea114	20c634be-77b2-4a73-9f6e-93bedc05b658	\N	2026-04-12 14:51:55.353313+00
f8f30f5c-1005-4c97-9db9-590053c2f46b	9854d7dc-b664-4d8f-af15-348b20920345	f91d0839-8da7-4d33-bec1-7b6563b445ad	\N	2026-04-12 14:52:04.41472+00
7cae859f-61d5-422c-a242-78e50aa6dda1	39b6b948-b93a-47c0-9d72-bd474ca0b1a9	f91d0839-8da7-4d33-bec1-7b6563b445ad	\N	2026-04-12 14:52:06.9921+00
1851c113-cf84-49c9-bf89-8b332e65c661	ae95da63-ec15-4b11-b142-ff6fdb9a7b03	f91d0839-8da7-4d33-bec1-7b6563b445ad	\N	2026-04-12 14:52:11.325453+00
7641a01b-43c8-446d-8e04-b6e9cd132892	e46010de-9a74-432f-92b6-40b9de20be76	f91d0839-8da7-4d33-bec1-7b6563b445ad	\N	2026-04-12 14:52:13.021256+00
e8afed4b-face-46da-ad9f-18817917a852	60da7298-fdb8-41f4-ba2d-eff14314ac52	f91d0839-8da7-4d33-bec1-7b6563b445ad	\N	2026-04-12 14:52:14.765526+00
7387c930-fd42-44a4-98a3-9ec696c1c213	58119498-aa74-4a50-b937-ef362d96849e	f91d0839-8da7-4d33-bec1-7b6563b445ad	\N	2026-04-12 14:52:17.983397+00
3d97f752-efc4-406c-b48c-c6837e2f9e9f	10b8fd36-5de5-42ad-8c4a-a8a4494274ad	f91d0839-8da7-4d33-bec1-7b6563b445ad	\N	2026-04-12 14:52:20.358519+00
699d7f3a-4116-4e1a-b572-ee72117896ee	0c3290ed-2e07-4bb2-aee3-c89339f6914f	f91d0839-8da7-4d33-bec1-7b6563b445ad	\N	2026-04-12 14:52:22.6287+00
c1c2a063-290a-42f6-9c76-8590d3824abd	a4b4e8b3-39d4-486f-917b-cbdf54b204a3	f91d0839-8da7-4d33-bec1-7b6563b445ad	\N	2026-04-12 14:52:25.205043+00
cdf76d8a-fe96-464c-a8d5-f1ca16e00555	610340d4-b744-4046-971e-023a4281ea6c	f91d0839-8da7-4d33-bec1-7b6563b445ad	\N	2026-04-12 14:52:27.447471+00
ee308eb7-a879-42df-8b8f-ad73f9bf3ec2	0a6c1e7d-b777-49a7-8a55-a85e63979d98	f91d0839-8da7-4d33-bec1-7b6563b445ad	\N	2026-04-12 14:52:29.011781+00
8d04ce9a-6133-4a8d-a05b-6ff224f551ef	4e252744-9763-44d4-b1f5-51affb91f884	f91d0839-8da7-4d33-bec1-7b6563b445ad	\N	2026-04-12 14:52:31.090713+00
bde891c3-6c61-416b-bb35-abdf2b6ff910	86772cf3-dfaa-4db2-9d2d-e2bdb4241d6c	f149d680-6b63-40cf-9b1c-5e9d97096f1c	\N	2026-04-12 14:52:37.225681+00
8d89a651-938b-4087-83c5-733c995c7791	86772cf3-dfaa-4db2-9d2d-e2bdb4241d6c	436d7827-0da9-42c1-b1bb-8745a68abb54	\N	2026-04-12 14:52:37.225681+00
137825d5-476e-4624-b34b-02082c42d049	86772cf3-dfaa-4db2-9d2d-e2bdb4241d6c	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	\N	2026-04-12 14:52:37.225681+00
335f6103-bd04-4303-a787-e0bb7e45ece2	86772cf3-dfaa-4db2-9d2d-e2bdb4241d6c	cc5561bb-cc4e-4829-bfad-ea93aae576ed	\N	2026-04-12 14:52:37.225681+00
ab4385ac-a6fb-42c2-9c5f-bc4e7e1d712f	4e252744-9763-44d4-b1f5-51affb91f884	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	\N	2026-04-12 14:52:41.176904+00
87b1bdb8-6d80-44f1-9de0-96c57618948c	4e252744-9763-44d4-b1f5-51affb91f884	9a8a5181-bdc8-4431-9a0a-14f52be82896	\N	2026-04-12 14:52:41.176904+00
286d5034-6c5f-4072-b4e8-190dfec91ca2	4e252744-9763-44d4-b1f5-51affb91f884	eecdcfc1-afe3-4fea-b614-8a121ba07575	\N	2026-04-12 14:52:41.176904+00
6f62bb81-b9e2-4ffd-9758-4471db0f89eb	48cc0745-4e5f-4dda-8ff5-07fa61d6eea7	cc5561bb-cc4e-4829-bfad-ea93aae576ed	\N	2026-04-12 14:52:44.732131+00
5bdef881-51bf-4570-96ed-ccad40982e48	48cc0745-4e5f-4dda-8ff5-07fa61d6eea7	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	\N	2026-04-12 14:52:44.732131+00
a6c0a418-16f8-45d6-925f-f0ca2095479e	610340d4-b744-4046-971e-023a4281ea6c	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	\N	2026-04-12 14:52:46.90591+00
8523cc68-0348-46f3-a1a2-9503fcd8f32d	7cc81d84-5d1b-42d9-820b-5f99c9dc2ed3	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	\N	2026-04-12 14:52:49.193481+00
873e0df1-786c-48f2-9c00-c5c48c040869	8c25fe94-99d4-44dd-9652-efe248083bb9	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	\N	2026-04-12 14:52:51.408735+00
1409ee6d-dc04-4d78-9192-cd1810ae8a44	ae7fadd4-07c4-408c-9a55-f4780cdcd1f0	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	\N	2026-04-12 14:52:53.258419+00
9601655c-e6a5-4f1e-9db4-0dc4b169d698	5cc3bb12-e940-4880-94e6-cfe1427ecfc6	cc5561bb-cc4e-4829-bfad-ea93aae576ed	\N	2026-04-12 14:52:56.759188+00
5d19237b-bb83-4742-a62a-c7317639ec37	5cc3bb12-e940-4880-94e6-cfe1427ecfc6	eecdcfc1-afe3-4fea-b614-8a121ba07575	\N	2026-04-12 14:52:56.759188+00
6208d72d-4fd1-4a5e-b66c-bfca677a2fd1	175b1a68-6756-44a3-9810-28d3aa10fda6	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	\N	2026-04-12 14:53:02.110945+00
efca6d25-9a05-468e-a35b-c44986f926b2	175b1a68-6756-44a3-9810-28d3aa10fda6	cc5561bb-cc4e-4829-bfad-ea93aae576ed	\N	2026-04-12 14:53:02.110945+00
60312c23-472f-485d-b07c-3eddf3425137	175b1a68-6756-44a3-9810-28d3aa10fda6	eecdcfc1-afe3-4fea-b614-8a121ba07575	\N	2026-04-12 14:53:02.110945+00
f27801e4-53e6-446a-8b80-67761455cf13	175b1a68-6756-44a3-9810-28d3aa10fda6	fb4fe76d-c487-4dc4-9de4-69a28896bc93	\N	2026-04-12 14:53:04.167323+00
5fc60b5b-3b68-48fd-82d6-9c6a7fb5570e	7892a694-bf37-41fa-b2ba-64f69230f4e4	fb4fe76d-c487-4dc4-9de4-69a28896bc93	\N	2026-04-12 14:53:06.679098+00
6b7ece49-5776-42cf-bdaf-55462e5b2143	91e5fbf6-b35e-489d-8bec-d77e32facc25	fb4fe76d-c487-4dc4-9de4-69a28896bc93	\N	2026-04-12 14:53:09.078669+00
6a243b40-64b9-4047-acca-e5e419bf4efa	7cc81d84-5d1b-42d9-820b-5f99c9dc2ed3	fb4fe76d-c487-4dc4-9de4-69a28896bc93	\N	2026-04-12 14:53:10.909607+00
2734a07b-1d15-4db9-a8f3-b1ed96143813	9b8c599c-b1ae-4a02-b2e2-eae82615b1c5	fb4fe76d-c487-4dc4-9de4-69a28896bc93	\N	2026-04-12 14:53:12.565901+00
8f93000f-b367-4dc5-a00a-0e4bee8992a2	7cc683f3-2ea9-40dd-94d9-2af83d2723da	fb4fe76d-c487-4dc4-9de4-69a28896bc93	\N	2026-04-12 14:53:17.407914+00
e92a45d9-2df7-44a5-b6e7-bf3693500bbe	8c870a0e-09ee-4f8d-9fa4-df771f36c4af	fb4fe76d-c487-4dc4-9de4-69a28896bc93	\N	2026-04-12 14:53:19.126697+00
32952eeb-32da-43b1-9d1e-439218e847a6	9854d7dc-b664-4d8f-af15-348b20920345	fb4fe76d-c487-4dc4-9de4-69a28896bc93	\N	2026-04-12 14:53:21.103698+00
d745b77a-25f3-4790-8210-2a349a6de340	ea762152-a4ba-4f83-b58c-8e8129348e5b	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	\N	2026-04-12 14:53:23.176659+00
fb33ffa7-ed74-4599-a7e5-139181300700	df1d7a4b-33db-4bd9-855b-a6d8f97360a1	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	\N	2026-04-12 14:53:28.062841+00
e59a6397-ae04-4fec-ace6-9fcc43850f7d	0328b5d2-f6e5-43e9-912e-d775bb7ea114	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:01:15.60861+00
535f8fef-e157-45d1-82ea-642287a89cae	d3b977c5-78be-43bd-b2df-9c6ad004ec64	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:01:18.747471+00
e2d1912f-6322-4c32-b60f-494fc0831785	0381a248-b039-47ca-a591-41c90db7a78d	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:01:22.598032+00
4f1251bb-88af-4466-8de6-40eeb7663420	ea762152-a4ba-4f83-b58c-8e8129348e5b	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:01:25.134745+00
c427f5bd-49f6-4388-a210-12130119c5c2	39b6b948-b93a-47c0-9d72-bd474ca0b1a9	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:01:27.594323+00
b5f6d7a2-1a70-486d-a360-fe8080582aa1	05a758ae-a3b8-401f-a768-a948669f601b	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:01:30.497208+00
bf5e0561-75d3-4f96-a1bf-70cfaed8a223	9c7a22c6-f3ee-4fe2-9955-26c400fd0ace	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:01:33.238465+00
2c708022-7d18-42f4-bd32-2447ad85c6b0	8c870a0e-09ee-4f8d-9fa4-df771f36c4af	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:01:36.038427+00
c914c1b7-f317-47e2-99d6-fb0610d3993a	0381a248-b039-47ca-a591-41c90db7a78d	54a2e013-7933-4ba6-bff4-eb07adb05f7e	\N	2026-03-24 21:50:14.492836+00
129d65a9-6d0c-4a12-a855-d7e7f62be203	0381a248-b039-47ca-a591-41c90db7a78d	20c634be-77b2-4a73-9f6e-93bedc05b658	\N	2026-03-24 21:50:14.492836+00
4ad1a70a-9d6c-44a7-9054-9fd0695310f1	83ec0c51-d0aa-4a2b-95b4-155b87738cb4	20c634be-77b2-4a73-9f6e-93bedc05b658	\N	2026-03-24 21:50:26.016555+00
0d9736e1-e57b-4eda-8908-4b40758dbfb1	83ec0c51-d0aa-4a2b-95b4-155b87738cb4	54a2e013-7933-4ba6-bff4-eb07adb05f7e	\N	2026-03-24 21:50:26.016555+00
dd01650f-d9bb-4023-9397-a2a189082ff0	9b8c599c-b1ae-4a02-b2e2-eae82615b1c5	54a2e013-7933-4ba6-bff4-eb07adb05f7e	\N	2026-03-24 21:50:48.639227+00
e8369f93-8d2c-4e56-9cda-ac681826b188	9b8c599c-b1ae-4a02-b2e2-eae82615b1c5	20c634be-77b2-4a73-9f6e-93bedc05b658	\N	2026-03-24 21:50:48.639227+00
bfc8c8f6-e3f4-45d9-9170-4090a7e39ade	86772cf3-dfaa-4db2-9d2d-e2bdb4241d6c	54a2e013-7933-4ba6-bff4-eb07adb05f7e	\N	2026-03-24 21:51:03.984623+00
73d1c34c-c59a-437a-9f49-9bd827e49619	86772cf3-dfaa-4db2-9d2d-e2bdb4241d6c	20c634be-77b2-4a73-9f6e-93bedc05b658	\N	2026-03-24 21:51:03.984623+00
80c8e27a-8c98-4050-94fd-74022de4af7c	610340d4-b744-4046-971e-023a4281ea6c	eecdcfc1-afe3-4fea-b614-8a121ba07575	\N	2026-03-24 21:51:13.08357+00
4fb417a4-40bf-4a7e-a02e-c30f9a410b23	6ffdd3d6-ab8e-4a24-bc27-25d51cbf0265	eecdcfc1-afe3-4fea-b614-8a121ba07575	\N	2026-03-24 21:51:15.865588+00
516bda01-d696-4ec4-aa0a-cfc0c98b0733	0a6c1e7d-b777-49a7-8a55-a85e63979d98	eecdcfc1-afe3-4fea-b614-8a121ba07575	\N	2026-03-24 21:51:17.349565+00
e73fe0d3-f4fd-4c3a-88eb-29aac3bb97fd	d3c6f53f-7209-4221-920c-bdc821b92372	cc5561bb-cc4e-4829-bfad-ea93aae576ed	\N	2026-03-24 21:51:25.281337+00
1d51871e-1d60-4f45-8e04-df7b37c1f47b	d3c6f53f-7209-4221-920c-bdc821b92372	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	\N	2026-03-24 21:51:25.281337+00
ad8f3b88-5fd8-4240-bacd-83863188dd75	d3c6f53f-7209-4221-920c-bdc821b92372	931a427a-ae31-4c47-a234-0345209e2b31	\N	2026-03-24 21:51:25.281337+00
c8e86aed-fda8-45cf-8e2a-131d93f475ef	a4b4e8b3-39d4-486f-917b-cbdf54b204a3	eecdcfc1-afe3-4fea-b614-8a121ba07575	\N	2026-03-24 21:51:33.243142+00
d83b132d-94f4-4600-a77d-bd7d2afdc36e	a4b4e8b3-39d4-486f-917b-cbdf54b204a3	fb4fe76d-c487-4dc4-9de4-69a28896bc93	\N	2026-03-24 21:51:33.243142+00
7673303a-82c3-413b-9548-018255adb776	a4b4e8b3-39d4-486f-917b-cbdf54b204a3	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	\N	2026-03-24 21:51:33.243142+00
30eb57d8-8d31-45e6-bd60-13e32c16bed7	a4b4e8b3-39d4-486f-917b-cbdf54b204a3	931a427a-ae31-4c47-a234-0345209e2b31	\N	2026-03-24 21:51:33.243142+00
91cc629d-9f1c-4c2c-83ea-da67eb23468d	7dbb9f67-2b06-4c44-b4f6-94b8f4bdaad4	cc5561bb-cc4e-4829-bfad-ea93aae576ed	\N	2026-03-24 21:51:35.493796+00
cd1bba2b-9e0e-421f-83a8-a196a9a9efea	6e680af6-049c-46f4-8a65-c76c50d29453	cc5561bb-cc4e-4829-bfad-ea93aae576ed	\N	2026-03-24 21:51:37.269556+00
24bfe56f-5d72-49fe-930f-8528765b4809	7cc81d84-5d1b-42d9-820b-5f99c9dc2ed3	cc5561bb-cc4e-4829-bfad-ea93aae576ed	\N	2026-03-24 21:51:39.165508+00
ece6c9d0-93a0-4e4c-bb9d-18c4b811680d	740ee69c-06c1-4a3b-a75c-19ab454b2775	cc5561bb-cc4e-4829-bfad-ea93aae576ed	\N	2026-03-24 21:51:40.937549+00
b37f902b-9d8f-4866-a196-e5733ec24476	6ffdd3d6-ab8e-4a24-bc27-25d51cbf0265	cc5561bb-cc4e-4829-bfad-ea93aae576ed	\N	2026-03-24 21:51:43.441638+00
f01f0831-074d-4a3d-a68b-e33a06e1b02b	9854d7dc-b664-4d8f-af15-348b20920345	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	\N	2026-04-12 17:29:51.264027+00
6d116c1a-3620-4361-a110-ab0ff25a8e18	9854d7dc-b664-4d8f-af15-348b20920345	eecdcfc1-afe3-4fea-b614-8a121ba07575	\N	2026-04-12 17:29:54.967093+00
aef135d0-4f84-4ce5-a284-a20a44b8ef26	5d89f5b8-1d05-487b-946b-8708e0290a8f	f149d680-6b63-40cf-9b1c-5e9d97096f1c	\N	2026-04-12 17:30:26.931271+00
a7b0b1d7-e701-4eb7-b662-4ce1cdd6f0b5	5d89f5b8-1d05-487b-946b-8708e0290a8f	54a2e013-7933-4ba6-bff4-eb07adb05f7e	\N	2026-04-12 17:30:26.931271+00
194b0660-4b4a-4534-aa15-e38970a8af54	5d89f5b8-1d05-487b-946b-8708e0290a8f	f91d0839-8da7-4d33-bec1-7b6563b445ad	\N	2026-04-12 17:30:31.525058+00
566a44f3-4336-4783-a040-f16d47bf7870	5d89f5b8-1d05-487b-946b-8708e0290a8f	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	\N	2026-04-12 17:30:31.525058+00
942fd79a-1b3c-4e01-8b7a-e87a168eab0a	5d89f5b8-1d05-487b-946b-8708e0290a8f	436d7827-0da9-42c1-b1bb-8745a68abb54	\N	2026-04-12 17:30:31.525058+00
1eda85f3-6a74-4f1a-a5b3-874444596166	5d89f5b8-1d05-487b-946b-8708e0290a8f	20c634be-77b2-4a73-9f6e-93bedc05b658	\N	2026-04-12 17:30:31.525058+00
c674586a-6c23-4965-bed8-18a4d9e4772f	4d24bf6a-dfc4-46a4-a41d-ecb6e8ad6be4	20c634be-77b2-4a73-9f6e-93bedc05b658	\N	2026-04-12 17:31:03.486424+00
31e2646b-7e1f-49c2-8f36-fcca8fdb7e8e	4d24bf6a-dfc4-46a4-a41d-ecb6e8ad6be4	54a2e013-7933-4ba6-bff4-eb07adb05f7e	\N	2026-04-12 17:31:03.486424+00
1a8b8027-0872-4906-9ca6-5d2bf6af18b3	4d24bf6a-dfc4-46a4-a41d-ecb6e8ad6be4	f149d680-6b63-40cf-9b1c-5e9d97096f1c	\N	2026-04-12 17:31:07.84258+00
06db6d89-483b-4a43-81c1-a359472fbc40	4d24bf6a-dfc4-46a4-a41d-ecb6e8ad6be4	436d7827-0da9-42c1-b1bb-8745a68abb54	\N	2026-04-12 17:31:07.84258+00
cf59a799-cfbe-4e9f-8e1a-b492a21934e2	4d24bf6a-dfc4-46a4-a41d-ecb6e8ad6be4	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	\N	2026-04-12 17:31:07.84258+00
1e1664a8-0926-4cb3-adaf-87490b07caa4	e940eada-79a1-440e-851e-2dfb9b92b693	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:01:37.636143+00
0393b7c7-81de-40d0-809a-87bf9aed0e35	7cc683f3-2ea9-40dd-94d9-2af83d2723da	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:01:39.293001+00
6f05a173-b543-4595-9d1a-2d52fd4f747d	8a7bf4f5-92de-48eb-a2bc-18dae9992013	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:01:41.513553+00
38374240-f772-4a7b-ad5f-44632436550b	e46010de-9a74-432f-92b6-40b9de20be76	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:01:43.773909+00
27a421cb-8f93-4846-b443-f985dda645c1	343cd39e-8d18-4812-a6d0-d9f480dc9cb9	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:01:46.832+00
2eb55009-1c53-4d6f-835b-6602f653bc20	ae95da63-ec15-4b11-b142-ff6fdb9a7b03	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:01:48.830963+00
f61de2f5-38a2-47b5-a473-477f3a209070	175b1a68-6756-44a3-9810-28d3aa10fda6	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:01:50.890145+00
f0489765-e49f-4e6e-bf9f-264a4fbf4a17	1b11d981-a65d-46bd-8220-700df1acf99f	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:01:52.547106+00
19b6bb4f-badb-4a32-9330-69bbaebf9beb	60da7298-fdb8-41f4-ba2d-eff14314ac52	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:01:54.527612+00
21ac3ce4-a3dd-409b-9c89-558c08b4c1f2	ed254dbb-5433-4617-9a20-f642fada5d3c	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:01:56.165393+00
7a788bbc-c0e5-4cdf-a7f8-6ccfe2378859	eafc9a41-ffe5-4cce-ac7b-9e7b0e274d8f	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:01:58.077751+00
508dc141-391c-4542-92a9-266508e4fff5	6d85775f-a88d-472b-876c-265b4f483da5	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:01:59.989844+00
143406d6-bdc7-4f3d-8e3a-e60cbe5ff7e5	ae7fadd4-07c4-408c-9a55-f4780cdcd1f0	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:02:02.680236+00
94d39e6a-a86a-4a54-8417-c68052a04bb2	5cc3bb12-e940-4880-94e6-cfe1427ecfc6	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:02:04.568407+00
567c9034-ccb7-4f9f-8f95-4a9cc3c94660	631a0690-b2e4-4267-b5cf-3d16d87c264b	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:02:06.896959+00
d4fe5042-905c-4b43-975d-087bd4fc4d2b	fda9b996-4df4-4ab4-bf71-2de86e81ea52	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:02:08.814536+00
9c6b55f4-fe6b-4a23-be54-693592ee5918	58119498-aa74-4a50-b937-ef362d96849e	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:02:11.716684+00
c7fde3d1-df23-4a6a-8441-50d1921af960	6a5611b1-a04b-43d0-8c35-a810d393a0aa	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:02:13.480614+00
7cd07a18-81bc-46ca-ab4d-91d0b52a43ab	10b8fd36-5de5-42ad-8c4a-a8a4494274ad	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:02:15.263871+00
dfdc8bef-411b-4580-b1d8-05f102f34faf	91e5fbf6-b35e-489d-8bec-d77e32facc25	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:02:17.244879+00
811e79ca-75a9-4d73-b568-b784442ec023	30b6df55-a118-4b1b-8df1-c5663a701ed2	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:02:19.65969+00
7e022ece-6dbf-4749-8a4d-d3f0c6df0369	0c3290ed-2e07-4bb2-aee3-c89339f6914f	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:02:21.441418+00
2e737580-272b-45e0-9080-cbba1e088b25	8c25fe94-99d4-44dd-9652-efe248083bb9	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:02:23.537406+00
3686d295-21ea-4e21-bd27-d1b9ffb9011d	14e6a58a-9286-479d-af56-fb4f1cc680dc	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:02:26.634765+00
0802cba0-bbae-4f8f-84e2-a94e9f6c2a72	a4b4e8b3-39d4-486f-917b-cbdf54b204a3	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:02:28.480781+00
587ad9fb-d06e-46c1-9b2d-326638bd419d	7dbb9f67-2b06-4c44-b4f6-94b8f4bdaad4	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:02:31.243693+00
6958e0ab-2699-41c9-b0a2-b398b7f1bf79	d3c6f53f-7209-4221-920c-bdc821b92372	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:02:34.245982+00
5756ad1b-20c4-43ab-b06d-48f67289f2a3	6e680af6-049c-46f4-8a65-c76c50d29453	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:02:35.908016+00
13c92f66-de92-4991-b52e-3a454d310f70	740ee69c-06c1-4a3b-a75c-19ab454b2775	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:02:39.413379+00
42647348-ba9e-4122-99e9-d4f0ae691436	610340d4-b744-4046-971e-023a4281ea6c	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:02:41.095914+00
e6c2a007-2f39-4fb2-8818-9e6fd12dc9b6	6ffdd3d6-ab8e-4a24-bc27-25d51cbf0265	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:02:42.814117+00
b64d3b59-1cc2-4a63-8eac-a641aa474b94	0a6c1e7d-b777-49a7-8a55-a85e63979d98	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:02:44.859646+00
f7d23d04-1016-4338-920e-5dbe55ddf007	48cc0745-4e5f-4dda-8ff5-07fa61d6eea7	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:02:46.759258+00
53e2da86-675a-48cb-8057-2c1bfc6b65bc	3f8de0d0-ef55-4067-ad87-a7310b3cdaf5	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:02:48.397116+00
d249f876-46a7-4993-9183-d8e57fc157bc	9b8c599c-b1ae-4a02-b2e2-eae82615b1c5	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:02:50.079099+00
8a1758d0-1394-4171-a992-ac1ea2949b55	4e252744-9763-44d4-b1f5-51affb91f884	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:02:51.947503+00
d209209d-1049-4562-b4bd-c1aa045e5312	86772cf3-dfaa-4db2-9d2d-e2bdb4241d6c	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:02:53.682561+00
df5e0246-27cc-43c1-8cd6-f2b072730cc3	5d89f5b8-1d05-487b-946b-8708e0290a8f	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:02:56.709047+00
4b2996ce-f408-4aeb-845d-b9981af82b5f	4d24bf6a-dfc4-46a4-a41d-ecb6e8ad6be4	507ff8a9-edd9-460a-af98-5d583676d2d2	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:02:58.434887+00
16672700-c205-4a87-bad0-28e57f476005	d3c6f53f-7209-4221-920c-bdc821b92372	eecdcfc1-afe3-4fea-b614-8a121ba07575	\N	2026-03-24 21:53:02.284809+00
84b4c356-5817-4e99-a72e-2c5645c7bddb	d3c6f53f-7209-4221-920c-bdc821b92372	fb4fe76d-c487-4dc4-9de4-69a28896bc93	\N	2026-03-24 21:53:02.284809+00
3421a1c1-5250-4543-a976-74427cb1212e	0c3290ed-2e07-4bb2-aee3-c89339f6914f	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	\N	2026-03-24 21:53:08.277291+00
8d189294-e619-4b98-bf9f-17bb1d93f2c8	0c3290ed-2e07-4bb2-aee3-c89339f6914f	eecdcfc1-afe3-4fea-b614-8a121ba07575	\N	2026-03-24 21:53:08.277291+00
a85f423a-bf81-4004-9106-6e31b082da74	0c3290ed-2e07-4bb2-aee3-c89339f6914f	fb4fe76d-c487-4dc4-9de4-69a28896bc93	\N	2026-03-24 21:53:08.277291+00
0ec8ccec-b784-4ab8-85d9-47649f9028f7	58119498-aa74-4a50-b937-ef362d96849e	fb4fe76d-c487-4dc4-9de4-69a28896bc93	\N	2026-03-24 21:53:11.241205+00
fc869474-a87f-4089-a332-470a5d0ef394	5e44115d-118e-4dd5-80c6-30b0bc1260dd	fb4fe76d-c487-4dc4-9de4-69a28896bc93	\N	2026-03-24 21:53:17.43136+00
f3c27ebd-099b-4756-8f98-520c54f1d8ff	c451eb0a-6299-4de1-8928-fe10fc43c789	255ce056-e234-417c-8d6a-db745e4bc729	\N	2026-03-22 14:00:21.969112+00
d9561381-73d9-4b64-86b8-5359ebde65cd	5e44115d-118e-4dd5-80c6-30b0bc1260dd	eecdcfc1-afe3-4fea-b614-8a121ba07575	\N	2026-03-24 21:53:17.43136+00
7d33e746-793b-4b84-a6a3-274d0fe18c95	5e44115d-118e-4dd5-80c6-30b0bc1260dd	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	\N	2026-03-24 21:53:17.43136+00
e8d14c21-d8ff-401f-98f3-aa0f1e88e481	5e44115d-118e-4dd5-80c6-30b0bc1260dd	cc5561bb-cc4e-4829-bfad-ea93aae576ed	\N	2026-03-24 21:53:19.475145+00
b5aa71fd-609a-4654-a5ce-fe4cd2448ec3	eafc9a41-ffe5-4cce-ac7b-9e7b0e274d8f	cc5561bb-cc4e-4829-bfad-ea93aae576ed	\N	2026-03-24 21:53:21.167116+00
05cf18a5-cc33-4342-bf27-8faf5aa87798	4e252744-9763-44d4-b1f5-51affb91f884	f01032bd-4de9-40ff-953c-d8a2ddc937f5	\N	2026-03-24 21:53:38.764656+00
8f87b303-ca2b-4481-bdfe-175d7ba66f92	6e680af6-049c-46f4-8a65-c76c50d29453	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	\N	2026-03-24 21:53:45.888829+00
32af019e-dd96-4d05-a479-bed174186f7d	6e680af6-049c-46f4-8a65-c76c50d29453	931a427a-ae31-4c47-a234-0345209e2b31	\N	2026-03-24 21:53:45.888829+00
652e4cdc-03dd-4068-8ad2-b065451023b5	d3b977c5-78be-43bd-b2df-9c6ad004ec64	13c4d090-b2db-4397-89d8-025d6588d0c1	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:24:46.518864+00
f7488b3b-7436-472e-8654-79fb24b64c14	c451eb0a-6299-4de1-8928-fe10fc43c789	13c4d090-b2db-4397-89d8-025d6588d0c1	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:24:52.414371+00
67c0f948-4e6d-432d-9490-90ed939af814	df1d7a4b-33db-4bd9-855b-a6d8f97360a1	13c4d090-b2db-4397-89d8-025d6588d0c1	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:24:54.99636+00
4ef3d52e-8738-496f-bb3b-ecc21e96e90b	6d1605d8-2318-40ad-b5a9-03feab324fd2	13c4d090-b2db-4397-89d8-025d6588d0c1	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:24:57.893459+00
59ab2aae-5d74-423e-a4f2-14c5a518d893	39b6b948-b93a-47c0-9d72-bd474ca0b1a9	13c4d090-b2db-4397-89d8-025d6588d0c1	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:24:59.83039+00
f128370d-dfa4-4073-9a51-c3f627dc62bf	175b1a68-6756-44a3-9810-28d3aa10fda6	13c4d090-b2db-4397-89d8-025d6588d0c1	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:25:04.991066+00
7ffeb30d-c40f-4bcb-8b51-8714227d6471	ae7fadd4-07c4-408c-9a55-f4780cdcd1f0	13c4d090-b2db-4397-89d8-025d6588d0c1	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:25:09.141207+00
954bb05b-69a0-4e3a-b7b3-e47a3225d9d9	58119498-aa74-4a50-b937-ef362d96849e	13c4d090-b2db-4397-89d8-025d6588d0c1	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:25:11.886121+00
50d8b4aa-04e2-4c77-ae29-c72e4f34b517	30b6df55-a118-4b1b-8df1-c5663a701ed2	13c4d090-b2db-4397-89d8-025d6588d0c1	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:25:13.944178+00
addfdc29-7a92-466d-a82a-0b4ed5ffa4bd	175b1a68-6756-44a3-9810-28d3aa10fda6	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.890905+00
3c21d8f2-0e79-4347-8f66-4b1041d4dfbb	175b1a68-6756-44a3-9810-28d3aa10fda6	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.926723+00
4103ab94-a613-4afc-9c8a-e914b3837065	175b1a68-6756-44a3-9810-28d3aa10fda6	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.947657+00
12d38cef-4a1b-4d84-9eac-175af569bec8	175b1a68-6756-44a3-9810-28d3aa10fda6	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.949836+00
00c9a696-e6f8-4bb3-9879-6ed05cdfa90f	10b8fd36-5de5-42ad-8c4a-a8a4494274ad	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.965043+00
306c9907-743b-4755-a0c6-2c37b9b90350	10b8fd36-5de5-42ad-8c4a-a8a4494274ad	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.982765+00
e286003d-aa5e-4ae0-87ae-701c798cc87d	10b8fd36-5de5-42ad-8c4a-a8a4494274ad	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.00242+00
e3aa116d-c7aa-40e6-9e3f-64bf369759fd	10b8fd36-5de5-42ad-8c4a-a8a4494274ad	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.004074+00
66b71a0e-5a2f-4473-a895-02aec22f8e0c	ed254dbb-5433-4617-9a20-f642fada5d3c	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.020637+00
0b6fbebc-2259-41c3-a6d5-76916e1a8fff	ed254dbb-5433-4617-9a20-f642fada5d3c	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.022886+00
1a9dbfaf-af26-442f-ae84-fd851cc6b318	ed254dbb-5433-4617-9a20-f642fada5d3c	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.054804+00
f47bbdf4-12f4-4e50-a366-bf0d2b834739	ed254dbb-5433-4617-9a20-f642fada5d3c	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.056416+00
a84a6a19-5010-4e54-9a64-4d5fdd9f6400	a4b4e8b3-39d4-486f-917b-cbdf54b204a3	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.073031+00
e0a38415-33b6-4767-9444-9a53477f2b76	a4b4e8b3-39d4-486f-917b-cbdf54b204a3	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.075131+00
07a0135f-bcff-4aa7-bccf-a8462005c6aa	a4b4e8b3-39d4-486f-917b-cbdf54b204a3	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.095044+00
a5baee07-238f-4770-95e3-50fa192f634a	a4b4e8b3-39d4-486f-917b-cbdf54b204a3	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.113369+00
6cd54043-7e9b-46cd-83ef-a3c85ebd3d2f	6e680af6-049c-46f4-8a65-c76c50d29453	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.128517+00
26851873-6c1a-4ed3-a48c-bf6828256944	6e680af6-049c-46f4-8a65-c76c50d29453	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.130372+00
788cafaf-afc1-4b61-a38b-ec25542ce357	6e680af6-049c-46f4-8a65-c76c50d29453	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.148795+00
a87e1e38-01f2-4e2e-ab89-af176e2e18dd	6e680af6-049c-46f4-8a65-c76c50d29453	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.167032+00
34b4d9a5-60d2-4373-a132-ed29a5733234	1b11d981-a65d-46bd-8220-700df1acf99f	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.168982+00
03dbf45f-5e7e-4a1b-943d-90ffca0de2d7	1b11d981-a65d-46bd-8220-700df1acf99f	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.184767+00
b0a27a49-cc8f-4c3d-a7bf-8cd2d840e27f	1b11d981-a65d-46bd-8220-700df1acf99f	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.202236+00
03e37143-c0d9-48f4-a7d7-546f65021e6a	1b11d981-a65d-46bd-8220-700df1acf99f	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.204528+00
b065b665-d051-49d3-8084-dea6a666698a	0c3290ed-2e07-4bb2-aee3-c89339f6914f	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.221253+00
4bed4951-2b43-4e6c-b091-cd343a4d579b	0c3290ed-2e07-4bb2-aee3-c89339f6914f	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.223163+00
afc41069-56ad-4414-9335-ad7ca8b358ee	0c3290ed-2e07-4bb2-aee3-c89339f6914f	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.240419+00
45b07088-0fde-4335-8034-384981e65684	0c3290ed-2e07-4bb2-aee3-c89339f6914f	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.25542+00
0ca4f36b-eb5e-4b93-80b6-e5f2ee3d7225	631a0690-b2e4-4267-b5cf-3d16d87c264b	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.257156+00
36af99c2-c598-407d-9190-68abfe9899f8	631a0690-b2e4-4267-b5cf-3d16d87c264b	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.331198+00
8b05b9e9-2003-443d-91eb-86d2778045e5	631a0690-b2e4-4267-b5cf-3d16d87c264b	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.348989+00
6969efa2-8d87-495b-84c0-c814dda68123	631a0690-b2e4-4267-b5cf-3d16d87c264b	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.351535+00
d4b2d58d-8dd2-4eff-a150-53d1968d71f4	3f8de0d0-ef55-4067-ad87-a7310b3cdaf5	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.368945+00
8c28bb7c-81fe-47d8-bab3-a25a582fc7a9	3f8de0d0-ef55-4067-ad87-a7310b3cdaf5	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.370612+00
264090a6-42a7-478c-8b43-7a063ecd80f9	3f8de0d0-ef55-4067-ad87-a7310b3cdaf5	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.389055+00
eca8893d-899c-47d0-939f-bd86d783462b	3f8de0d0-ef55-4067-ad87-a7310b3cdaf5	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.405658+00
1abe5570-e25b-4556-841f-03a670296d91	e46010de-9a74-432f-92b6-40b9de20be76	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.407809+00
fad7acc6-be33-43cb-9119-8dfcdc92cd11	e46010de-9a74-432f-92b6-40b9de20be76	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.424592+00
bc32f857-6acd-4e57-ab11-1ac35f386c9c	e46010de-9a74-432f-92b6-40b9de20be76	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.442858+00
f27b3a47-ad40-45d7-854e-667db3cf1b36	e46010de-9a74-432f-92b6-40b9de20be76	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.444495+00
e8624f26-a0c9-44fa-b27d-edaa37bb76e2	8c870a0e-09ee-4f8d-9fa4-df771f36c4af	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.460009+00
033ea3da-4e09-430d-8225-0a46ae1767b0	8c870a0e-09ee-4f8d-9fa4-df771f36c4af	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.461717+00
5173ed7b-96e1-4d56-bad7-fea8004e2755	8c870a0e-09ee-4f8d-9fa4-df771f36c4af	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.480238+00
5c869198-1dba-4c96-bca9-f85d65c83ef4	8c870a0e-09ee-4f8d-9fa4-df771f36c4af	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.496886+00
5a33f5e4-b844-4675-a479-21c4290e4c62	ea762152-a4ba-4f83-b58c-8e8129348e5b	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.498547+00
d9e954bd-9769-437c-9db3-58656408c630	ea762152-a4ba-4f83-b58c-8e8129348e5b	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.514948+00
276d32d6-6787-4a29-ac56-fcac69b61e27	ea762152-a4ba-4f83-b58c-8e8129348e5b	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.532963+00
cd3aec54-1377-44d6-afa9-2415f9717cca	ea762152-a4ba-4f83-b58c-8e8129348e5b	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.534602+00
285c8af5-99ff-4c74-8991-a92de8b5df14	d3c6f53f-7209-4221-920c-bdc821b92372	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.551452+00
be3ed3aa-0c5c-4bae-81e5-04527e52da3f	d3c6f53f-7209-4221-920c-bdc821b92372	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.553136+00
64584fc2-f605-4fc6-94b2-56aadc34bbd0	d3c6f53f-7209-4221-920c-bdc821b92372	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.571258+00
d9835ba1-f091-4e8b-9e98-8663cefbf4f7	d3c6f53f-7209-4221-920c-bdc821b92372	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.58991+00
25e06444-abc4-4ec2-8cc2-b00119270b64	6ffdd3d6-ab8e-4a24-bc27-25d51cbf0265	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.591661+00
e458287d-5291-487a-a417-ddac5e5aefa6	6ffdd3d6-ab8e-4a24-bc27-25d51cbf0265	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.608079+00
144e4c99-ec9e-4d63-8d82-ab5aeed446a5	6ffdd3d6-ab8e-4a24-bc27-25d51cbf0265	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.626143+00
4c65eac0-055f-4184-8dca-99aa7b77b7fc	6ffdd3d6-ab8e-4a24-bc27-25d51cbf0265	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.628658+00
2a384549-b00c-453b-8471-e13dc369ca62	7892a694-bf37-41fa-b2ba-64f69230f4e4	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.644806+00
c0200501-89f2-47b9-b8d5-40e6af5ea072	7892a694-bf37-41fa-b2ba-64f69230f4e4	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.646348+00
f9adf1a4-b5b1-401a-81ba-a4d7a001d097	7892a694-bf37-41fa-b2ba-64f69230f4e4	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.677864+00
ac0f365c-ba76-4ae6-a4a2-cb20fd1a3413	7892a694-bf37-41fa-b2ba-64f69230f4e4	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.680114+00
70c3de14-d805-4b09-856b-3d6b455de84a	60da7298-fdb8-41f4-ba2d-eff14314ac52	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.69488+00
7294c014-c4a1-4b19-a352-098c246fce51	60da7298-fdb8-41f4-ba2d-eff14314ac52	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.69698+00
0f3c95e5-6623-44db-b476-d4b961a00176	60da7298-fdb8-41f4-ba2d-eff14314ac52	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.730353+00
4117ce69-b5d3-4e19-917f-3242cffecd35	60da7298-fdb8-41f4-ba2d-eff14314ac52	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.746179+00
7c34feda-0419-4e6c-9122-2c151d54a29e	0a6c1e7d-b777-49a7-8a55-a85e63979d98	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.762656+00
69bf40c2-5740-46a0-a87e-91ab03e39e89	0a6c1e7d-b777-49a7-8a55-a85e63979d98	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.779387+00
b83b05f8-4857-4752-a430-983b76c9b0e6	0a6c1e7d-b777-49a7-8a55-a85e63979d98	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.816869+00
629804b2-c2ba-4b2a-9487-0d38e8545bde	0a6c1e7d-b777-49a7-8a55-a85e63979d98	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.834638+00
71ff1306-ac36-4d95-93dc-0d4b2dfc11ae	740ee69c-06c1-4a3b-a75c-19ab454b2775	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.852558+00
d668d60d-cfbb-4772-9c84-49f2e05e991f	740ee69c-06c1-4a3b-a75c-19ab454b2775	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.870623+00
b514fac2-8dfb-4bce-bc0c-8ea263a5ad48	740ee69c-06c1-4a3b-a75c-19ab454b2775	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.905463+00
95e2b803-6b87-40e8-8c80-f55f566b36e7	740ee69c-06c1-4a3b-a75c-19ab454b2775	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.92247+00
bde5ec96-9302-4c5f-bfd6-536c760b2837	05a758ae-a3b8-401f-a768-a948669f601b	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.924202+00
6f5eb02c-fba0-4fc9-82a4-f4ac4be40beb	05a758ae-a3b8-401f-a768-a948669f601b	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.941171+00
2913daf4-56cd-46ea-860b-55214b2acb2a	05a758ae-a3b8-401f-a768-a948669f601b	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.959561+00
7b51585d-45a2-4f00-99a8-4bb58df6d708	05a758ae-a3b8-401f-a768-a948669f601b	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.961368+00
b539de6f-b344-4ca5-8cf4-c918936cc5e7	5e44115d-118e-4dd5-80c6-30b0bc1260dd	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.978158+00
f55e6032-1311-4545-9e9a-51742a45037b	5e44115d-118e-4dd5-80c6-30b0bc1260dd	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.97998+00
aa97eb1b-9748-4cdd-8d03-f7884ce62e88	5e44115d-118e-4dd5-80c6-30b0bc1260dd	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.996725+00
14b7d66e-7573-45ee-a2df-fa5960c8a44f	5e44115d-118e-4dd5-80c6-30b0bc1260dd	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:05.998634+00
dc832077-1b1d-4830-ba5f-56aa2a80bd00	9c7a22c6-f3ee-4fe2-9955-26c400fd0ace	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.032175+00
cd7edcfe-187b-49d3-9149-762448e21176	9c7a22c6-f3ee-4fe2-9955-26c400fd0ace	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.034055+00
820c99e3-6a84-4c88-bc62-fe58d7d3a35a	9c7a22c6-f3ee-4fe2-9955-26c400fd0ace	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.051445+00
963360bd-4048-43c5-aa79-ee34e5e1d997	9c7a22c6-f3ee-4fe2-9955-26c400fd0ace	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.066351+00
d1a600e4-081c-4e3a-9674-67f864971eed	fda9b996-4df4-4ab4-bf71-2de86e81ea52	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.068353+00
85259107-2198-4a02-b443-cbd0901a257f	fda9b996-4df4-4ab4-bf71-2de86e81ea52	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.085383+00
8aea6414-c796-4fc3-bd66-bf5847ca5532	fda9b996-4df4-4ab4-bf71-2de86e81ea52	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.101994+00
73bc8749-9fb8-4ae2-9c03-9d640ac3f014	fda9b996-4df4-4ab4-bf71-2de86e81ea52	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.103976+00
54925e15-a599-4923-ba09-ee9cbcdecf44	e506fe75-0df4-48ea-ac85-17b42f896982	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.119878+00
b321ffb3-180e-4bfd-bcf0-f9b43edf5363	e506fe75-0df4-48ea-ac85-17b42f896982	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.121772+00
a39c7d44-df04-4f4c-8111-fe8675665eba	e506fe75-0df4-48ea-ac85-17b42f896982	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.139473+00
7f060e78-c1f0-4c1d-b067-e604c79aacfa	e506fe75-0df4-48ea-ac85-17b42f896982	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.155818+00
30da3c75-d985-4796-9a8f-a64ad1b382bc	14e6a58a-9286-479d-af56-fb4f1cc680dc	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.15749+00
2b0699f1-99d0-4c83-bfa3-3ef767b1a433	14e6a58a-9286-479d-af56-fb4f1cc680dc	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.173832+00
c1a4ffdc-041e-4a5c-b488-a158455f8f8d	14e6a58a-9286-479d-af56-fb4f1cc680dc	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.191824+00
dd4561e2-7131-4eba-9379-35b75445c2cb	14e6a58a-9286-479d-af56-fb4f1cc680dc	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.193708+00
49e4c2bb-ac6c-45e6-b3c1-0d3542d4dd45	30b6df55-a118-4b1b-8df1-c5663a701ed2	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.209597+00
832b635d-a7b8-4aa8-8897-e12f7326d3de	30b6df55-a118-4b1b-8df1-c5663a701ed2	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.211499+00
861e224d-79ea-4eab-8dcb-bac9c73b098d	30b6df55-a118-4b1b-8df1-c5663a701ed2	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.231819+00
ae1ed287-1261-4dda-8bf1-f3ada98b1fdb	30b6df55-a118-4b1b-8df1-c5663a701ed2	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.248534+00
ada03680-ce73-4b05-88aa-d3e24574b6fc	6d1605d8-2318-40ad-b5a9-03feab324fd2	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.250356+00
ba757af4-03d5-4b45-8aaf-a2319668dd93	6d1605d8-2318-40ad-b5a9-03feab324fd2	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.266987+00
94be88b0-ac84-417c-b82b-1a025e4fb1cd	6d1605d8-2318-40ad-b5a9-03feab324fd2	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.347072+00
14a038ec-2be8-4262-a43f-651e4cffc043	6d1605d8-2318-40ad-b5a9-03feab324fd2	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.349019+00
b6cb3d0a-c9c7-4cfc-af92-309b5299a13c	4e252744-9763-44d4-b1f5-51affb91f884	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.365821+00
00f53fb5-db0f-4a4c-9c53-0acd7106c844	4e252744-9763-44d4-b1f5-51affb91f884	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.367711+00
8d12919f-7667-482b-b10c-2fab6dfbb1b7	4e252744-9763-44d4-b1f5-51affb91f884	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.38662+00
d77305b3-d5b6-4808-874f-c1d8605bd9d0	4e252744-9763-44d4-b1f5-51affb91f884	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.401981+00
e359b822-39e6-4d65-9c7d-4b617eed092a	58119498-aa74-4a50-b937-ef362d96849e	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.419648+00
5a6c8982-e5cf-4962-adf3-2af804abfda1	58119498-aa74-4a50-b937-ef362d96849e	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.421499+00
c746ef06-8831-45a7-bfe1-54f66c9dc04f	58119498-aa74-4a50-b937-ef362d96849e	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.4422+00
d66c9cb8-f3e4-4010-a19b-6844ba26e582	58119498-aa74-4a50-b937-ef362d96849e	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.458647+00
d56ac89a-f3ba-420d-8f78-bc81973b6ad1	6a5611b1-a04b-43d0-8c35-a810d393a0aa	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.536667+00
572af348-2b8f-4bda-8a5a-d864f79f07c1	6a5611b1-a04b-43d0-8c35-a810d393a0aa	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.538472+00
3aecb21e-882b-4a55-b966-f99306233596	6a5611b1-a04b-43d0-8c35-a810d393a0aa	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.541571+00
15fd83ac-c0c3-4353-8aff-2e6cc3eda5c6	6a5611b1-a04b-43d0-8c35-a810d393a0aa	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.557348+00
b12c2a51-3311-47f4-a8c7-c757df886963	7cc81d84-5d1b-42d9-820b-5f99c9dc2ed3	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.559027+00
d03a7955-b6a8-42fd-96a1-4a8ee23c2f5e	7cc81d84-5d1b-42d9-820b-5f99c9dc2ed3	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.560549+00
1934ca3c-51ed-4b82-bc39-93c5886df974	7cc81d84-5d1b-42d9-820b-5f99c9dc2ed3	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.577379+00
84dbb5b1-170a-406d-af20-bf5aecd06ae7	7cc81d84-5d1b-42d9-820b-5f99c9dc2ed3	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.579359+00
e8fc26f3-4b45-4589-a885-53c461ad37bb	5f926628-1321-410f-835a-a1701355219d	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.581221+00
96820955-98d2-40f1-bacd-494a9a08c0b3	5f926628-1321-410f-835a-a1701355219d	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.58269+00
95d56e08-2046-4b5b-9d7a-f1cda7332be5	5f926628-1321-410f-835a-a1701355219d	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.599209+00
a76b8143-0772-4ee9-a7e6-e69026b0e3bb	5f926628-1321-410f-835a-a1701355219d	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.600901+00
5f186cb9-2c0c-4567-a230-d2ae86251b2f	9854d7dc-b664-4d8f-af15-348b20920345	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.602469+00
39452cd5-6f63-4445-8514-73e3d577cb6a	9854d7dc-b664-4d8f-af15-348b20920345	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.61758+00
8cc3048e-9185-4c33-a588-4a4e4ea663f6	9854d7dc-b664-4d8f-af15-348b20920345	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.620512+00
ccc8d4c8-91f7-4356-911b-516a04f46605	9854d7dc-b664-4d8f-af15-348b20920345	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.621902+00
db126970-075b-4fa4-bd38-6c80722e4aba	610340d4-b744-4046-971e-023a4281ea6c	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.637392+00
272bd3ae-3431-4dce-a813-ce7b07197c8b	610340d4-b744-4046-971e-023a4281ea6c	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.638918+00
4ca066d7-00a8-4055-8369-c50077138b04	610340d4-b744-4046-971e-023a4281ea6c	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.641827+00
c4b18b33-b67c-40a9-9bb9-c47c116ae228	610340d4-b744-4046-971e-023a4281ea6c	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.659375+00
b571aa6d-07b7-4c9c-827a-b6734270c598	ae7fadd4-07c4-408c-9a55-f4780cdcd1f0	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.660944+00
bba571d6-24b7-433e-8ba8-70717ba0c18a	ae7fadd4-07c4-408c-9a55-f4780cdcd1f0	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.66268+00
49b62466-1d23-427a-8761-c9d20e55781d	ae7fadd4-07c4-408c-9a55-f4780cdcd1f0	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.681038+00
a1236322-d2fb-4ca7-978c-799ac1d93a7f	ae7fadd4-07c4-408c-9a55-f4780cdcd1f0	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.682473+00
fddb8eb3-cb87-46e2-8ad4-e1c292f67b2b	7dbb9f67-2b06-4c44-b4f6-94b8f4bdaad4	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.684014+00
ceaa7387-c197-499d-8988-f8134029b03c	7dbb9f67-2b06-4c44-b4f6-94b8f4bdaad4	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.699742+00
777d9e67-47a0-4cf0-9df3-d8f0e799d464	7dbb9f67-2b06-4c44-b4f6-94b8f4bdaad4	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.703621+00
7f67b80f-ca02-4e0c-8f06-44e85602aa56	7dbb9f67-2b06-4c44-b4f6-94b8f4bdaad4	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.705344+00
74870617-4657-4055-8e9e-d96ccafe2617	8a7bf4f5-92de-48eb-a2bc-18dae9992013	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.720695+00
c9f4c4d9-634e-4e19-97e7-d4adf1a57a70	8a7bf4f5-92de-48eb-a2bc-18dae9992013	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.722393+00
52985f84-f637-4702-83c8-eafed1023449	8a7bf4f5-92de-48eb-a2bc-18dae9992013	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.725312+00
5bf2f7ea-d6ea-441c-b8b6-d33b69c0fff5	8a7bf4f5-92de-48eb-a2bc-18dae9992013	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.74072+00
893e29be-543c-4fd5-bf37-a18ddf712ea1	df1d7a4b-33db-4bd9-855b-a6d8f97360a1	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.742392+00
a5b161aa-d2a4-4d2d-b592-e563ba3cb8aa	df1d7a4b-33db-4bd9-855b-a6d8f97360a1	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.744027+00
77369a6a-fae4-464a-aee8-26e2ef3e615b	df1d7a4b-33db-4bd9-855b-a6d8f97360a1	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.761124+00
9ce6ee66-a077-4982-b975-5d03dc2ce5fb	df1d7a4b-33db-4bd9-855b-a6d8f97360a1	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.762942+00
a678dfef-1b5a-46ee-ad99-d5120adcd8b4	7cc683f3-2ea9-40dd-94d9-2af83d2723da	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.764868+00
fdf1938e-1c02-46a5-91ca-91666dcce7fc	7cc683f3-2ea9-40dd-94d9-2af83d2723da	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.766704+00
d8303c6d-c3e0-4432-b635-4672eb1081db	7cc683f3-2ea9-40dd-94d9-2af83d2723da	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.783813+00
1ec390c7-a99b-42a4-89be-9a90ffaf2da0	7cc683f3-2ea9-40dd-94d9-2af83d2723da	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.785395+00
ba72bd03-3b4d-4fbe-8822-0c2467b034be	eafc9a41-ffe5-4cce-ac7b-9e7b0e274d8f	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.786941+00
81d1bc06-4437-4aac-be5b-a4c41982cda7	eafc9a41-ffe5-4cce-ac7b-9e7b0e274d8f	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.802289+00
c8cfa1d3-97f4-4a25-b631-8c1236193a4f	eafc9a41-ffe5-4cce-ac7b-9e7b0e274d8f	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.805462+00
bea9872e-746c-4ef3-9aff-1868e1d60336	eafc9a41-ffe5-4cce-ac7b-9e7b0e274d8f	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.807085+00
7888b448-f7ff-4b4c-b471-96704def0212	8c25fe94-99d4-44dd-9652-efe248083bb9	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.822254+00
d15c3647-2463-4be9-81d0-3e06a3a089a2	8c25fe94-99d4-44dd-9652-efe248083bb9	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.82402+00
349a9f25-7c88-42c6-b3c2-1a1386bb9b74	8c25fe94-99d4-44dd-9652-efe248083bb9	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.827432+00
ae3050e5-c886-4fe4-8b39-f6cc1dbe51ee	8c25fe94-99d4-44dd-9652-efe248083bb9	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.842583+00
8e3d4d72-851c-4bfa-926a-04d2c3de5e74	6d85775f-a88d-472b-876c-265b4f483da5	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.908448+00
f2a2aa50-e172-42f9-9a83-fc923c2cd93b	6d85775f-a88d-472b-876c-265b4f483da5	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.910327+00
1cc98fa1-dc8b-457e-8ee8-0a3102f8d11e	6d85775f-a88d-472b-876c-265b4f483da5	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.928917+00
04cce747-d252-44dc-8da0-e0f4137d3fd8	6d85775f-a88d-472b-876c-265b4f483da5	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.931075+00
3e191a2a-cc7f-4690-93ae-d4c309266df6	fd1ab8e1-89e7-49f1-b029-41ed3b1565bd	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.93302+00
6b587a89-fb35-451e-9b02-526f874d18a1	fd1ab8e1-89e7-49f1-b029-41ed3b1565bd	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.934888+00
57e3327c-8ffd-4b4b-8e43-877c8cd1d421	fd1ab8e1-89e7-49f1-b029-41ed3b1565bd	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:06.952135+00
7ca60e89-3558-4997-b213-fa04da00e5f5	fd1ab8e1-89e7-49f1-b029-41ed3b1565bd	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.018015+00
e4182171-6c97-403c-92dd-cc9e06b70862	5cc3bb12-e940-4880-94e6-cfe1427ecfc6	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.034824+00
7e27dc81-9055-4b11-9a61-9b0acbd92d27	5cc3bb12-e940-4880-94e6-cfe1427ecfc6	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.036563+00
eacec7b4-ce58-4f4e-94d9-40d58ff0574d	5cc3bb12-e940-4880-94e6-cfe1427ecfc6	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.039785+00
b7cdbbdb-2f01-4f6b-b01d-49f4f6a5e658	5cc3bb12-e940-4880-94e6-cfe1427ecfc6	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.055989+00
49b9ef17-163d-4e9b-97a4-0a2e9ce9289f	d3b977c5-78be-43bd-b2df-9c6ad004ec64	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.057827+00
66b4e368-1e16-430a-b99f-07d3a7233016	d3b977c5-78be-43bd-b2df-9c6ad004ec64	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.073648+00
e57bc2bb-c9eb-418b-a8e6-ba0cc5a3b829	d3b977c5-78be-43bd-b2df-9c6ad004ec64	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.076688+00
da654baa-4baa-4fb8-a850-aea9043e8be5	d3b977c5-78be-43bd-b2df-9c6ad004ec64	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.093322+00
6caba19f-ac56-4afc-a577-39d2642cd524	39b6b948-b93a-47c0-9d72-bd474ca0b1a9	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.094964+00
f29affd0-2ae5-431e-ae9f-cdcf7fe9f114	39b6b948-b93a-47c0-9d72-bd474ca0b1a9	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.114312+00
60459896-de9b-4f84-83b5-f7a941f9df24	39b6b948-b93a-47c0-9d72-bd474ca0b1a9	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.132098+00
db4c9a79-615b-4526-944a-7bbaebcf7f8d	39b6b948-b93a-47c0-9d72-bd474ca0b1a9	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.133907+00
b2dcd25f-42ef-4301-8f10-1f14f08a94c4	343cd39e-8d18-4812-a6d0-d9f480dc9cb9	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.14949+00
54fb97b6-2320-4051-9a60-e34f5ebf46ee	343cd39e-8d18-4812-a6d0-d9f480dc9cb9	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.151533+00
a3aee609-e3e6-43cc-9e93-c61fcdeb8710	343cd39e-8d18-4812-a6d0-d9f480dc9cb9	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.155184+00
ed8fe03a-f77d-4120-b2a0-f600ca8a49f8	343cd39e-8d18-4812-a6d0-d9f480dc9cb9	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.170111+00
648cb2ec-0090-4cd7-a4c8-fed6feb7a532	ae95da63-ec15-4b11-b142-ff6fdb9a7b03	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.171674+00
a374d8d7-e0fd-429f-834b-fba59ca5656f	ae95da63-ec15-4b11-b142-ff6fdb9a7b03	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.173379+00
aec04fd0-c2c1-43b8-9790-14ef09b8ff4f	ae95da63-ec15-4b11-b142-ff6fdb9a7b03	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.189646+00
3ec13f69-3cc1-485a-8dd7-9b111bf8da7b	ae95da63-ec15-4b11-b142-ff6fdb9a7b03	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.191403+00
2e93ba94-edfb-4a9c-95f3-9037b01a2680	91e5fbf6-b35e-489d-8bec-d77e32facc25	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.19305+00
d4e0abc8-89f8-48af-8d71-01a00ce966ea	91e5fbf6-b35e-489d-8bec-d77e32facc25	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.19441+00
2846e808-845a-4dc6-a36c-708e11f2b0c8	91e5fbf6-b35e-489d-8bec-d77e32facc25	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.211+00
7172da17-30f2-4a9d-afc9-198e7a99b059	91e5fbf6-b35e-489d-8bec-d77e32facc25	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.213468+00
06b14442-9cf9-4bd0-b969-f38dbecb45de	48cc0745-4e5f-4dda-8ff5-07fa61d6eea7	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.215428+00
da4a782e-f04f-4fd5-b851-1057c726e94e	48cc0745-4e5f-4dda-8ff5-07fa61d6eea7	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.230312+00
95f9cba0-143b-45c9-b2b5-654b85cee647	48cc0745-4e5f-4dda-8ff5-07fa61d6eea7	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.23423+00
7c258add-f106-48eb-9353-8f194b3e7efe	48cc0745-4e5f-4dda-8ff5-07fa61d6eea7	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.236004+00
c7238a21-cfc7-4ab8-b1be-ddc0ca38faa9	e940eada-79a1-440e-851e-2dfb9b92b693	436d7827-0da9-42c1-b1bb-8745a68abb54	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.250622+00
229bfc9b-02c5-45d1-8846-8c4e0a86b43e	e940eada-79a1-440e-851e-2dfb9b92b693	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.25236+00
5df8ab00-4ec4-4177-8999-b9eb0fc9870b	e940eada-79a1-440e-851e-2dfb9b92b693	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.271431+00
adc0d506-77ff-47c1-b4b3-07ab84ea9923	e940eada-79a1-440e-851e-2dfb9b92b693	20c634be-77b2-4a73-9f6e-93bedc05b658	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.272993+00
12ebbf88-1d84-4a85-9e4e-15c555d55fe4	df1d7a4b-33db-4bd9-855b-a6d8f97360a1	255ce056-e234-417c-8d6a-db745e4bc729	\N	2026-03-25 01:25:27.112085+00
4313fab9-7558-4042-baf6-bda957f1452a	0381a248-b039-47ca-a591-41c90db7a78d	255ce056-e234-417c-8d6a-db745e4bc729	\N	2026-03-25 01:25:32.432181+00
ee52a419-e6cb-4be7-a05b-822046d1185f	0381a248-b039-47ca-a591-41c90db7a78d	13c4d090-b2db-4397-89d8-025d6588d0c1	\N	2026-03-25 01:25:32.432181+00
03715fdd-9b43-404e-9961-aec8bd84b777	c451eb0a-6299-4de1-8928-fe10fc43c789	54a2e013-7933-4ba6-bff4-eb07adb05f7e	\N	2026-03-25 01:25:35.636011+00
6a8d44e7-8db5-4c0b-ba8a-74734cc5e1d2	c451eb0a-6299-4de1-8928-fe10fc43c789	20c634be-77b2-4a73-9f6e-93bedc05b658	\N	2026-03-25 01:25:35.636011+00
66810787-5957-44c2-a8b7-2f4bd02fda41	9854d7dc-b664-4d8f-af15-348b20920345	255ce056-e234-417c-8d6a-db745e4bc729	\N	2026-03-25 01:25:42.125274+00
ba69509a-479f-4dd7-9cc0-e3f20c6d7099	9854d7dc-b664-4d8f-af15-348b20920345	13c4d090-b2db-4397-89d8-025d6588d0c1	\N	2026-03-25 01:25:42.125274+00
04059568-2cb1-481f-9116-9106ac868ab4	ea762152-a4ba-4f83-b58c-8e8129348e5b	fb4fe76d-c487-4dc4-9de4-69a28896bc93	\N	2026-03-25 01:25:44.945524+00
96b5d223-d632-42b1-b9dd-b452640e5e2b	ea762152-a4ba-4f83-b58c-8e8129348e5b	255ce056-e234-417c-8d6a-db745e4bc729	\N	2026-03-25 01:25:44.945524+00
\.


--
-- Data for Name: employees; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.employees (id, first_name, last_name, is_active, shift_id, team_id, created_at, updated_at) FROM stdin;
e46010de-9a74-432f-92b6-40b9de20be76	Elizabeth	Smith	t	7df01eef-a728-4466-9824-355c6cd4e1fc	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.458757+00	2026-03-22 19:33:36.308062+00
175b1a68-6756-44a3-9810-28d3aa10fda6	James	Smith	t	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.28657+00	2026-03-22 19:33:42.93208+00
60da7298-fdb8-41f4-ba2d-eff14314ac52	Jessica	Smith	t	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.513612+00	2026-03-22 19:33:48.957627+00
631a0690-b2e4-4267-b5cf-3d16d87c264b	Linda	Smith	t	7a06632f-324d-4050-aea1-c8799611ccd0	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.440072+00	2026-03-22 19:34:08.261564+00
10b8fd36-5de5-42ad-8c4a-a8a4494274ad	Mary	Smith	t	7a06632f-324d-4050-aea1-c8799611ccd0	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.30738+00	2026-03-22 19:34:15.198452+00
0c3290ed-2e07-4bb2-aee3-c89339f6914f	Michael	Smith	t	7a06632f-324d-4050-aea1-c8799611ccd0	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.438316+00	2026-03-22 19:34:21.766453+00
a4b4e8b3-39d4-486f-917b-cbdf54b204a3	Patricia	Smith	t	7a06632f-324d-4050-aea1-c8799611ccd0	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.326452+00	2026-03-22 19:34:26.33439+00
ed254dbb-5433-4617-9a20-f642fada5d3c	John	Smith	t	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.309534+00	2026-03-22 15:24:04.309534+00
1b11d981-a65d-46bd-8220-700df1acf99f	Jennifer	Smith	t	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.421217+00	2026-03-22 15:24:04.421217+00
d3c6f53f-7209-4221-920c-bdc821b92372	Richard	Smith	t	7a06632f-324d-4050-aea1-c8799611ccd0	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.492269+00	2026-03-22 19:34:29.474452+00
8c870a0e-09ee-4f8d-9fa4-df771f36c4af	David	Smith	t	7df01eef-a728-4466-9824-355c6cd4e1fc	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.474711+00	2026-03-22 15:24:04.474711+00
6e680af6-049c-46f4-8a65-c76c50d29453	Robert	Smith	t	7a06632f-324d-4050-aea1-c8799611ccd0	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.402907+00	2026-03-22 19:34:33.494408+00
7892a694-bf37-41fa-b2ba-64f69230f4e4	Joseph	Smith	t	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.511747+00	2026-03-22 15:24:04.511747+00
ea762152-a4ba-4f83-b58c-8e8129348e5b	Barbara	Smith	t	ffc7f49a-1e41-47e2-ad3a-564571bd648a	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.476708+00	2026-03-22 19:33:12.081887+00
6ffdd3d6-ab8e-4a24-bc27-25d51cbf0265	Susan	Smith	t	7a06632f-324d-4050-aea1-c8799611ccd0	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.494139+00	2026-03-22 19:34:40.526458+00
3f8de0d0-ef55-4067-ad87-a7310b3cdaf5	William	Smith	t	b1726a36-4a64-4552-a7e2-1def20917c9b	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.456447+00	2026-03-22 19:34:45.614532+00
0381a248-b039-47ca-a591-41c90db7a78d	Xai	Lor	t	7df01eef-a728-4466-9824-355c6cd4e1fc	\N	2026-03-24 21:50:08.843304+00	2026-04-12 14:44:43.778545+00
86772cf3-dfaa-4db2-9d2d-e2bdb4241d6c	Kang	Yang	t	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	\N	2026-03-24 21:50:56.827904+00	2026-04-12 14:45:18.746754+00
9b8c599c-b1ae-4a02-b2e2-eae82615b1c5	Ger	Thao	t	7a06632f-324d-4050-aea1-c8799611ccd0	\N	2026-03-24 21:50:33.163221+00	2026-04-12 14:45:21.811052+00
83ec0c51-d0aa-4a2b-95b4-155b87738cb4	John	Htoo	t	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	\N	2026-03-24 21:50:20.368657+00	2026-04-12 14:51:36.25718+00
0328b5d2-f6e5-43e9-912e-d775bb7ea114	Allen	Hang	t	7a06632f-324d-4050-aea1-c8799611ccd0	\N	2026-04-12 14:51:51.299349+00	2026-04-12 14:53:30.53189+00
c451eb0a-6299-4de1-8928-fe10fc43c789	Thomond	Obrien	t	7a06632f-324d-4050-aea1-c8799611ccd0	\N	2026-03-22 13:12:57.101474+00	2026-03-22 14:00:35.611131+00
e506fe75-0df4-48ea-ac85-17b42f896982	Daniel	Smith	t	7df01eef-a728-4466-9824-355c6cd4e1fc	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.586285+00	2026-03-22 15:24:04.586285+00
39b6b948-b93a-47c0-9d72-bd474ca0b1a9	Brian	Smith	t	ffc7f49a-1e41-47e2-ad3a-564571bd648a	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.776594+00	2026-03-22 19:33:19.167999+00
fd1ab8e1-89e7-49f1-b029-41ed3b1565bd	Carol	Smith	t	7df01eef-a728-4466-9824-355c6cd4e1fc	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.755714+00	2026-03-22 19:33:21.476032+00
05a758ae-a3b8-401f-a768-a948669f601b	Charles	Smith	t	7df01eef-a728-4466-9824-355c6cd4e1fc	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.548499+00	2026-03-22 19:33:23.068123+00
9c7a22c6-f3ee-4fe2-9955-26c400fd0ace	Christopher	Smith	t	7df01eef-a728-4466-9824-355c6cd4e1fc	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.567618+00	2026-03-22 19:33:24.936013+00
7cc683f3-2ea9-40dd-94d9-2af83d2723da	Donna	Smith	t	7df01eef-a728-4466-9824-355c6cd4e1fc	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.717143+00	2026-03-22 15:24:04.717143+00
eafc9a41-ffe5-4cce-ac7b-9e7b0e274d8f	Joshua	Smith	t	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.718686+00	2026-03-22 15:24:04.718686+00
5f926628-1321-410f-835a-a1701355219d	Donald	Smith	t	7df01eef-a728-4466-9824-355c6cd4e1fc	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.646228+00	2026-03-22 19:33:29.788024+00
e940eada-79a1-440e-851e-2dfb9b92b693	Deborah	Smith	t	7df01eef-a728-4466-9824-355c6cd4e1fc	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.829144+00	2026-03-22 15:24:04.829144+00
343cd39e-8d18-4812-a6d0-d9f480dc9cb9	Dorothy	Smith	t	7df01eef-a728-4466-9824-355c6cd4e1fc	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.793385+00	2026-03-22 19:33:34.243993+00
d3b977c5-78be-43bd-b2df-9c6ad004ec64	ERIC	JONES	t	ffc7f49a-1e41-47e2-ad3a-564571bd648a	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.774171+00	2026-03-22 19:29:23.17163+00
8a7bf4f5-92de-48eb-a2bc-18dae9992013	Emily	Smith	t	7df01eef-a728-4466-9824-355c6cd4e1fc	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.698487+00	2026-03-22 19:33:39.092066+00
df1d7a4b-33db-4bd9-855b-a6d8f97360a1	Max	Kangas	t	7a06632f-324d-4050-aea1-c8799611ccd0	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.700343+00	2026-03-22 19:29:44.779624+00
9854d7dc-b664-4d8f-af15-348b20920345	Ashley	Smith	t	ffc7f49a-1e41-47e2-ad3a-564571bd648a	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.66281+00	2026-03-22 19:33:09.686712+00
6d1605d8-2318-40ad-b5a9-03feab324fd2	Betty	Smith	t	ffc7f49a-1e41-47e2-ad3a-564571bd648a	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.607266+00	2026-03-22 19:33:15.292049+00
ae95da63-ec15-4b11-b142-ff6fdb9a7b03	George	Smith	t	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.795186+00	2026-03-22 19:33:41.484026+00
5e44115d-118e-4dd5-80c6-30b0bc1260dd	Karen	Smith	t	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.550523+00	2026-03-22 19:33:59.587507+00
6d85775f-a88d-472b-876c-265b4f483da5	Kenneth	Smith	t	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.739186+00	2026-03-22 19:34:01.569623+00
5cc3bb12-e940-4880-94e6-cfe1427ecfc6	Kevin	Smith	t	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.757517+00	2026-03-22 19:34:03.645603+00
ae7fadd4-07c4-408c-9a55-f4780cdcd1f0	Kimberly	Smith	t	7a06632f-324d-4050-aea1-c8799611ccd0	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.68126+00	2026-03-22 19:34:06.657653+00
fda9b996-4df4-4ab4-bf71-2de86e81ea52	Lisa	Smith	t	7a06632f-324d-4050-aea1-c8799611ccd0	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.569489+00	2026-03-22 19:34:09.829704+00
58119498-aa74-4a50-b937-ef362d96849e	Margaret	Smith	t	7a06632f-324d-4050-aea1-c8799611ccd0	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.625846+00	2026-03-22 19:34:11.681639+00
6a5611b1-a04b-43d0-8c35-a810d393a0aa	Mark	Smith	t	7a06632f-324d-4050-aea1-c8799611ccd0	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.62782+00	2026-03-22 19:34:13.505623+00
30b6df55-a118-4b1b-8df1-c5663a701ed2	Matthew	Smith	t	7a06632f-324d-4050-aea1-c8799611ccd0	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.604933+00	2026-03-22 19:34:17.982437+00
91e5fbf6-b35e-489d-8bec-d77e32facc25	Melissa	Smith	t	7a06632f-324d-4050-aea1-c8799611ccd0	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.811658+00	2026-03-22 19:34:20.365103+00
8c25fe94-99d4-44dd-9652-efe248083bb9	Michelle	Smith	t	7a06632f-324d-4050-aea1-c8799611ccd0	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.737515+00	2026-03-22 19:34:23.334427+00
14e6a58a-9286-479d-af56-fb4f1cc680dc	Nancy	Smith	t	7a06632f-324d-4050-aea1-c8799611ccd0	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.588074+00	2026-03-22 19:34:24.566426+00
7dbb9f67-2b06-4c44-b4f6-94b8f4bdaad4	Paul	Smith	t	7a06632f-324d-4050-aea1-c8799611ccd0	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.683124+00	2026-03-22 19:34:28.192025+00
7cc81d84-5d1b-42d9-820b-5f99c9dc2ed3	Sandra	Smith	t	7a06632f-324d-4050-aea1-c8799611ccd0	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.644369+00	2026-03-22 19:34:35.142455+00
740ee69c-06c1-4a3b-a75c-19ab454b2775	Sarah	Smith	t	7a06632f-324d-4050-aea1-c8799611ccd0	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.531975+00	2026-03-22 19:34:36.886466+00
610340d4-b744-4046-971e-023a4281ea6c	Steven	Smith	t	7a06632f-324d-4050-aea1-c8799611ccd0	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.664637+00	2026-03-22 19:34:39.190433+00
0a6c1e7d-b777-49a7-8a55-a85e63979d98	Thomas	Smith	t	b1726a36-4a64-4552-a7e2-1def20917c9b	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.529575+00	2026-03-22 19:34:42.538422+00
48cc0745-4e5f-4dda-8ff5-07fa61d6eea7	Timothy	Smith	t	b1726a36-4a64-4552-a7e2-1def20917c9b	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.813889+00	2026-03-22 19:34:43.983122+00
4e252744-9763-44d4-b1f5-51affb91f884	Hayley	Williams	t	b1726a36-4a64-4552-a7e2-1def20917c9b	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:04.609266+00	2026-03-22 19:34:47.734444+00
5d89f5b8-1d05-487b-946b-8708e0290a8f	mikey	b	t	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	\N	2026-04-12 17:30:10.246837+00	2026-04-12 17:30:22.807915+00
4d24bf6a-dfc4-46a4-a41d-ecb6e8ad6be4	mikey jj	jj	t	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	\N	2026-04-12 17:30:49.608729+00	2026-04-12 17:30:58.974882+00
\.


--
-- Data for Name: job_functions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.job_functions (id, name, color_code, productivity_rate, is_active, sort_order, unit_of_measure, custom_unit, created_at, updated_at, team_id, exclude_from_targets, lunch_coverage_required, break_coverage_required) FROM stdin;
13c4d090-b2db-4397-89d8-025d6588d0c1	Help desk	#d13353	\N	t	5			2026-03-22 13:57:51.380212+00	2026-03-22 13:57:51.380212+00	\N	f	f	f
fb4fe76d-c487-4dc4-9de4-69a28896bc93	DG Pick	#516381	\N	t	6			2026-03-22 13:58:04.339478+00	2026-03-22 13:58:04.339478+00	\N	f	f	f
6e5485ae-fd39-4945-bbbe-5a59ee96dadf	Runner	#1b7948	\N	t	7			2026-03-22 13:58:22.849772+00	2026-03-22 13:58:29.139282+00	\N	f	f	f
cc5561bb-cc4e-4829-bfad-ea93aae576ed	speedcell	#c5f73b	\N	t	8			2026-03-22 13:58:44.104413+00	2026-03-22 13:58:44.104413+00	\N	f	f	f
9a8a5181-bdc8-4431-9a0a-14f52be82896	startup	#bf09d7	\N	t	9			2026-03-22 13:58:59.902394+00	2026-03-22 13:58:59.902394+00	\N	f	f	f
eecdcfc1-afe3-4fea-b614-8a121ba07575	DG	#6df73b	\N	t	10			2026-03-22 13:59:16.912563+00	2026-03-22 13:59:16.912563+00	\N	f	f	f
931a427a-ae31-4c47-a234-0345209e2b31	RT-pick	#f73ba9	\N	t	13			2026-03-22 14:22:06.095535+00	2026-03-22 14:22:06.095535+00	\N	f	f	f
436d7827-0da9-42c1-b1bb-8745a68abb54	Locus	#FFD700	30	t	0	orders/hour	\N	2026-03-22 15:24:04.17793+00	2026-03-22 15:24:04.17793+00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	f	f	f
f149d680-6b63-40cf-9b1c-5e9d97096f1c	Pick	#FFFF00	55	t	1	cartons/hour	\N	2026-03-22 15:24:04.214271+00	2026-03-22 15:24:04.214271+00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	f	f	f
54a2e013-7933-4ba6-bff4-eb07adb05f7e	X4	#3B82F6	50	t	2	cases/hour	\N	2026-03-22 15:24:04.230939+00	2026-03-22 15:24:04.230939+00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	f	f	f
20c634be-77b2-4a73-9f6e-93bedc05b658	EM9	#10B981	45	t	3	units/hour	\N	2026-03-22 15:24:04.233217+00	2026-03-22 15:24:04.233217+00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	f	f	f
f91d0839-8da7-4d33-bec1-7b6563b445ad	Projects	#8a638c	\N	t	35			2026-04-12 14:49:16.97936+00	2026-04-12 14:49:16.97936+00	\N	f	f	f
255ce056-e234-417c-8d6a-db745e4bc729	TL	#1db9ed	\N	t	11			2026-03-22 13:59:53.403795+00	2026-04-12 16:54:59.487496+00	\N	t	f	f
f01032bd-4de9-40ff-953c-d8a2ddc937f5	coordinator	#25f8ea	\N	t	12			2026-03-22 14:00:06.977986+00	2026-04-12 16:55:04.676043+00	\N	t	f	f
507ff8a9-edd9-460a-af98-5d583676d2d2	Conveyor	#47679a	\N	t	14			2026-06-08 00:01:02.958655+00	2026-06-08 00:01:02.958655+00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	f	f	f
\.


--
-- Data for Name: password_reset_tokens; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.password_reset_tokens (id, user_id, token_hash, expires_at, used_at, created_at) FROM stdin;
\.


--
-- Data for Name: preferred_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.preferred_assignments (id, employee_id, job_function_id, is_required, priority, notes, team_id, created_at, updated_at, am_job_function_id, pm_job_function_id) FROM stdin;
58eb07e3-844c-488d-8524-97b8fff586f2	d3b977c5-78be-43bd-b2df-9c6ad004ec64	f01032bd-4de9-40ff-953c-d8a2ddc937f5	t	0		\N	2026-03-22 22:07:10.718104+00	2026-03-22 22:07:10.718104+00	\N	\N
afb71691-8ffd-4f0f-969b-a283dd4b0dcf	c451eb0a-6299-4de1-8928-fe10fc43c789	255ce056-e234-417c-8d6a-db745e4bc729	t	0		\N	2026-03-22 22:07:21.267796+00	2026-03-22 22:07:21.267796+00	\N	\N
6da20d63-96a4-43a6-8a76-fae4294cdaca	4e252744-9763-44d4-b1f5-51affb91f884	f01032bd-4de9-40ff-953c-d8a2ddc937f5	t	0		\N	2026-03-22 22:07:39.072018+00	2026-03-22 22:07:39.072018+00	\N	\N
5759eabe-34ba-4efc-83f2-42cbdeabbfc1	0381a248-b039-47ca-a591-41c90db7a78d	20c634be-77b2-4a73-9f6e-93bedc05b658	t	0		\N	2026-03-24 21:54:04.646153+00	2026-04-12 16:52:33.141067+00	20c634be-77b2-4a73-9f6e-93bedc05b658	54a2e013-7933-4ba6-bff4-eb07adb05f7e
4b40759f-7c26-4fc5-b122-9529aea7c73b	9b8c599c-b1ae-4a02-b2e2-eae82615b1c5	20c634be-77b2-4a73-9f6e-93bedc05b658	t	0		\N	2026-03-24 21:54:31.831356+00	2026-04-12 16:52:43.286975+00	20c634be-77b2-4a73-9f6e-93bedc05b658	54a2e013-7933-4ba6-bff4-eb07adb05f7e
f3d72478-50cc-4c1e-aa9a-0abe5d032cde	86772cf3-dfaa-4db2-9d2d-e2bdb4241d6c	54a2e013-7933-4ba6-bff4-eb07adb05f7e	t	0		\N	2026-03-24 21:54:19.938124+00	2026-04-12 16:52:52.470362+00	54a2e013-7933-4ba6-bff4-eb07adb05f7e	20c634be-77b2-4a73-9f6e-93bedc05b658
5dde5929-72f1-46e0-881a-14565bd1053f	83ec0c51-d0aa-4a2b-95b4-155b87738cb4	54a2e013-7933-4ba6-bff4-eb07adb05f7e	t	0		\N	2026-03-24 21:55:09.3736+00	2026-04-12 16:52:59.996878+00	54a2e013-7933-4ba6-bff4-eb07adb05f7e	20c634be-77b2-4a73-9f6e-93bedc05b658
3544d3a3-469c-4474-84fc-d4c391c38c75	0328b5d2-f6e5-43e9-912e-d775bb7ea114	54a2e013-7933-4ba6-bff4-eb07adb05f7e	t	0		\N	2026-04-12 16:54:38.305727+00	2026-04-12 16:54:38.305727+00	54a2e013-7933-4ba6-bff4-eb07adb05f7e	54a2e013-7933-4ba6-bff4-eb07adb05f7e
\.


--
-- Data for Name: pto_days; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.pto_days (id, employee_id, pto_date, start_time, end_time, pto_type, notes, team_id, created_at) FROM stdin;
0320354b-b216-4e26-8a2a-557f240d45bf	fd1ab8e1-89e7-49f1-b029-41ed3b1565bd	2026-03-21	\N	\N	\N	\N	\N	2026-03-22 21:15:44.879558+00
c00cf3af-b401-4197-a33e-b2f2e6ac9f0c	8c870a0e-09ee-4f8d-9fa4-df771f36c4af	2026-03-26	\N	\N	\N	\N	\N	2026-03-24 22:37:39.790788+00
a87549a1-61f3-4f44-8bb4-c76329cc1cd0	5f926628-1321-410f-835a-a1701355219d	2026-03-26	\N	\N	\N	\N	\N	2026-03-24 22:37:56.540268+00
74ef6c0e-fbfc-4279-a026-ca15f9925a6a	df1d7a4b-33db-4bd9-855b-a6d8f97360a1	2026-03-27	\N	\N	full_day	Auto-approved request	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-25 22:38:09.289687+00
19c27290-bee9-4751-9fbf-f22438b25d4d	c451eb0a-6299-4de1-8928-fe10fc43c789	2026-03-27	\N	\N	full_day	Auto-approved request	\N	2026-03-25 22:40:58.773859+00
e2c06695-7cb7-4ab0-8bf4-212ae8ed32d6	df1d7a4b-33db-4bd9-855b-a6d8f97360a1	2026-04-15	\N	\N	full_day	use pst	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-04-12 16:49:20.712049+00
3e9ec585-9741-4e3e-b401-1197b17a25dd	0381a248-b039-47ca-a591-41c90db7a78d	2026-04-14	08:00:00	10:00:00	partial	Auto-approved request	\N	2026-04-12 19:02:50.03053+00
7588db8f-9a40-49d0-b12c-783118ad67a6	7cc683f3-2ea9-40dd-94d9-2af83d2723da	2026-04-15	\N	\N	full_day	Auto-approved request	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-04-12 21:32:13.545441+00
5b9711fc-300e-419f-9bff-e5ba5542c967	7cc683f3-2ea9-40dd-94d9-2af83d2723da	2026-04-12	\N	\N	\N	\N	\N	2026-04-12 21:50:19.088245+00
\.


--
-- Data for Name: schedule_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.schedule_assignments (id, employee_id, job_function_id, shift_id, schedule_date, assignment_order, start_time, end_time, team_id, created_at, updated_at) FROM stdin;
a8ce9627-1ae7-4e7a-97eb-886b42d24b60	0328b5d2-f6e5-43e9-912e-d775bb7ea114	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-15	1	12:00:00	16:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
639f4d5c-627b-47e4-8363-76aa6c566ae0	0328b5d2-f6e5-43e9-912e-d775bb7ea114	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-15	1	16:30:00	20:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
d33db7ad-0d9d-4a0f-b5bd-08d0eb705610	83ec0c51-d0aa-4a2b-95b4-155b87738cb4	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-15	1	10:00:00	14:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
1ec7f453-a5aa-48aa-bacd-d4c3c0a3826e	83ec0c51-d0aa-4a2b-95b4-155b87738cb4	20c634be-77b2-4a73-9f6e-93bedc05b658	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-15	1	14:30:00	18:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
4ca11706-22d9-42b6-bf71-29decde4f2ed	d3b977c5-78be-43bd-b2df-9c6ad004ec64	f01032bd-4de9-40ff-953c-d8a2ddc937f5	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-15	1	06:00:00	12:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
53e4f51f-a2b3-4dbf-a954-ced5d11fee99	d3b977c5-78be-43bd-b2df-9c6ad004ec64	f01032bd-4de9-40ff-953c-d8a2ddc937f5	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-15	1	13:00:00	14:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
97fc675d-3480-4d66-ba94-341b3c93d151	0381a248-b039-47ca-a591-41c90db7a78d	20c634be-77b2-4a73-9f6e-93bedc05b658	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-15	1	08:00:00	12:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
ae9be0b2-8a23-4caf-9d1d-601fe9bd58df	0381a248-b039-47ca-a591-41c90db7a78d	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-15	1	13:00:00	16:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
1b3c0a73-b948-48d6-bf1c-552a65d58d86	c451eb0a-6299-4de1-8928-fe10fc43c789	255ce056-e234-417c-8d6a-db745e4bc729	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-15	1	12:00:00	16:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
41044344-1957-4287-b58e-a17a5ed77527	c451eb0a-6299-4de1-8928-fe10fc43c789	255ce056-e234-417c-8d6a-db745e4bc729	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-15	1	16:30:00	20:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
c07dd30a-117b-4ee0-9645-2113f43a4d77	9b8c599c-b1ae-4a02-b2e2-eae82615b1c5	20c634be-77b2-4a73-9f6e-93bedc05b658	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-15	1	12:00:00	16:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
4c42f5cd-8f64-45bb-ae27-96c9316bd3cb	9b8c599c-b1ae-4a02-b2e2-eae82615b1c5	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-15	1	16:30:00	20:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
56b65345-8e5d-4daa-9c30-4c287151605e	4e252744-9763-44d4-b1f5-51affb91f884	f01032bd-4de9-40ff-953c-d8a2ddc937f5	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-15	1	16:00:00	20:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
90147c06-f0b5-4c42-80fb-ed640727ce25	86772cf3-dfaa-4db2-9d2d-e2bdb4241d6c	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-15	1	10:00:00	14:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
4eccdde8-7c7a-42fa-b67f-7bff16a577cb	86772cf3-dfaa-4db2-9d2d-e2bdb4241d6c	20c634be-77b2-4a73-9f6e-93bedc05b658	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-15	1	14:30:00	18:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
0bdfa6a5-c975-4a60-b218-e72bee14313c	3f8de0d0-ef55-4067-ad87-a7310b3cdaf5	f149d680-6b63-40cf-9b1c-5e9d97096f1c	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-15	1	16:00:00	20:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
cf8caeb2-233e-4453-8680-3db29cc661f0	0a6c1e7d-b777-49a7-8a55-a85e63979d98	436d7827-0da9-42c1-b1bb-8745a68abb54	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-15	1	16:00:00	19:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
9d6052e3-0997-4b36-a27e-2ae0179f696e	0a6c1e7d-b777-49a7-8a55-a85e63979d98	eecdcfc1-afe3-4fea-b614-8a121ba07575	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-15	1	19:00:00	20:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
62de3b90-956d-420c-8f74-fd4e6b878f00	d3b977c5-78be-43bd-b2df-9c6ad004ec64	f01032bd-4de9-40ff-953c-d8a2ddc937f5	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-03-22	1	06:00:00	14:30:00	\N	2026-03-22 21:27:37.739847+00	2026-03-22 21:27:37.739847+00
d9c8547e-098a-4d74-830a-e57151e00fa1	0328b5d2-f6e5-43e9-912e-d775bb7ea114	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	12:00:00	13:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
fac38d92-737a-4b77-953c-9a1cdb210fb7	9854d7dc-b664-4d8f-af15-348b20920345	f149d680-6b63-40cf-9b1c-5e9d97096f1c	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-03-22	1	10:00:00	14:30:00	\N	2026-03-22 21:27:37.739847+00	2026-03-22 21:27:37.739847+00
f299f2d2-4c6f-4418-b590-34ec2e458c6e	ea762152-a4ba-4f83-b58c-8e8129348e5b	54a2e013-7933-4ba6-bff4-eb07adb05f7e	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-03-22	1	06:00:00	10:00:00	\N	2026-03-22 21:27:37.739847+00	2026-03-22 21:27:37.739847+00
3ae5f179-f470-4e8c-899c-9c801ddd0e7a	ea762152-a4ba-4f83-b58c-8e8129348e5b	9a8a5181-bdc8-4431-9a0a-14f52be82896	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-03-22	1	10:00:00	14:30:00	\N	2026-03-22 21:27:37.739847+00	2026-03-22 21:27:37.739847+00
26d1fdef-5341-4b28-8e7c-09df78367151	0328b5d2-f6e5-43e9-912e-d775bb7ea114	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	14:00:00	16:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
0ad3f5ae-127e-4437-adcd-5683cff290fb	6d1605d8-2318-40ad-b5a9-03feab324fd2	436d7827-0da9-42c1-b1bb-8745a68abb54	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-03-22	1	10:00:00	14:30:00	\N	2026-03-22 21:27:37.739847+00	2026-03-22 21:27:37.739847+00
f33dc0ed-867d-4b4c-bf80-40a380488e91	48cc0745-4e5f-4dda-8ff5-07fa61d6eea7	436d7827-0da9-42c1-b1bb-8745a68abb54	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-15	1	16:00:00	19:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
a23a9840-2e4b-4487-9803-d4ae058a6989	0328b5d2-f6e5-43e9-912e-d775bb7ea114	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	16:30:00	19:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
4f99831a-04f3-4522-8c9c-68e5e478e3a0	48cc0745-4e5f-4dda-8ff5-07fa61d6eea7	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-15	1	19:00:00	20:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
33dd6904-2a7c-4350-9b1c-5b167998e58a	fd1ab8e1-89e7-49f1-b029-41ed3b1565bd	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-15	1	13:00:00	16:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
0edae582-8be1-4738-a5ff-cf597781378d	fd1ab8e1-89e7-49f1-b029-41ed3b1565bd	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-15	1	08:00:00	12:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
583243cb-0856-4e15-ab90-91c11fadc1e5	e940eada-79a1-440e-851e-2dfb9b92b693	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-15	1	13:00:00	16:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
c04652a1-cd73-4ebd-9dec-89a817ac9d6b	e940eada-79a1-440e-851e-2dfb9b92b693	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-15	1	08:00:00	12:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
ef852a15-152c-4c43-939c-119be6d9f880	5f926628-1321-410f-835a-a1701355219d	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-15	1	13:00:00	16:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
b13669c2-dfbf-4566-8a81-a32578e891f3	5f926628-1321-410f-835a-a1701355219d	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-15	1	08:00:00	12:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
6c43dc5e-d2b3-44d7-a8a6-4e52bdb58c61	343cd39e-8d18-4812-a6d0-d9f480dc9cb9	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-15	1	13:00:00	16:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
52e13ad6-5c5f-400c-b5fb-86d8d42d73a6	343cd39e-8d18-4812-a6d0-d9f480dc9cb9	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-15	1	10:00:00	12:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
19008417-f9cc-4e96-8c76-1d7c658f4814	343cd39e-8d18-4812-a6d0-d9f480dc9cb9	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-15	1	08:00:00	10:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
aa399d9d-e314-4a73-9851-fb209f4f1d7c	8a7bf4f5-92de-48eb-a2bc-18dae9992013	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-15	1	13:00:00	16:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
c7d3911f-9497-4013-9ee0-b4033dfc9e82	0328b5d2-f6e5-43e9-912e-d775bb7ea114	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	19:15:00	20:30:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
1509f471-a6e6-4d79-855c-d1aab6f55222	6d1605d8-2318-40ad-b5a9-03feab324fd2	9a8a5181-bdc8-4431-9a0a-14f52be82896	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-15	1	06:00:00	08:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
cde93812-e5a5-40f8-b4dd-912505c669b4	6d1605d8-2318-40ad-b5a9-03feab324fd2	436d7827-0da9-42c1-b1bb-8745a68abb54	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-15	1	13:00:00	14:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
c8d145af-8fa2-4c9c-af92-8acd620c1b7a	6d1605d8-2318-40ad-b5a9-03feab324fd2	f149d680-6b63-40cf-9b1c-5e9d97096f1c	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-15	1	10:00:00	12:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
597b3606-9ff3-4eca-ac5d-0f74c844c3ff	6d1605d8-2318-40ad-b5a9-03feab324fd2	436d7827-0da9-42c1-b1bb-8745a68abb54	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-15	1	08:00:00	09:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
7b2ce428-5a8b-42a6-9cac-bf261226f313	83ec0c51-d0aa-4a2b-95b4-155b87738cb4	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-06-08	1	10:00:00	11:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
38e8bbf9-72a9-4b83-bb48-880b265b9e4c	1b11d981-a65d-46bd-8220-700df1acf99f	436d7827-0da9-42c1-b1bb-8745a68abb54	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-15	1	14:30:00	18:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
1443a975-b90d-424d-b080-8b56fca35f28	1b11d981-a65d-46bd-8220-700df1acf99f	436d7827-0da9-42c1-b1bb-8745a68abb54	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-15	1	10:00:00	14:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
28bb277c-7f9d-49ee-aae0-bd0aae014c91	6d85775f-a88d-472b-876c-265b4f483da5	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-15	1	14:30:00	18:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
a273a33c-57f3-4b23-9ea9-cef005782876	6d85775f-a88d-472b-876c-265b4f483da5	20c634be-77b2-4a73-9f6e-93bedc05b658	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-15	1	10:00:00	14:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
ce214f97-4f88-45bf-a069-f825e6d00ed1	631a0690-b2e4-4267-b5cf-3d16d87c264b	436d7827-0da9-42c1-b1bb-8745a68abb54	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-15	1	12:00:00	16:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
b46a0f1d-cfd3-48bf-96cb-b440dc3ce01b	83ec0c51-d0aa-4a2b-95b4-155b87738cb4	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-06-08	1	12:00:00	14:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
bb1c6d96-55ee-42c4-a341-44a56d2aa632	fda9b996-4df4-4ab4-bf71-2de86e81ea52	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-15	1	12:00:00	16:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
204f2671-d654-4ad8-82ac-e58437bcf6b4	83ec0c51-d0aa-4a2b-95b4-155b87738cb4	20c634be-77b2-4a73-9f6e-93bedc05b658	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-06-08	1	14:30:00	16:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
f0e6cc9e-3af4-4c9d-9a5a-89a92182c58e	83ec0c51-d0aa-4a2b-95b4-155b87738cb4	20c634be-77b2-4a73-9f6e-93bedc05b658	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-06-08	1	17:00:00	18:30:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
1a324256-5d30-4ad9-bfce-ad91f15ec995	ae7fadd4-07c4-408c-9a55-f4780cdcd1f0	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-15	1	12:00:00	16:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
b942ca8e-7868-4edb-94cb-231976e87856	ae7fadd4-07c4-408c-9a55-f4780cdcd1f0	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-15	1	16:30:00	20:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
31d31d59-8e13-43fd-bc01-307152aeed25	6a5611b1-a04b-43d0-8c35-a810d393a0aa	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-15	1	12:00:00	16:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
4694226e-24c3-467c-bb3a-f626e11bdcfc	6a5611b1-a04b-43d0-8c35-a810d393a0aa	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-15	1	16:30:00	19:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
8d33db72-9228-486b-afc4-a1c9e9941d93	d3b977c5-78be-43bd-b2df-9c6ad004ec64	f01032bd-4de9-40ff-953c-d8a2ddc937f5	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-06-08	1	06:00:00	07:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
cc47c5c1-88d3-4e3b-bfa7-3dcf3de13bb6	30b6df55-a118-4b1b-8df1-c5663a701ed2	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-15	1	12:00:00	16:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
7d1ce8b0-d2b6-4dd0-9999-44789d477a2f	30b6df55-a118-4b1b-8df1-c5663a701ed2	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-15	1	16:30:00	19:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
627dd38f-6882-4424-8648-801ad98f8762	d3b977c5-78be-43bd-b2df-9c6ad004ec64	f01032bd-4de9-40ff-953c-d8a2ddc937f5	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-06-08	1	08:00:00	09:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
d85d2f50-ed0a-4f0a-8de1-92f3860c47fb	d3b977c5-78be-43bd-b2df-9c6ad004ec64	f01032bd-4de9-40ff-953c-d8a2ddc937f5	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-06-08	1	10:00:00	12:30:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
a9b94f1d-cac3-4b5f-9727-279bda5653d4	91e5fbf6-b35e-489d-8bec-d77e32facc25	fb4fe76d-c487-4dc4-9de4-69a28896bc93	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-15	1	12:00:00	16:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
10754373-0224-44ee-b035-34f206a15032	7dbb9f67-2b06-4c44-b4f6-94b8f4bdaad4	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-15	1	12:00:00	16:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
077a7b6f-9587-484a-9e48-718f6ba91e4f	7dbb9f67-2b06-4c44-b4f6-94b8f4bdaad4	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-15	1	16:30:00	20:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
054e8128-67d2-452c-bf97-fb232be358c6	d3b977c5-78be-43bd-b2df-9c6ad004ec64	f01032bd-4de9-40ff-953c-d8a2ddc937f5	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-06-08	1	13:00:00	14:30:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
1146d71d-f9b9-4fd8-bf1f-0656c66584fe	0381a248-b039-47ca-a591-41c90db7a78d	20c634be-77b2-4a73-9f6e-93bedc05b658	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-06-08	1	08:00:00	09:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
7face7d4-8d4c-4516-910e-5faa9a1d143d	0381a248-b039-47ca-a591-41c90db7a78d	20c634be-77b2-4a73-9f6e-93bedc05b658	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-06-08	1	10:00:00	12:30:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
567d925a-5414-41e7-9bb3-346e20fa8328	9c7a22c6-f3ee-4fe2-9955-26c400fd0ace	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-03-24	1	08:00:00	18:30:00	\N	2026-03-24 22:37:08.300564+00	2026-03-24 22:37:08.300564+00
25a3c2a5-721a-4d58-934b-64db8252186a	0381a248-b039-47ca-a591-41c90db7a78d	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-06-08	1	13:00:00	14:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
d0bd49fd-91d7-485a-a844-916cd9ac112e	9c7a22c6-f3ee-4fe2-9955-26c400fd0ace	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-03-26	1	08:00:00	18:30:00	\N	2026-03-24 22:37:26.971612+00	2026-03-24 22:37:26.971612+00
3c4e69f2-65ac-484e-95f3-3dfd634cfd32	df1d7a4b-33db-4bd9-855b-a6d8f97360a1	436d7827-0da9-42c1-b1bb-8745a68abb54	7a06632f-324d-4050-aea1-c8799611ccd0	2026-03-25	1	08:00:00	12:00:00	\N	2026-03-25 10:01:54.368107+00	2026-03-25 10:01:54.368107+00
401df916-c6b5-4724-ac24-a76748aacb97	df1d7a4b-33db-4bd9-855b-a6d8f97360a1	436d7827-0da9-42c1-b1bb-8745a68abb54	7a06632f-324d-4050-aea1-c8799611ccd0	2026-03-25	1	13:00:00	19:00:00	\N	2026-03-25 10:01:54.368107+00	2026-03-25 10:01:54.368107+00
96ada98d-9f7d-4ded-abcd-456c28bad230	9854d7dc-b664-4d8f-af15-348b20920345	436d7827-0da9-42c1-b1bb-8745a68abb54	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-03-25	1	08:00:00	09:00:00	\N	2026-03-25 10:01:54.368107+00	2026-03-25 10:01:54.368107+00
e5f27ccf-f351-46bf-b60c-68d8dd193fc8	9854d7dc-b664-4d8f-af15-348b20920345	f149d680-6b63-40cf-9b1c-5e9d97096f1c	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-03-25	1	10:00:00	12:00:00	\N	2026-03-25 10:01:54.368107+00	2026-03-25 10:01:54.368107+00
8aad4c17-1e78-49b6-9dc3-fd09c33dcf35	9854d7dc-b664-4d8f-af15-348b20920345	f149d680-6b63-40cf-9b1c-5e9d97096f1c	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-03-25	1	13:00:00	19:00:00	\N	2026-03-25 10:01:54.368107+00	2026-03-25 10:01:54.368107+00
05309e78-90fd-448e-aa51-82ceda2cbb9b	ea762152-a4ba-4f83-b58c-8e8129348e5b	436d7827-0da9-42c1-b1bb-8745a68abb54	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-03-25	1	08:00:00	09:00:00	\N	2026-03-25 10:01:54.368107+00	2026-03-25 10:01:54.368107+00
d38f41c5-afe9-47f2-9c19-3f64102aa8b1	ea762152-a4ba-4f83-b58c-8e8129348e5b	f149d680-6b63-40cf-9b1c-5e9d97096f1c	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-03-25	1	10:00:00	12:00:00	\N	2026-03-25 10:01:54.368107+00	2026-03-25 10:01:54.368107+00
d245871a-d346-4e0f-9258-689878a1f453	ea762152-a4ba-4f83-b58c-8e8129348e5b	f149d680-6b63-40cf-9b1c-5e9d97096f1c	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-03-25	1	13:00:00	19:00:00	\N	2026-03-25 10:01:54.368107+00	2026-03-25 10:01:54.368107+00
219f452a-390f-4ffb-b410-77f955c6735d	6d1605d8-2318-40ad-b5a9-03feab324fd2	436d7827-0da9-42c1-b1bb-8745a68abb54	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-03-25	1	08:00:00	12:00:00	\N	2026-03-25 10:01:54.368107+00	2026-03-25 10:01:54.368107+00
35bf28ed-881b-4ad1-ae14-6677283ce8e7	6d1605d8-2318-40ad-b5a9-03feab324fd2	436d7827-0da9-42c1-b1bb-8745a68abb54	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-03-25	1	13:00:00	19:00:00	\N	2026-03-25 10:01:54.368107+00	2026-03-25 10:01:54.368107+00
2bf53023-6296-4bcf-8ef7-ed1b344cec60	39b6b948-b93a-47c0-9d72-bd474ca0b1a9	f149d680-6b63-40cf-9b1c-5e9d97096f1c	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-03-25	1	08:00:00	12:00:00	\N	2026-03-25 10:01:54.368107+00	2026-03-25 10:01:54.368107+00
30c6f022-3342-451d-9f77-15fcbf34d044	39b6b948-b93a-47c0-9d72-bd474ca0b1a9	f149d680-6b63-40cf-9b1c-5e9d97096f1c	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-03-25	1	13:00:00	20:30:00	\N	2026-03-25 10:01:54.368107+00	2026-03-25 10:01:54.368107+00
0c3a4846-b96e-4f5b-a300-2d4829cbdd5d	fd1ab8e1-89e7-49f1-b029-41ed3b1565bd	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-03-25	1	13:00:00	18:00:00	\N	2026-03-25 10:01:54.368107+00	2026-03-25 10:01:54.368107+00
c384f7dc-a3cb-4749-b673-d15e27ba6562	05a758ae-a3b8-401f-a768-a948669f601b	fb4fe76d-c487-4dc4-9de4-69a28896bc93	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-03-25	1	10:00:00	12:00:00	\N	2026-03-25 10:01:54.368107+00	2026-03-25 10:01:54.368107+00
362901af-2651-4a73-87dc-358606964652	05a758ae-a3b8-401f-a768-a948669f601b	fb4fe76d-c487-4dc4-9de4-69a28896bc93	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-03-25	1	13:00:00	20:30:00	\N	2026-03-25 10:01:54.368107+00	2026-03-25 10:01:54.368107+00
869d983e-4137-48d3-abec-b4bbf8469905	9c7a22c6-f3ee-4fe2-9955-26c400fd0ace	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-03-25	1	08:00:00	12:00:00	\N	2026-03-25 10:01:54.368107+00	2026-03-25 10:01:54.368107+00
7966e86f-0730-461c-bb11-9df6b152a01c	9c7a22c6-f3ee-4fe2-9955-26c400fd0ace	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-03-25	1	13:00:00	20:30:00	\N	2026-03-25 10:01:54.368107+00	2026-03-25 10:01:54.368107+00
43d06619-694a-48c3-860c-530cbaa13c0a	e506fe75-0df4-48ea-ac85-17b42f896982	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-03-25	1	10:00:00	12:00:00	\N	2026-03-25 10:01:54.368107+00	2026-03-25 10:01:54.368107+00
98758998-fc5c-40da-8fbb-37a68e386f5c	e506fe75-0df4-48ea-ac85-17b42f896982	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-03-25	1	13:00:00	19:00:00	\N	2026-03-25 10:01:54.368107+00	2026-03-25 10:01:54.368107+00
5325defd-3500-470c-95f6-7a1f24c26bc7	8c870a0e-09ee-4f8d-9fa4-df771f36c4af	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-03-25	1	08:00:00	09:00:00	\N	2026-03-25 10:01:54.368107+00	2026-03-25 10:01:54.368107+00
16b09a94-707d-4a40-8071-7aa1aa97f4f4	60da7298-fdb8-41f4-ba2d-eff14314ac52	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-03-25	1	10:00:00	12:00:00	\N	2026-03-25 10:01:54.368107+00	2026-03-25 10:01:54.368107+00
b3f3dd7e-6bb9-4c84-aeb8-5c16c54a5ab2	60da7298-fdb8-41f4-ba2d-eff14314ac52	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-03-25	1	13:00:00	19:00:00	\N	2026-03-25 10:01:54.368107+00	2026-03-25 10:01:54.368107+00
620c5e85-68f5-4558-978f-3fbf26d4e251	ed254dbb-5433-4617-9a20-f642fada5d3c	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-03-25	1	13:00:00	18:00:00	\N	2026-03-25 10:01:54.368107+00	2026-03-25 10:01:54.368107+00
f4a6b6f7-6a79-4cd0-9774-2c4e4956fc63	eafc9a41-ffe5-4cce-ac7b-9e7b0e274d8f	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-03-25	1	10:00:00	12:00:00	\N	2026-03-25 10:01:54.368107+00	2026-03-25 10:01:54.368107+00
ca79fae5-1255-4114-9680-c08868567a8b	eafc9a41-ffe5-4cce-ac7b-9e7b0e274d8f	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-03-25	1	13:00:00	18:30:00	\N	2026-03-25 10:01:54.368107+00	2026-03-25 10:01:54.368107+00
430099cd-4be2-4ae1-9f3b-ee61f6d365df	5e44115d-118e-4dd5-80c6-30b0bc1260dd	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-03-25	1	10:00:00	12:00:00	\N	2026-03-25 10:01:54.368107+00	2026-03-25 10:01:54.368107+00
21e8c859-ec02-4fb4-b8e4-7a84cfc3b5e6	5e44115d-118e-4dd5-80c6-30b0bc1260dd	eecdcfc1-afe3-4fea-b614-8a121ba07575	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-03-25	1	13:00:00	18:30:00	\N	2026-03-25 10:01:54.368107+00	2026-03-25 10:01:54.368107+00
d8897b7e-cbf3-485c-a00d-a24609ccaf6d	0c3290ed-2e07-4bb2-aee3-c89339f6914f	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7a06632f-324d-4050-aea1-c8799611ccd0	2026-03-25	1	13:00:00	20:30:00	\N	2026-03-25 10:01:54.368107+00	2026-03-25 10:01:54.368107+00
85d313a6-b06d-454a-9aeb-7d01d979e010	a4b4e8b3-39d4-486f-917b-cbdf54b204a3	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7a06632f-324d-4050-aea1-c8799611ccd0	2026-03-25	1	13:00:00	20:30:00	\N	2026-03-25 10:01:54.368107+00	2026-03-25 10:01:54.368107+00
9d26ff0c-6e40-40fc-b2a9-c4aa979d7be4	7dbb9f67-2b06-4c44-b4f6-94b8f4bdaad4	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7a06632f-324d-4050-aea1-c8799611ccd0	2026-03-25	1	10:00:00	12:00:00	\N	2026-03-25 10:01:54.368107+00	2026-03-25 10:01:54.368107+00
86d219ae-3d1d-4f7a-a4a5-6cb7bcb1724e	7dbb9f67-2b06-4c44-b4f6-94b8f4bdaad4	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7a06632f-324d-4050-aea1-c8799611ccd0	2026-03-25	1	13:00:00	18:30:00	\N	2026-03-25 10:01:54.368107+00	2026-03-25 10:01:54.368107+00
deb18278-f6c1-4c6c-aa2a-045e9a78abf0	0381a248-b039-47ca-a591-41c90db7a78d	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-06-08	1	15:00:00	16:30:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
8878d412-b3d0-4aa3-aea9-983d53134233	10b8fd36-5de5-42ad-8c4a-a8a4494274ad	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-15	1	12:00:00	16:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
a901e48f-679b-4103-af41-86a07509d6ab	10b8fd36-5de5-42ad-8c4a-a8a4494274ad	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-15	1	16:30:00	19:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
f59f951b-2e5f-4ad6-996b-3ea0c8e416b5	c451eb0a-6299-4de1-8928-fe10fc43c789	255ce056-e234-417c-8d6a-db745e4bc729	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	12:00:00	13:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
98cda0cf-c47a-43a5-8b75-f2268966a23e	c451eb0a-6299-4de1-8928-fe10fc43c789	255ce056-e234-417c-8d6a-db745e4bc729	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	14:00:00	16:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
0f3be8bd-0f6f-4892-b325-cdbd658f8fd2	c451eb0a-6299-4de1-8928-fe10fc43c789	255ce056-e234-417c-8d6a-db745e4bc729	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	16:30:00	19:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
945763e6-7fa3-422c-9dea-1168300072c9	c451eb0a-6299-4de1-8928-fe10fc43c789	255ce056-e234-417c-8d6a-db745e4bc729	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	19:15:00	20:30:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
8e7b3cbd-059e-4fca-bf24-ead8c5d546d0	6ffdd3d6-ab8e-4a24-bc27-25d51cbf0265	eecdcfc1-afe3-4fea-b614-8a121ba07575	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-15	1	12:00:00	16:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
ed5134ad-7ff5-496a-8701-cae16148cb3c	9b8c599c-b1ae-4a02-b2e2-eae82615b1c5	20c634be-77b2-4a73-9f6e-93bedc05b658	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	12:00:00	13:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
f6ee1bfb-e343-4c37-9b26-23179083e5cb	9b8c599c-b1ae-4a02-b2e2-eae82615b1c5	20c634be-77b2-4a73-9f6e-93bedc05b658	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	14:00:00	16:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
3cac8e71-b686-4665-b4d0-685fd5605a06	610340d4-b744-4046-971e-023a4281ea6c	eecdcfc1-afe3-4fea-b614-8a121ba07575	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-15	1	16:30:00	19:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
d12d104b-0425-41af-a554-7b5ffcef2fc6	610340d4-b744-4046-971e-023a4281ea6c	20c634be-77b2-4a73-9f6e-93bedc05b658	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-15	1	19:00:00	20:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
d8b97cf0-b90e-4801-980d-b65d7a0a5e0d	39b6b948-b93a-47c0-9d72-bd474ca0b1a9	f91d0839-8da7-4d33-bec1-7b6563b445ad	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-15	1	08:00:00	11:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
858995df-4245-4795-8a99-197869b2c646	39b6b948-b93a-47c0-9d72-bd474ca0b1a9	436d7827-0da9-42c1-b1bb-8745a68abb54	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-15	1	11:00:00	12:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
e8366e88-1d23-46d7-bbd7-8a35962483ef	9b8c599c-b1ae-4a02-b2e2-eae82615b1c5	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	16:30:00	19:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
becad571-6c17-46bf-a3b0-923f35a1aaa9	9b8c599c-b1ae-4a02-b2e2-eae82615b1c5	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	19:15:00	20:30:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
35ec96f8-dda8-460d-8814-7b1e717ccca8	4e252744-9763-44d4-b1f5-51affb91f884	f01032bd-4de9-40ff-953c-d8a2ddc937f5	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-06-08	1	16:00:00	18:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
888451b6-149b-4976-b4a5-4d4660b12aaa	6e680af6-049c-46f4-8a65-c76c50d29453	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-15	1	19:00:00	20:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
5e29ad43-c1e6-460e-9813-bf104843faee	ea762152-a4ba-4f83-b58c-8e8129348e5b	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-15	1	08:00:00	12:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
c84a206d-83a9-4a00-91a9-37822e082582	ea762152-a4ba-4f83-b58c-8e8129348e5b	9a8a5181-bdc8-4431-9a0a-14f52be82896	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-15	1	06:00:00	08:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
c65e955f-0df4-4d56-a2e0-fb07b0f4d872	4e252744-9763-44d4-b1f5-51affb91f884	f01032bd-4de9-40ff-953c-d8a2ddc937f5	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-06-08	1	18:15:00	20:30:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
5edc2d53-b4e8-494f-9d57-0cbc72f792e9	86772cf3-dfaa-4db2-9d2d-e2bdb4241d6c	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-06-08	1	10:00:00	11:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
e9bd59c3-75a6-4543-8ec1-d2e2ed196361	86772cf3-dfaa-4db2-9d2d-e2bdb4241d6c	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-06-08	1	12:00:00	14:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
ab44a1da-268e-4505-8108-10e6e2242e14	86772cf3-dfaa-4db2-9d2d-e2bdb4241d6c	20c634be-77b2-4a73-9f6e-93bedc05b658	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-06-08	1	14:30:00	16:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
629f4eeb-bb5d-4b4a-9b11-808154d5df12	ed254dbb-5433-4617-9a20-f642fada5d3c	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-15	1	10:00:00	14:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
0cef5b06-a037-42f8-95fd-8668f4dba4a6	ed254dbb-5433-4617-9a20-f642fada5d3c	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-15	1	14:30:00	18:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
a101b612-ff38-4360-a88e-fc02ff29b137	86772cf3-dfaa-4db2-9d2d-e2bdb4241d6c	20c634be-77b2-4a73-9f6e-93bedc05b658	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-06-08	1	17:00:00	18:30:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
97e2e65c-36df-4476-a954-c4bf4bb364cf	0c3290ed-2e07-4bb2-aee3-c89339f6914f	fb4fe76d-c487-4dc4-9de4-69a28896bc93	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-15	1	16:30:00	19:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
d0c97601-877e-49c1-abd2-054cac8ee882	0a6c1e7d-b777-49a7-8a55-a85e63979d98	436d7827-0da9-42c1-b1bb-8745a68abb54	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-06-08	1	16:00:00	18:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
b18e1089-004f-40c9-a904-48eeaa6a0240	7892a694-bf37-41fa-b2ba-64f69230f4e4	fb4fe76d-c487-4dc4-9de4-69a28896bc93	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-15	1	10:00:00	12:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
9511df4d-2320-43e8-a42d-556bd13f36f0	0a6c1e7d-b777-49a7-8a55-a85e63979d98	f149d680-6b63-40cf-9b1c-5e9d97096f1c	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-06-08	1	18:15:00	20:30:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
02140abe-7b05-4a47-9935-a5dcd379cfc6	48cc0745-4e5f-4dda-8ff5-07fa61d6eea7	436d7827-0da9-42c1-b1bb-8745a68abb54	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-06-08	1	16:00:00	18:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
c8480e75-bd25-4d18-b767-1866d69566ae	48cc0745-4e5f-4dda-8ff5-07fa61d6eea7	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-06-08	1	18:15:00	20:30:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
9a81ee7f-8f90-49a7-be59-74139556d585	8c870a0e-09ee-4f8d-9fa4-df771f36c4af	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-15	1	14:00:00	16:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
16d594fb-d292-4960-8b7d-24181b1c95ef	8c870a0e-09ee-4f8d-9fa4-df771f36c4af	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-15	1	08:00:00	09:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
ba67cfb6-3099-46d4-89c3-5d0584885bd3	3f8de0d0-ef55-4067-ad87-a7310b3cdaf5	f149d680-6b63-40cf-9b1c-5e9d97096f1c	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-06-08	1	16:00:00	18:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
3ecaac42-8bf0-4094-8b1c-f2dbd62b2603	8c870a0e-09ee-4f8d-9fa4-df771f36c4af	20c634be-77b2-4a73-9f6e-93bedc05b658	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-15	1	13:00:00	14:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
50a543be-8ada-4cf7-b906-85cb34925dde	8c870a0e-09ee-4f8d-9fa4-df771f36c4af	20c634be-77b2-4a73-9f6e-93bedc05b658	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-15	1	16:00:00	16:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
d8ad4929-5383-4088-8aa0-d19636f887fc	05a758ae-a3b8-401f-a768-a948669f601b	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-15	1	13:00:00	16:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
2a682ca3-a2fd-450f-abb3-0d2ede13b1fc	3f8de0d0-ef55-4067-ad87-a7310b3cdaf5	eecdcfc1-afe3-4fea-b614-8a121ba07575	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-06-08	1	18:15:00	20:30:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
6af2f4cb-954c-430a-b58d-030a436dcf17	05a758ae-a3b8-401f-a768-a948669f601b	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-15	1	08:00:00	09:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
cca00fc8-4af7-4508-a936-01d883591289	05a758ae-a3b8-401f-a768-a948669f601b	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-15	1	12:00:00	12:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
1e88aad3-d341-449b-948d-d959f33ded84	9c7a22c6-f3ee-4fe2-9955-26c400fd0ace	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-15	1	08:00:00	12:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
5b121e25-8b5d-4028-ac46-9848b14a6a17	9c7a22c6-f3ee-4fe2-9955-26c400fd0ace	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-15	1	15:00:00	16:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
8de1b7f6-d770-40b6-8084-1420d4ad6bb4	9c7a22c6-f3ee-4fe2-9955-26c400fd0ace	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-15	1	13:00:00	14:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
a059b300-ae74-47a8-b3cf-691ea27e1fcf	e506fe75-0df4-48ea-ac85-17b42f896982	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-15	1	08:00:00	12:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
8e5e2394-fced-464e-b3c9-8b379a7d20c8	6d1605d8-2318-40ad-b5a9-03feab324fd2	436d7827-0da9-42c1-b1bb-8745a68abb54	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-06-08	1	10:00:00	12:30:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
4d0d720c-b6a2-4521-8158-38478f274a98	e46010de-9a74-432f-92b6-40b9de20be76	f91d0839-8da7-4d33-bec1-7b6563b445ad	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-15	1	13:00:00	16:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
136825cb-695a-4195-8ecf-166cb7891ed6	e46010de-9a74-432f-92b6-40b9de20be76	20c634be-77b2-4a73-9f6e-93bedc05b658	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-15	1	11:00:00	12:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
043cc366-b1d4-416a-8222-72376731e5e4	e46010de-9a74-432f-92b6-40b9de20be76	f91d0839-8da7-4d33-bec1-7b6563b445ad	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-15	1	12:00:00	12:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
faa48d62-11f3-4a9e-a28d-517e1a9c0c01	9854d7dc-b664-4d8f-af15-348b20920345	13c4d090-b2db-4397-89d8-025d6588d0c1	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-15	1	08:00:00	12:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
3f58d483-e3f9-4a0b-aa2e-8abf21887a28	9854d7dc-b664-4d8f-af15-348b20920345	13c4d090-b2db-4397-89d8-025d6588d0c1	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-15	1	13:00:00	14:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
98f361f6-3fd6-48a8-aea5-1905bf2355dd	9854d7dc-b664-4d8f-af15-348b20920345	9a8a5181-bdc8-4431-9a0a-14f52be82896	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-15	1	06:00:00	08:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
f70048c7-e715-4ed9-bf4d-ad31783a7f5c	a4b4e8b3-39d4-486f-917b-cbdf54b204a3	436d7827-0da9-42c1-b1bb-8745a68abb54	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-15	1	17:00:00	18:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
31b1bd65-6adb-4c03-8c4e-73a3dcf2f6fa	a4b4e8b3-39d4-486f-917b-cbdf54b204a3	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-15	1	18:00:00	19:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
94073d13-178a-4aec-909b-1ef99ffef59e	4d24bf6a-dfc4-46a4-a41d-ecb6e8ad6be4	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-15	1	17:00:00	18:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
473ac995-b301-44bc-a5a3-ed6125d08ae7	4d24bf6a-dfc4-46a4-a41d-ecb6e8ad6be4	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-15	1	11:00:00	12:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
7c7d6e4c-e4d3-4621-a585-83784604756d	5d89f5b8-1d05-487b-946b-8708e0290a8f	436d7827-0da9-42c1-b1bb-8745a68abb54	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-15	1	17:00:00	18:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
091334a8-aaa4-4180-a7ee-337fa5535b5f	60da7298-fdb8-41f4-ba2d-eff14314ac52	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-15	1	11:00:00	12:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
9cb3653f-2a8e-4f2b-b69b-08fb19bc0b51	60da7298-fdb8-41f4-ba2d-eff14314ac52	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-15	1	17:00:00	18:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
9e4a6722-dba5-4c5c-bd35-0ee0f2536a2c	0328b5d2-f6e5-43e9-912e-d775bb7ea114	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-14	1	12:00:00	16:00:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
67c26b92-1ddb-49be-9b00-adbc2c516b89	0328b5d2-f6e5-43e9-912e-d775bb7ea114	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-14	1	16:30:00	20:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
9643417e-f8cb-4976-9c2d-01522b4f7bd4	83ec0c51-d0aa-4a2b-95b4-155b87738cb4	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-14	1	10:00:00	14:00:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
22b7937f-4821-40f2-a58b-d83d1bc3c367	83ec0c51-d0aa-4a2b-95b4-155b87738cb4	20c634be-77b2-4a73-9f6e-93bedc05b658	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-14	1	14:30:00	18:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
d1bfed48-cbc4-4c45-9395-a29ca5220765	d3b977c5-78be-43bd-b2df-9c6ad004ec64	f01032bd-4de9-40ff-953c-d8a2ddc937f5	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-14	1	06:00:00	12:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
a78061ed-6bb5-4a61-992d-9de0dc40e49e	d3b977c5-78be-43bd-b2df-9c6ad004ec64	f01032bd-4de9-40ff-953c-d8a2ddc937f5	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-14	1	13:00:00	14:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
e451e238-83d2-445f-b2f2-22193f4b5864	df1d7a4b-33db-4bd9-855b-a6d8f97360a1	436d7827-0da9-42c1-b1bb-8745a68abb54	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-14	1	12:00:00	16:00:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
22eb58d9-c092-4a22-ab5e-3103847d6fbc	df1d7a4b-33db-4bd9-855b-a6d8f97360a1	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-14	1	16:30:00	20:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
052739cc-9849-40ad-ad84-fc96310a9221	0381a248-b039-47ca-a591-41c90db7a78d	20c634be-77b2-4a73-9f6e-93bedc05b658	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-14	1	08:00:00	12:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
d8f266ae-9f6c-4d28-ba39-48c0f54a6bfc	0381a248-b039-47ca-a591-41c90db7a78d	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-14	1	13:00:00	16:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
b8f67169-edca-418c-abf7-cbf7015c922b	c451eb0a-6299-4de1-8928-fe10fc43c789	255ce056-e234-417c-8d6a-db745e4bc729	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-14	1	12:00:00	16:00:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
ea7f6fe6-3afc-4f79-914e-741e22042dd8	c451eb0a-6299-4de1-8928-fe10fc43c789	255ce056-e234-417c-8d6a-db745e4bc729	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-14	1	16:30:00	20:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
089063d8-08a8-4775-a81b-9dae1d03b994	9854d7dc-b664-4d8f-af15-348b20920345	13c4d090-b2db-4397-89d8-025d6588d0c1	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-14	1	06:00:00	12:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
e919daa0-8021-4afa-8286-a1d7e7578ca1	9854d7dc-b664-4d8f-af15-348b20920345	13c4d090-b2db-4397-89d8-025d6588d0c1	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-14	1	13:00:00	14:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
12bc45da-71e4-461c-a72a-4867fbec09ec	ea762152-a4ba-4f83-b58c-8e8129348e5b	54a2e013-7933-4ba6-bff4-eb07adb05f7e	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-14	1	06:00:00	12:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
af94dbc6-0b68-4b14-9c5b-8a6c33c114f7	ea762152-a4ba-4f83-b58c-8e8129348e5b	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-14	1	13:00:00	14:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
36cc03fa-fcc6-488a-8b99-cbdf8db485a9	6d1605d8-2318-40ad-b5a9-03feab324fd2	9a8a5181-bdc8-4431-9a0a-14f52be82896	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-14	1	06:00:00	12:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
0f78b1f1-bb68-4423-aaab-b6b56d79c75a	6d1605d8-2318-40ad-b5a9-03feab324fd2	436d7827-0da9-42c1-b1bb-8745a68abb54	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-06-08	1	13:00:00	14:30:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
961d8b94-7f61-4158-87f0-0a07d96fa25a	6d1605d8-2318-40ad-b5a9-03feab324fd2	9a8a5181-bdc8-4431-9a0a-14f52be82896	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-06-08	1	06:00:00	07:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
2011f041-dde5-47ac-bfe4-c103aceb446e	6d1605d8-2318-40ad-b5a9-03feab324fd2	436d7827-0da9-42c1-b1bb-8745a68abb54	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-06-08	1	08:00:00	09:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
992b3b41-2c22-4408-8b17-542c4178bae1	fd1ab8e1-89e7-49f1-b029-41ed3b1565bd	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-14	1	08:00:00	12:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
034477da-a49e-4e40-8b1b-989e7a87dc4d	fd1ab8e1-89e7-49f1-b029-41ed3b1565bd	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-14	1	13:00:00	16:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
2c87f57c-50d7-479b-a872-cb50fcb2fbd4	05a758ae-a3b8-401f-a768-a948669f601b	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-14	1	08:00:00	12:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
ff0fb257-c7b3-4731-8696-4fcb4df55c5f	05a758ae-a3b8-401f-a768-a948669f601b	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-14	1	13:00:00	16:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
b2e53369-6125-46f4-aa6a-1018b991c890	9c7a22c6-f3ee-4fe2-9955-26c400fd0ace	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-14	1	08:00:00	12:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
12669e82-6662-412d-b76a-7b4b4a6ea0c1	9c7a22c6-f3ee-4fe2-9955-26c400fd0ace	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-14	1	13:00:00	16:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
cc22fda8-9bd4-4da5-b0eb-0e7441e39b44	e506fe75-0df4-48ea-ac85-17b42f896982	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-14	1	08:00:00	12:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
07a7c727-041c-4390-a4c8-bbd5908be5e6	e506fe75-0df4-48ea-ac85-17b42f896982	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-14	1	13:00:00	16:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
e41f8df6-ff1f-46df-bb56-8ff33a1d90d2	8c870a0e-09ee-4f8d-9fa4-df771f36c4af	20c634be-77b2-4a73-9f6e-93bedc05b658	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-14	1	08:00:00	12:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
509d79e4-e9a7-483a-8e32-2e49ff134fb8	8c870a0e-09ee-4f8d-9fa4-df771f36c4af	fb4fe76d-c487-4dc4-9de4-69a28896bc93	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-14	1	13:00:00	16:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
cbc8295b-af52-4821-8a05-f850aa49faff	e940eada-79a1-440e-851e-2dfb9b92b693	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-14	1	08:00:00	12:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
14dbb980-82d9-4ae9-98fc-d21adddb2c37	e940eada-79a1-440e-851e-2dfb9b92b693	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-14	1	13:00:00	16:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
c0453485-b491-418b-973e-558af1831e9c	5f926628-1321-410f-835a-a1701355219d	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-14	1	08:00:00	12:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
c79eb10e-8d4e-4057-b337-1036efc789d2	631a0690-b2e4-4267-b5cf-3d16d87c264b	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	12:00:00	13:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
bd2033e9-6e21-485b-a14a-1d0e8a2ad32b	7cc683f3-2ea9-40dd-94d9-2af83d2723da	eecdcfc1-afe3-4fea-b614-8a121ba07575	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-14	1	08:00:00	12:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
986b4c83-5d1a-47ce-8362-b57743dd3212	7cc683f3-2ea9-40dd-94d9-2af83d2723da	eecdcfc1-afe3-4fea-b614-8a121ba07575	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-14	1	13:00:00	16:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
a7b9b060-4852-4146-a624-b1f953274a88	343cd39e-8d18-4812-a6d0-d9f480dc9cb9	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-14	1	08:00:00	12:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
3e783b8c-b19b-4b6c-ae51-461ef11ed68a	631a0690-b2e4-4267-b5cf-3d16d87c264b	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	14:00:00	16:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
1164a790-c18d-40d1-bb84-0da4a6507da2	631a0690-b2e4-4267-b5cf-3d16d87c264b	436d7827-0da9-42c1-b1bb-8745a68abb54	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	16:30:00	19:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
970b7ee5-1613-4651-875f-3642b707e2b2	e46010de-9a74-432f-92b6-40b9de20be76	f91d0839-8da7-4d33-bec1-7b6563b445ad	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-14	1	13:00:00	16:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
07b1e237-989e-4274-93f4-5b14722d0414	8a7bf4f5-92de-48eb-a2bc-18dae9992013	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-14	1	08:00:00	12:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
8ec1208f-0661-44bb-bc99-099d3a68ea57	8a7bf4f5-92de-48eb-a2bc-18dae9992013	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-14	1	13:00:00	16:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
989d3cd8-40a2-4d86-add4-23115f1f4bb7	631a0690-b2e4-4267-b5cf-3d16d87c264b	20c634be-77b2-4a73-9f6e-93bedc05b658	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	19:15:00	20:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
9402c948-4cfc-4488-9fc0-7710d6cece6a	ae95da63-ec15-4b11-b142-ff6fdb9a7b03	436d7827-0da9-42c1-b1bb-8745a68abb54	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-14	1	14:30:00	18:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
a89e265e-6b43-4952-bf7a-d2be5f7897ec	175b1a68-6756-44a3-9810-28d3aa10fda6	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-14	1	10:00:00	14:00:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
397cdc22-f5b9-4daa-bcea-10d0dd64e6bf	175b1a68-6756-44a3-9810-28d3aa10fda6	fb4fe76d-c487-4dc4-9de4-69a28896bc93	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-14	1	14:30:00	18:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
aa6f286b-a12b-4e96-9c77-80d6704dff45	1b11d981-a65d-46bd-8220-700df1acf99f	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-14	1	10:00:00	14:00:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
df704833-b736-4565-bab4-bd6c8f4e2cec	1b11d981-a65d-46bd-8220-700df1acf99f	436d7827-0da9-42c1-b1bb-8745a68abb54	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-14	1	14:30:00	18:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
6d5d2b2c-f4e0-4e59-87b3-2375e1e1a64e	60da7298-fdb8-41f4-ba2d-eff14314ac52	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-14	1	10:00:00	14:00:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
5b8fd6f4-ac65-411b-a280-3ac4d5bd6bd2	60da7298-fdb8-41f4-ba2d-eff14314ac52	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-14	1	14:30:00	18:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
709f9c6a-0998-4526-9437-f97ff56dae2e	ed254dbb-5433-4617-9a20-f642fada5d3c	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-14	1	10:00:00	14:00:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
51830dcc-54f0-4bc1-a179-952ac0864991	ed254dbb-5433-4617-9a20-f642fada5d3c	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-14	1	14:30:00	18:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
2ee5e452-0fe0-4ccc-aac7-2ba4a3c08ccb	7892a694-bf37-41fa-b2ba-64f69230f4e4	fb4fe76d-c487-4dc4-9de4-69a28896bc93	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-14	1	10:00:00	14:00:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
84a19a29-b7f4-4200-a155-cf4560e59fb5	7892a694-bf37-41fa-b2ba-64f69230f4e4	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-14	1	14:30:00	18:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
1081fec3-715c-48af-9e29-4295c1c1acf2	eafc9a41-ffe5-4cce-ac7b-9e7b0e274d8f	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-14	1	10:00:00	14:00:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
468d0b49-a213-44dd-919c-21c47ad7f0c6	eafc9a41-ffe5-4cce-ac7b-9e7b0e274d8f	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-14	1	14:30:00	18:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
8a439d51-6302-4ad2-ac52-12065e94268f	5e44115d-118e-4dd5-80c6-30b0bc1260dd	20c634be-77b2-4a73-9f6e-93bedc05b658	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-14	1	10:00:00	14:00:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
d5f1040e-f84c-4135-94e7-7332b86f750d	5e44115d-118e-4dd5-80c6-30b0bc1260dd	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-14	1	14:30:00	18:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
d6be3dbb-f033-4f2d-80b8-ae33382d9be7	6d85775f-a88d-472b-876c-265b4f483da5	436d7827-0da9-42c1-b1bb-8745a68abb54	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-14	1	10:00:00	14:00:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
13b57ee0-c33b-488b-b399-6057435b2b0f	6d85775f-a88d-472b-876c-265b4f483da5	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-14	1	14:30:00	18:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
ae0d2c57-5085-4f74-8abd-0d4437c3858c	fda9b996-4df4-4ab4-bf71-2de86e81ea52	436d7827-0da9-42c1-b1bb-8745a68abb54	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	14:00:00	16:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
00827b45-6649-4558-9fbb-947e95a1c6c4	5cc3bb12-e940-4880-94e6-cfe1427ecfc6	eecdcfc1-afe3-4fea-b614-8a121ba07575	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-14	1	14:30:00	18:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
912845b0-c80b-4ecd-8664-5422855caffe	ae7fadd4-07c4-408c-9a55-f4780cdcd1f0	436d7827-0da9-42c1-b1bb-8745a68abb54	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-14	1	12:00:00	16:00:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
6d5dd45a-4aae-4193-9a21-b282be062051	fda9b996-4df4-4ab4-bf71-2de86e81ea52	436d7827-0da9-42c1-b1bb-8745a68abb54	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	12:00:00	13:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
bd798a75-24de-4f85-a4a2-b713ee070224	631a0690-b2e4-4267-b5cf-3d16d87c264b	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-14	1	12:00:00	16:00:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
3e316138-f9af-4770-805b-852e3bf5101f	fda9b996-4df4-4ab4-bf71-2de86e81ea52	436d7827-0da9-42c1-b1bb-8745a68abb54	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-14	1	12:00:00	16:00:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
f7a0d870-4d72-4c71-8a12-20d8b7ca7cc5	fda9b996-4df4-4ab4-bf71-2de86e81ea52	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	16:30:00	19:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
8de983e8-e925-4211-bd1f-0fc03eb94fee	fda9b996-4df4-4ab4-bf71-2de86e81ea52	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	19:15:00	20:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
2756310d-0a7a-4ea0-b5c7-9609e30a3e4c	6a5611b1-a04b-43d0-8c35-a810d393a0aa	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	16:30:00	19:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
7d4f5fbd-e6e2-4bca-b89b-417bab48bfd7	6a5611b1-a04b-43d0-8c35-a810d393a0aa	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-14	1	12:00:00	16:00:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
54b87a07-1edf-47d0-b766-d06d48f20cdd	6a5611b1-a04b-43d0-8c35-a810d393a0aa	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-14	1	16:30:00	20:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
786c430d-eade-488d-b1c1-0919fb334418	10b8fd36-5de5-42ad-8c4a-a8a4494274ad	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-14	1	12:00:00	16:00:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
c76ccc6f-9811-462e-a587-849e59eb30ee	6a5611b1-a04b-43d0-8c35-a810d393a0aa	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	12:00:00	13:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
75fa7202-d6d5-42f4-9a16-b054344ee315	30b6df55-a118-4b1b-8df1-c5663a701ed2	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-14	1	12:00:00	16:00:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
07d1c02e-a3e5-4408-95fb-b19fe952e241	30b6df55-a118-4b1b-8df1-c5663a701ed2	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-14	1	16:30:00	20:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
8572664f-f79f-43fa-aef7-caa74c9bd6e2	91e5fbf6-b35e-489d-8bec-d77e32facc25	436d7827-0da9-42c1-b1bb-8745a68abb54	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-14	1	12:00:00	16:00:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
d1b84c03-0b5e-4024-a4d2-f01c19c203d6	6a5611b1-a04b-43d0-8c35-a810d393a0aa	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	14:00:00	16:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
c7523509-714a-439e-90e5-8bdcdcf94f20	df1d7a4b-33db-4bd9-855b-a6d8f97360a1	436d7827-0da9-42c1-b1bb-8745a68abb54	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	14:00:00	16:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
055ab5c8-4469-4f52-a34c-a95da177ad50	0c3290ed-2e07-4bb2-aee3-c89339f6914f	20c634be-77b2-4a73-9f6e-93bedc05b658	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-14	1	16:30:00	20:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
088d4415-bdc6-4c3f-84da-8d95edb9ec6c	8c25fe94-99d4-44dd-9652-efe248083bb9	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-14	1	12:00:00	16:00:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
b84b244a-e709-4235-aca2-86b195802361	df1d7a4b-33db-4bd9-855b-a6d8f97360a1	436d7827-0da9-42c1-b1bb-8745a68abb54	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	12:00:00	13:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
fae63820-4d8e-4197-bca7-c9e00898958f	14e6a58a-9286-479d-af56-fb4f1cc680dc	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-14	1	12:00:00	16:00:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
1c31c15b-f174-44a2-b3b1-b589a9ae827e	df1d7a4b-33db-4bd9-855b-a6d8f97360a1	436d7827-0da9-42c1-b1bb-8745a68abb54	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	16:30:00	19:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
4111a42c-ea4c-439c-bdf5-dfa56a232f02	df1d7a4b-33db-4bd9-855b-a6d8f97360a1	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	19:15:00	20:30:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
c60f3be2-5c6a-4f2a-84a5-5447fe1f9918	a4b4e8b3-39d4-486f-917b-cbdf54b204a3	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-14	1	16:30:00	20:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
2bf38d9c-7323-4e2a-a849-1e430a198432	7dbb9f67-2b06-4c44-b4f6-94b8f4bdaad4	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-14	1	12:00:00	16:00:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
6c480000-0a8d-4ba0-8d11-9ca7f1f0de69	7dbb9f67-2b06-4c44-b4f6-94b8f4bdaad4	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-14	1	16:30:00	20:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
e4a26daf-ce99-44cb-b248-6b790a04ab0f	d3c6f53f-7209-4221-920c-bdc821b92372	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-14	1	12:00:00	16:00:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
61ec8d64-1ba7-4fcd-beec-143c41f942a1	d3c6f53f-7209-4221-920c-bdc821b92372	eecdcfc1-afe3-4fea-b614-8a121ba07575	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-14	1	16:30:00	20:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
bbb3e4f1-c183-4ae9-8a55-2a90195628a3	ae7fadd4-07c4-408c-9a55-f4780cdcd1f0	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	12:00:00	13:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
b2114ff6-7e5c-4951-a242-9d0e4b63b5ae	ae7fadd4-07c4-408c-9a55-f4780cdcd1f0	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	14:00:00	16:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
65af7b76-fea1-4292-94cb-46419a091bbc	ae7fadd4-07c4-408c-9a55-f4780cdcd1f0	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	16:30:00	19:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
831fc279-8b30-4e0d-8268-30ec5e9e4d32	1b11d981-a65d-46bd-8220-700df1acf99f	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-06-08	1	10:00:00	11:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
de479826-ef68-4f3c-9129-e5a76a9164b7	1b11d981-a65d-46bd-8220-700df1acf99f	436d7827-0da9-42c1-b1bb-8745a68abb54	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-06-08	1	14:30:00	16:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
d7c74bc5-732d-46d6-889d-4d000f916036	1b11d981-a65d-46bd-8220-700df1acf99f	436d7827-0da9-42c1-b1bb-8745a68abb54	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-06-08	1	12:00:00	14:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
cf9bf229-f3e0-4d6b-94a8-c92eeace5972	1b11d981-a65d-46bd-8220-700df1acf99f	436d7827-0da9-42c1-b1bb-8745a68abb54	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-06-08	1	17:00:00	18:30:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
b6475f57-4ce2-4261-8cc8-72859a5cb630	610340d4-b744-4046-971e-023a4281ea6c	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-14	1	16:30:00	20:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
af98eb5f-29ce-484a-b30b-f2f685094290	6d85775f-a88d-472b-876c-265b4f483da5	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-06-08	1	14:30:00	16:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
4bbe1f01-5998-4a2e-84fd-4db81ddef1a8	0a6c1e7d-b777-49a7-8a55-a85e63979d98	436d7827-0da9-42c1-b1bb-8745a68abb54	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-14	1	16:00:00	20:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
c276c5c2-385d-4efe-8ed3-27c3a3cbadf9	48cc0745-4e5f-4dda-8ff5-07fa61d6eea7	436d7827-0da9-42c1-b1bb-8745a68abb54	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-14	1	16:00:00	20:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
fe008181-5a2a-4bad-8f5d-a54aa6f92cd3	3f8de0d0-ef55-4067-ad87-a7310b3cdaf5	f149d680-6b63-40cf-9b1c-5e9d97096f1c	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-14	1	16:00:00	20:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
b13d373d-988c-4acd-8b26-6f99041ff70b	9b8c599c-b1ae-4a02-b2e2-eae82615b1c5	20c634be-77b2-4a73-9f6e-93bedc05b658	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-14	1	12:00:00	16:00:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
6caddd4a-e5bb-4eb4-8622-37d71cf27886	9b8c599c-b1ae-4a02-b2e2-eae82615b1c5	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-14	1	16:30:00	20:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
19e8cc37-97db-4285-893e-d2bbb15b2620	4e252744-9763-44d4-b1f5-51affb91f884	f01032bd-4de9-40ff-953c-d8a2ddc937f5	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-14	1	16:00:00	20:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
5e0c376d-c086-4556-91e7-75199278835b	86772cf3-dfaa-4db2-9d2d-e2bdb4241d6c	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-14	1	10:00:00	14:00:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
0fe1b174-73d6-4655-9ab0-5c6a23fdeb3a	86772cf3-dfaa-4db2-9d2d-e2bdb4241d6c	20c634be-77b2-4a73-9f6e-93bedc05b658	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-14	1	14:30:00	18:30:00	\N	2026-04-12 17:29:20.641059+00	2026-04-12 17:29:20.641059+00
37bc5b3f-fd36-4071-9313-c08d842d3e08	eafc9a41-ffe5-4cce-ac7b-9e7b0e274d8f	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-15	1	10:00:00	14:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
43c06586-6eef-4b1f-8b6b-0e18abb22dc6	eafc9a41-ffe5-4cce-ac7b-9e7b0e274d8f	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-15	1	14:30:00	18:30:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
a7e3fbd1-93b4-4891-b264-4ccc6cb0c6ab	d3c6f53f-7209-4221-920c-bdc821b92372	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-15	1	17:00:00	18:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
12528716-a5fe-4dca-b420-4a938631d3d0	0328b5d2-f6e5-43e9-912e-d775bb7ea114	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-13	1	12:00:00	16:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
b006530c-e3af-49e5-8d8b-7f9c00f05b65	0328b5d2-f6e5-43e9-912e-d775bb7ea114	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-13	1	16:30:00	20:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
10d7cf7b-f9a4-4aea-93e4-bf37781d2a23	83ec0c51-d0aa-4a2b-95b4-155b87738cb4	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-13	1	10:00:00	14:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
ed89c2f2-a758-45da-90cb-93df56f3a9a9	83ec0c51-d0aa-4a2b-95b4-155b87738cb4	20c634be-77b2-4a73-9f6e-93bedc05b658	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-13	1	14:30:00	18:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
8e07dd26-a639-4ffe-af36-e8951e89eb8a	d3b977c5-78be-43bd-b2df-9c6ad004ec64	f01032bd-4de9-40ff-953c-d8a2ddc937f5	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-13	1	06:00:00	12:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
a432b21b-88d9-4d1c-b0c1-a294664fdea7	d3b977c5-78be-43bd-b2df-9c6ad004ec64	f01032bd-4de9-40ff-953c-d8a2ddc937f5	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-13	1	13:00:00	14:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
e1f13255-dc68-4f2e-953b-1fbb7fb1e1c9	0381a248-b039-47ca-a591-41c90db7a78d	20c634be-77b2-4a73-9f6e-93bedc05b658	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-13	1	08:00:00	12:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
f0ff1e23-1b51-41eb-a58e-c26dd34a39b8	0381a248-b039-47ca-a591-41c90db7a78d	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-13	1	13:00:00	16:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
29a7b65d-e68f-4098-8225-9cf637e404c8	c451eb0a-6299-4de1-8928-fe10fc43c789	255ce056-e234-417c-8d6a-db745e4bc729	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-13	1	12:00:00	16:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
1b44ec07-b6fe-4ca9-ad6a-bc502e4b451a	c451eb0a-6299-4de1-8928-fe10fc43c789	255ce056-e234-417c-8d6a-db745e4bc729	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-13	1	16:30:00	20:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
3fb2fa12-b23a-42bb-a6de-af5366af48fe	9b8c599c-b1ae-4a02-b2e2-eae82615b1c5	20c634be-77b2-4a73-9f6e-93bedc05b658	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-13	1	12:00:00	16:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
cec24724-0e57-4f76-b827-1e29e5928472	9b8c599c-b1ae-4a02-b2e2-eae82615b1c5	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-13	1	16:30:00	20:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
071dc1f3-1cbf-4d53-b905-cc10c7aea613	4e252744-9763-44d4-b1f5-51affb91f884	f01032bd-4de9-40ff-953c-d8a2ddc937f5	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-13	1	16:00:00	20:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
b76b31de-db1d-4498-b6b9-11255d087efa	86772cf3-dfaa-4db2-9d2d-e2bdb4241d6c	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-13	1	10:00:00	14:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
48c07b67-74e9-4462-977b-831368880110	86772cf3-dfaa-4db2-9d2d-e2bdb4241d6c	20c634be-77b2-4a73-9f6e-93bedc05b658	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-13	1	14:30:00	18:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
0bd014df-a9f8-4296-903a-92741cc2d07e	3f8de0d0-ef55-4067-ad87-a7310b3cdaf5	f149d680-6b63-40cf-9b1c-5e9d97096f1c	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-13	1	16:00:00	20:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
d8ea455a-9e1f-42b6-a101-c9e82fe63f2c	0a6c1e7d-b777-49a7-8a55-a85e63979d98	436d7827-0da9-42c1-b1bb-8745a68abb54	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-13	1	16:00:00	19:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
2e0fc794-f51b-43c6-ba0e-602ae7b31c6c	0a6c1e7d-b777-49a7-8a55-a85e63979d98	eecdcfc1-afe3-4fea-b614-8a121ba07575	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-13	1	19:00:00	20:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
0b0ad3f8-2178-4796-b8df-5092d7c9662d	48cc0745-4e5f-4dda-8ff5-07fa61d6eea7	436d7827-0da9-42c1-b1bb-8745a68abb54	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-13	1	16:00:00	19:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
5f5ffde9-5369-428d-91cc-3df0fae2eb0b	48cc0745-4e5f-4dda-8ff5-07fa61d6eea7	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-13	1	19:00:00	20:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
4bc68593-4eca-4d09-a541-6c196931092d	fd1ab8e1-89e7-49f1-b029-41ed3b1565bd	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-13	1	13:00:00	16:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
fd37d0e4-c6c7-4d49-ac6f-a313239e8b04	fd1ab8e1-89e7-49f1-b029-41ed3b1565bd	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-13	1	08:00:00	12:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
ba7eb006-633f-4b7b-a839-5a0ea2c1b912	e940eada-79a1-440e-851e-2dfb9b92b693	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-13	1	13:00:00	16:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
a20fa398-a26f-410f-80db-088963b6a4c1	e940eada-79a1-440e-851e-2dfb9b92b693	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-13	1	08:00:00	12:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
3874a1ca-b5d7-4a69-a957-1da86f529743	5f926628-1321-410f-835a-a1701355219d	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-13	1	13:00:00	16:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
88d1f1c6-d1f5-4168-80fc-2b0f8e70d72b	5f926628-1321-410f-835a-a1701355219d	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-13	1	08:00:00	12:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
50544893-87cd-4640-8821-6996fe94d0fe	343cd39e-8d18-4812-a6d0-d9f480dc9cb9	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-13	1	13:00:00	16:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
675f045a-de60-4e63-a4ef-633aa434b6d4	343cd39e-8d18-4812-a6d0-d9f480dc9cb9	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-13	1	10:00:00	12:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
aac0dd0c-d43a-434b-a8e3-9b216f37f028	343cd39e-8d18-4812-a6d0-d9f480dc9cb9	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-13	1	08:00:00	10:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
b511e59b-e62d-4f2b-9230-079aea3fd4c5	8a7bf4f5-92de-48eb-a2bc-18dae9992013	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-13	1	13:00:00	16:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
ed8d580a-4ff8-469a-80dd-abbc293589cc	6d85775f-a88d-472b-876c-265b4f483da5	436d7827-0da9-42c1-b1bb-8745a68abb54	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-06-08	1	10:00:00	11:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
dab6eb7d-8eba-4a5c-8681-28cdd77c77cd	6d1605d8-2318-40ad-b5a9-03feab324fd2	9a8a5181-bdc8-4431-9a0a-14f52be82896	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-13	1	06:00:00	08:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
4ae3fc68-62e6-497e-a1b5-e879e97b8f50	6d1605d8-2318-40ad-b5a9-03feab324fd2	436d7827-0da9-42c1-b1bb-8745a68abb54	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-13	1	13:00:00	14:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
f2792937-c46b-4cfe-bcc7-4fb21a636c1f	6d1605d8-2318-40ad-b5a9-03feab324fd2	f149d680-6b63-40cf-9b1c-5e9d97096f1c	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-13	1	10:00:00	12:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
cf7da1ed-6c93-4685-a886-049047d1694b	6d1605d8-2318-40ad-b5a9-03feab324fd2	436d7827-0da9-42c1-b1bb-8745a68abb54	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-13	1	08:00:00	09:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
98bf5f3b-da97-4197-b164-f2ed09abddea	6d85775f-a88d-472b-876c-265b4f483da5	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-06-08	1	12:00:00	14:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
f42f2fbe-b7a8-4b3e-8dfd-c4cb5e9c82d1	1b11d981-a65d-46bd-8220-700df1acf99f	436d7827-0da9-42c1-b1bb-8745a68abb54	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-13	1	14:30:00	18:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
1119ca5d-b88e-4be1-962f-c4d16db99696	1b11d981-a65d-46bd-8220-700df1acf99f	436d7827-0da9-42c1-b1bb-8745a68abb54	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-13	1	10:00:00	14:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
9e274cd7-3fe1-4976-ab16-2c4fa407bcad	6d85775f-a88d-472b-876c-265b4f483da5	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-13	1	14:30:00	18:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
19eea4f3-2296-4723-bbb6-ca525bddcb35	6d85775f-a88d-472b-876c-265b4f483da5	20c634be-77b2-4a73-9f6e-93bedc05b658	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-13	1	10:00:00	14:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
d760e203-71a6-412b-8e82-8cc80b6ec294	631a0690-b2e4-4267-b5cf-3d16d87c264b	436d7827-0da9-42c1-b1bb-8745a68abb54	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-13	1	12:00:00	16:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
0ac6810e-b423-4278-8dde-2d52e3452e7f	6d85775f-a88d-472b-876c-265b4f483da5	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-06-08	1	17:00:00	18:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
4c95e114-048b-4573-840e-b3e42b99794f	fda9b996-4df4-4ab4-bf71-2de86e81ea52	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-13	1	12:00:00	16:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
4d1b0641-6d8d-4953-91bc-e44f344bc20c	7dbb9f67-2b06-4c44-b4f6-94b8f4bdaad4	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	16:30:00	19:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
7589f2bf-9b47-4026-b3e4-ac9f47ea73f7	7dbb9f67-2b06-4c44-b4f6-94b8f4bdaad4	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	12:00:00	13:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
f3c16ef0-6e25-4bc0-a878-071c9b7accb2	7dbb9f67-2b06-4c44-b4f6-94b8f4bdaad4	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	14:00:00	16:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
bb98ea0f-d68c-44fd-83d9-9b4c0843b93f	df1d7a4b-33db-4bd9-855b-a6d8f97360a1	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-13	1	12:00:00	16:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
486ee132-d174-44d7-89ca-204531c76443	df1d7a4b-33db-4bd9-855b-a6d8f97360a1	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-13	1	16:30:00	20:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
f20a0cb9-8725-4cd2-afba-a7b10b746fc5	7dbb9f67-2b06-4c44-b4f6-94b8f4bdaad4	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	19:15:00	20:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
58640af5-3684-4122-9124-07cb0c5d98e5	740ee69c-06c1-4a3b-a75c-19ab454b2775	20c634be-77b2-4a73-9f6e-93bedc05b658	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	12:00:00	13:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
d07141e2-ab37-4af6-aded-88ce5f302fd0	6a5611b1-a04b-43d0-8c35-a810d393a0aa	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-13	1	12:00:00	16:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
c61d7ec5-04e0-47cd-b1b1-2d633e860f45	6a5611b1-a04b-43d0-8c35-a810d393a0aa	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-13	1	16:30:00	19:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
cae1f00a-d3ab-40c5-b7ff-c5adfd4c72bd	740ee69c-06c1-4a3b-a75c-19ab454b2775	436d7827-0da9-42c1-b1bb-8745a68abb54	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	14:00:00	16:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
54ebf69d-1935-4ae9-b9c9-2463bddd2728	30b6df55-a118-4b1b-8df1-c5663a701ed2	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-13	1	12:00:00	16:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
fb4f2f91-0690-43b3-827e-d8038bc4e2ae	30b6df55-a118-4b1b-8df1-c5663a701ed2	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-13	1	16:30:00	19:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
6e3b988e-b595-461d-bbc6-5218605e301d	740ee69c-06c1-4a3b-a75c-19ab454b2775	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	16:30:00	19:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
465689f6-c8d0-4c28-a284-c67e0491056f	30b6df55-a118-4b1b-8df1-c5663a701ed2	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	16:30:00	19:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
b71b1b31-b226-4f0c-93e4-508602d27146	91e5fbf6-b35e-489d-8bec-d77e32facc25	fb4fe76d-c487-4dc4-9de4-69a28896bc93	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-13	1	12:00:00	16:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
d880afad-eef3-41b6-bfde-6da621aa862e	7dbb9f67-2b06-4c44-b4f6-94b8f4bdaad4	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-13	1	12:00:00	16:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
aae41c6a-84ad-43f6-83da-2f7d5058a915	7dbb9f67-2b06-4c44-b4f6-94b8f4bdaad4	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-13	1	16:30:00	20:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
22b859df-c31f-40d4-907e-102851e3a48e	30b6df55-a118-4b1b-8df1-c5663a701ed2	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	12:00:00	13:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
2c739aa3-4477-4a34-a0fe-bb11c47645dd	30b6df55-a118-4b1b-8df1-c5663a701ed2	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	14:00:00	16:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
382eeec8-a521-4cce-93b7-9e6b84e1dd94	6ffdd3d6-ab8e-4a24-bc27-25d51cbf0265	eecdcfc1-afe3-4fea-b614-8a121ba07575	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	12:00:00	13:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
06948075-34a2-4daa-a51e-aecb03ba130e	6ffdd3d6-ab8e-4a24-bc27-25d51cbf0265	eecdcfc1-afe3-4fea-b614-8a121ba07575	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	14:00:00	16:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
b76a326d-ae1c-43fe-b606-837900ba3dee	6ffdd3d6-ab8e-4a24-bc27-25d51cbf0265	eecdcfc1-afe3-4fea-b614-8a121ba07575	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	16:30:00	18:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
8676a7c0-386b-440e-bce2-f3dfe39f1714	10b8fd36-5de5-42ad-8c4a-a8a4494274ad	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-13	1	12:00:00	16:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
bf4dde62-a923-4337-b8ea-7d0260c72e8c	10b8fd36-5de5-42ad-8c4a-a8a4494274ad	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-13	1	16:30:00	19:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
7a0a0f3b-2610-4564-a3a1-138420e051dc	91e5fbf6-b35e-489d-8bec-d77e32facc25	fb4fe76d-c487-4dc4-9de4-69a28896bc93	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	16:30:00	19:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
9e9481a1-8f2e-4fd0-8e4b-c505c32d49b1	91e5fbf6-b35e-489d-8bec-d77e32facc25	fb4fe76d-c487-4dc4-9de4-69a28896bc93	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	12:00:00	13:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
fb9a4523-a68a-4de8-b731-18736b761588	91e5fbf6-b35e-489d-8bec-d77e32facc25	fb4fe76d-c487-4dc4-9de4-69a28896bc93	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	14:00:00	16:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
4b1fa372-f0f2-4f2d-a3ba-7aa4d1194ab3	6ffdd3d6-ab8e-4a24-bc27-25d51cbf0265	eecdcfc1-afe3-4fea-b614-8a121ba07575	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-13	1	12:00:00	16:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
0b8608c0-0a12-4665-b32f-7c5bc51c1cf0	58119498-aa74-4a50-b937-ef362d96849e	436d7827-0da9-42c1-b1bb-8745a68abb54	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	12:00:00	13:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
a50f8fa4-c8a0-458f-817e-e75b61ff7772	7cc81d84-5d1b-42d9-820b-5f99c9dc2ed3	fb4fe76d-c487-4dc4-9de4-69a28896bc93	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-13	1	16:30:00	19:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
bdc885f1-9e5f-4639-a098-22752386f74e	7cc81d84-5d1b-42d9-820b-5f99c9dc2ed3	20c634be-77b2-4a73-9f6e-93bedc05b658	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-13	1	19:00:00	20:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
0d0cf0e8-924b-4b7d-a126-d7e52173b5a1	58119498-aa74-4a50-b937-ef362d96849e	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	14:00:00	16:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
94354d62-8bf2-4c69-bf7c-e2ad0691b8ba	610340d4-b744-4046-971e-023a4281ea6c	eecdcfc1-afe3-4fea-b614-8a121ba07575	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-13	1	16:30:00	19:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
068d6db7-6d59-4b50-94db-a397649cebd4	610340d4-b744-4046-971e-023a4281ea6c	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-13	1	19:00:00	20:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
f46a8fe6-e436-4d91-83b3-f8ded31f496c	39b6b948-b93a-47c0-9d72-bd474ca0b1a9	f91d0839-8da7-4d33-bec1-7b6563b445ad	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-13	1	08:00:00	11:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
d700104f-8b0e-4a41-990d-17f1f6fc0ea5	39b6b948-b93a-47c0-9d72-bd474ca0b1a9	436d7827-0da9-42c1-b1bb-8745a68abb54	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-13	1	11:00:00	12:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
cb1c7666-8354-4254-a52a-cb2299e5eeee	58119498-aa74-4a50-b937-ef362d96849e	f91d0839-8da7-4d33-bec1-7b6563b445ad	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	16:30:00	18:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
1cf14402-7a73-4b4b-8a60-463db82a2f48	ea762152-a4ba-4f83-b58c-8e8129348e5b	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-13	1	08:00:00	12:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
994f8b49-53bd-4ebc-a4b4-4ac498714ff3	ea762152-a4ba-4f83-b58c-8e8129348e5b	9a8a5181-bdc8-4431-9a0a-14f52be82896	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-13	1	06:00:00	08:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
21db4365-2e70-41e7-9c9c-01e3def0f2e6	7892a694-bf37-41fa-b2ba-64f69230f4e4	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-06-08	1	10:00:00	11:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
0cbf4fd9-6b4f-43d7-99fa-399d13bc31f5	7892a694-bf37-41fa-b2ba-64f69230f4e4	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-06-08	1	12:00:00	14:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
50a3e8e8-793b-4f2a-8dc6-12a09ab5b980	7892a694-bf37-41fa-b2ba-64f69230f4e4	fb4fe76d-c487-4dc4-9de4-69a28896bc93	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-13	1	10:00:00	12:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
2ee5fb82-5187-4cbf-b8c6-216f6e880095	7892a694-bf37-41fa-b2ba-64f69230f4e4	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-06-08	1	14:30:00	16:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
543f6fa8-e9c9-4ca8-a0a5-1702128eeb26	7892a694-bf37-41fa-b2ba-64f69230f4e4	20c634be-77b2-4a73-9f6e-93bedc05b658	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-06-08	1	16:00:00	16:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
635fac28-275e-4295-8888-531e717bbf86	10b8fd36-5de5-42ad-8c4a-a8a4494274ad	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	12:00:00	13:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
110480e7-12da-455d-9c62-915f243a2cf9	8c870a0e-09ee-4f8d-9fa4-df771f36c4af	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-13	1	08:00:00	09:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
b0cbfae8-10a8-426e-ae38-4b6cc26c1390	10b8fd36-5de5-42ad-8c4a-a8a4494274ad	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	14:00:00	16:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
a1723cd2-177b-4eb1-b34e-0cbaa345c79d	8c870a0e-09ee-4f8d-9fa4-df771f36c4af	20c634be-77b2-4a73-9f6e-93bedc05b658	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-13	1	16:00:00	16:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
34e83738-e9fc-43ed-ab7f-ac8795af55af	ae95da63-ec15-4b11-b142-ff6fdb9a7b03	f91d0839-8da7-4d33-bec1-7b6563b445ad	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-13	1	14:30:00	18:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
1cd3ae36-df8c-4925-9f0b-71f74c1151f6	10b8fd36-5de5-42ad-8c4a-a8a4494274ad	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	16:30:00	19:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
91f7feef-f13d-4586-bb22-190304037042	7cc81d84-5d1b-42d9-820b-5f99c9dc2ed3	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	16:30:00	19:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
cc4a256e-4353-455b-8bf2-70a9301a324f	7cc81d84-5d1b-42d9-820b-5f99c9dc2ed3	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	12:00:00	13:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
8c85bc67-f09f-4765-91d4-b123c031e725	05a758ae-a3b8-401f-a768-a948669f601b	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-13	1	13:00:00	16:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
b0ab9c6b-8c11-43c4-933f-897856135660	7cc81d84-5d1b-42d9-820b-5f99c9dc2ed3	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	14:00:00	16:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
8f77e3b8-a03b-42ca-96b9-d59524886300	05a758ae-a3b8-401f-a768-a948669f601b	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-13	1	08:00:00	09:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
98e9b532-ea68-4773-8445-36dd22aca848	610340d4-b744-4046-971e-023a4281ea6c	f91d0839-8da7-4d33-bec1-7b6563b445ad	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	12:00:00	13:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
13d89f49-2156-496d-bac5-1579c4f735c9	610340d4-b744-4046-971e-023a4281ea6c	f91d0839-8da7-4d33-bec1-7b6563b445ad	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	14:00:00	16:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
a5520cc9-62f4-4f1e-b101-c6e0fe4934a3	4d24bf6a-dfc4-46a4-a41d-ecb6e8ad6be4	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-13	1	12:00:00	14:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
40d1caed-df4e-45e6-ab0d-4dd258dae69d	610340d4-b744-4046-971e-023a4281ea6c	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	16:30:00	18:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
581107fb-52c2-47bd-b8f3-0c02c950f177	4d24bf6a-dfc4-46a4-a41d-ecb6e8ad6be4	20c634be-77b2-4a73-9f6e-93bedc05b658	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-13	1	11:00:00	12:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
a1b6f271-b5a9-42c0-96da-bd70d64e1005	7cc683f3-2ea9-40dd-94d9-2af83d2723da	eecdcfc1-afe3-4fea-b614-8a121ba07575	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-13	1	09:00:00	12:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
e64385d6-0b40-4cca-ae99-86d2eedebfa3	7cc683f3-2ea9-40dd-94d9-2af83d2723da	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-13	1	14:00:00	16:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
471412a9-6224-4d41-ad35-cdc41ec7b665	7cc683f3-2ea9-40dd-94d9-2af83d2723da	20c634be-77b2-4a73-9f6e-93bedc05b658	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-13	1	13:00:00	14:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
18560154-f32d-405a-a043-3e339bbd72f3	ae95da63-ec15-4b11-b142-ff6fdb9a7b03	20c634be-77b2-4a73-9f6e-93bedc05b658	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-06-08	1	10:00:00	11:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
97917a6c-cdcd-4743-8e84-0b8d169cfeae	9854d7dc-b664-4d8f-af15-348b20920345	13c4d090-b2db-4397-89d8-025d6588d0c1	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-13	1	08:00:00	12:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
5a26d183-bc25-453a-9683-ab752855d05a	9854d7dc-b664-4d8f-af15-348b20920345	13c4d090-b2db-4397-89d8-025d6588d0c1	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-13	1	13:00:00	14:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
b72266fd-2dc0-499f-9f7d-62d045dcdecf	9854d7dc-b664-4d8f-af15-348b20920345	9a8a5181-bdc8-4431-9a0a-14f52be82896	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-13	1	06:00:00	08:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
3958470d-6dc8-4f07-9fa1-a204d892d336	9c7a22c6-f3ee-4fe2-9955-26c400fd0ace	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-13	1	08:00:00	12:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
de26d19c-a38b-4e1c-8ec7-2d6832c5b1cd	9c7a22c6-f3ee-4fe2-9955-26c400fd0ace	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-13	1	13:00:00	16:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
63ee7dba-925c-401a-aaf7-a9f3b2cebd07	e506fe75-0df4-48ea-ac85-17b42f896982	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-13	1	08:00:00	12:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
940a21d0-277b-4dc1-9ea1-57c7de4aca73	e506fe75-0df4-48ea-ac85-17b42f896982	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-13	1	15:00:00	16:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
8979541d-0dee-406b-8410-576123c0837d	e46010de-9a74-432f-92b6-40b9de20be76	f91d0839-8da7-4d33-bec1-7b6563b445ad	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-13	1	12:00:00	12:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
c8f87c76-2136-43cf-a4e2-e025e2b14820	e46010de-9a74-432f-92b6-40b9de20be76	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-13	1	11:00:00	12:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
f9483e6c-9ee8-4b30-9dbc-3f7b84a24fbb	ae95da63-ec15-4b11-b142-ff6fdb9a7b03	20c634be-77b2-4a73-9f6e-93bedc05b658	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-06-08	1	13:00:00	14:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
a4ed91e0-99ec-42ac-afe9-43a474246231	e46010de-9a74-432f-92b6-40b9de20be76	f91d0839-8da7-4d33-bec1-7b6563b445ad	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-13	1	13:00:00	14:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
247d9bd2-80e1-43db-b409-f3d0a5268bc6	5d89f5b8-1d05-487b-946b-8708e0290a8f	436d7827-0da9-42c1-b1bb-8745a68abb54	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-13	1	17:00:00	18:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
b5665443-5091-4557-a0ba-72e7abf632ff	ae95da63-ec15-4b11-b142-ff6fdb9a7b03	436d7827-0da9-42c1-b1bb-8745a68abb54	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-06-08	1	15:00:00	16:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
632a1d75-4e6f-4c3d-89ba-220f8b07a186	5d89f5b8-1d05-487b-946b-8708e0290a8f	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-13	1	18:00:00	18:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
d7f9b5d0-54ae-4348-95db-fae10bc0b58b	60da7298-fdb8-41f4-ba2d-eff14314ac52	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-13	1	10:00:00	12:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
b7806213-3f41-4590-aac3-4997bd99adfa	60da7298-fdb8-41f4-ba2d-eff14314ac52	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-13	1	17:00:00	18:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
530f0deb-8dc1-4150-bfae-106dbbb533d3	ed254dbb-5433-4617-9a20-f642fada5d3c	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-13	1	11:00:00	12:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
8fdca14d-c562-4ba1-82af-542fca0a4abb	ed254dbb-5433-4617-9a20-f642fada5d3c	436d7827-0da9-42c1-b1bb-8745a68abb54	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-13	1	17:00:00	18:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
858ad284-2a37-495b-94e4-d515338ca1d8	0c3290ed-2e07-4bb2-aee3-c89339f6914f	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-13	1	17:00:00	19:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
9ebfc5b4-4bcf-4017-bbca-3e09b73f4da3	175b1a68-6756-44a3-9810-28d3aa10fda6	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-13	1	10:00:00	14:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
bc5b55a5-6ef7-476c-aabb-4271830393c9	175b1a68-6756-44a3-9810-28d3aa10fda6	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-13	1	14:30:00	18:30:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
fa53262f-63a3-43a7-a1e0-9e91ed580383	d3c6f53f-7209-4221-920c-bdc821b92372	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-13	1	17:00:00	18:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
4e82f958-6839-4c6a-b5e3-debcbaf5cc6c	6e680af6-049c-46f4-8a65-c76c50d29453	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-13	1	17:00:00	18:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
68edd7ec-d772-48a2-ac29-6bfd0c68f752	eafc9a41-ffe5-4cce-ac7b-9e7b0e274d8f	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-13	1	10:00:00	12:00:00	\N	2026-04-12 19:03:44.209891+00	2026-04-12 19:03:44.209891+00
3fb63ece-2560-4844-8988-d53a81250a7e	175b1a68-6756-44a3-9810-28d3aa10fda6	eecdcfc1-afe3-4fea-b614-8a121ba07575	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-15	1	10:00:00	12:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
36d01c64-0218-46e0-a24e-f16b8115981e	5e44115d-118e-4dd5-80c6-30b0bc1260dd	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-15	1	10:00:00	12:00:00	\N	2026-04-12 21:33:15.984486+00	2026-04-12 21:33:15.984486+00
721ac1c7-1869-4bcc-aad9-b56a63bba866	0328b5d2-f6e5-43e9-912e-d775bb7ea114	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	12:00:00	13:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
31e37687-8c07-48a7-84b9-ba944c662ae7	0328b5d2-f6e5-43e9-912e-d775bb7ea114	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	14:00:00	16:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
f26f14c2-1976-4540-93cb-5e75093a5a34	0328b5d2-f6e5-43e9-912e-d775bb7ea114	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	16:30:00	19:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
4f83cea8-2c59-4f6f-88db-0f3a195d35bd	0328b5d2-f6e5-43e9-912e-d775bb7ea114	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	19:15:00	20:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
fefdf737-a8f6-4076-8a13-f3064e58811c	83ec0c51-d0aa-4a2b-95b4-155b87738cb4	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-16	1	10:00:00	11:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
b0c134da-d796-46e6-b571-574aec16ae65	83ec0c51-d0aa-4a2b-95b4-155b87738cb4	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-16	1	12:00:00	14:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
07e24d5f-d8e9-4075-aa01-4e9aa713d603	83ec0c51-d0aa-4a2b-95b4-155b87738cb4	20c634be-77b2-4a73-9f6e-93bedc05b658	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-16	1	14:30:00	16:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
057f084d-7917-4c05-8822-0e847e612a07	83ec0c51-d0aa-4a2b-95b4-155b87738cb4	20c634be-77b2-4a73-9f6e-93bedc05b658	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-16	1	17:00:00	18:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
0eddfa36-d587-4deb-8cda-cf48f1a9df4e	d3b977c5-78be-43bd-b2df-9c6ad004ec64	f01032bd-4de9-40ff-953c-d8a2ddc937f5	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-16	1	06:00:00	07:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
e7f0c6c6-8379-41a3-8306-735868583a74	d3b977c5-78be-43bd-b2df-9c6ad004ec64	f01032bd-4de9-40ff-953c-d8a2ddc937f5	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-16	1	08:00:00	09:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
e994a7c8-c4b5-4147-8980-d5237d6b7fcc	d3b977c5-78be-43bd-b2df-9c6ad004ec64	f01032bd-4de9-40ff-953c-d8a2ddc937f5	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-16	1	10:00:00	12:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
44063b77-19ee-4508-9da5-1ed71fa08822	d3b977c5-78be-43bd-b2df-9c6ad004ec64	f01032bd-4de9-40ff-953c-d8a2ddc937f5	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-16	1	13:00:00	14:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
9adffe91-0522-4490-8f48-c1d678decf8d	0381a248-b039-47ca-a591-41c90db7a78d	20c634be-77b2-4a73-9f6e-93bedc05b658	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	08:00:00	09:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
39870b31-cf53-4ef6-86b5-d8a49ce85974	0381a248-b039-47ca-a591-41c90db7a78d	20c634be-77b2-4a73-9f6e-93bedc05b658	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	10:00:00	12:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
5701f4ec-5414-4d50-a929-ecbb4a4d83f5	0381a248-b039-47ca-a591-41c90db7a78d	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	13:00:00	14:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
da39c792-7d6a-4d6c-83d8-a772e0841bf0	0381a248-b039-47ca-a591-41c90db7a78d	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	15:00:00	16:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
ec024a78-ea23-4e3e-b542-2df7f23b49ad	c451eb0a-6299-4de1-8928-fe10fc43c789	255ce056-e234-417c-8d6a-db745e4bc729	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	12:00:00	13:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
e24f2804-1789-42dd-ace0-83a4c5cb6519	c451eb0a-6299-4de1-8928-fe10fc43c789	255ce056-e234-417c-8d6a-db745e4bc729	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	14:00:00	16:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
8a7aaea1-c328-4dfc-b015-e24b4ef8a8d2	c451eb0a-6299-4de1-8928-fe10fc43c789	255ce056-e234-417c-8d6a-db745e4bc729	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	16:30:00	19:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
00c890f6-1f75-48fc-899d-b33f61996b87	c451eb0a-6299-4de1-8928-fe10fc43c789	255ce056-e234-417c-8d6a-db745e4bc729	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	19:15:00	20:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
f4c73839-ba27-4732-81de-2b62a3cb4f19	9b8c599c-b1ae-4a02-b2e2-eae82615b1c5	20c634be-77b2-4a73-9f6e-93bedc05b658	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	12:00:00	13:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
4fe24c02-a842-4b88-8a57-c3d1845631f5	9b8c599c-b1ae-4a02-b2e2-eae82615b1c5	20c634be-77b2-4a73-9f6e-93bedc05b658	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	14:00:00	16:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
1402eb23-56d2-464a-b597-96870a1348cc	9b8c599c-b1ae-4a02-b2e2-eae82615b1c5	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	16:30:00	19:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
edfa2e8f-37db-4625-9cc5-f0a7c8a3f772	9b8c599c-b1ae-4a02-b2e2-eae82615b1c5	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	19:15:00	20:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
054dd00b-1879-4670-861b-c6d6dc100b49	4e252744-9763-44d4-b1f5-51affb91f884	f01032bd-4de9-40ff-953c-d8a2ddc937f5	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-16	1	16:00:00	18:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
2d6172b3-392b-432c-be50-c8e7612043fe	4e252744-9763-44d4-b1f5-51affb91f884	f01032bd-4de9-40ff-953c-d8a2ddc937f5	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-16	1	18:15:00	20:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
f13a7179-2338-4d0f-98ec-664cfc6751b7	86772cf3-dfaa-4db2-9d2d-e2bdb4241d6c	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-16	1	10:00:00	11:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
c8ac1340-843f-471e-b300-f67c8b5f7586	86772cf3-dfaa-4db2-9d2d-e2bdb4241d6c	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-16	1	12:00:00	14:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
9553f0fd-a635-4bdc-becb-618e23c205d9	86772cf3-dfaa-4db2-9d2d-e2bdb4241d6c	20c634be-77b2-4a73-9f6e-93bedc05b658	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-16	1	14:30:00	16:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
2fae917f-1395-445c-b608-98b72fc228c2	86772cf3-dfaa-4db2-9d2d-e2bdb4241d6c	20c634be-77b2-4a73-9f6e-93bedc05b658	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-16	1	17:00:00	18:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
6dfe1376-1de1-4aad-b6fa-df3b69daddef	3f8de0d0-ef55-4067-ad87-a7310b3cdaf5	436d7827-0da9-42c1-b1bb-8745a68abb54	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-16	1	16:00:00	18:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
b604984c-2265-437a-88e5-e9731ee1075a	3f8de0d0-ef55-4067-ad87-a7310b3cdaf5	f149d680-6b63-40cf-9b1c-5e9d97096f1c	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-16	1	18:15:00	20:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
0bbbdf78-c6f3-4174-8159-38668c64e269	0a6c1e7d-b777-49a7-8a55-a85e63979d98	436d7827-0da9-42c1-b1bb-8745a68abb54	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-16	1	16:00:00	18:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
c1785d86-657f-490d-a738-ee3d596f9beb	0a6c1e7d-b777-49a7-8a55-a85e63979d98	eecdcfc1-afe3-4fea-b614-8a121ba07575	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-16	1	18:15:00	20:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
3a2178af-b0a8-4895-ba73-2f70822d28a8	48cc0745-4e5f-4dda-8ff5-07fa61d6eea7	f149d680-6b63-40cf-9b1c-5e9d97096f1c	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-16	1	16:00:00	18:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
8a8c456f-55d3-4143-b6c8-6df18528efde	48cc0745-4e5f-4dda-8ff5-07fa61d6eea7	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-16	1	18:15:00	20:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
d947de48-3ddb-4306-b609-4f0c14ce82f5	6d1605d8-2318-40ad-b5a9-03feab324fd2	436d7827-0da9-42c1-b1bb-8745a68abb54	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-16	1	10:00:00	12:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
b05b6f70-22ca-4bfe-aca3-c11fcc2833fe	6d1605d8-2318-40ad-b5a9-03feab324fd2	436d7827-0da9-42c1-b1bb-8745a68abb54	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-16	1	13:00:00	14:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
e4d418a1-b1f0-406a-92fd-9c764d0e5d98	6d1605d8-2318-40ad-b5a9-03feab324fd2	9a8a5181-bdc8-4431-9a0a-14f52be82896	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-16	1	06:00:00	07:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
7f35e1ad-917e-4f74-bdf1-6dcb7f84235a	6d1605d8-2318-40ad-b5a9-03feab324fd2	436d7827-0da9-42c1-b1bb-8745a68abb54	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-16	1	08:00:00	09:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
b19bf183-2145-4c3c-9616-f5ee181b0dbb	39b6b948-b93a-47c0-9d72-bd474ca0b1a9	f149d680-6b63-40cf-9b1c-5e9d97096f1c	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-16	1	10:00:00	12:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
efb2dc40-bd9a-4698-8d02-47e0d9e21b4b	39b6b948-b93a-47c0-9d72-bd474ca0b1a9	f149d680-6b63-40cf-9b1c-5e9d97096f1c	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-16	1	13:00:00	14:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
171c2646-f183-4a02-a6e4-fe008cd09e1f	39b6b948-b93a-47c0-9d72-bd474ca0b1a9	436d7827-0da9-42c1-b1bb-8745a68abb54	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-16	1	08:00:00	09:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
99dbcbf4-bfae-46d1-b3d3-a7e09ab91bc2	ea762152-a4ba-4f83-b58c-8e8129348e5b	436d7827-0da9-42c1-b1bb-8745a68abb54	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-16	1	10:00:00	12:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
913b19f9-d300-4695-bb1f-6d85ce96b9e2	ea762152-a4ba-4f83-b58c-8e8129348e5b	436d7827-0da9-42c1-b1bb-8745a68abb54	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-16	1	13:00:00	14:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
269af863-e369-4a06-ad21-b85e5f605fc3	ea762152-a4ba-4f83-b58c-8e8129348e5b	9a8a5181-bdc8-4431-9a0a-14f52be82896	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-16	1	06:00:00	07:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
ca654dad-9ec3-4b69-bd52-f36fb542fe6d	ea762152-a4ba-4f83-b58c-8e8129348e5b	54a2e013-7933-4ba6-bff4-eb07adb05f7e	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-16	1	08:00:00	09:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
beeb2ba0-3814-4d41-92f6-74d71c24ec5c	9854d7dc-b664-4d8f-af15-348b20920345	f149d680-6b63-40cf-9b1c-5e9d97096f1c	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-16	1	10:00:00	12:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
1ce23168-9d65-4db6-b447-8bb23fedea24	9854d7dc-b664-4d8f-af15-348b20920345	f149d680-6b63-40cf-9b1c-5e9d97096f1c	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-16	1	13:00:00	14:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
3c2e5ca0-ba11-470b-8997-98b984e6a098	9854d7dc-b664-4d8f-af15-348b20920345	9a8a5181-bdc8-4431-9a0a-14f52be82896	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-16	1	06:00:00	07:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
9a30f44d-f64a-4069-bb1d-194e6e4ef410	9854d7dc-b664-4d8f-af15-348b20920345	13c4d090-b2db-4397-89d8-025d6588d0c1	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-16	1	08:00:00	09:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
288b7656-ba91-41a0-a63c-caedfb1e0a08	fd1ab8e1-89e7-49f1-b029-41ed3b1565bd	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	15:00:00	16:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
a857ed5d-4ef3-4a27-a6d4-ab17d9f4cf42	fd1ab8e1-89e7-49f1-b029-41ed3b1565bd	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	10:00:00	12:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
7ede428e-211e-48a9-8879-01f6bc3e017c	fd1ab8e1-89e7-49f1-b029-41ed3b1565bd	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	13:00:00	14:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
d6fe213d-0cf9-474a-9bdd-bb5b43858f87	fd1ab8e1-89e7-49f1-b029-41ed3b1565bd	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	08:00:00	09:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
2080864a-de53-4941-a9d2-eabc838b6373	ae95da63-ec15-4b11-b142-ff6fdb9a7b03	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-06-08	1	16:00:00	16:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
2ee67398-da81-4ed8-8def-a68175712bfc	e940eada-79a1-440e-851e-2dfb9b92b693	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	15:00:00	16:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
0f5a73cb-5512-4c0e-95fc-6072fc7dab3d	e940eada-79a1-440e-851e-2dfb9b92b693	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	13:00:00	14:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
87c1b10f-49e5-4018-9227-470226718b1f	e940eada-79a1-440e-851e-2dfb9b92b693	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	10:00:00	12:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
ee719e6e-5d00-4ae7-af32-4d3c3d26b7a7	e940eada-79a1-440e-851e-2dfb9b92b693	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	08:00:00	09:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
38786e68-d289-43da-a321-a0714962fa30	5f926628-1321-410f-835a-a1701355219d	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	15:00:00	16:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
869fef2f-9e7c-4bae-b8a0-08099b901569	5f926628-1321-410f-835a-a1701355219d	20c634be-77b2-4a73-9f6e-93bedc05b658	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	10:00:00	12:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
c76b19d2-6797-411d-af84-121da6826b59	5f926628-1321-410f-835a-a1701355219d	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	13:00:00	14:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
94317fe4-4a60-496a-bd1c-9865aecad5b6	5f926628-1321-410f-835a-a1701355219d	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	08:00:00	09:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
ee23da4f-0f53-4cbf-86cf-5aebaad0f609	0c3290ed-2e07-4bb2-aee3-c89339f6914f	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	12:00:00	13:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
c93a514d-815f-4533-968a-476d7eaa055a	343cd39e-8d18-4812-a6d0-d9f480dc9cb9	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	15:00:00	16:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
86b2e33a-fd2a-46e6-beb7-091579261f1c	343cd39e-8d18-4812-a6d0-d9f480dc9cb9	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	13:00:00	14:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
88538ebd-0c59-4eb4-984f-23b27ec1315b	343cd39e-8d18-4812-a6d0-d9f480dc9cb9	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	11:00:00	12:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
bfe2bdb4-ebc4-423d-8518-1e2dcfc6f284	0c3290ed-2e07-4bb2-aee3-c89339f6914f	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	14:00:00	16:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
aedd921d-3f13-4cf2-8ed4-a4ef0a2d3f18	0c3290ed-2e07-4bb2-aee3-c89339f6914f	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	16:30:00	19:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
3af20e15-6b52-48c7-8fb0-a17bd9590c64	8a7bf4f5-92de-48eb-a2bc-18dae9992013	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	15:00:00	16:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
b20787a9-12f8-4f2f-892a-50e742a21d96	8c25fe94-99d4-44dd-9652-efe248083bb9	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	12:00:00	13:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
7b66ec05-e276-4a5d-a1dd-80277c18e281	8a7bf4f5-92de-48eb-a2bc-18dae9992013	20c634be-77b2-4a73-9f6e-93bedc05b658	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	13:00:00	14:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
cbf334b4-6173-4df6-a90b-604038a0aad0	8a7bf4f5-92de-48eb-a2bc-18dae9992013	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	08:00:00	09:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
d6ce39e3-417b-4624-ae6d-8225f70a8008	8a7bf4f5-92de-48eb-a2bc-18dae9992013	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	14:00:00	14:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
1d74208b-e3ec-4536-9f85-d15328e2f499	8c870a0e-09ee-4f8d-9fa4-df771f36c4af	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	15:00:00	16:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
7da8236e-05d5-4192-af52-ac39c8680c14	8c870a0e-09ee-4f8d-9fa4-df771f36c4af	fb4fe76d-c487-4dc4-9de4-69a28896bc93	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	10:00:00	12:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
1a3bfe2b-a42d-4d14-a48e-b1d39669c996	8c870a0e-09ee-4f8d-9fa4-df771f36c4af	fb4fe76d-c487-4dc4-9de4-69a28896bc93	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	13:00:00	14:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
b0bf4258-c2ef-4da7-8171-f86cf58023bd	9c7a22c6-f3ee-4fe2-9955-26c400fd0ace	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	10:00:00	12:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
7040e307-c9a1-4c90-8c63-63d0777f3df1	9c7a22c6-f3ee-4fe2-9955-26c400fd0ace	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	13:00:00	14:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
127df747-d863-4a79-832a-5ff06367b59c	9c7a22c6-f3ee-4fe2-9955-26c400fd0ace	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	15:00:00	16:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
bb3993ff-4089-4152-a956-a808481fbe20	9c7a22c6-f3ee-4fe2-9955-26c400fd0ace	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	08:00:00	09:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
b0b935d2-638c-4b7d-aaeb-3e2791c7982f	e506fe75-0df4-48ea-ac85-17b42f896982	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	10:00:00	12:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
ee6b1d49-a824-4e06-a3ba-afb7ba11527f	e506fe75-0df4-48ea-ac85-17b42f896982	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	13:00:00	14:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
a82ad86f-0890-428f-94df-14e00e737305	e506fe75-0df4-48ea-ac85-17b42f896982	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	15:00:00	16:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
c0b452c0-9094-4b11-9ebd-9b372202b3d5	e506fe75-0df4-48ea-ac85-17b42f896982	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	08:00:00	09:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
e7b5d593-ca3f-493c-8ba5-c9dab02e88aa	8c25fe94-99d4-44dd-9652-efe248083bb9	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	14:00:00	16:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
ce71ca52-2f47-4360-a928-43f1527c6e6d	e46010de-9a74-432f-92b6-40b9de20be76	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	15:00:00	16:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
6fd35b08-ae16-402e-9440-6c8a7e67a3d6	e46010de-9a74-432f-92b6-40b9de20be76	f91d0839-8da7-4d33-bec1-7b6563b445ad	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	08:00:00	09:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
9f90f5be-e237-4669-8ccc-905c8af886cc	14e6a58a-9286-479d-af56-fb4f1cc680dc	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	12:00:00	13:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
ed360573-e7a1-48b7-b55c-15056fd666c4	05a758ae-a3b8-401f-a768-a948669f601b	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	10:00:00	12:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
c1828887-5663-4f49-b7d5-93130fd331d4	05a758ae-a3b8-401f-a768-a948669f601b	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	13:00:00	14:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
6a1433d9-5f5b-481c-bf25-f653c3a12090	05a758ae-a3b8-401f-a768-a948669f601b	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	15:00:00	16:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
f8328530-df1e-4b02-8a5e-d330b85fc7c3	05a758ae-a3b8-401f-a768-a948669f601b	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	08:00:00	09:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
28091ee5-82dc-41a2-b6c7-c0466613809b	7cc683f3-2ea9-40dd-94d9-2af83d2723da	eecdcfc1-afe3-4fea-b614-8a121ba07575	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	10:00:00	12:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
2814cb23-a810-490a-88dd-2e6b6bb24600	7cc683f3-2ea9-40dd-94d9-2af83d2723da	eecdcfc1-afe3-4fea-b614-8a121ba07575	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	13:00:00	14:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
21456342-6e94-4ff8-989c-aaec6a13e40f	7cc683f3-2ea9-40dd-94d9-2af83d2723da	eecdcfc1-afe3-4fea-b614-8a121ba07575	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	15:00:00	16:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
46aefc4b-4040-4597-ae6b-a580f074e689	7cc683f3-2ea9-40dd-94d9-2af83d2723da	eecdcfc1-afe3-4fea-b614-8a121ba07575	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-16	1	09:00:00	09:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
a0453da9-606a-41c8-851b-64f812a96cd7	1b11d981-a65d-46bd-8220-700df1acf99f	436d7827-0da9-42c1-b1bb-8745a68abb54	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-16	1	17:00:00	18:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
be0744be-458d-43b1-98ad-db7c90377301	1b11d981-a65d-46bd-8220-700df1acf99f	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-16	1	12:00:00	14:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
59167bed-2646-48f4-bb01-ccb26277fbbb	14e6a58a-9286-479d-af56-fb4f1cc680dc	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	14:00:00	16:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
dc1427de-75b5-4ff1-a51b-86bd53a954f3	d3c6f53f-7209-4221-920c-bdc821b92372	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	12:00:00	13:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
92f5f4c2-ee8f-4b0a-ba78-987783c7da9d	6d85775f-a88d-472b-876c-265b4f483da5	436d7827-0da9-42c1-b1bb-8745a68abb54	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-16	1	17:00:00	18:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
a96236a3-4a74-44eb-9a58-db8517e7abf4	d3c6f53f-7209-4221-920c-bdc821b92372	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7a06632f-324d-4050-aea1-c8799611ccd0	2026-06-08	1	14:00:00	16:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
c396e038-b58d-4a23-91d4-b8d94a7b77b0	6d85775f-a88d-472b-876c-265b4f483da5	436d7827-0da9-42c1-b1bb-8745a68abb54	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-16	1	12:00:00	14:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
bb17df6d-382b-44fc-949b-6fdada118c01	6d85775f-a88d-472b-876c-265b4f483da5	20c634be-77b2-4a73-9f6e-93bedc05b658	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-16	1	11:00:00	11:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
ae25b272-ce70-4e1e-bb34-ab2057075b5c	7892a694-bf37-41fa-b2ba-64f69230f4e4	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-16	1	17:00:00	18:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
b0cb2d17-37ca-410b-a719-66ae3d847257	ed254dbb-5433-4617-9a20-f642fada5d3c	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-06-08	1	10:00:00	11:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
dc3fdd46-7465-408c-add2-ffb0245114f5	60da7298-fdb8-41f4-ba2d-eff14314ac52	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-06-08	1	10:00:00	11:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
e0f2a727-9b97-4890-9183-3eee52d41706	eafc9a41-ffe5-4cce-ac7b-9e7b0e274d8f	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-06-08	1	10:00:00	11:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
eb4b1336-5c56-432e-a634-08741a7242fe	4d24bf6a-dfc4-46a4-a41d-ecb6e8ad6be4	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-16	1	17:00:00	18:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
666e5eba-7908-49fc-b27a-bec135b76720	5cc3bb12-e940-4880-94e6-cfe1427ecfc6	436d7827-0da9-42c1-b1bb-8745a68abb54	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-06-08	1	10:00:00	11:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
b4e55438-de64-4d58-af8d-e7ed9084924f	4d24bf6a-dfc4-46a4-a41d-ecb6e8ad6be4	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-16	1	11:00:00	11:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
7bbe55c0-f4e1-4320-a445-24c9b8247bb4	5d89f5b8-1d05-487b-946b-8708e0290a8f	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-06-08	1	10:00:00	11:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
6bb5df3b-6a62-4847-b8cb-2310f6ec9068	4d24bf6a-dfc4-46a4-a41d-ecb6e8ad6be4	f91d0839-8da7-4d33-bec1-7b6563b445ad	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-06-08	1	10:00:00	11:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
593b513b-4b53-4329-9c31-4e17ba6e4822	ae95da63-ec15-4b11-b142-ff6fdb9a7b03	436d7827-0da9-42c1-b1bb-8745a68abb54	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-16	1	17:00:00	18:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
0a8593cf-48ca-4a80-8de6-384f78899df4	ae95da63-ec15-4b11-b142-ff6fdb9a7b03	f91d0839-8da7-4d33-bec1-7b6563b445ad	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-16	1	10:00:00	11:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
8d23dd1d-80a1-486e-8622-ebfb5dd789d4	ed254dbb-5433-4617-9a20-f642fada5d3c	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-16	1	17:00:00	18:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
f22037d6-1be1-4ee1-9927-8a50074a0ab6	ed254dbb-5433-4617-9a20-f642fada5d3c	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-16	1	14:30:00	16:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
546d8683-397e-44a3-9692-12a106c8b50d	ed254dbb-5433-4617-9a20-f642fada5d3c	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-16	1	12:00:00	14:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
b5cbc9e7-1feb-49c2-8e41-7141dc970d53	ed254dbb-5433-4617-9a20-f642fada5d3c	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-16	1	10:00:00	11:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
2e82a6de-3511-4cd9-bea1-7ea5b5f5cc93	5cc3bb12-e940-4880-94e6-cfe1427ecfc6	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-16	1	14:30:00	16:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
93c51b09-c485-4f73-9781-cdbd166fd39d	5cc3bb12-e940-4880-94e6-cfe1427ecfc6	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-16	1	10:00:00	11:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
bf54aff0-5d91-4634-b4ff-8b483bcc9000	5cc3bb12-e940-4880-94e6-cfe1427ecfc6	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-16	1	12:00:00	14:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
effa15d8-9fee-4cac-9e2c-bf552a0f535c	5cc3bb12-e940-4880-94e6-cfe1427ecfc6	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-16	1	17:00:00	18:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
5374db13-7d4f-4e29-8f27-4f90ead5895f	fd1ab8e1-89e7-49f1-b029-41ed3b1565bd	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-06-08	1	08:00:00	09:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
6165cc6d-5892-41af-8edd-64151a63059f	fd1ab8e1-89e7-49f1-b029-41ed3b1565bd	20c634be-77b2-4a73-9f6e-93bedc05b658	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-06-08	1	11:00:00	12:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
a5d77a29-178b-40ff-9474-cfb0e7ba7bc5	e940eada-79a1-440e-851e-2dfb9b92b693	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-06-08	1	08:00:00	09:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
98f4bae7-c787-4a2e-b25d-b9ba6393392f	60da7298-fdb8-41f4-ba2d-eff14314ac52	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-16	1	17:00:00	18:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
988c8d8b-80d5-48ac-8b81-66fdb57f9c8b	e940eada-79a1-440e-851e-2dfb9b92b693	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-06-08	1	11:00:00	12:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
a7b00435-133a-4c99-91da-120c1f7bb500	5f926628-1321-410f-835a-a1701355219d	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-06-08	1	08:00:00	09:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
4110e53f-75fc-4683-bcf6-0675e02687b2	60da7298-fdb8-41f4-ba2d-eff14314ac52	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-16	1	11:00:00	11:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
ba5c576a-e290-4f4e-94ac-8553ce0a6465	eafc9a41-ffe5-4cce-ac7b-9e7b0e274d8f	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-16	1	17:00:00	18:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
d4677cb4-503b-46a2-b3a9-c4625d6b2d90	5f926628-1321-410f-835a-a1701355219d	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-06-08	1	09:00:00	09:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
6261a684-976d-42cd-b3c4-85a4e5cd877c	eafc9a41-ffe5-4cce-ac7b-9e7b0e274d8f	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-16	1	10:00:00	11:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
3f980428-7ebc-481c-94b0-3c3af1d09a75	5f926628-1321-410f-835a-a1701355219d	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-06-08	1	11:00:00	12:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
9cb755c4-b5cd-4769-8682-5528b8d2fbc1	343cd39e-8d18-4812-a6d0-d9f480dc9cb9	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-06-08	1	08:00:00	09:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
7eaf9a75-50be-4e86-8426-bce02607dd73	8a7bf4f5-92de-48eb-a2bc-18dae9992013	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-06-08	1	08:00:00	09:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
a5653bc7-24f8-41d1-bbc4-533e3b1e5caf	175b1a68-6756-44a3-9810-28d3aa10fda6	fb4fe76d-c487-4dc4-9de4-69a28896bc93	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-16	1	17:00:00	18:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
8c0d5778-d9f5-42cc-82e0-9ab12f56db4e	39b6b948-b93a-47c0-9d72-bd474ca0b1a9	f91d0839-8da7-4d33-bec1-7b6563b445ad	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-06-08	1	08:00:00	09:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
ed330fb0-6cc2-483c-9382-93a5a86b1e6b	e46010de-9a74-432f-92b6-40b9de20be76	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-06-08	1	08:00:00	09:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
23c8db1e-54b7-4bbd-b5ea-93073813df92	8c870a0e-09ee-4f8d-9fa4-df771f36c4af	fb4fe76d-c487-4dc4-9de4-69a28896bc93	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-06-08	1	10:00:00	12:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
f711ed5b-7fcf-4acd-a4a4-467057c4f67a	05a758ae-a3b8-401f-a768-a948669f601b	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-06-08	1	08:00:00	09:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
f17b7c5a-944e-439f-99da-bdcbd6bab8e1	05a758ae-a3b8-401f-a768-a948669f601b	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-06-08	1	10:00:00	12:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
a71bfab2-7e03-4909-a4af-976e04a855cb	631a0690-b2e4-4267-b5cf-3d16d87c264b	436d7827-0da9-42c1-b1bb-8745a68abb54	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	15:00:00	16:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
4f117bee-ad2a-4af3-822c-380d258bcc0f	ea762152-a4ba-4f83-b58c-8e8129348e5b	9a8a5181-bdc8-4431-9a0a-14f52be82896	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-06-08	1	06:00:00	07:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
1f6fd00d-9860-4dc8-922f-b82d6ef5dd7d	9c7a22c6-f3ee-4fe2-9955-26c400fd0ace	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-06-08	1	08:00:00	09:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
8be56243-75e0-4d74-a7b7-966e736f238b	fda9b996-4df4-4ab4-bf71-2de86e81ea52	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	14:00:00	16:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
a74c59ff-f3fa-4404-93b6-1b6bf929f9af	9c7a22c6-f3ee-4fe2-9955-26c400fd0ace	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-06-08	1	10:00:00	12:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
18ab733c-47b9-4494-a66b-c8695dd4569f	e506fe75-0df4-48ea-ac85-17b42f896982	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-06-08	1	08:00:00	09:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
c96a1134-6ed4-4afa-a8dc-c90ad6af9d0f	fda9b996-4df4-4ab4-bf71-2de86e81ea52	20c634be-77b2-4a73-9f6e-93bedc05b658	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	13:00:00	13:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
5bd54072-045a-4176-a3ec-d56476ef9b32	e506fe75-0df4-48ea-ac85-17b42f896982	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-06-08	1	11:00:00	12:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
0575dc7f-d304-4e05-8de1-709e69d47dd8	fda9b996-4df4-4ab4-bf71-2de86e81ea52	20c634be-77b2-4a73-9f6e-93bedc05b658	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	16:30:00	17:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
db219005-34cd-4958-9666-ea519815ef33	14e6a58a-9286-479d-af56-fb4f1cc680dc	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	14:00:00	16:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
6833f4b0-2c9d-4073-80be-9434fdf66908	7cc683f3-2ea9-40dd-94d9-2af83d2723da	eecdcfc1-afe3-4fea-b614-8a121ba07575	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-06-08	1	10:00:00	12:00:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
0483b9d5-9702-4893-862e-4dfe7d0ffc31	7cc683f3-2ea9-40dd-94d9-2af83d2723da	eecdcfc1-afe3-4fea-b614-8a121ba07575	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-06-08	1	09:00:00	09:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
c6c09758-45b8-4413-a8bb-7071b3f75371	175b1a68-6756-44a3-9810-28d3aa10fda6	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-06-08	1	10:00:00	11:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
96ab0449-60fb-430c-9baa-aa16d9b01e36	14e6a58a-9286-479d-af56-fb4f1cc680dc	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	12:00:00	13:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
4982368f-baf1-4016-99da-e2799742ea0b	9854d7dc-b664-4d8f-af15-348b20920345	9a8a5181-bdc8-4431-9a0a-14f52be82896	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-06-08	1	06:00:00	07:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
55129ded-cfd9-4dc0-906a-28af1fcd98d5	9854d7dc-b664-4d8f-af15-348b20920345	13c4d090-b2db-4397-89d8-025d6588d0c1	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-06-08	1	10:00:00	12:30:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
92afb827-8cd3-4d30-a947-1274925b8024	9854d7dc-b664-4d8f-af15-348b20920345	13c4d090-b2db-4397-89d8-025d6588d0c1	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-06-08	1	13:00:00	14:30:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
e030652e-eb63-4c64-bd3a-ff1aaaca6b6b	9854d7dc-b664-4d8f-af15-348b20920345	13c4d090-b2db-4397-89d8-025d6588d0c1	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-06-08	1	08:00:00	09:45:00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:07:19.876344+00	2026-06-08 00:07:19.876344+00
2f1b18fd-1e91-4d22-b4c7-3cc489212dac	91e5fbf6-b35e-489d-8bec-d77e32facc25	fb4fe76d-c487-4dc4-9de4-69a28896bc93	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	15:00:00	16:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
ff802e03-0948-4c7f-bb18-f0708198000e	91e5fbf6-b35e-489d-8bec-d77e32facc25	fb4fe76d-c487-4dc4-9de4-69a28896bc93	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	16:30:00	17:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
109365f7-4fe5-46e6-b2d7-72efc3bb2776	58119498-aa74-4a50-b937-ef362d96849e	f91d0839-8da7-4d33-bec1-7b6563b445ad	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	12:00:00	13:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
33a7e2ff-3459-47bc-9deb-3333dec95c81	58119498-aa74-4a50-b937-ef362d96849e	f91d0839-8da7-4d33-bec1-7b6563b445ad	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	14:00:00	16:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
b502a20e-56ef-4073-a1b5-b455605cdfee	58119498-aa74-4a50-b937-ef362d96849e	f91d0839-8da7-4d33-bec1-7b6563b445ad	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	16:30:00	17:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
53bcc1d8-4b4e-4872-8796-4abf3a55f8c9	6a5611b1-a04b-43d0-8c35-a810d393a0aa	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	16:30:00	19:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
fce68ef0-d6f0-4c46-a034-12301d04d28c	6a5611b1-a04b-43d0-8c35-a810d393a0aa	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	12:00:00	13:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
4efd5b5b-93e1-41f0-a394-d38ac520e620	6a5611b1-a04b-43d0-8c35-a810d393a0aa	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	14:00:00	16:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
06e20a3b-d2b4-4fe2-93fc-8a402a76956b	30b6df55-a118-4b1b-8df1-c5663a701ed2	436d7827-0da9-42c1-b1bb-8745a68abb54	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	15:00:00	16:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
2a0154c0-5f47-4520-8078-b68cc7f68d2d	df1d7a4b-33db-4bd9-855b-a6d8f97360a1	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	12:00:00	13:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
4bd8948a-01c5-47b7-b918-cd686b1059d9	df1d7a4b-33db-4bd9-855b-a6d8f97360a1	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	14:00:00	16:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
1e1f075d-1121-45de-9dab-881f9c29b39d	df1d7a4b-33db-4bd9-855b-a6d8f97360a1	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	16:30:00	17:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
a1c1f832-fca4-4345-b613-99f7d452cd4c	0c3290ed-2e07-4bb2-aee3-c89339f6914f	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	17:00:00	19:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
54350270-0548-46f7-b71e-f157c1bfe28f	a4b4e8b3-39d4-486f-917b-cbdf54b204a3	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	19:15:00	20:30:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
f14c2ea5-2cff-4ec9-9986-a000ce57dd92	a4b4e8b3-39d4-486f-917b-cbdf54b204a3	eecdcfc1-afe3-4fea-b614-8a121ba07575	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	17:00:00	18:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
6bdbd07e-fbc0-4a55-8c9c-022922438af6	610340d4-b744-4046-971e-023a4281ea6c	f91d0839-8da7-4d33-bec1-7b6563b445ad	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	17:00:00	18:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
041a7282-4273-4322-88ef-c2e6de7272ff	610340d4-b744-4046-971e-023a4281ea6c	20c634be-77b2-4a73-9f6e-93bedc05b658	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	19:15:00	20:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
132e5dc2-d7aa-4563-9d96-654204f2603c	7dbb9f67-2b06-4c44-b4f6-94b8f4bdaad4	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	16:30:00	19:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
5edd1416-eb22-41ed-9e86-34ffd46deb6a	7dbb9f67-2b06-4c44-b4f6-94b8f4bdaad4	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	12:00:00	13:45:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
184618fe-3193-4ad6-9b24-1593d0ca5366	7dbb9f67-2b06-4c44-b4f6-94b8f4bdaad4	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	14:00:00	16:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
554c077b-c28c-4d3b-aca3-8a3827008cbf	7dbb9f67-2b06-4c44-b4f6-94b8f4bdaad4	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	19:15:00	20:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
53edf63d-f9e0-4dd4-b380-ff5bbe058a57	740ee69c-06c1-4a3b-a75c-19ab454b2775	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	17:00:00	18:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
d16581b3-eb1d-4092-b839-be6d4e53460a	740ee69c-06c1-4a3b-a75c-19ab454b2775	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	19:15:00	20:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
218a78ba-054f-49ef-b4b3-21995eb6ec6c	d3c6f53f-7209-4221-920c-bdc821b92372	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-16	1	17:00:00	18:00:00	\N	2026-04-12 22:50:08.13764+00	2026-04-12 22:50:08.13764+00
e06f7878-cf5e-450a-b318-758ad3f18f73	0328b5d2-f6e5-43e9-912e-d775bb7ea114	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	12:00:00	13:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
bbb39a9c-71e8-4ccc-85ae-30c6b3fa2a36	0328b5d2-f6e5-43e9-912e-d775bb7ea114	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	14:00:00	16:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
d6ab1c61-d8b7-4f88-aaf4-35e6e1284a51	0328b5d2-f6e5-43e9-912e-d775bb7ea114	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	16:30:00	19:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
8ebebeab-b9b1-4bb0-b273-32add8e0cb74	0328b5d2-f6e5-43e9-912e-d775bb7ea114	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	19:15:00	20:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
72924fc2-20dd-4bf6-9923-ad3f76a779b1	83ec0c51-d0aa-4a2b-95b4-155b87738cb4	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	10:00:00	11:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
c14034e4-ef5d-4ab2-84c5-2090b2118aa4	83ec0c51-d0aa-4a2b-95b4-155b87738cb4	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	12:00:00	14:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
a6c1578d-2927-4345-b07b-fa6b275ad4f6	83ec0c51-d0aa-4a2b-95b4-155b87738cb4	20c634be-77b2-4a73-9f6e-93bedc05b658	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	14:30:00	16:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
3f2bf081-a59d-45bb-837e-10a876ff2e5c	83ec0c51-d0aa-4a2b-95b4-155b87738cb4	20c634be-77b2-4a73-9f6e-93bedc05b658	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	17:00:00	18:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
0124f22e-048a-40c2-8926-97f8bda595b0	d3b977c5-78be-43bd-b2df-9c6ad004ec64	f01032bd-4de9-40ff-953c-d8a2ddc937f5	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-12	1	06:00:00	07:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
97c813dc-2afb-40b3-b817-4651fafb61f5	d3b977c5-78be-43bd-b2df-9c6ad004ec64	f01032bd-4de9-40ff-953c-d8a2ddc937f5	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-12	1	08:00:00	09:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
09b9701b-23b5-45d5-a152-dc8c6f1f6b8c	d3b977c5-78be-43bd-b2df-9c6ad004ec64	f01032bd-4de9-40ff-953c-d8a2ddc937f5	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-12	1	10:00:00	12:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
3dc9aa7d-d2d4-4fdf-955c-2a3256310e36	d3b977c5-78be-43bd-b2df-9c6ad004ec64	f01032bd-4de9-40ff-953c-d8a2ddc937f5	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-12	1	13:00:00	14:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
a849bc36-ae82-406c-aff2-1593fa4b0fc8	0381a248-b039-47ca-a591-41c90db7a78d	20c634be-77b2-4a73-9f6e-93bedc05b658	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	08:00:00	09:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
beb73221-cfbc-4582-b392-cd2c69f3eb0d	0381a248-b039-47ca-a591-41c90db7a78d	20c634be-77b2-4a73-9f6e-93bedc05b658	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	10:00:00	12:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
3b6dc932-111b-4b8f-8eac-3826541ff5e1	0381a248-b039-47ca-a591-41c90db7a78d	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	13:00:00	14:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
bcaea7b5-99e1-4cb7-84d6-cb3b90019b4c	0381a248-b039-47ca-a591-41c90db7a78d	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	15:00:00	16:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
56277cee-f6df-41aa-ab05-0570046c79ff	c451eb0a-6299-4de1-8928-fe10fc43c789	255ce056-e234-417c-8d6a-db745e4bc729	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	12:00:00	13:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
453c980c-24f5-4e3b-ace5-00b1bfc182ca	c451eb0a-6299-4de1-8928-fe10fc43c789	255ce056-e234-417c-8d6a-db745e4bc729	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	14:00:00	16:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
06bd8aa8-6a06-40da-a1b3-530f226390c9	c451eb0a-6299-4de1-8928-fe10fc43c789	255ce056-e234-417c-8d6a-db745e4bc729	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	16:30:00	19:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
eff3ad8c-8621-4bec-a066-d6f967f83638	c451eb0a-6299-4de1-8928-fe10fc43c789	255ce056-e234-417c-8d6a-db745e4bc729	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	19:15:00	20:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
ad893ee1-5570-4f95-afe4-0bd96e378ebd	9b8c599c-b1ae-4a02-b2e2-eae82615b1c5	20c634be-77b2-4a73-9f6e-93bedc05b658	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	12:00:00	13:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
9f0a1e7c-1aa7-4477-aef7-38b9a09e2177	9b8c599c-b1ae-4a02-b2e2-eae82615b1c5	20c634be-77b2-4a73-9f6e-93bedc05b658	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	14:00:00	16:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
70675f41-ee8e-4ed3-912a-bcc5ddec21aa	9b8c599c-b1ae-4a02-b2e2-eae82615b1c5	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	16:30:00	19:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
f6f1feaf-9a19-464c-b281-3e4ba5ba94c4	9b8c599c-b1ae-4a02-b2e2-eae82615b1c5	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	19:15:00	20:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
212493ec-3dd9-4826-9ed3-db7252d0ee9c	4e252744-9763-44d4-b1f5-51affb91f884	f01032bd-4de9-40ff-953c-d8a2ddc937f5	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-12	1	16:00:00	18:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
c6010934-b48e-47c8-830a-5e19874f9b10	4e252744-9763-44d4-b1f5-51affb91f884	f01032bd-4de9-40ff-953c-d8a2ddc937f5	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-12	1	18:15:00	20:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
eb5f3b4d-5297-46c1-a9f7-e2b7122ca824	86772cf3-dfaa-4db2-9d2d-e2bdb4241d6c	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	10:00:00	11:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
2433cc6c-0e34-4f92-9056-69968bf8fc15	86772cf3-dfaa-4db2-9d2d-e2bdb4241d6c	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	12:00:00	14:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
b2569a28-db26-4c76-8698-a8fe7238ffc9	86772cf3-dfaa-4db2-9d2d-e2bdb4241d6c	20c634be-77b2-4a73-9f6e-93bedc05b658	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	14:30:00	16:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
efa233f5-9e80-46a8-a6c1-b7546e49b0f3	86772cf3-dfaa-4db2-9d2d-e2bdb4241d6c	20c634be-77b2-4a73-9f6e-93bedc05b658	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	17:00:00	18:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
a74b2bb7-5d8c-4755-b3b6-1bdcdcbc87c5	3f8de0d0-ef55-4067-ad87-a7310b3cdaf5	436d7827-0da9-42c1-b1bb-8745a68abb54	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-12	1	16:00:00	18:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
29c4717e-e5aa-4d77-81c4-eb57adfc859f	3f8de0d0-ef55-4067-ad87-a7310b3cdaf5	f149d680-6b63-40cf-9b1c-5e9d97096f1c	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-12	1	18:15:00	20:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
6d0bfde2-c514-403e-b652-0752bb00525b	0a6c1e7d-b777-49a7-8a55-a85e63979d98	436d7827-0da9-42c1-b1bb-8745a68abb54	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-12	1	16:00:00	18:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
33b24302-5200-4ead-9335-8b5905ce62b7	0a6c1e7d-b777-49a7-8a55-a85e63979d98	eecdcfc1-afe3-4fea-b614-8a121ba07575	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-12	1	18:15:00	20:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
e2012148-0d87-4125-b96b-4a58b80f89e9	48cc0745-4e5f-4dda-8ff5-07fa61d6eea7	f149d680-6b63-40cf-9b1c-5e9d97096f1c	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-12	1	16:00:00	18:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
e03e007e-20e6-4fc6-8c6e-d8d2aaec6819	48cc0745-4e5f-4dda-8ff5-07fa61d6eea7	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-12	1	18:15:00	20:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
3cd15c97-e110-4cf2-923a-661045d74925	6d1605d8-2318-40ad-b5a9-03feab324fd2	436d7827-0da9-42c1-b1bb-8745a68abb54	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-12	1	10:00:00	12:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
bb4eb0be-c77e-4b79-b757-058293df37be	6d1605d8-2318-40ad-b5a9-03feab324fd2	436d7827-0da9-42c1-b1bb-8745a68abb54	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-12	1	13:00:00	14:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
dc0b9a86-7ce0-4ddd-9700-fc3d8300237b	6d1605d8-2318-40ad-b5a9-03feab324fd2	9a8a5181-bdc8-4431-9a0a-14f52be82896	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-12	1	06:00:00	07:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
b86f157a-a083-46c8-a301-c4ab14b1fe79	6d1605d8-2318-40ad-b5a9-03feab324fd2	436d7827-0da9-42c1-b1bb-8745a68abb54	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-12	1	08:00:00	09:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
ffdd3e5e-5199-49f5-b9a6-6b0b2c6bfc33	39b6b948-b93a-47c0-9d72-bd474ca0b1a9	f149d680-6b63-40cf-9b1c-5e9d97096f1c	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-12	1	10:00:00	12:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
60de34cb-8cbf-4886-b2f2-2add947d7d51	39b6b948-b93a-47c0-9d72-bd474ca0b1a9	f149d680-6b63-40cf-9b1c-5e9d97096f1c	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-12	1	13:00:00	14:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
7803b413-fb06-4fa5-bd2c-17af469d9bb7	39b6b948-b93a-47c0-9d72-bd474ca0b1a9	436d7827-0da9-42c1-b1bb-8745a68abb54	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-12	1	08:00:00	09:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
90732e46-23ce-4dfc-82ef-26ae9f507d37	ea762152-a4ba-4f83-b58c-8e8129348e5b	436d7827-0da9-42c1-b1bb-8745a68abb54	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-12	1	10:00:00	12:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
a362e536-81ff-48fa-aa3c-7f89e023bd3a	ea762152-a4ba-4f83-b58c-8e8129348e5b	436d7827-0da9-42c1-b1bb-8745a68abb54	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-12	1	13:00:00	14:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
72208968-bd50-4e58-8152-4c717f2032ee	ea762152-a4ba-4f83-b58c-8e8129348e5b	9a8a5181-bdc8-4431-9a0a-14f52be82896	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-12	1	06:00:00	07:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
07b27b57-3200-4f8b-9c22-6af6f6c56efc	ea762152-a4ba-4f83-b58c-8e8129348e5b	54a2e013-7933-4ba6-bff4-eb07adb05f7e	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-12	1	08:00:00	09:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
75cb4642-1066-4dbb-8695-fdbdc6201970	9854d7dc-b664-4d8f-af15-348b20920345	f149d680-6b63-40cf-9b1c-5e9d97096f1c	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-12	1	10:00:00	12:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
75bbf8fa-b0ba-4912-ad6e-d5425afbf449	9854d7dc-b664-4d8f-af15-348b20920345	f149d680-6b63-40cf-9b1c-5e9d97096f1c	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-12	1	13:00:00	14:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
1a347f36-367b-47db-90fb-0ac3b0c2dd2a	9854d7dc-b664-4d8f-af15-348b20920345	9a8a5181-bdc8-4431-9a0a-14f52be82896	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-12	1	06:00:00	07:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
d7529ede-d02a-4d03-98de-163ab434cdc2	9854d7dc-b664-4d8f-af15-348b20920345	13c4d090-b2db-4397-89d8-025d6588d0c1	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-12	1	08:00:00	09:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
ddd945e9-b994-42b8-9888-bc75127a4b44	fd1ab8e1-89e7-49f1-b029-41ed3b1565bd	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	15:00:00	16:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
c5f0c7d0-6ec4-4baa-87b3-ebcc06e2e5d1	fd1ab8e1-89e7-49f1-b029-41ed3b1565bd	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	10:00:00	12:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
4ae0ae17-6452-476b-a07f-56f037471718	fd1ab8e1-89e7-49f1-b029-41ed3b1565bd	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	13:00:00	14:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
7bbbb1e3-8cb5-45ea-a210-9dc822f65de6	fd1ab8e1-89e7-49f1-b029-41ed3b1565bd	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	08:00:00	09:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
77a8e54c-c15a-4299-a3d7-61fb7312d050	e940eada-79a1-440e-851e-2dfb9b92b693	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	15:00:00	16:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
787d3273-417a-480d-acbd-e8d744038f75	e940eada-79a1-440e-851e-2dfb9b92b693	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	13:00:00	14:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
2bd00cfe-9fc8-4b14-82ef-a1f1bcadb708	e940eada-79a1-440e-851e-2dfb9b92b693	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	10:00:00	12:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
142e2df2-3a0d-4236-9df6-1a0ad6789372	e940eada-79a1-440e-851e-2dfb9b92b693	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	08:00:00	09:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
09fab345-95de-402e-bcb8-eff99f79845f	5f926628-1321-410f-835a-a1701355219d	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	15:00:00	16:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
f55e1fb6-e1e3-4b30-979b-6921c2d08dd9	5f926628-1321-410f-835a-a1701355219d	20c634be-77b2-4a73-9f6e-93bedc05b658	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	10:00:00	12:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
df609c12-6d69-4355-a998-eece14eddee1	5f926628-1321-410f-835a-a1701355219d	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	13:00:00	14:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
3e5a638c-1a2c-4d55-a8ee-b32aff18202b	5f926628-1321-410f-835a-a1701355219d	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	08:00:00	09:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
aa069482-8d85-4bd6-95bd-3e92527a6c89	343cd39e-8d18-4812-a6d0-d9f480dc9cb9	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	15:00:00	16:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
ecd191a2-030f-4327-b542-568d3d0f5eff	343cd39e-8d18-4812-a6d0-d9f480dc9cb9	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	13:00:00	14:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
206f9bb4-502e-415b-b22e-81da2da547cc	343cd39e-8d18-4812-a6d0-d9f480dc9cb9	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	11:00:00	12:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
03107d4a-9d17-49c3-b425-b98e17f412b9	8a7bf4f5-92de-48eb-a2bc-18dae9992013	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	15:00:00	16:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
d7ac966e-29bc-42e6-ac5f-7fff33af8737	8a7bf4f5-92de-48eb-a2bc-18dae9992013	20c634be-77b2-4a73-9f6e-93bedc05b658	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	13:00:00	14:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
bb9aece3-ee1f-4a51-a376-7b0dc35845a7	8a7bf4f5-92de-48eb-a2bc-18dae9992013	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	08:00:00	09:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
9d862608-b594-438c-92bc-9fc79c40ec5d	8a7bf4f5-92de-48eb-a2bc-18dae9992013	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	14:00:00	14:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
a0e3b4f8-c491-4019-8952-fe5ac1281372	8c870a0e-09ee-4f8d-9fa4-df771f36c4af	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	15:00:00	16:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
880e8107-3ed0-4f32-aecf-215e9be59581	8c870a0e-09ee-4f8d-9fa4-df771f36c4af	fb4fe76d-c487-4dc4-9de4-69a28896bc93	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	10:00:00	12:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
fbb7fcb1-ac0e-46cf-a49f-218715aa4d9c	8c870a0e-09ee-4f8d-9fa4-df771f36c4af	fb4fe76d-c487-4dc4-9de4-69a28896bc93	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	13:00:00	14:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
68d7f53d-a80e-4b50-aba6-5c93a0f42fff	9c7a22c6-f3ee-4fe2-9955-26c400fd0ace	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	10:00:00	12:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
81577867-06fc-4dea-8a0f-7b2fa8dcb563	9c7a22c6-f3ee-4fe2-9955-26c400fd0ace	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	13:00:00	14:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
3bfb5630-3707-4584-b609-76090abe42b6	9c7a22c6-f3ee-4fe2-9955-26c400fd0ace	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	15:00:00	16:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
e5ded558-ca8b-457b-9470-197df965cffe	9c7a22c6-f3ee-4fe2-9955-26c400fd0ace	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	08:00:00	09:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
84592ec5-c6d2-4a0f-8a90-ccc07c49b999	e506fe75-0df4-48ea-ac85-17b42f896982	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	10:00:00	12:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
0c72f4ba-dbe6-4701-8f96-e2dea2367055	e506fe75-0df4-48ea-ac85-17b42f896982	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	13:00:00	14:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
0c0bfebd-46db-4365-829d-6c2f9405bb7e	e506fe75-0df4-48ea-ac85-17b42f896982	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	15:00:00	16:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
372d0f4d-ff88-4af0-bd73-497edab14bad	e506fe75-0df4-48ea-ac85-17b42f896982	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	08:00:00	09:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
61256128-e260-4eb3-a7fd-76177f7e0256	e46010de-9a74-432f-92b6-40b9de20be76	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	15:00:00	16:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
c23c2294-ef3e-4c97-8e11-51cda792c011	e46010de-9a74-432f-92b6-40b9de20be76	f91d0839-8da7-4d33-bec1-7b6563b445ad	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	08:00:00	09:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
314118ab-d0a5-4884-97e5-8041f417f2ed	05a758ae-a3b8-401f-a768-a948669f601b	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	10:00:00	12:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
e4e15c13-d8c5-4e92-bef2-2ab57b9bb0d2	05a758ae-a3b8-401f-a768-a948669f601b	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	13:00:00	14:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
02ef3503-4862-4527-b61e-824970e50666	05a758ae-a3b8-401f-a768-a948669f601b	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	15:00:00	16:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
e91478d6-5242-48b6-9a31-67fbb99df08c	05a758ae-a3b8-401f-a768-a948669f601b	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-12	1	08:00:00	09:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
1e36c599-1d36-41d0-aae8-96d1ffe7f656	1b11d981-a65d-46bd-8220-700df1acf99f	436d7827-0da9-42c1-b1bb-8745a68abb54	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	17:00:00	18:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
969e3716-380a-424b-89cb-dc4fec85d976	1b11d981-a65d-46bd-8220-700df1acf99f	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	12:00:00	14:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
8beaf2a7-5c3a-4e19-9a68-fad8b61d5084	6d85775f-a88d-472b-876c-265b4f483da5	436d7827-0da9-42c1-b1bb-8745a68abb54	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	17:00:00	18:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
0523bdc4-8cd8-4900-bc2c-0310397c76c9	6d85775f-a88d-472b-876c-265b4f483da5	436d7827-0da9-42c1-b1bb-8745a68abb54	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	12:00:00	14:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
1347ee1e-0c90-4d95-aac6-418b1be22d54	6d85775f-a88d-472b-876c-265b4f483da5	20c634be-77b2-4a73-9f6e-93bedc05b658	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	11:00:00	11:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
8990a4bc-9013-4eee-94d9-d8581f74ca9b	7892a694-bf37-41fa-b2ba-64f69230f4e4	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	17:00:00	18:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
8c1e1127-6411-4409-ae78-66e5016b19f8	4d24bf6a-dfc4-46a4-a41d-ecb6e8ad6be4	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	17:00:00	18:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
b3d1e80b-3d9c-4d36-a8c7-38dcacb2e375	4d24bf6a-dfc4-46a4-a41d-ecb6e8ad6be4	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	11:00:00	11:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
0cc43c1a-ce6a-47e7-9667-8ddeb21a8ef0	ae95da63-ec15-4b11-b142-ff6fdb9a7b03	436d7827-0da9-42c1-b1bb-8745a68abb54	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	17:00:00	18:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
64c29947-a1aa-4378-b6d2-1e93d19f8197	ae95da63-ec15-4b11-b142-ff6fdb9a7b03	f91d0839-8da7-4d33-bec1-7b6563b445ad	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	10:00:00	11:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
277b83a7-e648-4969-bc67-71bdbb2108ff	ed254dbb-5433-4617-9a20-f642fada5d3c	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	17:00:00	18:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
15732bec-97b4-4718-9d92-c85df5d6fe39	ed254dbb-5433-4617-9a20-f642fada5d3c	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	14:30:00	16:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
9d96784c-251d-4dd4-82d2-96ed1cfc30f9	ed254dbb-5433-4617-9a20-f642fada5d3c	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	12:00:00	14:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
299fd69e-4bdd-42be-a208-915f91828df0	ed254dbb-5433-4617-9a20-f642fada5d3c	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	10:00:00	11:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
ab7c5f52-e1d7-47a2-829c-23c1c59085a5	60da7298-fdb8-41f4-ba2d-eff14314ac52	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	17:00:00	18:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
5d7d1148-23e3-45e9-83b7-169db242476a	60da7298-fdb8-41f4-ba2d-eff14314ac52	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	11:00:00	11:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
a21e2528-89bd-43f6-9309-42b70f2a500d	eafc9a41-ffe5-4cce-ac7b-9e7b0e274d8f	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	14:30:00	16:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
eb4c0d69-32fd-4a56-b881-443f68f04104	eafc9a41-ffe5-4cce-ac7b-9e7b0e274d8f	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	10:00:00	11:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
a30dfc19-8777-4b09-b700-34c3f9c41aac	eafc9a41-ffe5-4cce-ac7b-9e7b0e274d8f	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	12:00:00	14:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
bc1b858a-6ee1-42d7-99a8-82e7efdf29c5	eafc9a41-ffe5-4cce-ac7b-9e7b0e274d8f	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	17:00:00	18:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
0ad11009-eb81-4aa8-b74e-76e12dbfd661	5cc3bb12-e940-4880-94e6-cfe1427ecfc6	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	17:00:00	18:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
dd697a1e-3e0e-4d09-a494-000185db275c	5cc3bb12-e940-4880-94e6-cfe1427ecfc6	eecdcfc1-afe3-4fea-b614-8a121ba07575	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	14:30:00	16:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
53a779a8-2bde-4f49-88ae-72234ba10f33	5cc3bb12-e940-4880-94e6-cfe1427ecfc6	eecdcfc1-afe3-4fea-b614-8a121ba07575	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	10:00:00	11:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
3f1f3d9f-1125-48d9-b6ca-6bc5ad462118	5cc3bb12-e940-4880-94e6-cfe1427ecfc6	eecdcfc1-afe3-4fea-b614-8a121ba07575	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	12:00:00	14:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
3f7bbab8-2d75-4a42-8c6e-42535786c781	175b1a68-6756-44a3-9810-28d3aa10fda6	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	10:00:00	11:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
d5480386-9a09-4c1f-b190-bb3642da2667	175b1a68-6756-44a3-9810-28d3aa10fda6	fb4fe76d-c487-4dc4-9de4-69a28896bc93	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-12	1	17:00:00	18:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
c2fe1eaf-b4e9-4715-a8ef-52aded736908	631a0690-b2e4-4267-b5cf-3d16d87c264b	436d7827-0da9-42c1-b1bb-8745a68abb54	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	15:00:00	16:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
9ac88603-7514-4ef9-9cc7-9fe6b7160b76	14e6a58a-9286-479d-af56-fb4f1cc680dc	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	14:00:00	16:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
59f8ba9e-99dd-465e-8a28-b68d2bd4cc0a	14e6a58a-9286-479d-af56-fb4f1cc680dc	20c634be-77b2-4a73-9f6e-93bedc05b658	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	13:00:00	13:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
cb6a82a9-68c8-4397-b7c2-b78283f7d1e2	14e6a58a-9286-479d-af56-fb4f1cc680dc	20c634be-77b2-4a73-9f6e-93bedc05b658	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	16:30:00	17:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
c696f39e-6784-4437-9416-ffaeac47ddfe	91e5fbf6-b35e-489d-8bec-d77e32facc25	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	14:00:00	16:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
25fa4ab7-71a4-4b44-904f-8bad667296af	91e5fbf6-b35e-489d-8bec-d77e32facc25	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	12:00:00	13:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
22b94cc6-b4dc-4bb9-bb07-5d9b3deb4487	91e5fbf6-b35e-489d-8bec-d77e32facc25	fb4fe76d-c487-4dc4-9de4-69a28896bc93	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	16:30:00	17:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
5d682238-739f-4900-bc4a-ac96f48a4f18	6a5611b1-a04b-43d0-8c35-a810d393a0aa	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	16:30:00	19:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
2214bcd3-1284-4c4c-af00-78a8f6c33c11	6a5611b1-a04b-43d0-8c35-a810d393a0aa	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	12:00:00	13:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
0b80b88e-1f66-49ce-9f00-a56718ef486c	6a5611b1-a04b-43d0-8c35-a810d393a0aa	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	14:00:00	16:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
39463eca-21b3-4039-a71b-eca55db43c7c	30b6df55-a118-4b1b-8df1-c5663a701ed2	436d7827-0da9-42c1-b1bb-8745a68abb54	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	15:00:00	16:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
bbd5b39b-af1e-4220-9b6e-b694f5778eeb	10b8fd36-5de5-42ad-8c4a-a8a4494274ad	f91d0839-8da7-4d33-bec1-7b6563b445ad	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	12:00:00	13:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
a132d68e-812f-4e9b-b4cf-9d28b109b79f	10b8fd36-5de5-42ad-8c4a-a8a4494274ad	f91d0839-8da7-4d33-bec1-7b6563b445ad	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	14:00:00	16:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
6696b207-5916-42c4-a636-5d20e176bca6	10b8fd36-5de5-42ad-8c4a-a8a4494274ad	f91d0839-8da7-4d33-bec1-7b6563b445ad	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	16:30:00	17:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
51a0f3a0-00e8-43cf-8f0a-ca297aceec85	58119498-aa74-4a50-b937-ef362d96849e	fb4fe76d-c487-4dc4-9de4-69a28896bc93	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	15:00:00	16:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
f476072d-bdf5-4973-b3ce-040c7ecde938	df1d7a4b-33db-4bd9-855b-a6d8f97360a1	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	12:00:00	13:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
f61497be-6297-45ad-a99d-63a2ff52e2e2	df1d7a4b-33db-4bd9-855b-a6d8f97360a1	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	14:00:00	16:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
2722266b-57ba-413c-b697-e059dce678c0	df1d7a4b-33db-4bd9-855b-a6d8f97360a1	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	16:30:00	17:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
4868995e-65c9-4f6d-9de4-85aad40c0c58	0c3290ed-2e07-4bb2-aee3-c89339f6914f	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	17:00:00	19:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
7e23c549-61eb-44b8-9684-ffd9542004e3	a4b4e8b3-39d4-486f-917b-cbdf54b204a3	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	19:15:00	20:30:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
00ab94fd-48af-402f-82ad-fa2449950791	a4b4e8b3-39d4-486f-917b-cbdf54b204a3	eecdcfc1-afe3-4fea-b614-8a121ba07575	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	17:00:00	18:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
cd8785fd-7785-4d72-af08-50c10569ca24	610340d4-b744-4046-971e-023a4281ea6c	f91d0839-8da7-4d33-bec1-7b6563b445ad	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	17:00:00	18:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
0cf786a5-7cc3-4446-9588-83ad7ec2faf1	610340d4-b744-4046-971e-023a4281ea6c	20c634be-77b2-4a73-9f6e-93bedc05b658	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	19:15:00	20:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
b6e37f97-1bcc-45e5-80cd-d056bf9eb475	7dbb9f67-2b06-4c44-b4f6-94b8f4bdaad4	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	16:30:00	19:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
661eea54-cf58-404f-aa51-a2ea098c5093	7dbb9f67-2b06-4c44-b4f6-94b8f4bdaad4	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	12:00:00	13:45:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
9f7b9432-08d0-452b-8613-c3f0efe8609a	7dbb9f67-2b06-4c44-b4f6-94b8f4bdaad4	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	14:00:00	16:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
d1b3deae-7cd6-48c0-a707-f4233114352c	7dbb9f67-2b06-4c44-b4f6-94b8f4bdaad4	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	19:15:00	20:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
b898d069-d733-4adf-a287-ae4f1e3c2516	740ee69c-06c1-4a3b-a75c-19ab454b2775	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	17:00:00	18:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
9dd12d9f-40d3-4b85-a8d0-528bb1a5c910	740ee69c-06c1-4a3b-a75c-19ab454b2775	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	19:15:00	20:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
754bdc8d-8a24-4e01-bcd9-6d620dcce61d	d3c6f53f-7209-4221-920c-bdc821b92372	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-12	1	17:00:00	18:00:00	\N	2026-04-12 23:13:32.236549+00	2026-04-12 23:13:32.236549+00
af41722c-8322-47f2-b825-b7eea7e11af2	0328b5d2-f6e5-43e9-912e-d775bb7ea114	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	12:00:00	13:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
831b7310-fd04-47da-9be1-4b6a38a9f926	0328b5d2-f6e5-43e9-912e-d775bb7ea114	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	14:00:00	16:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
37712b44-002e-4519-9b46-095f2e02ba7f	0328b5d2-f6e5-43e9-912e-d775bb7ea114	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	16:30:00	19:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
8b7d514d-d6e8-4414-b876-d051cba82ad5	0328b5d2-f6e5-43e9-912e-d775bb7ea114	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	19:15:00	20:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
7516ecd1-e6c3-4d25-8265-ef8dd90eff72	83ec0c51-d0aa-4a2b-95b4-155b87738cb4	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-17	1	10:00:00	11:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
1f7fda99-6ef1-4fd2-b0bb-1b00344da137	83ec0c51-d0aa-4a2b-95b4-155b87738cb4	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-17	1	12:00:00	14:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
5422d991-0e97-4dc6-8367-1bc9f2ca628d	83ec0c51-d0aa-4a2b-95b4-155b87738cb4	20c634be-77b2-4a73-9f6e-93bedc05b658	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-17	1	14:30:00	16:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
e2c0182c-5ea0-4869-96ff-c1c1fe3d4c02	83ec0c51-d0aa-4a2b-95b4-155b87738cb4	20c634be-77b2-4a73-9f6e-93bedc05b658	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-17	1	17:00:00	18:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
9180581d-c222-47f9-921c-284c4907149c	d3b977c5-78be-43bd-b2df-9c6ad004ec64	f01032bd-4de9-40ff-953c-d8a2ddc937f5	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-17	1	06:00:00	07:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
2c61916d-1116-47c4-9ae2-5bade6ca8c69	d3b977c5-78be-43bd-b2df-9c6ad004ec64	f01032bd-4de9-40ff-953c-d8a2ddc937f5	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-17	1	08:00:00	09:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
c0e8da0c-3953-4406-8d1a-3a30c406ced4	d3b977c5-78be-43bd-b2df-9c6ad004ec64	f01032bd-4de9-40ff-953c-d8a2ddc937f5	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-17	1	10:00:00	12:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
8913b870-4e32-4aa5-af45-788191902810	d3b977c5-78be-43bd-b2df-9c6ad004ec64	f01032bd-4de9-40ff-953c-d8a2ddc937f5	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-17	1	13:00:00	14:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
50e91a3e-a444-4f15-a0c9-e568ee7f36bb	0381a248-b039-47ca-a591-41c90db7a78d	20c634be-77b2-4a73-9f6e-93bedc05b658	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	08:00:00	09:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
0fc237e8-53eb-4451-8d36-b2058a685f32	0381a248-b039-47ca-a591-41c90db7a78d	20c634be-77b2-4a73-9f6e-93bedc05b658	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	10:00:00	12:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
dfbe38aa-b0ae-4259-8733-799b758c0400	0381a248-b039-47ca-a591-41c90db7a78d	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	13:00:00	14:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
5d86dd91-6276-45cf-b66f-e5d63b8b5f24	0381a248-b039-47ca-a591-41c90db7a78d	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	15:00:00	16:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
2c1a82ec-98e7-4740-9551-ecb133505d42	c451eb0a-6299-4de1-8928-fe10fc43c789	255ce056-e234-417c-8d6a-db745e4bc729	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	12:00:00	13:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
663f88f0-3c4a-4be9-99d9-395bb397e799	c451eb0a-6299-4de1-8928-fe10fc43c789	255ce056-e234-417c-8d6a-db745e4bc729	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	14:00:00	16:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
b5a9a93b-88d8-4fb4-9b11-f224451a702c	c451eb0a-6299-4de1-8928-fe10fc43c789	255ce056-e234-417c-8d6a-db745e4bc729	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	16:30:00	19:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
569f2264-d0b9-4bb6-a9fb-5a4026f0810a	c451eb0a-6299-4de1-8928-fe10fc43c789	255ce056-e234-417c-8d6a-db745e4bc729	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	19:15:00	20:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
36392585-a26f-4bd6-9629-7e5613495950	9b8c599c-b1ae-4a02-b2e2-eae82615b1c5	20c634be-77b2-4a73-9f6e-93bedc05b658	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	12:00:00	13:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
114fb037-3028-42b5-8c74-84e1e6579bf0	9b8c599c-b1ae-4a02-b2e2-eae82615b1c5	20c634be-77b2-4a73-9f6e-93bedc05b658	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	14:00:00	16:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
919ba8ef-d691-4313-8259-22674529e105	9b8c599c-b1ae-4a02-b2e2-eae82615b1c5	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	16:30:00	19:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
9429647a-de4f-459e-8b58-e4f61196b609	9b8c599c-b1ae-4a02-b2e2-eae82615b1c5	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	19:15:00	20:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
599f685f-eec5-474a-bf20-3f401d66246b	4e252744-9763-44d4-b1f5-51affb91f884	f01032bd-4de9-40ff-953c-d8a2ddc937f5	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-17	1	16:00:00	18:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
9b84dab6-f1c9-4948-b15d-5ec1f8407eb3	4e252744-9763-44d4-b1f5-51affb91f884	f01032bd-4de9-40ff-953c-d8a2ddc937f5	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-17	1	18:15:00	20:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
e5284f33-b555-464a-8db7-4a6ee4c01826	86772cf3-dfaa-4db2-9d2d-e2bdb4241d6c	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-17	1	10:00:00	11:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
79e17ebb-53ac-45c5-a8f3-617e77cf1b55	86772cf3-dfaa-4db2-9d2d-e2bdb4241d6c	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-17	1	12:00:00	14:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
9daad8f9-0d65-47c5-a560-699159e951b5	86772cf3-dfaa-4db2-9d2d-e2bdb4241d6c	20c634be-77b2-4a73-9f6e-93bedc05b658	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-17	1	14:30:00	16:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
a3844550-f622-4c52-a46b-93dda07ea049	86772cf3-dfaa-4db2-9d2d-e2bdb4241d6c	20c634be-77b2-4a73-9f6e-93bedc05b658	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-17	1	17:00:00	18:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
aeebf4c4-8996-48f7-9be5-d3e04b9dc6d4	3f8de0d0-ef55-4067-ad87-a7310b3cdaf5	436d7827-0da9-42c1-b1bb-8745a68abb54	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-17	1	16:00:00	18:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
d7a85e56-79c4-4e53-8ad8-1d22bd9ff4da	3f8de0d0-ef55-4067-ad87-a7310b3cdaf5	f149d680-6b63-40cf-9b1c-5e9d97096f1c	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-17	1	18:15:00	20:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
4bebc69e-1c19-414d-8b5e-b942d8a7a7f6	0a6c1e7d-b777-49a7-8a55-a85e63979d98	436d7827-0da9-42c1-b1bb-8745a68abb54	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-17	1	16:00:00	18:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
8b1a9f27-66cd-406a-a99b-9de002f11d38	0a6c1e7d-b777-49a7-8a55-a85e63979d98	eecdcfc1-afe3-4fea-b614-8a121ba07575	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-17	1	18:15:00	20:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
7d707083-8ff4-4472-be1c-d7d731f8b202	48cc0745-4e5f-4dda-8ff5-07fa61d6eea7	f149d680-6b63-40cf-9b1c-5e9d97096f1c	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-17	1	16:00:00	18:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
6bfc13fd-efcc-4797-ace7-adb14698ec6a	48cc0745-4e5f-4dda-8ff5-07fa61d6eea7	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	b1726a36-4a64-4552-a7e2-1def20917c9b	2026-04-17	1	18:15:00	20:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
269a49b0-506a-4730-8bdc-918d0b7b37c8	6d1605d8-2318-40ad-b5a9-03feab324fd2	436d7827-0da9-42c1-b1bb-8745a68abb54	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-17	1	10:00:00	12:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
f150d36c-7f99-4e01-b932-ee434085d68d	6d1605d8-2318-40ad-b5a9-03feab324fd2	436d7827-0da9-42c1-b1bb-8745a68abb54	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-17	1	13:00:00	14:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
bcb06cc9-e404-4a6a-a1c6-7b5da78405b9	6d1605d8-2318-40ad-b5a9-03feab324fd2	9a8a5181-bdc8-4431-9a0a-14f52be82896	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-17	1	06:00:00	07:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
77270546-fb40-4f40-a466-b1a54ee9e531	6d1605d8-2318-40ad-b5a9-03feab324fd2	436d7827-0da9-42c1-b1bb-8745a68abb54	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-17	1	08:00:00	09:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
09bc61c4-4d2e-4331-9c8c-dff441c6e9d7	39b6b948-b93a-47c0-9d72-bd474ca0b1a9	f149d680-6b63-40cf-9b1c-5e9d97096f1c	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-17	1	10:00:00	12:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
818e3295-c761-4d88-8ebc-0f35706f81e7	39b6b948-b93a-47c0-9d72-bd474ca0b1a9	f149d680-6b63-40cf-9b1c-5e9d97096f1c	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-17	1	13:00:00	14:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
04e4e272-2918-4dad-a705-1b1dfd2c7278	39b6b948-b93a-47c0-9d72-bd474ca0b1a9	436d7827-0da9-42c1-b1bb-8745a68abb54	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-17	1	08:00:00	09:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
892c2000-1483-4c88-97f1-5935771ea4d3	ea762152-a4ba-4f83-b58c-8e8129348e5b	436d7827-0da9-42c1-b1bb-8745a68abb54	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-17	1	10:00:00	12:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
8c890a20-ab97-4c09-9bd5-aedde0058bae	ea762152-a4ba-4f83-b58c-8e8129348e5b	436d7827-0da9-42c1-b1bb-8745a68abb54	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-17	1	13:00:00	14:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
3b960e0d-1b2a-4c55-ab14-d42ce719b802	ea762152-a4ba-4f83-b58c-8e8129348e5b	9a8a5181-bdc8-4431-9a0a-14f52be82896	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-17	1	06:00:00	07:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
adf23c51-dbd8-4c89-9954-a6b2ac1a4b7c	ea762152-a4ba-4f83-b58c-8e8129348e5b	54a2e013-7933-4ba6-bff4-eb07adb05f7e	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-17	1	08:00:00	09:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
da26b5fe-d830-4497-ac6d-9b9681a953b6	9854d7dc-b664-4d8f-af15-348b20920345	f149d680-6b63-40cf-9b1c-5e9d97096f1c	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-17	1	10:00:00	12:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
9a1bcd05-0b70-4fc3-84ca-0e42c314cd18	9854d7dc-b664-4d8f-af15-348b20920345	f149d680-6b63-40cf-9b1c-5e9d97096f1c	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-17	1	13:00:00	14:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
c7270434-d5ca-42d8-b0e4-e346e1435038	9854d7dc-b664-4d8f-af15-348b20920345	9a8a5181-bdc8-4431-9a0a-14f52be82896	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-17	1	06:00:00	07:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
a6608465-c2b5-459c-b917-433ab9b50402	9854d7dc-b664-4d8f-af15-348b20920345	13c4d090-b2db-4397-89d8-025d6588d0c1	ffc7f49a-1e41-47e2-ad3a-564571bd648a	2026-04-17	1	08:00:00	09:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
0b45c14f-ef3e-4b74-b1ab-0f39e9280af3	fd1ab8e1-89e7-49f1-b029-41ed3b1565bd	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	15:00:00	16:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
e787ca7f-39f2-4a15-89a7-9e38bc9c2bc3	fd1ab8e1-89e7-49f1-b029-41ed3b1565bd	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	10:00:00	12:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
5563cb34-9a03-4991-9e25-464cfc09fd52	fd1ab8e1-89e7-49f1-b029-41ed3b1565bd	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	13:00:00	14:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
168952d2-d821-46d8-8cae-cb34915f9a54	fd1ab8e1-89e7-49f1-b029-41ed3b1565bd	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	08:00:00	09:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
a32907e2-d033-4704-b453-f8f598ff38bf	e940eada-79a1-440e-851e-2dfb9b92b693	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	15:00:00	16:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
953f5992-98df-4ade-9596-3a2576dfd8ec	e940eada-79a1-440e-851e-2dfb9b92b693	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	13:00:00	14:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
3da3ef92-d9b4-4e1a-9f5d-c0282cc7176f	e940eada-79a1-440e-851e-2dfb9b92b693	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	10:00:00	12:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
3c1dc1fd-b607-4fa8-ab0f-05c4baf217aa	e940eada-79a1-440e-851e-2dfb9b92b693	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	08:00:00	09:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
4c873c29-819c-444c-8f33-2026079e66e0	5f926628-1321-410f-835a-a1701355219d	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	15:00:00	16:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
1376f221-da2e-4ee6-8b6e-42d658f011a1	5f926628-1321-410f-835a-a1701355219d	20c634be-77b2-4a73-9f6e-93bedc05b658	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	10:00:00	12:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
cc8ed6da-dcf7-42af-bae8-02ad87c1dbcd	5f926628-1321-410f-835a-a1701355219d	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	13:00:00	14:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
90f86713-a801-4707-84d1-4f84ab45a0e6	5f926628-1321-410f-835a-a1701355219d	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	08:00:00	09:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
92eb81fe-3cac-4e09-bf1f-7cb3906f2dca	343cd39e-8d18-4812-a6d0-d9f480dc9cb9	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	15:00:00	16:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
ad221ce3-8caa-47f4-8e20-37d590bc318c	343cd39e-8d18-4812-a6d0-d9f480dc9cb9	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	13:00:00	14:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
ef108122-8b7c-4372-9b22-2c8e7953bc35	343cd39e-8d18-4812-a6d0-d9f480dc9cb9	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	11:00:00	12:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
c835c399-cd5a-432e-8a42-fbfcb765168c	8a7bf4f5-92de-48eb-a2bc-18dae9992013	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	15:00:00	16:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
7f512d22-3206-4a53-9203-5559731d558f	8a7bf4f5-92de-48eb-a2bc-18dae9992013	20c634be-77b2-4a73-9f6e-93bedc05b658	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	13:00:00	14:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
a82a1aef-9667-49bd-9410-dbaacdc95efe	8a7bf4f5-92de-48eb-a2bc-18dae9992013	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	08:00:00	09:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
7fc715a7-22dc-4143-9cba-3ca5c76dec58	8a7bf4f5-92de-48eb-a2bc-18dae9992013	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	14:00:00	14:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
bd12dd3e-df3d-47b6-87f1-848d6a9004d0	8c870a0e-09ee-4f8d-9fa4-df771f36c4af	436d7827-0da9-42c1-b1bb-8745a68abb54	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	15:00:00	16:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
62d222ea-dec3-4e45-a42f-3bbc63f33979	8c870a0e-09ee-4f8d-9fa4-df771f36c4af	fb4fe76d-c487-4dc4-9de4-69a28896bc93	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	10:00:00	12:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
697cff4a-b3a2-4e4e-8b36-f243a55066ec	8c870a0e-09ee-4f8d-9fa4-df771f36c4af	fb4fe76d-c487-4dc4-9de4-69a28896bc93	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	13:00:00	14:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
251669d7-0d6e-4ddb-b297-f5599c70004e	9c7a22c6-f3ee-4fe2-9955-26c400fd0ace	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	10:00:00	12:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
0fb54b5c-071c-45a0-b225-b184c59837b2	9c7a22c6-f3ee-4fe2-9955-26c400fd0ace	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	13:00:00	14:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
e199bb62-ad5e-43c8-b4a6-7bfbd076e4e7	9c7a22c6-f3ee-4fe2-9955-26c400fd0ace	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	15:00:00	16:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
2a864b7e-2cc1-4ed3-8c69-0a5cb286a0c9	9c7a22c6-f3ee-4fe2-9955-26c400fd0ace	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	08:00:00	09:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
21d4dd71-cd50-4e0f-b030-41f229858169	e506fe75-0df4-48ea-ac85-17b42f896982	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	10:00:00	12:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
5fc323b8-b136-451f-86e3-a2707ef1b8ce	e506fe75-0df4-48ea-ac85-17b42f896982	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	13:00:00	14:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
e1147c4f-ebb5-4f89-9197-fa2512611455	e506fe75-0df4-48ea-ac85-17b42f896982	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	15:00:00	16:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
b7ee0b40-635c-4c23-91aa-62b630612fc9	e506fe75-0df4-48ea-ac85-17b42f896982	931a427a-ae31-4c47-a234-0345209e2b31	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	08:00:00	09:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
4bffc62b-3715-4283-afd8-2f257eb33003	e46010de-9a74-432f-92b6-40b9de20be76	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	15:00:00	16:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
fd0075de-0b6b-4c8d-9868-16b74cdb8eca	e46010de-9a74-432f-92b6-40b9de20be76	f91d0839-8da7-4d33-bec1-7b6563b445ad	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	08:00:00	09:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
003b4ea0-967b-4095-8d19-2c84cbbcddb9	05a758ae-a3b8-401f-a768-a948669f601b	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	10:00:00	12:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
7f7a4743-4b1c-4d36-a103-a708b674b635	05a758ae-a3b8-401f-a768-a948669f601b	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	13:00:00	14:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
e355c095-d346-4445-aa16-93336a9d858a	05a758ae-a3b8-401f-a768-a948669f601b	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	15:00:00	16:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
e28b13eb-b016-43cf-8dba-5c9ffec26775	05a758ae-a3b8-401f-a768-a948669f601b	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	08:00:00	09:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
20f7f6ae-c3b9-42c5-bd2b-25f608bbc7f6	7cc683f3-2ea9-40dd-94d9-2af83d2723da	eecdcfc1-afe3-4fea-b614-8a121ba07575	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	10:00:00	12:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
a6a6c386-4e92-4ab2-9e0b-02b1e7c14241	7cc683f3-2ea9-40dd-94d9-2af83d2723da	eecdcfc1-afe3-4fea-b614-8a121ba07575	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	13:00:00	14:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
4acb5dfc-d6ee-4ddc-8c0a-0c5f5c2bccc1	7cc683f3-2ea9-40dd-94d9-2af83d2723da	eecdcfc1-afe3-4fea-b614-8a121ba07575	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	15:00:00	16:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
644eda85-1cd7-40a6-a298-1b39b518bbfe	7cc683f3-2ea9-40dd-94d9-2af83d2723da	eecdcfc1-afe3-4fea-b614-8a121ba07575	7df01eef-a728-4466-9824-355c6cd4e1fc	2026-04-17	1	09:00:00	09:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
f501d165-7a34-4510-b582-c5646fd7a98d	1b11d981-a65d-46bd-8220-700df1acf99f	436d7827-0da9-42c1-b1bb-8745a68abb54	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-17	1	17:00:00	18:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
1e2b804b-d135-428d-85fb-39d1192ea319	1b11d981-a65d-46bd-8220-700df1acf99f	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-17	1	12:00:00	14:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
7a4426f9-3e9c-4856-9e4e-fdc0adadbbf4	6d85775f-a88d-472b-876c-265b4f483da5	436d7827-0da9-42c1-b1bb-8745a68abb54	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-17	1	17:00:00	18:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
10618fc6-f53c-439e-9994-4f25044957b1	6d85775f-a88d-472b-876c-265b4f483da5	436d7827-0da9-42c1-b1bb-8745a68abb54	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-17	1	12:00:00	14:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
53453c59-2f92-437b-be23-bb7f4ca4ef88	6d85775f-a88d-472b-876c-265b4f483da5	20c634be-77b2-4a73-9f6e-93bedc05b658	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-17	1	11:00:00	11:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
17b7b9a1-e040-44a1-96ba-fca79e6251fc	7892a694-bf37-41fa-b2ba-64f69230f4e4	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-17	1	17:00:00	18:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
aac4a9cf-c6d7-4169-bb7a-832435795e33	4d24bf6a-dfc4-46a4-a41d-ecb6e8ad6be4	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-17	1	17:00:00	18:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
0aa8aa03-76f0-492e-967f-1f304adc91ff	4d24bf6a-dfc4-46a4-a41d-ecb6e8ad6be4	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-17	1	11:00:00	11:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
c1cbfde1-6268-48ed-9410-8bf5d2430c51	ae95da63-ec15-4b11-b142-ff6fdb9a7b03	f91d0839-8da7-4d33-bec1-7b6563b445ad	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-17	1	10:00:00	11:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
c463edf8-f358-44e9-9ced-fab70aade000	ae95da63-ec15-4b11-b142-ff6fdb9a7b03	436d7827-0da9-42c1-b1bb-8745a68abb54	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-17	1	17:00:00	18:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
8a7bc7b4-46b4-447f-ba92-cb87248651eb	ed254dbb-5433-4617-9a20-f642fada5d3c	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-17	1	17:00:00	18:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
b7d1558c-9c5e-4112-8394-dbd2fd2a9bc4	ed254dbb-5433-4617-9a20-f642fada5d3c	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-17	1	14:30:00	16:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
8a400755-983d-49b3-9888-1a5441e2f9f4	ed254dbb-5433-4617-9a20-f642fada5d3c	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-17	1	12:00:00	14:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
795f905f-1b25-465c-8ff6-31c294d8b862	ed254dbb-5433-4617-9a20-f642fada5d3c	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-17	1	10:00:00	11:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
835d9857-9e22-4ec2-b43b-1e9942f98feb	5cc3bb12-e940-4880-94e6-cfe1427ecfc6	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-17	1	14:30:00	16:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
db429f12-5c0d-4ddf-aae4-4e0c6b9338c5	5cc3bb12-e940-4880-94e6-cfe1427ecfc6	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-17	1	10:00:00	11:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
2441f17a-784a-4540-b0b8-ee1198d0a746	5cc3bb12-e940-4880-94e6-cfe1427ecfc6	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-17	1	12:00:00	14:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
98ebb511-bd2d-476b-afcb-eeba7690780d	5cc3bb12-e940-4880-94e6-cfe1427ecfc6	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-17	1	17:00:00	18:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
f6840394-82fb-44c7-b7d7-4c6003ab85f1	60da7298-fdb8-41f4-ba2d-eff14314ac52	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-17	1	17:00:00	18:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
d4735c6c-67fc-43e3-965a-b8974ded6c68	60da7298-fdb8-41f4-ba2d-eff14314ac52	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-17	1	11:00:00	11:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
11280795-e409-491b-aa22-72a2c6421eb6	eafc9a41-ffe5-4cce-ac7b-9e7b0e274d8f	931a427a-ae31-4c47-a234-0345209e2b31	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-17	1	17:00:00	18:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
03166f85-9400-49d7-83bc-526755c58c45	eafc9a41-ffe5-4cce-ac7b-9e7b0e274d8f	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-17	1	10:00:00	11:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
b0e43ee8-5b19-449e-9daf-1d55ed54a3fe	175b1a68-6756-44a3-9810-28d3aa10fda6	fb4fe76d-c487-4dc4-9de4-69a28896bc93	7d8b2d99-5dfe-4a83-b396-c66c9493d57c	2026-04-17	1	17:00:00	18:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
42bb1eb6-c3df-4cb8-83c8-8479457f4470	631a0690-b2e4-4267-b5cf-3d16d87c264b	436d7827-0da9-42c1-b1bb-8745a68abb54	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	15:00:00	16:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
1a9eeb1d-e79c-48f9-b2ca-826750b7788f	fda9b996-4df4-4ab4-bf71-2de86e81ea52	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	14:00:00	16:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
ca57aa15-e91f-46fa-8ad0-76d1054b3834	fda9b996-4df4-4ab4-bf71-2de86e81ea52	20c634be-77b2-4a73-9f6e-93bedc05b658	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	13:00:00	13:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
c1451b60-1baa-43fa-afab-3eb45e9791af	fda9b996-4df4-4ab4-bf71-2de86e81ea52	20c634be-77b2-4a73-9f6e-93bedc05b658	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	16:30:00	17:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
7e27014b-e6f6-422f-a0f0-dd2e4125d171	14e6a58a-9286-479d-af56-fb4f1cc680dc	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	14:00:00	16:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
006558b3-7aea-42f8-a8dd-8909c12e0a3a	14e6a58a-9286-479d-af56-fb4f1cc680dc	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	12:00:00	13:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
0d835e41-2525-42ea-b7f0-ea73658251f1	91e5fbf6-b35e-489d-8bec-d77e32facc25	fb4fe76d-c487-4dc4-9de4-69a28896bc93	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	15:00:00	16:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
384c2471-8391-4a22-82ce-ec9070ef071f	91e5fbf6-b35e-489d-8bec-d77e32facc25	fb4fe76d-c487-4dc4-9de4-69a28896bc93	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	16:30:00	17:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
9a454efe-0b59-4199-bd5c-f1a1cdd2a69c	58119498-aa74-4a50-b937-ef362d96849e	f91d0839-8da7-4d33-bec1-7b6563b445ad	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	12:00:00	13:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
e0eef137-9df9-4c95-b8a6-b9f4e317d25c	58119498-aa74-4a50-b937-ef362d96849e	f91d0839-8da7-4d33-bec1-7b6563b445ad	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	14:00:00	16:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
022d8eeb-c851-414a-9fba-ce297d54de9c	58119498-aa74-4a50-b937-ef362d96849e	f91d0839-8da7-4d33-bec1-7b6563b445ad	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	16:30:00	17:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
bb34c792-996b-4b7e-aef6-a191ebaf6353	6a5611b1-a04b-43d0-8c35-a810d393a0aa	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	16:30:00	19:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
ef23a7e9-ad9f-4d14-9f60-8a71cb56d4a5	6a5611b1-a04b-43d0-8c35-a810d393a0aa	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	12:00:00	13:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
9e6bad69-4418-4665-97f3-8e29fc6ea543	6a5611b1-a04b-43d0-8c35-a810d393a0aa	931a427a-ae31-4c47-a234-0345209e2b31	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	14:00:00	16:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
86e24578-1575-4c11-b798-38ce73d16bb2	30b6df55-a118-4b1b-8df1-c5663a701ed2	436d7827-0da9-42c1-b1bb-8745a68abb54	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	15:00:00	16:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
2ce3fcb5-a6e9-4b10-a6c2-3ebec9fd349b	df1d7a4b-33db-4bd9-855b-a6d8f97360a1	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	12:00:00	13:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
3b525e16-81ff-4f00-9c85-0f8be3ff91d1	df1d7a4b-33db-4bd9-855b-a6d8f97360a1	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	14:00:00	16:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
7a562784-e5a5-4021-bdec-97de61b2cd6b	df1d7a4b-33db-4bd9-855b-a6d8f97360a1	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	16:30:00	17:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
0587001d-e91e-4155-aec3-94179a3e3149	0c3290ed-2e07-4bb2-aee3-c89339f6914f	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	17:00:00	19:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
3d46bbf3-73be-4414-b86d-0d27ca009734	a4b4e8b3-39d4-486f-917b-cbdf54b204a3	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	19:15:00	20:30:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
235718cb-4f66-4e03-8242-64b8c3d08318	a4b4e8b3-39d4-486f-917b-cbdf54b204a3	eecdcfc1-afe3-4fea-b614-8a121ba07575	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	17:00:00	18:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
82fe6bef-8a16-446e-82d0-d29fce39f3e5	610340d4-b744-4046-971e-023a4281ea6c	f91d0839-8da7-4d33-bec1-7b6563b445ad	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	17:00:00	18:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
aff94074-19ea-49a7-b2bd-fdc006db4acd	610340d4-b744-4046-971e-023a4281ea6c	20c634be-77b2-4a73-9f6e-93bedc05b658	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	19:15:00	20:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
5fbb24fa-3960-416c-8bcd-6d781d45fe83	7dbb9f67-2b06-4c44-b4f6-94b8f4bdaad4	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	16:30:00	19:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
0c147adb-5dee-429b-8500-8b11c86c8673	7dbb9f67-2b06-4c44-b4f6-94b8f4bdaad4	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	12:00:00	13:45:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
4b66cc54-7233-4eed-bffd-ddf170f6f870	7dbb9f67-2b06-4c44-b4f6-94b8f4bdaad4	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	14:00:00	16:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
e270825f-6d02-4bba-9555-5d0a363616d7	7dbb9f67-2b06-4c44-b4f6-94b8f4bdaad4	f149d680-6b63-40cf-9b1c-5e9d97096f1c	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	19:15:00	20:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
c80bb050-877c-4644-a1a4-b03a22963d7d	740ee69c-06c1-4a3b-a75c-19ab454b2775	54a2e013-7933-4ba6-bff4-eb07adb05f7e	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	17:00:00	18:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
00f21287-b3c6-4339-abb6-c842bf941138	740ee69c-06c1-4a3b-a75c-19ab454b2775	cc5561bb-cc4e-4829-bfad-ea93aae576ed	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	19:15:00	20:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
f6a06056-f69a-4884-8e05-7721b6fd7de5	d3c6f53f-7209-4221-920c-bdc821b92372	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	7a06632f-324d-4050-aea1-c8799611ccd0	2026-04-17	1	17:00:00	18:00:00	\N	2026-04-12 23:33:42.487924+00	2026-04-12 23:33:42.487924+00
\.


--
-- Data for Name: schedule_assignments_archive; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.schedule_assignments_archive (id, employee_id, job_function_id, shift_id, schedule_date, assignment_order, start_time, end_time, team_id, created_at, updated_at, archived_at) FROM stdin;
\.


--
-- Data for Name: schedule_requests; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.schedule_requests (id, employee_id, team_id, request_type, status, request_date, start_time, end_time, original_shift_id, requested_shift_id, approval_rule_results, approved_by, admin_override, rejection_reason, created_pto_id, created_swap_id, notes, submitted_by, created_at, updated_at) FROM stdin;
b9b6333e-64c4-432c-857a-295c4686911c	df1d7a4b-33db-4bd9-855b-a6d8f97360a1	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	pto_full_day	approved	2026-03-27	\N	\N	\N	\N	{"24h_advance": true, "max_pto_hours_per_week": true}	\N	f	\N	74ef6c0e-fbfc-4279-a026-ca15f9925a6a	\N	\N	a4e93f71-43b2-4f45-a864-e7b13f2d342a	2026-03-25 22:38:09.289687+00	2026-03-25 22:38:09.289687+00
012d05e8-a8ba-4df9-b3b0-a23e126172ad	0381a248-b039-47ca-a591-41c90db7a78d	\N	pto_full_day	rejected	2026-03-26	\N	\N	\N	\N	{"24h_advance": false, "max_pto_hours_per_week": true}	\N	f	Requests must be made at least 24 hours in advance	\N	\N	\N	a4e93f71-43b2-4f45-a864-e7b13f2d342a	2026-03-25 22:40:48.007689+00	2026-03-25 22:40:48.007689+00
e09847b4-96f7-4fe0-8752-4c9671fba9e3	c451eb0a-6299-4de1-8928-fe10fc43c789	\N	pto_full_day	approved	2026-03-27	\N	\N	\N	\N	{"24h_advance": true, "max_pto_hours_per_week": true}	\N	f	\N	19c27290-bee9-4751-9fbf-f22438b25d4d	\N	\N	a4e93f71-43b2-4f45-a864-e7b13f2d342a	2026-03-25 22:40:58.773859+00	2026-03-25 22:40:58.773859+00
a1b1d69c-9ebf-4a46-a686-aadf686cdd77	e506fe75-0df4-48ea-ac85-17b42f896982	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	pto_full_day	rejected	2026-03-27	\N	\N	\N	\N	{"24h_advance": true, "max_pto_hours_per_day": false}	\N	f	Team PTO hours limit for the day exceeded	\N	\N	\N	a4e93f71-43b2-4f45-a864-e7b13f2d342a	2026-03-25 23:02:20.223201+00	2026-03-25 23:02:20.223201+00
c773372a-5d49-40df-b304-46c64d2c9bb0	df1d7a4b-33db-4bd9-855b-a6d8f97360a1	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	pto_full_day	rejected	2026-04-13	\N	\N	\N	\N	{"24h_advance": false, "max_pto_hours_per_day": true}	\N	f	Requests must be made at least 24 hours in advance	\N	\N	\N	ad4f104a-539e-4de3-9561-24de0694c5e8	2026-04-12 16:48:18.347756+00	2026-04-12 16:48:18.347756+00
b417eff2-a48e-4a83-9552-ea279b9c62d8	df1d7a4b-33db-4bd9-855b-a6d8f97360a1	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	pto_full_day	approved	2026-04-15	\N	\N	\N	\N	{"24h_advance": true, "max_pto_hours_per_day": true}	\N	f	\N	e2c06695-7cb7-4ab0-8bf4-212ae8ed32d6	\N	use pst	ad4f104a-539e-4de3-9561-24de0694c5e8	2026-04-12 16:49:20.712049+00	2026-04-12 16:49:20.712049+00
68942fdb-a1e7-4366-87ec-f8b03a47ac92	9854d7dc-b664-4d8f-af15-348b20920345	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	pto_full_day	rejected	2026-04-13	\N	\N	\N	\N	{"24h_advance": false, "max_pto_hours_per_day": true}	\N	f	Requests must be made at least 24 hours in advance	\N	\N	\N	ad4f104a-539e-4de3-9561-24de0694c5e8	2026-04-12 17:31:55.525268+00	2026-04-12 17:31:55.525268+00
951fd36b-04d9-47d6-a22b-15c7bf39b643	0381a248-b039-47ca-a591-41c90db7a78d	\N	pto_partial	approved	2026-04-14	08:00:00	10:00:00	\N	\N	{"24h_advance": true, "max_pto_hours_per_day": true}	\N	f	\N	3e9ec585-9741-4e3e-b401-1197b17a25dd	\N	\N	ad4f104a-539e-4de3-9561-24de0694c5e8	2026-04-12 19:02:50.03053+00	2026-04-12 19:02:50.03053+00
181467a1-4563-4802-8ca6-bf20b00ea93e	7cc683f3-2ea9-40dd-94d9-2af83d2723da	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	pto_full_day	approved	2026-04-15	\N	\N	\N	\N	{"24h_advance": true, "max_pto_hours_per_day": true}	\N	f	\N	7588db8f-9a40-49d0-b12c-783118ad67a6	\N	\N	ad4f104a-539e-4de3-9561-24de0694c5e8	2026-04-12 21:32:13.545441+00	2026-04-12 21:32:13.545441+00
bfdc368f-0a3b-4ad2-a800-2c80cb056661	c451eb0a-6299-4de1-8928-fe10fc43c789	\N	pto_full_day	rejected	2026-05-29	\N	\N	\N	\N	{"24h_advance": true, "date_not_blocked": true, "max_pto_hours_per_day": true}	ad4f104a-539e-4de3-9561-24de0694c5e8	t	\N	\N	\N	\N	ad4f104a-539e-4de3-9561-24de0694c5e8	2026-04-12 23:09:19.937378+00	2026-04-12 23:20:22.970017+00
\.


--
-- Data for Name: shift_swaps; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.shift_swaps (id, employee_id, swap_date, original_shift_id, swapped_shift_id, notes, team_id, created_at, updated_at) FROM stdin;
41eff63f-5b3b-4a45-9ba6-de6682c34474	05a758ae-a3b8-401f-a768-a948669f601b	2026-03-22	7df01eef-a728-4466-9824-355c6cd4e1fc	ffc7f49a-1e41-47e2-ad3a-564571bd648a	m	\N	2026-03-22 21:14:31.342896+00	2026-03-22 21:14:31.342896+00
7949afcd-a302-4ae4-928b-27d4a3214c89	39b6b948-b93a-47c0-9d72-bd474ca0b1a9	2026-03-23	ffc7f49a-1e41-47e2-ad3a-564571bd648a	7df01eef-a728-4466-9824-355c6cd4e1fc	\N	\N	2026-03-22 21:59:44.210048+00	2026-03-22 21:59:44.210048+00
\.


--
-- Data for Name: shifts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.shifts (id, name, start_time, end_time, break_1_start, break_1_end, break_2_start, break_2_end, lunch_start, lunch_end, is_active, created_at, team_id) FROM stdin;
b1726a36-4a64-4552-a7e2-1def20917c9b	4pm	16:00:00	20:30:00	18:00:00	18:15:00	\N	\N	\N	\N	t	2026-03-22 14:03:40.485255+00	\N
ffc7f49a-1e41-47e2-ad3a-564571bd648a	6M	06:00:00	14:30:00	07:45:00	08:00:00	09:45:00	10:00:00	12:30:00	13:00:00	t	2026-03-22 15:24:04.252191+00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5
7a06632f-324d-4050-aea1-c8799611ccd0	12pm	12:00:00	20:30:00	13:45:00	14:00:00	19:00:00	19:15:00	16:00:00	16:30:00	t	2026-03-22 13:17:09.345535+00	\N
7df01eef-a728-4466-9824-355c6cd4e1fc	8AM	08:00:00	16:30:00	09:45:00	10:00:00	14:45:00	15:00:00	12:30:00	13:00:00	t	2026-03-22 15:24:04.269748+00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5
7d8b2d99-5dfe-4a83-b396-c66c9493d57c	10AM	10:00:00	18:30:00	11:45:00	12:00:00	16:45:00	17:00:00	14:00:00	14:30:00	t	2026-03-22 15:24:04.271413+00	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5
\.


--
-- Data for Name: staffing_targets; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.staffing_targets (id, job_function_id, hour_start, headcount, is_active, team_id, created_at, updated_at) FROM stdin;
00436403-7ca4-42df-b083-52533eedba72	f01032bd-4de9-40ff-953c-d8a2ddc937f5	06:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
f98f67e6-57db-431d-83c8-cb4cb102bf3a	f01032bd-4de9-40ff-953c-d8a2ddc937f5	07:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
8c8d6865-dff8-4a53-85cc-06c46bc2b852	f01032bd-4de9-40ff-953c-d8a2ddc937f5	08:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
dee7efcb-f30e-4db9-9575-bbcf1a41eeba	f01032bd-4de9-40ff-953c-d8a2ddc937f5	09:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
4a63257d-76ce-494a-9246-d59df61e5ce7	f01032bd-4de9-40ff-953c-d8a2ddc937f5	10:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
86188c12-457f-4d69-a6c8-79ab36368627	f01032bd-4de9-40ff-953c-d8a2ddc937f5	11:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
aed21907-a0a0-4dc9-89b7-774e65dc17e2	f01032bd-4de9-40ff-953c-d8a2ddc937f5	12:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
03848b1a-ea29-43a9-9aad-b7b5e35fb45b	f01032bd-4de9-40ff-953c-d8a2ddc937f5	13:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
ba94aa38-2e1c-4d1b-b918-689915025c30	f01032bd-4de9-40ff-953c-d8a2ddc937f5	14:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
c9d248e2-16bf-413d-a8b5-8639db7fc936	f01032bd-4de9-40ff-953c-d8a2ddc937f5	15:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
59af0495-7b41-4ae6-8cd1-2c76a965dee2	f01032bd-4de9-40ff-953c-d8a2ddc937f5	16:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
0435cf17-c2d9-48b9-bc7d-93862ea55484	f01032bd-4de9-40ff-953c-d8a2ddc937f5	17:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
7220a870-46ef-41a9-a88d-12a48f663414	f01032bd-4de9-40ff-953c-d8a2ddc937f5	18:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
d2e3a6de-ef24-4932-b987-e3e449126834	f01032bd-4de9-40ff-953c-d8a2ddc937f5	19:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
28c405fc-9b5c-48db-9474-73b29b63ebbe	f01032bd-4de9-40ff-953c-d8a2ddc937f5	20:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
0858ff61-ee5d-463e-ad80-3aae2057c18d	eecdcfc1-afe3-4fea-b614-8a121ba07575	07:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
f518b1cf-4650-4ea1-9648-02d3d95ff892	eecdcfc1-afe3-4fea-b614-8a121ba07575	08:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
ae261cec-dc79-452a-9dbd-4d6d64bdb2cf	fb4fe76d-c487-4dc4-9de4-69a28896bc93	06:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
574f6c1a-7026-4dc9-8ddb-e383586a58de	fb4fe76d-c487-4dc4-9de4-69a28896bc93	07:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
96c09ddf-f29d-4f77-9fd8-86b35e4420f9	fb4fe76d-c487-4dc4-9de4-69a28896bc93	08:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
8a2a33a5-31ff-4080-b8dc-1b44be748b1a	fb4fe76d-c487-4dc4-9de4-69a28896bc93	09:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
ee2e1c4d-5397-4c74-a590-12c7e4cc0948	fb4fe76d-c487-4dc4-9de4-69a28896bc93	19:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
03a63ae8-6b79-4ad6-a4ba-d9881cff4e23	fb4fe76d-c487-4dc4-9de4-69a28896bc93	20:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
1b126ec9-ff3b-49a0-9153-3150e82e5596	20c634be-77b2-4a73-9f6e-93bedc05b658	06:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
8a588f27-f9c0-4a33-b76b-52874b38b092	20c634be-77b2-4a73-9f6e-93bedc05b658	07:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
d4f1fa2a-377a-4391-b414-974f0609802f	20c634be-77b2-4a73-9f6e-93bedc05b658	20:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
305769ed-38a4-44c2-ace7-ded936f6f854	13c4d090-b2db-4397-89d8-025d6588d0c1	06:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
91404e18-8cba-4c0b-8d96-6a6d07699665	13c4d090-b2db-4397-89d8-025d6588d0c1	07:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
f82e0c72-9895-405c-bd62-7724bd02c952	436d7827-0da9-42c1-b1bb-8745a68abb54	06:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
bfeecc15-babe-49f4-9102-5d1ab53fb236	436d7827-0da9-42c1-b1bb-8745a68abb54	07:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
b129bf81-b526-4b7e-93ef-24853a72a5d2	fb4fe76d-c487-4dc4-9de4-69a28896bc93	10:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:16:59.848695+00
b1a30a2b-59b6-4d92-9cba-03ff8bd5924a	fb4fe76d-c487-4dc4-9de4-69a28896bc93	11:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:16:59.848695+00
28a474e2-4859-4fc4-b774-f10c16760779	fb4fe76d-c487-4dc4-9de4-69a28896bc93	12:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:16:59.848695+00
dcb9aa4c-b186-495c-bbab-0d9bc616a67c	fb4fe76d-c487-4dc4-9de4-69a28896bc93	13:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:16:59.848695+00
9c5c5e69-3910-43ea-9ad9-81efed642dc8	fb4fe76d-c487-4dc4-9de4-69a28896bc93	14:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:16:59.848695+00
2410e951-2116-48e4-a3b2-f44afbf081dd	fb4fe76d-c487-4dc4-9de4-69a28896bc93	15:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:16:59.848695+00
931b7a77-053b-448b-b911-45aa6d880199	fb4fe76d-c487-4dc4-9de4-69a28896bc93	16:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:16:59.848695+00
74bf1cc8-35b7-4cb4-b5c9-a6ea739be911	fb4fe76d-c487-4dc4-9de4-69a28896bc93	17:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:16:59.848695+00
9cf13f73-6e41-4d6d-b44d-06ad2c06bcaf	fb4fe76d-c487-4dc4-9de4-69a28896bc93	18:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:16:59.848695+00
5f8a7a1c-710f-4a12-9d00-40d68b25307b	20c634be-77b2-4a73-9f6e-93bedc05b658	08:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:16:59.848695+00
fc427dc4-3543-4321-820a-ee1f245ba278	20c634be-77b2-4a73-9f6e-93bedc05b658	09:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:16:59.848695+00
0a541be7-b70e-4936-bbf6-afda9d41978f	20c634be-77b2-4a73-9f6e-93bedc05b658	10:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:16:59.848695+00
666d6f27-987a-4907-ab86-6c1b5aaa1367	20c634be-77b2-4a73-9f6e-93bedc05b658	11:00:00	3	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:16:59.848695+00
6613b29a-f43a-440a-a429-4446e31ac3a4	20c634be-77b2-4a73-9f6e-93bedc05b658	19:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:18:22.228612+00
39facf02-8612-47a1-9ee1-efef31d803ff	13c4d090-b2db-4397-89d8-025d6588d0c1	14:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:18:22.228612+00
ce9b8758-8d72-47f3-861b-aa547d39b655	13c4d090-b2db-4397-89d8-025d6588d0c1	15:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:18:22.228612+00
2df18fd4-c27c-48ca-8176-ad0857cceeed	13c4d090-b2db-4397-89d8-025d6588d0c1	16:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:18:22.228612+00
b6157ace-0bbe-4ebb-977f-f3c323bbdbad	13c4d090-b2db-4397-89d8-025d6588d0c1	17:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:18:22.228612+00
e505507c-0c7b-4c1e-a8fb-cd95645a07b0	13c4d090-b2db-4397-89d8-025d6588d0c1	18:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:18:22.228612+00
9b4b1399-c1a0-4ebc-bbcc-2d507b97f68e	13c4d090-b2db-4397-89d8-025d6588d0c1	19:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:18:22.228612+00
d332d39a-8111-49d8-879b-542e4bb830f5	13c4d090-b2db-4397-89d8-025d6588d0c1	20:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:18:22.228612+00
e2615376-b082-485b-a6fa-835791a61ba7	436d7827-0da9-42c1-b1bb-8745a68abb54	08:00:00	4	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:18:22.228612+00
bfe61ac2-5dc3-49c0-aaa6-43ead3a1e65f	436d7827-0da9-42c1-b1bb-8745a68abb54	09:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:18:22.228612+00
b416f9e1-ccf9-4d1c-be36-61d2a573b9a6	436d7827-0da9-42c1-b1bb-8745a68abb54	10:00:00	3	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:18:22.228612+00
6795fca0-13a4-4c11-9e33-d838f6d1eca7	436d7827-0da9-42c1-b1bb-8745a68abb54	11:00:00	4	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:18:22.228612+00
cd1d6e1a-3d90-4d2e-83e3-e774a0507dcb	436d7827-0da9-42c1-b1bb-8745a68abb54	12:00:00	5	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:18:22.228612+00
a45d2ded-d7d1-4f2e-8d69-0952ac795204	436d7827-0da9-42c1-b1bb-8745a68abb54	13:00:00	5	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:18:22.228612+00
76481b1c-8a72-47cc-b47e-3c28a2ec36e9	436d7827-0da9-42c1-b1bb-8745a68abb54	14:00:00	5	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:18:22.228612+00
a264b7c6-753b-48f6-a5b7-02ff39c68985	436d7827-0da9-42c1-b1bb-8745a68abb54	15:00:00	5	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:18:22.228612+00
6b9f2733-6ca4-4a01-a13c-a678b458f37c	436d7827-0da9-42c1-b1bb-8745a68abb54	16:00:00	5	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:18:22.228612+00
f9ffe1b4-906f-45d5-b554-22cad5485175	436d7827-0da9-42c1-b1bb-8745a68abb54	17:00:00	5	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:18:22.228612+00
1dc0bbe0-f394-46ba-b90d-e768fe69a582	436d7827-0da9-42c1-b1bb-8745a68abb54	18:00:00	3	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:18:22.228612+00
cbaeac25-d7b3-461c-9474-b854e62e324e	436d7827-0da9-42c1-b1bb-8745a68abb54	19:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
ce15deaa-253b-4a24-a935-1934c9bf618d	436d7827-0da9-42c1-b1bb-8745a68abb54	20:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
41fb6830-1248-45d4-a975-b28411592853	f149d680-6b63-40cf-9b1c-5e9d97096f1c	06:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
9754ffed-d882-4d01-8855-1913d58cd1ba	f149d680-6b63-40cf-9b1c-5e9d97096f1c	07:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
1763c480-c00d-4ba1-b578-ea92c40e9dfe	f91d0839-8da7-4d33-bec1-7b6563b445ad	06:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
ddf3f313-b99f-44f1-ad7d-a201cfbb7952	f91d0839-8da7-4d33-bec1-7b6563b445ad	07:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
215864c4-9a51-457b-a470-b60b6868a363	f91d0839-8da7-4d33-bec1-7b6563b445ad	08:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
4d461e53-ed32-461a-b5f6-aa1a0475b24a	f91d0839-8da7-4d33-bec1-7b6563b445ad	09:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
0318234e-3f8e-43d2-b283-be948f3ec10b	f91d0839-8da7-4d33-bec1-7b6563b445ad	10:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
a1ea8f8a-e705-4419-bcf9-fdc9d0dece87	f91d0839-8da7-4d33-bec1-7b6563b445ad	12:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
ebb509ce-ee80-40c2-a6f0-de3e2fb8b907	f91d0839-8da7-4d33-bec1-7b6563b445ad	13:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
c844e0c2-b00d-4cf6-8319-df275c1317a2	f91d0839-8da7-4d33-bec1-7b6563b445ad	14:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
50bd66fa-2ee6-48e9-8bcd-cab8470132d6	f91d0839-8da7-4d33-bec1-7b6563b445ad	15:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
8788a8d2-6de5-4739-9b68-d1ffdf7d5d54	f91d0839-8da7-4d33-bec1-7b6563b445ad	16:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
7e69db67-7bdc-4128-bbe4-5de3af18bdc2	f91d0839-8da7-4d33-bec1-7b6563b445ad	17:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
2e7864d5-ed4c-4b74-950b-dd83153d4e0d	f91d0839-8da7-4d33-bec1-7b6563b445ad	18:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
c18eab9e-cd8b-4aaa-92ac-03e50dc95408	f91d0839-8da7-4d33-bec1-7b6563b445ad	19:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
c75ac270-9764-4096-ab68-7a42bc4bade3	f91d0839-8da7-4d33-bec1-7b6563b445ad	20:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
5f1b921e-4a5d-493f-9bff-8374c9d46bd3	931a427a-ae31-4c47-a234-0345209e2b31	06:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
f7e9df31-ae13-4c65-8b33-dbb5469a1045	931a427a-ae31-4c47-a234-0345209e2b31	07:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
8b338fb9-3436-4540-a825-72b2eaaac7c4	931a427a-ae31-4c47-a234-0345209e2b31	19:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
ccabd897-ca1e-44af-865c-bf9fa4644a77	931a427a-ae31-4c47-a234-0345209e2b31	20:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
f68beff9-540d-47d6-858b-7d37eb86eda8	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	06:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
b5b247fb-21e1-486e-8c04-eddf317f210a	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	07:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
cff8bb38-94a8-4375-9754-b4b76a8c2df5	cc5561bb-cc4e-4829-bfad-ea93aae576ed	06:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
c8e0cec6-8621-4c34-b2b5-3005f19a8bf6	cc5561bb-cc4e-4829-bfad-ea93aae576ed	07:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
003c702d-5c63-4efb-8f8f-ca4e99a28d0a	cc5561bb-cc4e-4829-bfad-ea93aae576ed	08:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
9131d1af-6146-40a8-8e67-bd3fb568c541	cc5561bb-cc4e-4829-bfad-ea93aae576ed	09:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
3b90e4a0-52d4-4260-a5b5-34bb9f439bf3	f149d680-6b63-40cf-9b1c-5e9d97096f1c	08:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
af3e979e-82c4-470e-be4d-7e18c909ec5a	f149d680-6b63-40cf-9b1c-5e9d97096f1c	09:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
07d97739-19e9-4e29-8189-bbbae6d49298	f149d680-6b63-40cf-9b1c-5e9d97096f1c	10:00:00	3	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
18c6422b-b211-48f8-883c-e417bdf6b651	f149d680-6b63-40cf-9b1c-5e9d97096f1c	11:00:00	3	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
18b858cb-9190-416e-a0cc-201bfe6b8f3f	f149d680-6b63-40cf-9b1c-5e9d97096f1c	12:00:00	5	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
9ef48cb4-7305-4a61-b323-a69eb51f66ce	f149d680-6b63-40cf-9b1c-5e9d97096f1c	13:00:00	5	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
ab224bf3-dba7-4d58-905b-9102b760deec	f149d680-6b63-40cf-9b1c-5e9d97096f1c	14:00:00	5	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
c89759c5-296e-43b0-862c-54fc2ece5628	f149d680-6b63-40cf-9b1c-5e9d97096f1c	15:00:00	5	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
03dc404f-2706-4469-9faa-84170723644d	f149d680-6b63-40cf-9b1c-5e9d97096f1c	16:00:00	5	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
cf0662c2-c765-425f-8496-363b2f164f53	f149d680-6b63-40cf-9b1c-5e9d97096f1c	17:00:00	3	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
8d82ae40-1258-46b4-814c-7b57f6bdb927	f149d680-6b63-40cf-9b1c-5e9d97096f1c	18:00:00	3	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
6cc77340-324c-4e99-bd78-9fc4cbf71ccb	f149d680-6b63-40cf-9b1c-5e9d97096f1c	19:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
7be06d50-7dbb-4500-bdc8-016f9d2fc397	f149d680-6b63-40cf-9b1c-5e9d97096f1c	20:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
e660e4fa-a458-4e66-ac92-4cf3f86e4e39	cc5561bb-cc4e-4829-bfad-ea93aae576ed	10:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:21:13.97611+00
a385f9b3-1a05-48f1-8936-9e2d36596da8	cc5561bb-cc4e-4829-bfad-ea93aae576ed	11:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:21:13.97611+00
a447f962-a020-4095-afc3-d086e7487139	cc5561bb-cc4e-4829-bfad-ea93aae576ed	12:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:21:13.97611+00
c030efe8-2b98-4806-aae9-fb798356b58b	cc5561bb-cc4e-4829-bfad-ea93aae576ed	13:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:21:13.97611+00
b1904c82-fea2-4a87-bb62-a3d1fd7557a7	cc5561bb-cc4e-4829-bfad-ea93aae576ed	14:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:21:13.97611+00
9dff63ab-6b11-4dae-9307-de3566874c17	cc5561bb-cc4e-4829-bfad-ea93aae576ed	15:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:21:13.97611+00
a8f9170f-9ce9-4324-92f3-fb0731ac7034	cc5561bb-cc4e-4829-bfad-ea93aae576ed	16:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:21:13.97611+00
33971213-9d11-4e8e-8286-50232e007c91	f91d0839-8da7-4d33-bec1-7b6563b445ad	11:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 23:15:11.881761+00
cc9f1797-f422-4ed8-b312-643ad5aa978e	cc5561bb-cc4e-4829-bfad-ea93aae576ed	20:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
cdc3ac6a-382f-488f-a7e2-c01f11649f0c	9a8a5181-bdc8-4431-9a0a-14f52be82896	08:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
4024c291-f486-4654-97e8-b3cbef9d6933	9a8a5181-bdc8-4431-9a0a-14f52be82896	09:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
ae8526f9-1197-4275-9da6-cfbb73870540	9a8a5181-bdc8-4431-9a0a-14f52be82896	10:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
f20e2228-aa64-4a60-ba73-f56862bc1d97	9a8a5181-bdc8-4431-9a0a-14f52be82896	11:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
9e34f02b-0c05-4488-8221-6a3f9ddf9987	9a8a5181-bdc8-4431-9a0a-14f52be82896	12:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
ad47480d-29eb-4c51-b7e8-5ea49ca33a22	9a8a5181-bdc8-4431-9a0a-14f52be82896	13:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
261040b1-0d77-4534-8e4a-13736d0dd1b9	9a8a5181-bdc8-4431-9a0a-14f52be82896	14:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
5a6dc4e0-d873-4ab8-aa7c-ce959a992730	9a8a5181-bdc8-4431-9a0a-14f52be82896	15:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
7382753c-d123-47e7-8198-71ab4fee951b	9a8a5181-bdc8-4431-9a0a-14f52be82896	16:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
83e84da2-7f9d-4c62-a7e0-1ad198c873a4	9a8a5181-bdc8-4431-9a0a-14f52be82896	17:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
0af95b94-7ce4-4dc8-85b8-2df3980a9d78	9a8a5181-bdc8-4431-9a0a-14f52be82896	18:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
d88da7a8-d16a-41d6-8633-f5410bfa9b39	9a8a5181-bdc8-4431-9a0a-14f52be82896	19:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
ca687d91-fa31-434f-b3fe-2cbef17b956a	9a8a5181-bdc8-4431-9a0a-14f52be82896	20:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
879c29c8-f2f1-47f3-a804-80fa21b3ca0b	255ce056-e234-417c-8d6a-db745e4bc729	06:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
658c3929-37ee-4243-8105-ef2f2e9ed9c2	255ce056-e234-417c-8d6a-db745e4bc729	07:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
317861c6-0d4b-4dc8-b459-c66df1b1747d	255ce056-e234-417c-8d6a-db745e4bc729	08:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
dcaccfb0-56fb-4dd8-9304-ce3b656e1fa7	255ce056-e234-417c-8d6a-db745e4bc729	09:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
9df8dbd4-a1de-41a1-aecd-4bf4041e9cfd	255ce056-e234-417c-8d6a-db745e4bc729	10:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
7b864631-2885-4db0-83ac-7cd974542a7a	255ce056-e234-417c-8d6a-db745e4bc729	11:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
6f10117a-e2e9-4c6f-98b9-dc4c75c2a0a5	255ce056-e234-417c-8d6a-db745e4bc729	12:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
9a0adeb7-9c91-4fa5-b1f8-f843084d7c6e	255ce056-e234-417c-8d6a-db745e4bc729	13:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
c4d06692-5f92-4744-95bf-4962ed97d90d	255ce056-e234-417c-8d6a-db745e4bc729	14:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
1d8d5e9e-9179-487f-9a11-c9c807622b40	255ce056-e234-417c-8d6a-db745e4bc729	15:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
40822c99-63d6-4693-8d8c-ffdb09e7f337	255ce056-e234-417c-8d6a-db745e4bc729	16:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
afa415bc-1c71-418f-bded-797192f1b405	255ce056-e234-417c-8d6a-db745e4bc729	17:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
502999c1-c61e-44c6-9416-b7383935ba27	255ce056-e234-417c-8d6a-db745e4bc729	18:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
61c51668-188d-478a-9f99-c0ebd99f2825	255ce056-e234-417c-8d6a-db745e4bc729	19:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
15450cb5-31d8-4403-8bbe-11d8dfd953de	255ce056-e234-417c-8d6a-db745e4bc729	20:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
d313d33b-fe84-4273-bd63-1f6280f753b4	54a2e013-7933-4ba6-bff4-eb07adb05f7e	06:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
15e925e2-14a4-4c3f-9ed3-d7e801f424ee	54a2e013-7933-4ba6-bff4-eb07adb05f7e	07:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
79588404-2fe7-4d6b-97b1-2554bbd92a55	54a2e013-7933-4ba6-bff4-eb07adb05f7e	20:00:00	0	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 14:50:09.955164+00
8c72dd10-6e64-4e62-94dd-00edf69b62a1	eecdcfc1-afe3-4fea-b614-8a121ba07575	10:00:00	1	t	\N	2026-04-12 17:07:41.150233+00	2026-04-12 17:07:41.150233+00
0d89bc3c-d375-4b93-8539-7deaad5ce744	eecdcfc1-afe3-4fea-b614-8a121ba07575	11:00:00	1	t	\N	2026-04-12 17:07:41.150233+00	2026-04-12 17:07:41.150233+00
83c3d145-a1db-4150-8afe-807adf760012	eecdcfc1-afe3-4fea-b614-8a121ba07575	12:00:00	1	t	\N	2026-04-12 17:07:41.150233+00	2026-04-12 17:07:41.150233+00
7a745f0f-9ccd-42cb-88f8-7c145596423e	eecdcfc1-afe3-4fea-b614-8a121ba07575	13:00:00	1	t	\N	2026-04-12 17:07:41.150233+00	2026-04-12 17:07:41.150233+00
2ae7e44a-b2ae-43ed-9182-e7f84a7a5508	eecdcfc1-afe3-4fea-b614-8a121ba07575	14:00:00	1	t	\N	2026-04-12 17:07:41.150233+00	2026-04-12 17:07:41.150233+00
879b67a0-f1e3-46e3-aa81-dbd4ebf6b4b4	eecdcfc1-afe3-4fea-b614-8a121ba07575	15:00:00	1	t	\N	2026-04-12 17:07:41.150233+00	2026-04-12 17:07:41.150233+00
c75761e4-32bf-484b-a514-e520977cbed9	eecdcfc1-afe3-4fea-b614-8a121ba07575	16:00:00	1	t	\N	2026-04-12 17:07:41.150233+00	2026-04-12 17:07:41.150233+00
973be867-c0b5-40af-bc53-e80f394e8a07	eecdcfc1-afe3-4fea-b614-8a121ba07575	17:00:00	1	t	\N	2026-04-12 17:07:41.150233+00	2026-04-12 17:07:41.150233+00
50605dd4-737c-4bb8-b052-36abd602638f	eecdcfc1-afe3-4fea-b614-8a121ba07575	18:00:00	1	t	\N	2026-04-12 17:07:41.150233+00	2026-04-12 17:07:41.150233+00
42b6088f-2bfc-4d70-90fa-b4a91c9d04dc	eecdcfc1-afe3-4fea-b614-8a121ba07575	19:00:00	1	t	\N	2026-04-12 17:07:41.150233+00	2026-04-12 17:07:41.150233+00
8bdf2834-8918-4d75-83c8-8478a5450df2	eecdcfc1-afe3-4fea-b614-8a121ba07575	20:00:00	1	t	\N	2026-04-12 17:07:41.150233+00	2026-04-12 17:07:41.150233+00
980d0e5c-db45-4078-b9fd-191d083d643d	eecdcfc1-afe3-4fea-b614-8a121ba07575	09:00:00	1	t	\N	2026-04-12 17:08:39.004375+00	2026-04-12 17:08:39.004375+00
3efbdbb3-0c29-4577-a696-e673f064f451	eecdcfc1-afe3-4fea-b614-8a121ba07575	06:00:00	0	t	\N	2026-04-12 17:12:30.683212+00	2026-04-12 17:15:51.041193+00
fcf2e68d-9176-49da-b921-f1a7af8abe7d	20c634be-77b2-4a73-9f6e-93bedc05b658	12:00:00	3	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:16:59.848695+00
850112ed-1779-40b7-a21e-65dccf05dc99	20c634be-77b2-4a73-9f6e-93bedc05b658	13:00:00	3	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:16:59.848695+00
2d1a4b24-a041-4a94-a486-bd0c3968c224	20c634be-77b2-4a73-9f6e-93bedc05b658	14:00:00	3	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:16:59.848695+00
9a530c00-6391-44e1-85c3-a46d8fdde73d	20c634be-77b2-4a73-9f6e-93bedc05b658	15:00:00	3	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:16:59.848695+00
08229a79-273b-4025-bf93-5c9b475f6977	20c634be-77b2-4a73-9f6e-93bedc05b658	16:00:00	3	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:16:59.848695+00
4e99fffc-d888-4f63-ab7d-e2949b5fb083	20c634be-77b2-4a73-9f6e-93bedc05b658	17:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:16:59.848695+00
e106ba9c-ee50-4afc-ac13-88ab87dd0ffa	20c634be-77b2-4a73-9f6e-93bedc05b658	18:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:16:59.848695+00
0b566085-2893-49aa-982d-91096172b9f4	13c4d090-b2db-4397-89d8-025d6588d0c1	08:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:16:59.848695+00
22bd4bda-2399-4fa2-9c2e-a7a236b3d8d9	13c4d090-b2db-4397-89d8-025d6588d0c1	09:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:16:59.848695+00
bffda91b-1eb0-473b-87dc-c27a6b3d512e	13c4d090-b2db-4397-89d8-025d6588d0c1	10:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:16:59.848695+00
b17f71a1-c05d-42a0-bb28-ebaee8c1fe7c	13c4d090-b2db-4397-89d8-025d6588d0c1	11:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:16:59.848695+00
4e391c30-e837-44d3-9e56-095fc1cab543	13c4d090-b2db-4397-89d8-025d6588d0c1	12:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:18:22.228612+00
d3315e9c-53e6-451c-b2c7-bf922e99493b	13c4d090-b2db-4397-89d8-025d6588d0c1	13:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:18:22.228612+00
56245f37-334e-4b78-9645-1ff140e7dd66	cc5561bb-cc4e-4829-bfad-ea93aae576ed	17:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:21:13.97611+00
f2cb2329-ee02-4155-9dfc-7b27172bd333	cc5561bb-cc4e-4829-bfad-ea93aae576ed	18:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:21:13.97611+00
2ec6dd5d-5d8e-41ba-8086-00908fe2d5ea	54a2e013-7933-4ba6-bff4-eb07adb05f7e	08:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:22:08.732333+00
815ac59d-4b48-4318-91c0-8dc85406df5c	9a8a5181-bdc8-4431-9a0a-14f52be82896	06:00:00	4	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 21:34:18.809271+00
ad317b0d-bb18-4364-bb3f-3d2c463d44b9	9a8a5181-bdc8-4431-9a0a-14f52be82896	07:00:00	4	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 21:34:18.809271+00
b71c5536-3b19-4582-8a6a-f999ac17572a	931a427a-ae31-4c47-a234-0345209e2b31	08:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
ab5f3e72-b2d4-40c0-8993-6de034affcd1	931a427a-ae31-4c47-a234-0345209e2b31	09:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
3bead66b-7474-4105-a099-22f155740786	931a427a-ae31-4c47-a234-0345209e2b31	10:00:00	3	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
ca850010-5ce5-4499-9bfc-df14f845208c	931a427a-ae31-4c47-a234-0345209e2b31	11:00:00	4	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
19ef128a-9f19-4044-825a-a4390c7670dd	931a427a-ae31-4c47-a234-0345209e2b31	12:00:00	4	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
b562c66d-4eec-448e-b26c-675129cc699f	931a427a-ae31-4c47-a234-0345209e2b31	13:00:00	4	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
7d434c17-f71e-4234-a8f1-32071c39c297	931a427a-ae31-4c47-a234-0345209e2b31	14:00:00	4	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
1a03b1a7-7ed3-4deb-b013-ac842d4f5078	931a427a-ae31-4c47-a234-0345209e2b31	15:00:00	4	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
5e4e9641-fe4d-46b7-8146-913ba21aadd2	931a427a-ae31-4c47-a234-0345209e2b31	16:00:00	4	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
84f836dc-70fe-4149-b6c7-20ffca855457	931a427a-ae31-4c47-a234-0345209e2b31	17:00:00	4	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
ac753906-0286-4cf1-aeed-270d3a647f33	931a427a-ae31-4c47-a234-0345209e2b31	18:00:00	4	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
d57bdcc1-6a8e-4e8b-a48a-35d3aba95407	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	08:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
7d99c5b5-669b-4d13-9603-4dafb46b4fa6	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	09:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
307ffc60-5fa8-43f7-81ef-e932484cc78f	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	10:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
b8600397-63b1-4553-a02c-9386c64593bb	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	11:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
da303dc1-8285-4a3f-924d-f9a21fd5ebde	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	12:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
d45a4270-2904-4323-810c-953524282cb3	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	13:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
dd5fbbf2-deb1-4c74-acfe-431b16091a3a	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	14:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
98f0ed30-4cc5-4e71-8283-b0a4116f1e52	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	15:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
5a5ca76e-171c-4c1d-94d2-fdc65d177a11	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	16:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
17aa8b30-3c1a-4734-a42e-4099e7a702e6	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	17:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
b2e911f6-86ef-48cc-970a-6e621d2a7077	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	18:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
dabb175a-dbb7-415a-812d-05bb71b717a7	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	19:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
7307bd75-117f-4751-aea1-2ab3b26831ec	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	20:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:20:47.334535+00
9c052de9-8896-45db-a3d6-9fdb25b677a2	cc5561bb-cc4e-4829-bfad-ea93aae576ed	19:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:21:13.97611+00
39ecfa63-c5d5-42e4-8b70-679567c8a9d9	54a2e013-7933-4ba6-bff4-eb07adb05f7e	09:00:00	1	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:22:08.732333+00
827e576b-f283-4fac-b640-6135e62e62c5	54a2e013-7933-4ba6-bff4-eb07adb05f7e	10:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:22:08.732333+00
87090659-b33a-49e0-ad65-71883369a7a4	54a2e013-7933-4ba6-bff4-eb07adb05f7e	11:00:00	3	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:22:08.732333+00
32701489-acfa-43d4-94e6-708edcef3784	54a2e013-7933-4ba6-bff4-eb07adb05f7e	12:00:00	3	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:22:08.732333+00
a64d2af8-9452-4408-bcfa-57b71740749b	54a2e013-7933-4ba6-bff4-eb07adb05f7e	13:00:00	3	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:22:08.732333+00
05c8be38-fcef-4485-8d21-3694291f2878	54a2e013-7933-4ba6-bff4-eb07adb05f7e	14:00:00	3	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:22:08.732333+00
d791a1e1-7100-4e26-9e2f-9ed413a2a6b9	54a2e013-7933-4ba6-bff4-eb07adb05f7e	15:00:00	3	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:22:08.732333+00
07bdfe68-b39c-42d2-bda9-872a0f872d5b	54a2e013-7933-4ba6-bff4-eb07adb05f7e	16:00:00	3	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:22:08.732333+00
a32382fb-31ea-45f8-86c4-45fa368bd0c5	54a2e013-7933-4ba6-bff4-eb07adb05f7e	17:00:00	3	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:22:08.732333+00
d1cddd9b-b124-4626-866b-adef2738a572	54a2e013-7933-4ba6-bff4-eb07adb05f7e	18:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:22:08.732333+00
056ac8cd-cf5a-4006-9327-085cc7c2b416	54a2e013-7933-4ba6-bff4-eb07adb05f7e	19:00:00	2	t	\N	2026-04-12 14:50:09.955164+00	2026-04-12 17:22:08.732333+00
e4ac8dd9-ab1d-4a8f-8a16-17286d7110cc	507ff8a9-edd9-460a-af98-5d583676d2d2	08:00:00	4	t	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:18:16.165386+00	2026-06-08 00:18:16.165386+00
b23ae04f-a216-437f-ad6b-16b828f3a3c6	507ff8a9-edd9-460a-af98-5d583676d2d2	09:00:00	4	t	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:18:16.165386+00	2026-06-08 00:18:16.165386+00
97cfcab2-6ca1-4d6c-be8e-bba7230f4dc4	507ff8a9-edd9-460a-af98-5d583676d2d2	10:00:00	4	t	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:18:16.165386+00	2026-06-08 00:18:16.165386+00
6e18ba64-6c3a-4e12-b800-dde1c09ed278	507ff8a9-edd9-460a-af98-5d583676d2d2	11:00:00	4	t	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:18:16.165386+00	2026-06-08 00:18:16.165386+00
23d58533-f9d6-4768-ac5f-c3e19bc5d8b6	507ff8a9-edd9-460a-af98-5d583676d2d2	12:00:00	5	t	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:18:16.165386+00	2026-06-08 00:18:16.165386+00
8e1c9654-4b8e-4d8d-9feb-e74553a6705c	507ff8a9-edd9-460a-af98-5d583676d2d2	13:00:00	5	t	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:18:16.165386+00	2026-06-08 00:18:16.165386+00
74b1a59a-9d3a-4174-aa05-80aaf9af4df8	507ff8a9-edd9-460a-af98-5d583676d2d2	14:00:00	5	t	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:18:16.165386+00	2026-06-08 00:18:16.165386+00
a393a193-b3c4-48c8-afbb-9bffe5b34907	507ff8a9-edd9-460a-af98-5d583676d2d2	15:00:00	5	t	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:18:16.165386+00	2026-06-08 00:18:16.165386+00
ce3d4d9d-31fc-46ca-b2a8-815b82a39c86	507ff8a9-edd9-460a-af98-5d583676d2d2	16:00:00	5	t	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:18:16.165386+00	2026-06-08 00:18:16.165386+00
a15cb48e-7331-4d9f-bfb8-6caa58649d35	507ff8a9-edd9-460a-af98-5d583676d2d2	17:00:00	5	t	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:18:16.165386+00	2026-06-08 00:18:16.165386+00
b4cf822e-5034-4a41-a386-82885a52f17c	507ff8a9-edd9-460a-af98-5d583676d2d2	18:00:00	5	t	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:18:16.165386+00	2026-06-08 00:18:16.165386+00
08b98f1d-8f7b-40d4-bfde-0238d1faa6f0	507ff8a9-edd9-460a-af98-5d583676d2d2	19:00:00	3	t	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:18:16.165386+00	2026-06-08 00:18:16.165386+00
421c8f4d-26ac-4656-9ec2-5a81f826a42f	20c634be-77b2-4a73-9f6e-93bedc05b658	08:00:00	2	t	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:18:16.165386+00	2026-06-08 00:18:16.165386+00
ccf82d41-1448-4e88-9f11-7006e9c906e9	20c634be-77b2-4a73-9f6e-93bedc05b658	09:00:00	2	t	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:18:16.165386+00	2026-06-08 00:18:16.165386+00
3bd10330-b12d-48c4-82c1-70cdb57ac298	13c4d090-b2db-4397-89d8-025d6588d0c1	08:00:00	2	t	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:18:16.165386+00	2026-06-08 00:18:16.165386+00
333501f6-791d-492b-91d7-7f15d7b4d7d7	13c4d090-b2db-4397-89d8-025d6588d0c1	09:00:00	2	t	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:18:16.165386+00	2026-06-08 00:18:16.165386+00
90410d0b-3c52-4650-8b8f-b39e7cd570fc	13c4d090-b2db-4397-89d8-025d6588d0c1	10:00:00	2	t	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:18:16.165386+00	2026-06-08 00:18:16.165386+00
5742e416-0f04-49ef-a413-f562a178196d	13c4d090-b2db-4397-89d8-025d6588d0c1	11:00:00	2	t	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:18:16.165386+00	2026-06-08 00:18:16.165386+00
5832c05e-9f94-4376-b92a-513f0628e1a0	436d7827-0da9-42c1-b1bb-8745a68abb54	09:00:00	3	t	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:18:16.165386+00	2026-06-08 00:18:16.165386+00
89c2adfa-7726-4e19-a36a-83f1e35cbaa7	f149d680-6b63-40cf-9b1c-5e9d97096f1c	08:00:00	2	t	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:18:16.165386+00	2026-06-08 00:18:16.165386+00
2c5ae681-0c92-42aa-ab3c-b9a02f910bc9	f149d680-6b63-40cf-9b1c-5e9d97096f1c	09:00:00	2	t	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:18:16.165386+00	2026-06-08 00:18:16.165386+00
6aad943b-492e-477a-ba1b-c1b26aa8ce71	931a427a-ae31-4c47-a234-0345209e2b31	10:00:00	4	t	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:18:16.165386+00	2026-06-08 00:18:16.165386+00
47c43436-1930-4868-a1d2-cefe585a8b43	931a427a-ae31-4c47-a234-0345209e2b31	15:00:00	5	t	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:18:16.165386+00	2026-06-08 00:18:16.165386+00
e292c9e8-972e-41f3-8c0c-6931ae2d6368	931a427a-ae31-4c47-a234-0345209e2b31	16:00:00	5	t	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:18:16.165386+00	2026-06-08 00:18:16.165386+00
30dd5bb1-e75b-46b1-9d8a-82aba939d4e4	931a427a-ae31-4c47-a234-0345209e2b31	17:00:00	5	t	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:18:16.165386+00	2026-06-08 00:18:16.165386+00
85845fc1-e125-4d8a-87e7-537deb5a57ae	931a427a-ae31-4c47-a234-0345209e2b31	18:00:00	5	t	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:18:16.165386+00	2026-06-08 00:18:16.165386+00
39990580-eaf6-4e33-bd08-5dbcb4b3bc9e	931a427a-ae31-4c47-a234-0345209e2b31	19:00:00	5	t	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:18:16.165386+00	2026-06-08 00:18:16.165386+00
2628cdbf-c90a-49db-b6f8-3bb27749ac10	931a427a-ae31-4c47-a234-0345209e2b31	20:00:00	5	t	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:18:16.165386+00	2026-06-08 00:18:16.165386+00
afafc0d4-3601-4998-b99c-6cc413dc512b	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	10:00:00	2	t	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:18:16.165386+00	2026-06-08 00:18:16.165386+00
f37ca31f-6b39-4403-9e8e-a6c25d9d7332	6e5485ae-fd39-4945-bbbe-5a59ee96dadf	11:00:00	2	t	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:18:16.165386+00	2026-06-08 00:18:16.165386+00
0145b632-00ba-4309-ab36-ef9dbb3a896d	9a8a5181-bdc8-4431-9a0a-14f52be82896	06:00:00	6	t	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:18:16.165386+00	2026-06-08 00:18:16.165386+00
f024a5da-f72e-4fd2-bd35-37483d11c0a7	9a8a5181-bdc8-4431-9a0a-14f52be82896	07:00:00	6	t	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:18:16.165386+00	2026-06-08 00:18:16.165386+00
fe865092-051f-401b-a8f3-10ff37cda7e0	54a2e013-7933-4ba6-bff4-eb07adb05f7e	09:00:00	2	t	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-06-08 00:18:16.165386+00	2026-06-08 00:18:16.165386+00
\.


--
-- Data for Name: target_hours; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.target_hours (id, job_function_id, target_hours, team_id, created_at, updated_at) FROM stdin;
f3fdde1f-d522-4f14-8c35-10f6d0fcd8db	436d7827-0da9-42c1-b1bb-8745a68abb54	8	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.274946+00	2026-03-22 15:24:07.274946+00
eb91281e-8e04-4b2e-aea9-8a6268f043ca	f149d680-6b63-40cf-9b1c-5e9d97096f1c	8	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.278129+00	2026-03-22 15:24:07.278129+00
259a9c02-5d0d-4ca8-88e8-096d5227b29a	54a2e013-7933-4ba6-bff4-eb07adb05f7e	8	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.29308+00	2026-03-22 15:24:07.29308+00
eedf582b-842b-433d-b5c2-564b76456182	20c634be-77b2-4a73-9f6e-93bedc05b658	8	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-03-22 15:24:07.294719+00	2026-03-22 15:24:07.294719+00
\.


--
-- Data for Name: team_blocked_dates; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.team_blocked_dates (id, team_id, blocked_date, reason, created_at) FROM stdin;
92cf4360-91a6-4e67-b504-b2c8a140a68f	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-05-27	Month-end close	2026-04-12 22:42:44.155036+00
c44d09fc-c4ec-4479-8aa8-6fbec9c0323e	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-05-28	Month-end close	2026-04-12 22:42:44.161473+00
a1dd8648-1181-4170-8769-8c3d207304ad	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	2026-05-29	Month-end close	2026-04-12 22:42:44.163336+00
\.


--
-- Data for Name: team_settings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.team_settings (id, team_id, setting_key, setting_value, created_at, updated_at) FROM stdin;
10bac02c-77c1-4386-ba0a-89e7443ee0a9	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	max_pto_hours_per_day	40	2026-03-25 23:02:38.942754+00	2026-03-25 23:02:48.68954+00
6cecb57b-51d5-446e-92bd-9050386a0732	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	max_shift_swaps_per_day	2	2026-03-25 23:02:38.99398+00	2026-03-25 23:02:48.743051+00
bf41bd7c-ec5c-4706-bcf3-6d83ecc02cba	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	max_leave_early_per_employee_per_day	1	2026-03-25 23:02:39.041861+00	2026-03-25 23:02:48.791028+00
c1226ffc-442f-4666-ac46-b8bc06d53939	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	max_shift_change_per_employee_per_day	1	2026-03-25 23:02:39.089971+00	2026-03-25 23:02:48.839023+00
\.


--
-- Data for Name: teams; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.teams (id, name, created_at, updated_at) FROM stdin;
7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	Default Team	2026-03-22 00:40:09.175272+00	2026-03-22 00:40:09.175272+00
\.


--
-- Data for Name: user_profiles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_profiles (id, username, email, password_hash, full_name, team_id, is_super_admin, is_admin, is_display_user, is_active, last_login, created_at, updated_at, employee_id) FROM stdin;
a4e93f71-43b2-4f45-a864-e7b13f2d342a	michael.johnson12	michael.johnson12@abbott.com	$2b$12$/.rZ2C32xodmqlnDNGNKre9OgT3X4Jbcvd2OIzc.JS3kXT9ECzyaS	Michael Johnson	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	t	t	f	t	2026-03-25 21:46:51.41889+00	2026-03-22 19:50:50.240187+00	2026-03-25 21:46:51.41889+00	\N
ad4f104a-539e-4de3-9561-24de0694c5e8	admin	admin@example.com	$2b$10$xWd0vSPpkYzHhuxn8unEfuA90aEcSfBa0FpoDgc6E0ek.tkFsMgQy	Admin User	7ad60b1f-f1c6-4c1a-8eb6-a3bd7d564fb5	t	f	f	t	2026-06-07 23:58:19.239436+00	2026-03-22 00:40:09.273109+00	2026-06-07 23:58:19.239436+00	\N
\.


--
-- Name: _data_backfills _data_backfills_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public._data_backfills
    ADD CONSTRAINT _data_backfills_pkey PRIMARY KEY (key);


--
-- Name: business_rules business_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.business_rules
    ADD CONSTRAINT business_rules_pkey PRIMARY KEY (id);


--
-- Name: cleanup_log cleanup_log_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cleanup_log
    ADD CONSTRAINT cleanup_log_pkey PRIMARY KEY (id);


--
-- Name: daily_targets_archive daily_targets_archive_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.daily_targets_archive
    ADD CONSTRAINT daily_targets_archive_pkey PRIMARY KEY (id);


--
-- Name: daily_targets daily_targets_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.daily_targets
    ADD CONSTRAINT daily_targets_pkey PRIMARY KEY (id);


--
-- Name: daily_targets daily_targets_schedule_date_job_function_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.daily_targets
    ADD CONSTRAINT daily_targets_schedule_date_job_function_id_key UNIQUE (schedule_date, job_function_id, team_id);


--
-- Name: employee_training employee_training_employee_id_job_function_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employee_training
    ADD CONSTRAINT employee_training_employee_id_job_function_id_key UNIQUE (employee_id, job_function_id);


--
-- Name: employee_training employee_training_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employee_training
    ADD CONSTRAINT employee_training_pkey PRIMARY KEY (id);


--
-- Name: employees employees_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employees
    ADD CONSTRAINT employees_pkey PRIMARY KEY (id);


--
-- Name: job_functions job_functions_name_team_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.job_functions
    ADD CONSTRAINT job_functions_name_team_key UNIQUE (name, team_id);


--
-- Name: job_functions job_functions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.job_functions
    ADD CONSTRAINT job_functions_pkey PRIMARY KEY (id);


--
-- Name: password_reset_tokens password_reset_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.password_reset_tokens
    ADD CONSTRAINT password_reset_tokens_pkey PRIMARY KEY (id);


--
-- Name: preferred_assignments preferred_assignments_employee_id_job_function_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.preferred_assignments
    ADD CONSTRAINT preferred_assignments_employee_id_job_function_id_key UNIQUE (employee_id, job_function_id);


--
-- Name: preferred_assignments preferred_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.preferred_assignments
    ADD CONSTRAINT preferred_assignments_pkey PRIMARY KEY (id);


--
-- Name: pto_days pto_days_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pto_days
    ADD CONSTRAINT pto_days_pkey PRIMARY KEY (id);


--
-- Name: schedule_assignments_archive schedule_assignments_archive_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule_assignments_archive
    ADD CONSTRAINT schedule_assignments_archive_pkey PRIMARY KEY (id);


--
-- Name: schedule_assignments schedule_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule_assignments
    ADD CONSTRAINT schedule_assignments_pkey PRIMARY KEY (id);


--
-- Name: schedule_requests schedule_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule_requests
    ADD CONSTRAINT schedule_requests_pkey PRIMARY KEY (id);


--
-- Name: shift_swaps shift_swaps_employee_id_swap_date_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shift_swaps
    ADD CONSTRAINT shift_swaps_employee_id_swap_date_key UNIQUE (employee_id, swap_date);


--
-- Name: shift_swaps shift_swaps_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shift_swaps
    ADD CONSTRAINT shift_swaps_pkey PRIMARY KEY (id);


--
-- Name: shifts shifts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shifts
    ADD CONSTRAINT shifts_pkey PRIMARY KEY (id);


--
-- Name: staffing_targets staffing_targets_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.staffing_targets
    ADD CONSTRAINT staffing_targets_pkey PRIMARY KEY (id);


--
-- Name: staffing_targets staffing_targets_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.staffing_targets
    ADD CONSTRAINT staffing_targets_unique UNIQUE NULLS NOT DISTINCT (job_function_id, hour_start, team_id);


--
-- Name: target_hours target_hours_job_function_team_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.target_hours
    ADD CONSTRAINT target_hours_job_function_team_key UNIQUE (job_function_id, team_id);


--
-- Name: target_hours target_hours_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.target_hours
    ADD CONSTRAINT target_hours_pkey PRIMARY KEY (id);


--
-- Name: team_blocked_dates team_blocked_dates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.team_blocked_dates
    ADD CONSTRAINT team_blocked_dates_pkey PRIMARY KEY (id);


--
-- Name: team_blocked_dates team_blocked_dates_team_id_blocked_date_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.team_blocked_dates
    ADD CONSTRAINT team_blocked_dates_team_id_blocked_date_key UNIQUE (team_id, blocked_date);


--
-- Name: team_settings team_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.team_settings
    ADD CONSTRAINT team_settings_pkey PRIMARY KEY (id);


--
-- Name: team_settings team_settings_team_id_setting_key_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.team_settings
    ADD CONSTRAINT team_settings_team_id_setting_key_key UNIQUE (team_id, setting_key);


--
-- Name: teams teams_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_name_key UNIQUE (name);


--
-- Name: teams teams_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_pkey PRIMARY KEY (id);


--
-- Name: user_profiles user_profiles_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_email_key UNIQUE (email);


--
-- Name: user_profiles user_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_pkey PRIMARY KEY (id);


--
-- Name: user_profiles user_profiles_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_username_key UNIQUE (username);


--
-- Name: idx_business_rules_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_business_rules_active ON public.business_rules USING btree (is_active);


--
-- Name: idx_business_rules_job_function; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_business_rules_job_function ON public.business_rules USING btree (job_function_name);


--
-- Name: idx_business_rules_priority; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_business_rules_priority ON public.business_rules USING btree (priority);


--
-- Name: idx_business_rules_team; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_business_rules_team ON public.business_rules USING btree (team_id);


--
-- Name: idx_daily_targets_archive_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_daily_targets_archive_date ON public.daily_targets_archive USING btree (schedule_date);


--
-- Name: idx_daily_targets_archive_team; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_daily_targets_archive_team ON public.daily_targets_archive USING btree (team_id);


--
-- Name: idx_daily_targets_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_daily_targets_date ON public.daily_targets USING btree (schedule_date);


--
-- Name: idx_daily_targets_team; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_daily_targets_team ON public.daily_targets USING btree (team_id);


--
-- Name: idx_employee_training_employee; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_employee_training_employee ON public.employee_training USING btree (employee_id);


--
-- Name: idx_employee_training_function; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_employee_training_function ON public.employee_training USING btree (job_function_id);


--
-- Name: idx_employee_training_team; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_employee_training_team ON public.employee_training USING btree (team_id);


--
-- Name: idx_employees_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_employees_active ON public.employees USING btree (is_active);


--
-- Name: idx_employees_shift_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_employees_shift_id ON public.employees USING btree (shift_id);


--
-- Name: idx_employees_team; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_employees_team ON public.employees USING btree (team_id);


--
-- Name: idx_job_functions_team; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_job_functions_team ON public.job_functions USING btree (team_id);


--
-- Name: idx_password_reset_tokens_expires; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_password_reset_tokens_expires ON public.password_reset_tokens USING btree (expires_at);


--
-- Name: idx_password_reset_tokens_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_password_reset_tokens_user ON public.password_reset_tokens USING btree (user_id);


--
-- Name: idx_preferred_assignments_employee; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_preferred_assignments_employee ON public.preferred_assignments USING btree (employee_id);


--
-- Name: idx_preferred_assignments_job_function; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_preferred_assignments_job_function ON public.preferred_assignments USING btree (job_function_id);


--
-- Name: idx_preferred_assignments_required; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_preferred_assignments_required ON public.preferred_assignments USING btree (is_required) WHERE (is_required = true);


--
-- Name: idx_preferred_assignments_team; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_preferred_assignments_team ON public.preferred_assignments USING btree (team_id);


--
-- Name: idx_pto_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_pto_date ON public.pto_days USING btree (pto_date);


--
-- Name: idx_pto_days_team; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_pto_days_team ON public.pto_days USING btree (team_id);


--
-- Name: idx_pto_employee; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_pto_employee ON public.pto_days USING btree (employee_id);


--
-- Name: idx_schedule_archive_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_schedule_archive_date ON public.schedule_assignments_archive USING btree (schedule_date);


--
-- Name: idx_schedule_archive_employee; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_schedule_archive_employee ON public.schedule_assignments_archive USING btree (employee_id);


--
-- Name: idx_schedule_archive_team; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_schedule_archive_team ON public.schedule_assignments_archive USING btree (team_id);


--
-- Name: idx_schedule_assignments_team; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_schedule_assignments_team ON public.schedule_assignments USING btree (team_id);


--
-- Name: idx_schedule_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_schedule_date ON public.schedule_assignments USING btree (schedule_date);


--
-- Name: idx_schedule_employee; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_schedule_employee ON public.schedule_assignments USING btree (employee_id);


--
-- Name: idx_schedule_requests_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_schedule_requests_date ON public.schedule_requests USING btree (request_date);


--
-- Name: idx_schedule_requests_employee_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_schedule_requests_employee_date ON public.schedule_requests USING btree (employee_id, request_date);


--
-- Name: idx_schedule_requests_team_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_schedule_requests_team_status ON public.schedule_requests USING btree (team_id, status);


--
-- Name: idx_shift_swaps_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_shift_swaps_date ON public.shift_swaps USING btree (swap_date);


--
-- Name: idx_shift_swaps_employee; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_shift_swaps_employee ON public.shift_swaps USING btree (employee_id);


--
-- Name: idx_shift_swaps_shift; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_shift_swaps_shift ON public.shift_swaps USING btree (swapped_shift_id);


--
-- Name: idx_shift_swaps_team; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_shift_swaps_team ON public.shift_swaps USING btree (team_id);


--
-- Name: idx_shifts_team; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_shifts_team ON public.shifts USING btree (team_id);


--
-- Name: idx_staffing_targets_team; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_staffing_targets_team ON public.staffing_targets USING btree (team_id);


--
-- Name: idx_target_hours_team; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_target_hours_team ON public.target_hours USING btree (team_id);


--
-- Name: idx_team_blocked_dates_team_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_team_blocked_dates_team_date ON public.team_blocked_dates USING btree (team_id, blocked_date);


--
-- Name: idx_team_settings_team; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_team_settings_team ON public.team_settings USING btree (team_id);


--
-- Name: idx_teams_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_teams_name ON public.teams USING btree (name);


--
-- Name: idx_user_profiles_admin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_profiles_admin ON public.user_profiles USING btree (is_super_admin);


--
-- Name: idx_user_profiles_display; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_profiles_display ON public.user_profiles USING btree (is_display_user);


--
-- Name: idx_user_profiles_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_profiles_email ON public.user_profiles USING btree (email);


--
-- Name: idx_user_profiles_employee_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_user_profiles_employee_id ON public.user_profiles USING btree (employee_id) WHERE (employee_id IS NOT NULL);


--
-- Name: idx_user_profiles_team; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_profiles_team ON public.user_profiles USING btree (team_id);


--
-- Name: idx_user_profiles_username; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_profiles_username ON public.user_profiles USING btree (username);


--
-- Name: preferred_assignments trigger_update_preferred_assignments_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_preferred_assignments_updated_at BEFORE UPDATE ON public.preferred_assignments FOR EACH ROW EXECUTE FUNCTION public.update_preferred_assignments_updated_at();


--
-- Name: shift_swaps trigger_update_shift_swaps_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_shift_swaps_updated_at BEFORE UPDATE ON public.shift_swaps FOR EACH ROW EXECUTE FUNCTION public.update_shift_swaps_updated_at();


--
-- Name: teams trigger_update_teams_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_teams_updated_at BEFORE UPDATE ON public.teams FOR EACH ROW EXECUTE FUNCTION public.update_teams_updated_at();


--
-- Name: user_profiles trigger_update_user_profiles_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_user_profiles_updated_at BEFORE UPDATE ON public.user_profiles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: schedule_assignments trigger_validate_assignment_time_conflict; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_validate_assignment_time_conflict BEFORE INSERT OR UPDATE ON public.schedule_assignments FOR EACH ROW EXECUTE FUNCTION public.validate_assignment_time_conflict();


--
-- Name: schedule_assignments trigger_validate_assignment_training; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_validate_assignment_training BEFORE INSERT OR UPDATE ON public.schedule_assignments FOR EACH ROW EXECUTE FUNCTION public.validate_assignment_training();


--
-- Name: shift_swaps trigger_validate_shift_swap_date; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_validate_shift_swap_date BEFORE INSERT OR UPDATE ON public.shift_swaps FOR EACH ROW EXECUTE FUNCTION public.validate_shift_swap_date();


--
-- Name: business_rules update_business_rules_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_business_rules_updated_at BEFORE UPDATE ON public.business_rules FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: daily_targets update_daily_targets_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_daily_targets_updated_at BEFORE UPDATE ON public.daily_targets FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: employees update_employees_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_employees_updated_at BEFORE UPDATE ON public.employees FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: job_functions update_job_functions_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_job_functions_updated_at BEFORE UPDATE ON public.job_functions FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: schedule_assignments update_schedule_assignments_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_schedule_assignments_updated_at BEFORE UPDATE ON public.schedule_assignments FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: business_rules business_rules_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.business_rules
    ADD CONSTRAINT business_rules_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE CASCADE;


--
-- Name: daily_targets_archive daily_targets_archive_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.daily_targets_archive
    ADD CONSTRAINT daily_targets_archive_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE SET NULL;


--
-- Name: daily_targets daily_targets_job_function_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.daily_targets
    ADD CONSTRAINT daily_targets_job_function_id_fkey FOREIGN KEY (job_function_id) REFERENCES public.job_functions(id) ON DELETE CASCADE;


--
-- Name: daily_targets daily_targets_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.daily_targets
    ADD CONSTRAINT daily_targets_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE CASCADE;


--
-- Name: employee_training employee_training_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employee_training
    ADD CONSTRAINT employee_training_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE;


--
-- Name: employee_training employee_training_job_function_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employee_training
    ADD CONSTRAINT employee_training_job_function_id_fkey FOREIGN KEY (job_function_id) REFERENCES public.job_functions(id) ON DELETE CASCADE;


--
-- Name: employee_training employee_training_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employee_training
    ADD CONSTRAINT employee_training_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE CASCADE;


--
-- Name: employees employees_shift_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employees
    ADD CONSTRAINT employees_shift_id_fkey FOREIGN KEY (shift_id) REFERENCES public.shifts(id) ON DELETE SET NULL;


--
-- Name: employees employees_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.employees
    ADD CONSTRAINT employees_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE CASCADE;


--
-- Name: job_functions job_functions_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.job_functions
    ADD CONSTRAINT job_functions_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE CASCADE;


--
-- Name: password_reset_tokens password_reset_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.password_reset_tokens
    ADD CONSTRAINT password_reset_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user_profiles(id) ON DELETE CASCADE;


--
-- Name: preferred_assignments preferred_assignments_am_job_function_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.preferred_assignments
    ADD CONSTRAINT preferred_assignments_am_job_function_id_fkey FOREIGN KEY (am_job_function_id) REFERENCES public.job_functions(id) ON DELETE SET NULL;


--
-- Name: preferred_assignments preferred_assignments_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.preferred_assignments
    ADD CONSTRAINT preferred_assignments_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE;


--
-- Name: preferred_assignments preferred_assignments_job_function_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.preferred_assignments
    ADD CONSTRAINT preferred_assignments_job_function_id_fkey FOREIGN KEY (job_function_id) REFERENCES public.job_functions(id) ON DELETE CASCADE;


--
-- Name: preferred_assignments preferred_assignments_pm_job_function_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.preferred_assignments
    ADD CONSTRAINT preferred_assignments_pm_job_function_id_fkey FOREIGN KEY (pm_job_function_id) REFERENCES public.job_functions(id) ON DELETE SET NULL;


--
-- Name: preferred_assignments preferred_assignments_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.preferred_assignments
    ADD CONSTRAINT preferred_assignments_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE CASCADE;


--
-- Name: pto_days pto_days_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pto_days
    ADD CONSTRAINT pto_days_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE;


--
-- Name: pto_days pto_days_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pto_days
    ADD CONSTRAINT pto_days_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE CASCADE;


--
-- Name: schedule_assignments_archive schedule_assignments_archive_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule_assignments_archive
    ADD CONSTRAINT schedule_assignments_archive_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE SET NULL;


--
-- Name: schedule_assignments schedule_assignments_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule_assignments
    ADD CONSTRAINT schedule_assignments_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE;


--
-- Name: schedule_assignments schedule_assignments_job_function_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule_assignments
    ADD CONSTRAINT schedule_assignments_job_function_id_fkey FOREIGN KEY (job_function_id) REFERENCES public.job_functions(id) ON DELETE CASCADE;


--
-- Name: schedule_assignments schedule_assignments_shift_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule_assignments
    ADD CONSTRAINT schedule_assignments_shift_id_fkey FOREIGN KEY (shift_id) REFERENCES public.shifts(id) ON DELETE CASCADE;


--
-- Name: schedule_assignments schedule_assignments_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule_assignments
    ADD CONSTRAINT schedule_assignments_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE CASCADE;


--
-- Name: schedule_requests schedule_requests_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule_requests
    ADD CONSTRAINT schedule_requests_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE;


--
-- Name: schedule_requests schedule_requests_original_shift_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule_requests
    ADD CONSTRAINT schedule_requests_original_shift_id_fkey FOREIGN KEY (original_shift_id) REFERENCES public.shifts(id);


--
-- Name: schedule_requests schedule_requests_requested_shift_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule_requests
    ADD CONSTRAINT schedule_requests_requested_shift_id_fkey FOREIGN KEY (requested_shift_id) REFERENCES public.shifts(id);


--
-- Name: schedule_requests schedule_requests_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule_requests
    ADD CONSTRAINT schedule_requests_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE CASCADE;


--
-- Name: shift_swaps shift_swaps_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shift_swaps
    ADD CONSTRAINT shift_swaps_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE CASCADE;


--
-- Name: shift_swaps shift_swaps_original_shift_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shift_swaps
    ADD CONSTRAINT shift_swaps_original_shift_id_fkey FOREIGN KEY (original_shift_id) REFERENCES public.shifts(id) ON DELETE CASCADE;


--
-- Name: shift_swaps shift_swaps_swapped_shift_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shift_swaps
    ADD CONSTRAINT shift_swaps_swapped_shift_id_fkey FOREIGN KEY (swapped_shift_id) REFERENCES public.shifts(id) ON DELETE CASCADE;


--
-- Name: shift_swaps shift_swaps_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shift_swaps
    ADD CONSTRAINT shift_swaps_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE CASCADE;


--
-- Name: shifts shifts_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shifts
    ADD CONSTRAINT shifts_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE CASCADE;


--
-- Name: staffing_targets staffing_targets_job_function_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.staffing_targets
    ADD CONSTRAINT staffing_targets_job_function_fkey FOREIGN KEY (job_function_id) REFERENCES public.job_functions(id) ON DELETE CASCADE;


--
-- Name: staffing_targets staffing_targets_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.staffing_targets
    ADD CONSTRAINT staffing_targets_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE CASCADE;


--
-- Name: target_hours target_hours_job_function_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.target_hours
    ADD CONSTRAINT target_hours_job_function_fkey FOREIGN KEY (job_function_id) REFERENCES public.job_functions(id) ON DELETE CASCADE;


--
-- Name: target_hours target_hours_team_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.target_hours
    ADD CONSTRAINT target_hours_team_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE CASCADE;


--
-- Name: team_blocked_dates team_blocked_dates_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.team_blocked_dates
    ADD CONSTRAINT team_blocked_dates_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE CASCADE;


--
-- Name: team_settings team_settings_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.team_settings
    ADD CONSTRAINT team_settings_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE CASCADE;


--
-- Name: user_profiles user_profiles_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id) ON DELETE SET NULL;


--
-- Name: user_profiles user_profiles_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

