-- Shift Swaps Table (First-time Setup - No DROP statements)
-- Allows employees to temporarily work a different shift for a specific day
-- Run this if you haven't created the table yet, or if Supabase warns about destructive operations

CREATE TABLE IF NOT EXISTS shift_swaps (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    swap_date DATE NOT NULL,
    original_shift_id UUID NOT NULL REFERENCES shifts(id) ON DELETE CASCADE,
    swapped_shift_id UUID NOT NULL REFERENCES shifts(id) ON DELETE CASCADE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(employee_id, swap_date)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_shift_swaps_employee ON shift_swaps(employee_id);
CREATE INDEX IF NOT EXISTS idx_shift_swaps_date ON shift_swaps(swap_date);
CREATE INDEX IF NOT EXISTS idx_shift_swaps_shift ON shift_swaps(swapped_shift_id);

-- Enable Row Level Security
ALTER TABLE shift_swaps ENABLE ROW LEVEL SECURITY;

-- RLS Policies (only create if they don't exist)
DO $$
BEGIN
    -- Check if policies exist before creating
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'shift_swaps' 
        AND policyname = 'Enable read access for all users'
    ) THEN
        CREATE POLICY "Enable read access for all users" ON shift_swaps FOR SELECT USING (true);
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'shift_swaps' 
        AND policyname = 'Enable insert for all users'
    ) THEN
        CREATE POLICY "Enable insert for all users" ON shift_swaps FOR INSERT WITH CHECK (true);
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'shift_swaps' 
        AND policyname = 'Enable update for all users'
    ) THEN
        CREATE POLICY "Enable update for all users" ON shift_swaps FOR UPDATE USING (true);
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'shift_swaps' 
        AND policyname = 'Enable delete for all users'
    ) THEN
        CREATE POLICY "Enable delete for all users" ON shift_swaps FOR DELETE USING (true);
    END IF;
END $$;

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_shift_swaps_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Only create trigger if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger 
        WHERE tgname = 'trigger_update_shift_swaps_updated_at'
    ) THEN
        CREATE TRIGGER trigger_update_shift_swaps_updated_at
            BEFORE UPDATE ON shift_swaps
            FOR EACH ROW
            EXECUTE FUNCTION update_shift_swaps_updated_at();
    END IF;
END $$;

