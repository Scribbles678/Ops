-- Per-team blocked dates for PTO/leave-early auto-approval.
-- When a date appears here, requests for that date (pto_full_day, pto_partial,
-- leave_early) are auto-rejected with the stored reason as the rejection message.

CREATE TABLE IF NOT EXISTS team_blocked_dates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  blocked_date DATE NOT NULL,
  reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(team_id, blocked_date)
);

CREATE INDEX IF NOT EXISTS idx_team_blocked_dates_team_date
  ON team_blocked_dates(team_id, blocked_date);
