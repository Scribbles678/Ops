-- Test script to check if shift_id column exists in employees table
-- Run this in your Supabase SQL Editor to verify the column exists

-- Check if the column exists
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'employees' 
AND column_name = 'shift_id';

-- If the above returns no results, run this to add the column:
-- ALTER TABLE employees ADD COLUMN shift_id UUID REFERENCES shifts(id) ON DELETE SET NULL;
