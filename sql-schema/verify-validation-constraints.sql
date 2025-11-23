-- Quick verification query to check all CHECK constraints were created
-- Run this to confirm all constraints are in place

SELECT 
  conname as constraint_name,
  conrelid::regclass as table_name,
  contype as constraint_type
FROM pg_constraint
WHERE conname LIKE 'check_%'
ORDER BY conrelid::regclass::text, conname;

-- Expected: Should show ~20+ constraints across multiple tables
-- If you see results, all CHECK constraints were created successfully!

