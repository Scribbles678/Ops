-- Database Updates for Operations Scheduling Tool
-- Run this SQL in your Supabase SQL Editor if you already have an existing database

-- Add new columns to job_functions table
ALTER TABLE job_functions 
ADD COLUMN IF NOT EXISTS unit_of_measure TEXT,
ADD COLUMN IF NOT EXISTS custom_unit TEXT;

-- Update existing job functions with default units of measure
UPDATE job_functions SET unit_of_measure = 'cartons/hour' WHERE name = 'RT Pick';
UPDATE job_functions SET unit_of_measure = 'cartons/hour' WHERE name = 'Pick';
UPDATE job_functions SET unit_of_measure = 'boxes/hour' WHERE name = 'Meter';
UPDATE job_functions SET unit_of_measure = 'cartons/hour' WHERE name = 'Locus';

-- If you have the old sample job functions, update them to match new names and colors
-- First, let's see what job functions you currently have
-- SELECT * FROM job_functions;

-- If you need to update existing job functions to match the new ones, run these:
-- UPDATE job_functions SET name = 'RT Pick', color_code = '#FFA500', productivity_rate = 200, unit_of_measure = 'cartons/hour' WHERE name = 'RT-Pick';
-- UPDATE job_functions SET name = 'Pick', color_code = '#FFFF00', productivity_rate = 180, unit_of_measure = 'cartons/hour' WHERE name = 'EM9 Packsize';
-- UPDATE job_functions SET name = 'Meter', color_code = '#87CEEB', productivity_rate = 150, unit_of_measure = 'boxes/hour' WHERE name = 'Meter 11';
-- UPDATE job_functions SET name = 'Locus', color_code = '#FFFFFF', productivity_rate = 220, unit_of_measure = 'cartons/hour' WHERE name = 'Locus All';
-- UPDATE job_functions SET name = 'Helpdesk', color_code = '#FFD700' WHERE name = 'Help Desk';

-- If you need to add the new job functions that don't exist yet:
INSERT INTO job_functions (name, color_code, productivity_rate, unit_of_measure, sort_order) 
SELECT * FROM (VALUES 
  ('Coordinator', '#C0C0C0', NULL, NULL, 6),
  ('Team Lead', '#000080', NULL, NULL, 7),
  ('Validated', '#FF0000', NULL, NULL, 8),
  ('Freight', '#800080', NULL, NULL, 9)
) AS new_jobs(name, color_code, productivity_rate, unit_of_measure, sort_order)
WHERE NOT EXISTS (SELECT 1 FROM job_functions WHERE job_functions.name = new_jobs.name);

-- Verify the changes
SELECT id, name, color_code, productivity_rate, unit_of_measure FROM job_functions ORDER BY sort_order;
