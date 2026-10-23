-- 024 — The database keeps each team's rows pointing only at its own team's rows
--
-- WHY: every team-owned table carries team_id, but until now nothing in the database
-- stopped a row stamped with team A from pointing at team B's employee, job function
-- or shift. The app checks this (server/utils/teamOwnership.ts, Sep 2026), but the
-- Sep 2026 audit found a dozen routes that didn't — a Site A save could put Site B's
-- people on Site A's board, and then block Site B's own save for that day. This is
-- the backstop: a composite foreign key (child.x_id, child.team_id) →
-- parent(id, team_id) on every such link, so a cross-team reference is refused by
-- the database even if a future route forgets the check.
--
-- SAFE ON A LIVE MULTI-TEAM DATABASE — nothing here deletes or rewrites data:
--   * New keys are added NOT VALID: they check every new or changed row at once but
--     don't reject rows that are already there. Section 3 then tries to VALIDATE
--     each one; if old cross-team rows exist it leaves that key NOT VALID and prints
--     a WARNING (in the boot log) instead of failing — fix those rows by hand, and the
--     next boot validates it. Run the read-only check in docs/RANCHER-DEPLOYMENT.md
--     ("Before deploying migration 024") first to know in advance.
--   * team_id is made NOT NULL only on tables that have no NULL rows; any table that
--     has some is skipped with a WARNING.
--   * Each new key copies the ON DELETE rule of the existing single-column key, so
--     deleting a parent behaves exactly as before.
--
-- Re-run safe: every step checks the catalog first, so after the first boot it does
-- nothing but look.

-- 1. Parents: (id, team_id) must be unique for a composite key to point at it.
--    Trivially true (id is the primary key); this only creates the index.
DO $$
DECLARE p text;
BEGIN
  FOREACH p IN ARRAY ARRAY['employees', 'job_functions', 'shifts', 'preferred_assignments'] LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = p::regclass AND conname = p || '_id_team_key') THEN
      EXECUTE format('ALTER TABLE %I ADD CONSTRAINT %I UNIQUE (id, team_id)', p, p || '_id_team_key');
    END IF;
  END LOOP;
END $$;

-- 2. The same-team keys, NOT VALID. (child table, column, parent, ON DELETE)
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('schedule_assignments',        'employee_id',             'employees',             'CASCADE'),
    ('schedule_assignments',        'job_function_id',         'job_functions',         'CASCADE'),
    ('schedule_assignments',        'shift_id',                'shifts',                'CASCADE'),
    ('employee_training',           'employee_id',             'employees',             'CASCADE'),
    ('employee_training',           'job_function_id',         'job_functions',         'CASCADE'),
    ('employees',                   'shift_id',                'shifts',                'SET NULL (shift_id)'),
    ('pto_days',                    'employee_id',             'employees',             'CASCADE'),
    ('shift_swaps',                 'employee_id',             'employees',             'CASCADE'),
    ('shift_swaps',                 'original_shift_id',       'shifts',                'CASCADE'),
    ('shift_swaps',                 'swapped_shift_id',        'shifts',                'CASCADE'),
    ('schedule_requests',           'employee_id',             'employees',             'CASCADE'),
    ('schedule_requests',           'original_shift_id',       'shifts',                'NO ACTION'),
    ('schedule_requests',           'requested_shift_id',      'shifts',                'NO ACTION'),
    ('preferred_assignments',       'employee_id',             'employees',             'CASCADE'),
    ('preferred_assignments',       'job_function_id',         'job_functions',         'CASCADE'),
    ('preferred_assignments',       'am_job_function_id',      'job_functions',         'SET NULL (am_job_function_id)'),
    ('preferred_assignments',       'pm_job_function_id',      'job_functions',         'SET NULL (pm_job_function_id)'),
    ('preferred_assignment_blocks', 'preferred_assignment_id', 'preferred_assignments', 'CASCADE'),
    ('preferred_assignment_blocks', 'job_function_id',         'job_functions',         'CASCADE'),
    ('staffing_targets',            'job_function_id',         'job_functions',         'CASCADE'),
    ('daily_targets',               'job_function_id',         'job_functions',         'CASCADE'),
    ('target_hours',                'job_function_id',         'job_functions',         'CASCADE'),
    ('performance_errors',          'employee_id',             'employees',             'CASCADE'),
    ('performance_errors',          'job_function_id',         'job_functions',         'SET NULL (job_function_id)'),
    ('performance_notes',           'employee_id',             'employees',             'CASCADE'),
    ('attendance_points',           'employee_id',             'employees',             'CASCADE'),
    ('audit_log',                   'employee_id',             'employees',             'SET NULL (employee_id)')
  ) AS v(tbl, col, parent, on_delete) LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conrelid = r.tbl::regclass AND conname = r.tbl || '_' || r.col || '_same_team') THEN
      EXECUTE format(
        'ALTER TABLE %I ADD CONSTRAINT %I FOREIGN KEY (%I, team_id) REFERENCES %I (id, team_id) ON DELETE %s NOT VALID',
        r.tbl, r.tbl || '_' || r.col || '_same_team', r.col, r.parent, r.on_delete);
    END IF;
  END LOOP;
