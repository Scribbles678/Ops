-- Check if a standalone "Meter" job function exists (not "Meter 1", "Meter 2", etc.)
-- Run this query first to see if it exists:

SELECT * FROM job_functions WHERE name = 'Meter';

-- If the above returns a row, you can safely delete it with this:
-- NOTE: This will also delete any employee training records that reference it
-- If employees have training on the standalone "Meter", you may want to reassign
-- those to individual meters (Meter 1, Meter 2, etc.) first

-- Check for any training records using the standalone "Meter"
SELECT et.*, e.first_name, e.last_name, jf.name as job_function_name
FROM employee_training et
JOIN employees e ON et.employee_id = e.id
JOIN job_functions jf ON et.job_function_id = jf.id
WHERE jf.name = 'Meter';

-- If there are training records, you may want to migrate them first:
-- Option 1: Delete the training records (employees will need to be retrained)
-- DELETE FROM employee_training WHERE job_function_id IN (SELECT id FROM job_functions WHERE name = 'Meter');

-- Option 2: Migrate training to Meter 1 (example - adjust as needed)
-- UPDATE employee_training 
-- SET job_function_id = (SELECT id FROM job_functions WHERE name = 'Meter 1' LIMIT 1)
-- WHERE job_function_id IN (SELECT id FROM job_functions WHERE name = 'Meter');

-- Once training is handled, delete the standalone "Meter" job function:
-- DELETE FROM job_functions WHERE name = 'Meter';

