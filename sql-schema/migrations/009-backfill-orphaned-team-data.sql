-- One-time data repair: adopt orphaned, team-less rows into the "domestic" team.
--
-- Why this exists:
--   Before the getWriteTeamId() fix, records created by a super admin were
--   stamped with team_id = NULL (super admins bypassed the team stamp). Those
--   rows are invisible to regular team admins, who read with WHERE team_id = <their team>.
--   The "domestic" team was built out this way, so its data is orphaned at NULL.
--
-- What this does:
--   Finds the team named "domestic" and reassigns every NULL-team operational
--   row to it, so the domestic team's admins can see the setup that was created.
--
-- Safety:
--   * No-op on a fresh install (no "domestic" team yet → nothing happens).
--   * Runs exactly once: a marker row in _data_backfills prevents it from ever
--     sweeping future NULL-team rows into domestic on later deploys.
--   * Only touches operational tables — never user_profiles (user/team
--     assignments are left alone).

DO $$
DECLARE
  v_team_id uuid;
  v_already boolean;
BEGIN
  -- One-time guard ledger (separate from schema migrations; tracks data backfills).
  CREATE TABLE IF NOT EXISTS _data_backfills (
    key text PRIMARY KEY,
    applied_at timestamptz DEFAULT now()
  );

  SELECT EXISTS (
    SELECT 1 FROM _data_backfills WHERE key = '009-backfill-orphaned-team-data'
  ) INTO v_already;

  IF v_already THEN
    RAISE NOTICE '[009] orphaned-team backfill already applied — skipping';
    RETURN;
  END IF;

  SELECT id INTO v_team_id
  FROM teams
  WHERE lower(name) = 'domestic'
  ORDER BY created_at
  LIMIT 1;

  IF v_team_id IS NULL THEN
    -- Fresh install or domestic not created yet. Do nothing and do NOT mark done,
    -- so the backfill can still apply on a later deploy once domestic exists.
    RAISE NOTICE '[009] no "domestic" team found — nothing to adopt (skipping, not marking done)';
    RETURN;
  END IF;

  UPDATE employees             SET team_id = v_team_id WHERE team_id IS NULL;
  UPDATE shifts                SET team_id = v_team_id WHERE team_id IS NULL;
  UPDATE job_functions         SET team_id = v_team_id WHERE team_id IS NULL;
  UPDATE employee_training     SET team_id = v_team_id WHERE team_id IS NULL;
  UPDATE staffing_targets      SET team_id = v_team_id WHERE team_id IS NULL;
  UPDATE preferred_assignments SET team_id = v_team_id WHERE team_id IS NULL;
  UPDATE pto_days              SET team_id = v_team_id WHERE team_id IS NULL;
  UPDATE shift_swaps           SET team_id = v_team_id WHERE team_id IS NULL;
  UPDATE daily_targets         SET team_id = v_team_id WHERE team_id IS NULL;
  UPDATE target_hours          SET team_id = v_team_id WHERE team_id IS NULL;
  UPDATE business_rules        SET team_id = v_team_id WHERE team_id IS NULL;
  UPDATE schedule_assignments  SET team_id = v_team_id WHERE team_id IS NULL;
  UPDATE schedule_requests     SET team_id = v_team_id WHERE team_id IS NULL;

  INSERT INTO _data_backfills (key) VALUES ('009-backfill-orphaned-team-data');

  RAISE NOTICE '[009] orphaned team-less rows adopted into "domestic" team %', v_team_id;
END $$;