END $$;

-- 3. Validate each same-team key that is still NOT VALID. Old cross-team rows leave
--    that one key unvalidated (new writes are still checked) and print a WARNING.
DO $$
DECLARE c record;
BEGIN
  FOR c IN SELECT conrelid::regclass AS tbl, conname
           FROM pg_constraint
           WHERE contype = 'f' AND NOT convalidated AND conname LIKE '%\_same\_team' LOOP
    BEGIN
      EXECUTE format('ALTER TABLE %s VALIDATE CONSTRAINT %I', c.tbl, c.conname);
    EXCEPTION WHEN foreign_key_violation THEN
      RAISE WARNING '024: % has rows pointing at another team''s rows; % stays NOT VALID until they are fixed (new writes are still checked)', c.tbl, c.conname;
    END;
  END LOOP;
END $$;

-- 4. team_id NOT NULL wherever no NULL rows exist. A row with no team is invisible to
--    every team-scoped read, and it slips past every same-team key above.
DO $$
DECLARE t text; has_null boolean;
BEGIN
  FOREACH t IN ARRAY ARRAY['shifts', 'job_functions', 'employees', 'employee_training', 'schedule_assignments',
    'daily_targets', 'target_hours', 'pto_days', 'shift_swaps', 'preferred_assignments',
    'preferred_assignment_blocks', 'business_rules', 'staffing_targets', 'schedule_requests',
    'performance_errors', 'performance_notes', 'attendance_points', 'audit_log'] LOOP
    IF EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = t::regclass AND attname = 'team_id' AND NOT attnotnull) THEN
      EXECUTE format('SELECT EXISTS (SELECT 1 FROM %I WHERE team_id IS NULL)', t) INTO has_null;
      IF has_null THEN
        RAISE WARNING '024: % has rows with no team; team_id left nullable - assign or remove those rows by hand', t;
      ELSE
        EXECUTE format('ALTER TABLE %I ALTER COLUMN team_id SET NOT NULL', t);
      END IF;
    END IF;
  END LOOP;
END $$;

-- 5. Indexes the multi-team queries lean on. Each date-scoped read filters on
--    (team_id, date); the overlap trigger looks up (employee_id, schedule_date) on every
--    insert; and the cascading keys need an index on the child column, or deleting a
--    shift or job function scans the whole assignments table.
CREATE INDEX IF NOT EXISTS idx_sa_team_date       ON schedule_assignments (team_id, schedule_date);
CREATE INDEX IF NOT EXISTS idx_sa_employee_date   ON schedule_assignments (employee_id, schedule_date);
CREATE INDEX IF NOT EXISTS idx_sa_job_function    ON schedule_assignments (job_function_id);
CREATE INDEX IF NOT EXISTS idx_sa_shift           ON schedule_assignments (shift_id);
CREATE INDEX IF NOT EXISTS idx_pto_days_team_date ON pto_days (team_id, pto_date);
CREATE INDEX IF NOT EXISTS idx_sr_team_date       ON schedule_requests (team_id, request_date);
CREATE INDEX IF NOT EXISTS idx_sr_created_pto     ON schedule_requests (created_pto_id) WHERE created_pto_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_audit_log_actor    ON audit_log (actor_id) WHERE actor_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ss_original_shift  ON shift_swaps (original_shift_id);
CREATE INDEX IF NOT EXISTS idx_ss_swapped_shift   ON shift_swaps (swapped_shift_id);
