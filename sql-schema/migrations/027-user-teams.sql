-- 027: an account can work in more than one team (Oct 2026).
--
-- user_profiles.team_id stays the account's HOME team: where it signs in, whose user
-- list it belongs to, what a team delete counts. user_teams holds the EXTRA teams a
-- Super Admin has given it (Supervisors and Team Leads only; never a kiosk). The
-- account still works in ONE team at a time: the session carries which, and every
-- team-scoped route reads that team exactly as before (server/middleware/auth.ts).
--
-- Additive: the table starts empty, so nobody can reach another team until a Super
-- Admin assigns one in Settings → Users. Deleting a team or an account removes its
-- memberships with it.
CREATE TABLE IF NOT EXISTS user_teams (
  user_id    uuid        NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  team_id    uuid        NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT user_teams_pkey PRIMARY KEY (user_id, team_id)
);

-- "Who works in this team" (each team's user list, and the membership check).
CREATE INDEX IF NOT EXISTS idx_user_teams_team ON user_teams (team_id);
