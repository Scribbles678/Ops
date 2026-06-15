-- Make required-assignment halves explicit so a NULL half can newly mean
-- "not pinned" (fill by demand) instead of "same as the base function".
-- One-time backfill: set any NULL am/pm to the row's job_function_id, preserving
-- the OLD effective behavior. After this, the builder treats a NULL half as
-- intentionally unpinned. Guarded by a marker so it never re-runs (which would
-- clobber intentional NULLs on rows created with the new one-half feature).
CREATE TABLE IF NOT EXISTS _data_backfills (
  key text PRIMARY KEY,
  applied_at timestamptz DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _data_backfills WHERE key = '012-explicit-half-assignments') THEN
    UPDATE preferred_assignments
      SET am_job_function_id = COALESCE(am_job_function_id, job_function_id),
          pm_job_function_id = COALESCE(pm_job_function_id, job_function_id)
      WHERE am_job_function_id IS NULL OR pm_job_function_id IS NULL;
    INSERT INTO _data_backfills (key) VALUES ('012-explicit-half-assignments');
  END IF;
END $$;
