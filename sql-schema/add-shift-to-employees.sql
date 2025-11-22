-- Add shift_id column to employees table
-- Run this SQL in your Supabase SQL Editor

-- Add shift_id column to employees table
ALTER TABLE employees 
ADD COLUMN shift_id UUID REFERENCES shifts(id) ON DELETE SET NULL;

-- Add index for better performance
CREATE INDEX idx_employees_shift_id ON employees(shift_id);

-- Add comment to document the column
COMMENT ON COLUMN employees.shift_id IS 'The shift this employee is assigned to';
