-- 025 — Each team has its own time zone
--
-- WHY: the app pod and this database run on UTC, so "today" rolled over at 7pm
-- Central (5pm Pacific). Evening requests were refused for too little notice, today
-- showed as past, and a same-day shift swap entered in the evening was rejected by
-- the trigger below as "a past date". Sites in different zones can't share one
-- "today" anyway. The app reads a team's today from this column
-- (server/utils/teamTime.ts); the super admin sets it per team in Settings → Teams.
--
-- Existing teams get America/Chicago, the zone the app has assumed so far (the kiosk
-- board was hard-wired to it). Set any site outside Central after deploying.
--
-- Re-run safe.

ALTER TABLE teams ADD COLUMN IF NOT EXISTS timezone text NOT NULL DEFAULT 'America/Chicago';

-- Same-day swaps: "past" by the SITE's calendar. An unknown zone name (it is checked
-- when saved, so this is belt and braces) falls back to the database's own date
-- rather than blocking every swap.
CREATE OR REPLACE FUNCTION validate_shift_swap_date() RETURNS trigger AS $$
DECLARE
  site_today date;
BEGIN
  BEGIN
    SELECT (now() AT TIME ZONE t.timezone)::date INTO site_today FROM teams t WHERE t.id = NEW.team_id;
  EXCEPTION WHEN others THEN
    site_today := NULL;
  END;
  IF NEW.swap_date < COALESCE(site_today, CURRENT_DATE) THEN
    RAISE EXCEPTION 'Cannot create shift swap for a past date';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
