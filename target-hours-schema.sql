-- Target Hours Table
-- This table stores target hours for each job function
CREATE TABLE IF NOT EXISTS target_hours (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  job_function_id UUID NOT NULL REFERENCES job_functions(id) ON DELETE CASCADE,
  target_hours DECIMAL(5,2) NOT NULL DEFAULT 0.00,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(job_function_id)
);

-- Create updated_at trigger for target_hours
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_target_hours_updated_at 
  BEFORE UPDATE ON target_hours 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert default target hours for existing job functions
INSERT INTO target_hours (job_function_id, target_hours)
SELECT id, 8.00 FROM job_functions
ON CONFLICT (job_function_id) DO NOTHING;

-- Add RLS policies
ALTER TABLE target_hours ENABLE ROW LEVEL SECURITY;

-- Allow all operations for authenticated users
CREATE POLICY "Allow all operations on target_hours for authenticated users" ON target_hours
  FOR ALL USING (true);
