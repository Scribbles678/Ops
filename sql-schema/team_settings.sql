-- Team Settings Table
-- Key/value settings per team for configurable rules (PTO limits, swap limits, etc.)

CREATE TABLE IF NOT EXISTS team_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  setting_key VARCHAR(100) NOT NULL,
  setting_value TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(team_id, setting_key)
);

CREATE INDEX IF NOT EXISTS idx_team_settings_team ON team_settings(team_id);
