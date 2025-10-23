-- Operations Scheduling Tool - Database Schema
-- Run this SQL in your Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Employees Table
CREATE TABLE employees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Job Functions Table
CREATE TABLE job_functions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT UNIQUE NOT NULL,
    color_code TEXT NOT NULL DEFAULT '#3B82F6',
    productivity_rate INTEGER,
    unit_of_measure TEXT,
    custom_unit TEXT,
    is_active BOOLEAN DEFAULT true,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Employee Training Table (Junction)
CREATE TABLE employee_training (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    job_function_id UUID NOT NULL REFERENCES job_functions(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(employee_id, job_function_id)
);

-- 4. Shifts Table
CREATE TABLE shifts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    break_1_start TIME,
    break_1_end TIME,
    break_2_start TIME,
    break_2_end TIME,
    lunch_start TIME,
    lunch_end TIME,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Schedule Assignments Table
CREATE TABLE schedule_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    job_function_id UUID NOT NULL REFERENCES job_functions(id) ON DELETE CASCADE,
    shift_id UUID NOT NULL REFERENCES shifts(id) ON DELETE CASCADE,
    schedule_date DATE NOT NULL,
    assignment_order INTEGER DEFAULT 1,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 6. Daily Targets Table
CREATE TABLE daily_targets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    schedule_date DATE NOT NULL,
    job_function_id UUID NOT NULL REFERENCES job_functions(id) ON DELETE CASCADE,
    target_units INTEGER NOT NULL,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(schedule_date, job_function_id)
);

-- Indexes for better performance
CREATE INDEX idx_employees_active ON employees(is_active);
CREATE INDEX idx_employee_training_employee ON employee_training(employee_id);
CREATE INDEX idx_employee_training_function ON employee_training(job_function_id);
CREATE INDEX idx_schedule_date ON schedule_assignments(schedule_date);
CREATE INDEX idx_schedule_employee ON schedule_assignments(employee_id);
CREATE INDEX idx_daily_targets_date ON daily_targets(schedule_date);

-- Enable Row Level Security
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE job_functions ENABLE ROW LEVEL SECURITY;
ALTER TABLE employee_training ENABLE ROW LEVEL SECURITY;
ALTER TABLE shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE schedule_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_targets ENABLE ROW LEVEL SECURITY;

-- Create policies for public read access (for display mode)
CREATE POLICY "Enable read access for all users" ON employees FOR SELECT USING (true);
CREATE POLICY "Enable read access for all users" ON job_functions FOR SELECT USING (true);
CREATE POLICY "Enable read access for all users" ON employee_training FOR SELECT USING (true);
CREATE POLICY "Enable read access for all users" ON shifts FOR SELECT USING (true);
CREATE POLICY "Enable read access for all users" ON schedule_assignments FOR SELECT USING (true);
CREATE POLICY "Enable read access for all users" ON daily_targets FOR SELECT USING (true);

-- Create policies for public write access (will be restricted to authenticated in future)
CREATE POLICY "Enable insert for all users" ON employees FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable update for all users" ON employees FOR UPDATE USING (true);
CREATE POLICY "Enable delete for all users" ON employees FOR DELETE USING (true);

CREATE POLICY "Enable insert for all users" ON job_functions FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable update for all users" ON job_functions FOR UPDATE USING (true);
CREATE POLICY "Enable delete for all users" ON job_functions FOR DELETE USING (true);

CREATE POLICY "Enable insert for all users" ON employee_training FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable update for all users" ON employee_training FOR UPDATE USING (true);
CREATE POLICY "Enable delete for all users" ON employee_training FOR DELETE USING (true);

CREATE POLICY "Enable insert for all users" ON shifts FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable update for all users" ON shifts FOR UPDATE USING (true);
CREATE POLICY "Enable delete for all users" ON shifts FOR DELETE USING (true);

CREATE POLICY "Enable insert for all users" ON schedule_assignments FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable update for all users" ON schedule_assignments FOR UPDATE USING (true);
CREATE POLICY "Enable delete for all users" ON schedule_assignments FOR DELETE USING (true);

CREATE POLICY "Enable insert for all users" ON daily_targets FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable update for all users" ON daily_targets FOR UPDATE USING (true);
CREATE POLICY "Enable delete for all users" ON daily_targets FOR DELETE USING (true);

-- Updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add triggers for updated_at
CREATE TRIGGER update_employees_updated_at BEFORE UPDATE ON employees
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_job_functions_updated_at BEFORE UPDATE ON job_functions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_schedule_assignments_updated_at BEFORE UPDATE ON schedule_assignments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_daily_targets_updated_at BEFORE UPDATE ON daily_targets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Seed Data: Shifts
INSERT INTO shifts (name, start_time, end_time, break_1_start, break_1_end, break_2_start, break_2_end, lunch_start, lunch_end) VALUES
('6:00 AM - 2:30 PM', '06:00:00', '14:30:00', '07:45:00', '08:00:00', '09:45:00', '10:00:00', '12:30:00', '13:00:00'),
('7:00 AM - 3:30 PM', '07:00:00', '15:30:00', '09:45:00', '10:00:00', '14:45:00', '15:00:00', '12:30:00', '13:00:00'),
('8:00 AM - 4:30 PM', '08:00:00', '16:30:00', '09:45:00', '10:00:00', '14:45:00', '15:00:00', '12:30:00', '13:00:00'),
('10:00 AM - 6:30 PM', '10:00:00', '18:30:00', '11:45:00', '12:00:00', '14:00:00', '14:30:00', '16:45:00', '17:00:00'),
('12:00 PM - 8:30 PM', '12:00:00', '20:30:00', '13:45:00', '14:00:00', '16:00:00', '16:30:00', '18:00:00', '18:15:00'),
('4:00 PM - 8:30 PM', '16:00:00', '20:30:00', NULL, NULL, NULL, NULL, NULL, NULL);

-- Seed Data: Job Functions
INSERT INTO job_functions (name, color_code, productivity_rate, unit_of_measure, sort_order) VALUES
('RT Pick', '#FFA500', 200, 'cartons/hour', 1),
('Pick', '#FFFF00', 180, 'cartons/hour', 2),
('Meter', '#87CEEB', 150, 'boxes/hour', 3),
('Locus', '#FFFFFF', 220, 'cartons/hour', 4),
('Helpdesk', '#FFD700', NULL, NULL, 5),
('Coordinator', '#C0C0C0', NULL, NULL, 6),
('Team Lead', '#000080', NULL, NULL, 7),
('Validated', '#FF0000', NULL, NULL, 8),
('Freight', '#800080', NULL, NULL, 9);

-- Seed Data: Sample Employees
INSERT INTO employees (first_name, last_name) VALUES
('Hayley', 'Williams'),
('Jeffery', 'Lee'),
('Maria', 'Garcia'),
('John', 'Smith'),
('Sarah', 'Johnson'),
('Michael', 'Brown'),
('Emily', 'Davis'),
('David', 'Martinez');

-- Enable Realtime for schedule_assignments table
ALTER PUBLICATION supabase_realtime ADD TABLE schedule_assignments;

