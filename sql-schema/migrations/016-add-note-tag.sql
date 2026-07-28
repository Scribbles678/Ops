-- 016 — Tag column for quick-add performance notes
--
-- The quick-add buttons ("Late from break", "Not on task", …) write a normal note,
-- but also stamp a stable tag so repeat incidents can be COUNTED. Free text alone
-- can't be tallied, and "late from break x5 this month" is exactly the kind of thing
-- a review needs.
--
-- Nullable: notes typed by hand have no tag, and that's the normal case.
--
-- Re-run safe (the bootstrap plugin applies every migration on each startup).

ALTER TABLE performance_notes
  ADD COLUMN IF NOT EXISTS tag text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'check_performance_note_tag_length'
  ) THEN
    ALTER TABLE performance_notes
      ADD CONSTRAINT check_performance_note_tag_length
      CHECK (tag IS NULL OR length(tag) <= 60);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_performance_notes_tag ON performance_notes (tag) WHERE tag IS NOT NULL;
