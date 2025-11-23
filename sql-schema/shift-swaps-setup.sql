-- Shift Swaps Table
-- Allows employees to temporarily work a different shift for a specific day

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

-- RLS Policies
DROP POLICY IF EXISTS "Enable read access for all users" ON shift_swaps;
CREATE POLICY "Enable read access for all users" ON shift_swaps FOR SELECT USING (true);

DROP POLICY IF EXISTS "Enable insert for all users" ON shift_swaps;
CREATE POLICY "Enable insert for all users" ON shift_swaps FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Enable update for all users" ON shift_swaps;
CREATE POLICY "Enable update for all users" ON shift_swaps FOR UPDATE USING (true);

DROP POLICY IF EXISTS "Enable delete for all users" ON shift_swaps;
CREATE POLICY "Enable delete for all users" ON shift_swaps FOR DELETE USING (true);

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_shift_swaps_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_shift_swaps_updated_at ON shift_swaps;
CREATE TRIGGER trigger_update_shift_swaps_updated_at
    BEFORE UPDATE ON shift_swaps
    FOR EACH ROW
    EXECUTE FUNCTION update_shift_swaps_updated_at();

