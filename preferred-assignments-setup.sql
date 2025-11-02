-- Preferred Assignments Table
-- This table stores preferred or required employee-job function assignments
-- When enabled, these assignments will be prioritized in AI schedule generation
-- and suggested in manual schedule creation

CREATE TABLE IF NOT EXISTS preferred_assignments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  job_function_id UUID NOT NULL REFERENCES job_functions(id) ON DELETE CASCADE,
  is_required BOOLEAN DEFAULT false, -- If true, employee should always be assigned to this function when available
  priority INTEGER DEFAULT 0, -- Higher priority = assigned first (0 = lowest priority)
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(employee_id, job_function_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_preferred_assignments_employee ON preferred_assignments(employee_id);
CREATE INDEX IF NOT EXISTS idx_preferred_assignments_job_function ON preferred_assignments(job_function_id);
CREATE INDEX IF NOT EXISTS idx_preferred_assignments_required ON preferred_assignments(is_required) WHERE is_required = true;

-- Enable Row Level Security
ALTER TABLE preferred_assignments ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "Enable read access for all users" ON preferred_assignments;
CREATE POLICY "Enable read access for all users" ON preferred_assignments FOR SELECT USING (true);

DROP POLICY IF EXISTS "Enable insert access for all users" ON preferred_assignments;
CREATE POLICY "Enable insert access for all users" ON preferred_assignments FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Enable update access for all users" ON preferred_assignments;
CREATE POLICY "Enable update access for all users" ON preferred_assignments FOR UPDATE USING (true);

DROP POLICY IF EXISTS "Enable delete access for all users" ON preferred_assignments;
CREATE POLICY "Enable delete access for all users" ON preferred_assignments FOR DELETE USING (true);

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_preferred_assignments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_preferred_assignments_updated_at ON preferred_assignments;
CREATE TRIGGER trigger_update_preferred_assignments_updated_at
    BEFORE UPDATE ON preferred_assignments
    FOR EACH ROW
    EXECUTE FUNCTION update_preferred_assignments_updated_at();

