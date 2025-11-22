-- Clear Employees, Training, and Schedule Records
-- This will delete all employees, their training assignments, and schedule records
-- WARNING: This will permanently delete all employee data!

-- Delete order respects foreign key constraints:
-- 1. Schedule assignments (references employees)
-- 2. Employee training (references employees)
-- 3. Employees (will cascade to the above, but explicit deletion is clearer)

BEGIN;

-- 1. Delete all schedule assignments
DELETE FROM schedule_assignments;

-- 2. Delete all employee training records
DELETE FROM employee_training;

-- 3. Delete all employees
DELETE FROM employees;

COMMIT;

-- Verify deletions (optional - uncomment to run)
-- SELECT 'schedule_assignments' as table_name, COUNT(*) as remaining_records FROM schedule_assignments
-- UNION ALL
-- SELECT 'employee_training', COUNT(*) FROM employee_training
-- UNION ALL
-- SELECT 'employees', COUNT(*) FROM employees;

