-- 014 — Remove the Database Cleanup feature
--
-- The cleanup feature moved schedule assignments and daily targets older than
-- 30 days out of the live tables and into their archive twins. It has been
-- removed from the app (tab, page, API routes and composable are all gone), so
-- the stored procedures behind it are now dead code.
--
-- WHAT THIS DROPS
--   cleanup_old_schedules_with_logging()  the archiver itself
--   get_cleanup_stats()                   its stats helper
--   cleanup_log                           its run log (no schedule data)
--   cleanup_status                        legacy view/table, if present
--
-- WHAT THIS DELIBERATELY KEEPS
--   schedule_assignments_archive
--   daily_targets_archive
--
-- Those two tables are NOT dropped. On any install where cleanup was ever run
-- they hold real schedule history, and dropping them would destroy it. Nothing
-- writes to them any more; the schedule CSV export reads them alongside the live
-- tables so a date range spanning the old 30-day cutoff still returns whole
-- results. They are safe to leave in place indefinitely.
--
-- Safe to re-run.

BEGIN;

DROP FUNCTION IF EXISTS cleanup_old_schedules_with_logging();
DROP FUNCTION IF EXISTS get_cleanup_stats();

DROP TABLE IF EXISTS cleanup_log;

-- cleanup_status was a status view in some installs and a table in others.
DROP VIEW  IF EXISTS cleanup_status;
DROP TABLE IF EXISTS cleanup_status;

COMMIT;

-- Verify (all four should return 0):
--   SELECT count(*) FROM pg_proc  WHERE proname IN ('cleanup_old_schedules_with_logging','get_cleanup_stats');
--   SELECT count(*) FROM pg_class WHERE relname IN ('cleanup_log','cleanup_status');
-- And confirm the archives survived:
--   SELECT count(*) FROM schedule_assignments_archive;
--   SELECT count(*) FROM daily_targets_archive;
