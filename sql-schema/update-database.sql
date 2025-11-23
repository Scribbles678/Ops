-- Complete Database Update Script for Operations Scheduling Tool
-- Run this in your Supabase SQL Editor to update your existing database

-- Step 1: Add new columns to job_functions table
ALTER TABLE job_functions 
ADD COLUMN IF NOT EXISTS unit_of_measure TEXT,
ADD COLUMN IF NOT EXISTS custom_unit TEXT;

-- Step 2: Update existing job functions with correct names, colors, rates, and units
-- (This will update any existing functions to match the new structure)

-- Update RT Pick
UPDATE job_functions 
SET name = 'RT Pick', 
    color_code = '#FFA500', 
    productivity_rate = 200, 
    unit_of_measure = 'cartons/hour' 
WHERE name IN ('RT Pick', 'RT-Pick') OR id IN (
    SELECT id FROM job_functions WHERE name LIKE '%RT%' OR name LIKE '%Pick%' LIMIT 1
);

-- Update Pick
UPDATE job_functions 
SET name = 'Pick', 
    color_code = '#FFFF00', 
    productivity_rate = 180, 
    unit_of_measure = 'cartons/hour' 
WHERE name IN ('Pick', 'EM9 Packsize') OR id IN (
    SELECT id FROM job_functions WHERE name LIKE '%Pick%' OR name LIKE '%EM9%' LIMIT 1
);

-- Update Meter
UPDATE job_functions 
SET name = 'Meter', 
    color_code = '#87CEEB', 
    productivity_rate = 150, 
    unit_of_measure = 'boxes/hour' 
WHERE name IN ('Meter', 'Meter 11') OR id IN (
    SELECT id FROM job_functions WHERE name LIKE '%Meter%' LIMIT 1
);

-- Update Locus
UPDATE job_functions 
SET name = 'Locus', 
    color_code = '#FFFFFF', 
    productivity_rate = 220, 
    unit_of_measure = 'cartons/hour' 
WHERE name IN ('Locus', 'Locus All') OR id IN (
    SELECT id FROM job_functions WHERE name LIKE '%Locus%' LIMIT 1
);

-- Update Helpdesk
UPDATE job_functions 
SET name = 'Helpdesk', 
    color_code = '#FFD700' 
WHERE name IN ('Helpdesk', 'Help Desk') OR id IN (
    SELECT id FROM job_functions WHERE name LIKE '%Help%' LIMIT 1
);

-- Step 3: Insert any missing job functions
INSERT INTO job_functions (name, color_code, productivity_rate, unit_of_measure, sort_order) 
SELECT * FROM (VALUES 
  ('RT Pick', '#FFA500', 200, 'cartons/hour', 1),
  ('Pick', '#FFFF00', 180, 'cartons/hour', 2),
  ('Meter', '#87CEEB', 150, 'boxes/hour', 3),
  ('Locus', '#FFFFFF', 220, 'cartons/hour', 4),
  ('Helpdesk', '#FFD700', NULL, NULL, 5),
  ('Coordinator', '#C0C0C0', NULL, NULL, 6),
  ('Team Lead', '#000080', NULL, NULL, 7),
  ('Validated', '#FF0000', NULL, NULL, 8),
  ('Freight', '#800080', NULL, NULL, 9)
) AS new_jobs(name, color_code, productivity_rate, unit_of_measure, sort_order)
WHERE NOT EXISTS (SELECT 1 FROM job_functions WHERE job_functions.name = new_jobs.name);

-- Step 4: Clean up any duplicate or old job functions (optional)
-- DELETE FROM job_functions WHERE name IN ('RT-Pick', 'EM9 Packsize', 'Meter 11', 'Locus All', 'Help Desk');

-- Step 5: Verify the results
SELECT 
    id, 
    name, 
    color_code, 
    productivity_rate, 
    unit_of_measure, 
    sort_order 
FROM job_functions 
ORDER BY sort_order;

-- Step 6: Show summary
SELECT 
    'Job Functions Updated' as status,
    COUNT(*) as total_functions,
    COUNT(CASE WHEN productivity_rate IS NOT NULL THEN 1 END) as functions_with_rates,
    COUNT(CASE WHEN unit_of_measure IS NOT NULL THEN 1 END) as functions_with_units
FROM job_functions;
