-- 015 — Performance tracking: picking errors and review notes
--
-- Two tables, both ADMIN-ONLY at the API layer (requireAdmin on every route).
-- This is review material about named people: regular Users keep their scheduling
-- access but never see it, and Display/kiosk accounts can never reach it at all.
--
--   performance_errors  one logged error occurrence (mostly picking)
--   performance_notes   free-text notes for reviews, with immutable authorship
--
-- Authorship (created_by) is ON DELETE SET NULL rather than CASCADE: deleting a
-- user account must never silently erase the error log or the notes they wrote.
--
-- Safe to re-run.

BEGIN;

-- ============================================================
-- PERFORMANCE ERRORS
-- ============================================================

CREATE TABLE IF NOT EXISTS performance_errors (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL,
  job_function_id uuid,
  error_date date NOT NULL,
  error_count integer NOT NULL DEFAULT 1,
  error_type text,
  notes text,
  team_id uuid,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT performance_errors_pkey PRIMARY KEY (id),
  CONSTRAINT performance_errors_employee_fkey
    FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE,
  -- Keep the error if the function is later retired; just lose the label.
  CONSTRAINT performance_errors_function_fkey
    FOREIGN KEY (job_function_id) REFERENCES job_functions(id) ON DELETE SET NULL,
  CONSTRAINT performance_errors_team_fkey
    FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE,
  CONSTRAINT performance_errors_author_fkey
    FOREIGN KEY (created_by) REFERENCES user_profiles(id) ON DELETE SET NULL,
  CONSTRAINT check_performance_error_count CHECK (error_count > 0),
  CONSTRAINT check_performance_error_type_length CHECK (error_type IS NULL OR length(error_type) <= 60),
  CONSTRAINT check_performance_error_notes_length CHECK (notes IS NULL OR length(notes) <= 2000)
);

CREATE INDEX IF NOT EXISTS idx_performance_errors_employee ON performance_errors (employee_id);
CREATE INDEX IF NOT EXISTS idx_performance_errors_date     ON performance_errors (error_date);
CREATE INDEX IF NOT EXISTS idx_performance_errors_team     ON performance_errors (team_id);

-- ============================================================
-- PERFORMANCE NOTES
-- ============================================================

CREATE TABLE IF NOT EXISTS performance_notes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  employee_id uuid NOT NULL,
  note_date date NOT NULL DEFAULT CURRENT_DATE,
  category text NOT NULL DEFAULT 'general',
  body text NOT NULL,
  team_id uuid,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT performance_notes_pkey PRIMARY KEY (id),
  CONSTRAINT performance_notes_employee_fkey
    FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE,
  CONSTRAINT performance_notes_team_fkey
    FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE,
  CONSTRAINT performance_notes_author_fkey
    FOREIGN KEY (created_by) REFERENCES user_profiles(id) ON DELETE SET NULL,
  CONSTRAINT check_performance_note_category
    CHECK (category IN ('positive', 'coaching', 'concern', 'general')),
  CONSTRAINT check_performance_note_body_not_empty CHECK (TRIM(BOTH FROM body) <> ''),
  CONSTRAINT check_performance_note_body_length CHECK (length(body) <= 5000)
);

CREATE INDEX IF NOT EXISTS idx_performance_notes_employee ON performance_notes (employee_id);
CREATE INDEX IF NOT EXISTS idx_performance_notes_date     ON performance_notes (note_date);
CREATE INDEX IF NOT EXISTS idx_performance_notes_team     ON performance_notes (team_id);

-- Reuse the shared updated_at trigger function already defined in setup.sql.
DROP TRIGGER IF EXISTS update_performance_errors_updated_at ON performance_errors;
CREATE TRIGGER update_performance_errors_updated_at
  BEFORE UPDATE ON performance_errors
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_performance_notes_updated_at ON performance_notes;
CREATE TRIGGER update_performance_notes_updated_at
  BEFORE UPDATE ON performance_notes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMIT;
