-- Update Locus color to gold for better visibility
-- Run this SQL in your Supabase SQL Editor

UPDATE job_functions
SET color_code = '#FFD700' -- Gold color (readable with white text)
WHERE name = 'Locus';

-- Verify the update
SELECT name, color_code FROM job_functions WHERE name = 'Locus';

