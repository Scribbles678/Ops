-- 026: a password change signs the person out everywhere, and is recorded.
--
-- user_profiles.password_changed_at: when the password last changed (an admin reset,
-- the person's own change, or an emailed reset link). server/middleware/auth.ts
-- refuses a session token issued before it. Until Oct 2026 a reset changed only the
-- password: every browser already signed in — a kiosk for up to 30 days — stayed
-- signed in, so a reset couldn't shut out whoever had the old one.
-- NULL for every existing account, so nobody is signed out by this migration.
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS password_changed_at timestamptz;

-- audit_log: accept 'account' entries (password resets and changes; they carry no
-- password or hash). Re-run safe: acts only when the CHECK doesn't already allow it,
-- like 011, so it doesn't lock and re-scan audit_log on every boot.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'check_audit_log_entity'
      AND conrelid = 'audit_log'::regclass
      AND pg_get_constraintdef(oid) LIKE '%''account''%'
  ) THEN
    ALTER TABLE audit_log DROP CONSTRAINT IF EXISTS check_audit_log_entity;
    ALTER TABLE audit_log ADD CONSTRAINT check_audit_log_entity
      CHECK (entity_type IN (
        'request', 'pto_day', 'attendance_point', 'performance_note', 'performance_error',
        'account'
      ));
  END IF;
END $$;
