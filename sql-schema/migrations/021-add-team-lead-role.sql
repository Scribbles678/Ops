-- 021 — Team Lead / Coordinator role
--
-- Roles are four boolean flags on user_profiles; this adds the fourth:
--   is_super_admin   Super Admin            (unchanged)
--   is_admin         Supervisor             (the role formerly labelled "Admin")
--   is_team_lead     Team Lead / Coordinator (NEW — everything a Supervisor can do
--                                            except request rules and blocked dates)
--   is_display_user  Kiosk                  (unchanged)
--
-- Deliberately NO data change and NO exclusivity CHECK: existing accounts keep
-- exactly the flags they have, so nobody is locked out on deploy. Exactly-one-role
-- is enforced by the user endpoints from here on (utils/roles.ts), and a row that
-- still carries two flags from before behaves as its stronger role until it is
-- next edited. Which of today's Admins are really team leads is a judgement the
-- Super Admin makes per person in Settings → User Management, not a migration.
--
-- Additive and idempotent; safe to re-run.

ALTER TABLE user_profiles
  ADD COLUMN IF NOT EXISTS is_team_lead boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN user_profiles.is_team_lead IS
  'Team Lead / Coordinator role. One of four exclusive role flags; see utils/roles.ts.';
