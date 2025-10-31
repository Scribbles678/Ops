-- Business Rules Setup for AI Schedule Generation
-- Run this SQL script in your Supabase SQL Editor

-- Create Business Rules Table
CREATE TABLE IF NOT EXISTS business_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_function_name TEXT NOT NULL,
    time_slot_start TIME NOT NULL,
    time_slot_end TIME NOT NULL,
    min_staff INTEGER,  -- NULL for global max limits only
    max_staff INTEGER,
    block_size_minutes INTEGER NOT NULL DEFAULT 0,
    priority INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- If table already exists, alter the min_staff column to allow NULL (handles errors gracefully)
DO $$ 
BEGIN
    ALTER TABLE business_rules ALTER COLUMN min_staff DROP NOT NULL;
EXCEPTION WHEN OTHERS THEN
    -- Column already allows NULL, ignore
    NULL;
END $$;

DO $$ 
BEGIN
    ALTER TABLE business_rules ALTER COLUMN block_size_minutes SET DEFAULT 0;
EXCEPTION WHEN OTHERS THEN
    -- Default already set, ignore
    NULL;
END $$;

-- Create Indexes
CREATE INDEX IF NOT EXISTS idx_business_rules_job_function ON business_rules(job_function_name);
CREATE INDEX IF NOT EXISTS idx_business_rules_active ON business_rules(is_active);
CREATE INDEX IF NOT EXISTS idx_business_rules_priority ON business_rules(priority);

-- Enable Row Level Security
ALTER TABLE business_rules ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Enable read access for all users" ON business_rules;
DROP POLICY IF EXISTS "Enable insert for all users" ON business_rules;
DROP POLICY IF EXISTS "Enable update for all users" ON business_rules;
DROP POLICY IF EXISTS "Enable delete for all users" ON business_rules;

-- Create RLS Policies
CREATE POLICY "Enable read access for all users" ON business_rules FOR SELECT USING (true);
CREATE POLICY "Enable insert for all users" ON business_rules FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable update for all users" ON business_rules FOR UPDATE USING (true);
CREATE POLICY "Enable delete for all users" ON business_rules FOR DELETE USING (true);

-- Create or Replace Trigger Function for updated_at
CREATE OR REPLACE FUNCTION update_business_rules_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS update_business_rules_updated_at ON business_rules;

-- Create Trigger
CREATE TRIGGER update_business_rules_updated_at
    BEFORE UPDATE ON business_rules
    FOR EACH ROW
    EXECUTE FUNCTION update_business_rules_updated_at();

-- Insert Default Business Rules (migrating from hard-coded rules)
-- Using ON CONFLICT DO NOTHING to avoid duplicates if run multiple times
INSERT INTO business_rules (job_function_name, time_slot_start, time_slot_end, min_staff, max_staff, block_size_minutes, priority, is_active, notes)
VALUES
    -- X4 Rules
    ('X4', '08:00', '14:30', 2, NULL, 390, 1, true, '6.5 hour block'),
    ('X4', '10:00', '18:30', 2, NULL, 510, 2, true, '8.5 hour block'),
    ('X4', '12:00', '20:30', 2, NULL, 510, 3, true, '8.5 hour block'),
    ('X4', '16:00', '20:30', 1, NULL, 270, 4, true, '4.5 hour block'),
    -- EM9 Rules
    ('EM9', '08:00', '14:30', 1, NULL, 390, 1, true, '6.5 hour block'),
    ('EM9', '10:00', '18:30', 2, NULL, 510, 2, true, '8.5 hour block'),
    ('EM9', '12:00', '20:30', 2, NULL, 510, 3, true, '8.5 hour block'),
    ('EM9', '16:00', '20:30', 1, NULL, 270, 4, true, '4.5 hour block'),
    -- Locus Rules
    ('Locus', '08:00', '14:30', 2, NULL, 390, 1, true, '6.5 hour block'),
    ('Locus', '10:00', '18:30', 3, NULL, 510, 2, true, '8.5 hour block'),
    ('Locus', '12:00', '20:30', 3, NULL, 510, 3, true, '8.5 hour block'),
    ('Locus', '16:00', '20:30', 2, NULL, 270, 4, true, '4.5 hour block'),
    -- Locus Global Max (min_staff is NULL, max_staff is 6)
    ('Locus', '08:00', '20:30', NULL, 6, 0, 0, true, 'Global max staff limit')
ON CONFLICT DO NOTHING;

-- Verify the setup
SELECT 
    job_function_name,
    time_slot_start,
    time_slot_end,
    min_staff,
    max_staff,
    block_size_minutes,
    priority,
    is_active,
    notes
FROM business_rules
ORDER BY job_function_name, priority, time_slot_start;

