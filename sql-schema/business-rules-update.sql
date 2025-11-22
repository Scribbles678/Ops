-- Update Business Rules with Tactical Staffing Knowledge
-- Run this SQL script to replace default rules with your order profile-based rules

-- Clear existing rules (optional - comment out if you want to keep other rules)
-- DELETE FROM business_rules;

-- Insert new tactical business rules
INSERT INTO business_rules (job_function_name, time_slot_start, time_slot_end, min_staff, max_staff, block_size_minutes, priority, is_active, notes)
VALUES
    -- Startup (special case for 6am shift employees)
    ('Startup', '06:00', '08:00', NULL, NULL, 120, 0, true, 'All 6am employees scheduled for Startup until 8am'),
    
    -- X4 Rules
    ('X4', '08:00', '11:00', 2, NULL, 180, 1, true, 'Morning coverage'),
    ('X4', '11:00', '20:30', 3, NULL, 570, 2, true, 'Main coverage period'),
    ('X4', '18:00', '19:00', 2, NULL, 60, 3, true, 'Evening coverage'),
    ('X4', '19:00', '20:30', 1, NULL, 90, 4, true, 'Late evening coverage'),
    
    -- EM9 Rules
    ('EM9', '08:00', '10:00', 1, NULL, 120, 1, true, 'Early morning'),
    ('EM9', '10:00', '11:00', 2, NULL, 60, 2, true, 'Pre-lunch ramp'),
    ('EM9', '11:00', '16:30', 3, NULL, 330, 3, true, 'Main coverage period'),
    ('EM9', '16:30', '17:30', 2, NULL, 60, 4, true, 'Afternoon coverage'),
    ('EM9', '17:30', '20:30', 1, NULL, 180, 5, true, 'Evening coverage'),
    
    -- Speedcell Rules
    ('Speedcell', '10:00', '19:30', 2, NULL, 570, 1, true, 'Full day coverage'),
    
    -- DG Pick Rules
    ('DG Pick', '10:00', '19:00', 1, NULL, 540, 1, true, 'Full day coverage'),
    
    -- Validated Rules
    ('Validated', '10:00', '18:30', 1, NULL, 510, 1, true, 'Full day coverage'),
    
    -- Freight Rules
    ('Freight', '10:00', '20:30', 1, NULL, 630, 1, true, 'Full day coverage'),
    
    -- Locus Rules
    ('Locus', '08:00', '11:00', 3, NULL, 180, 1, true, 'Morning coverage'),
    ('Locus', '11:00', '16:00', 5, NULL, 300, 2, true, 'Peak coverage period'),
    ('Locus', '16:00', '18:00', 4, NULL, 120, 3, true, 'Afternoon coverage'),
    ('Locus', '18:00', '19:00', 3, NULL, 60, 4, true, 'Evening coverage'),
    ('Locus', '19:00', '20:00', 2, NULL, 60, 5, true, 'Late evening coverage'),
    -- Locus Global Max
    ('Locus', '08:00', '20:00', NULL, 6, 0, 0, true, 'Global max: No more than 6 people ever'),
    
    -- Pick Rules
    ('Pick', '08:00', '10:00', 1, NULL, 120, 1, true, 'Early morning'),
    ('Pick', '10:00', '12:00', 3, NULL, 120, 2, true, 'Morning ramp'),
    ('Pick', '12:00', '16:00', 6, NULL, 240, 3, true, 'Peak lunch/afternoon period'),
    ('Pick', '16:00', '18:30', 4, NULL, 150, 4, true, 'Afternoon coverage'),
    ('Pick', '18:30', '19:30', 2, NULL, 60, 5, true, 'Evening coverage'),
    
    -- Meter Rules
    ('Meter', '08:00', '10:00', 1, NULL, 120, 1, true, 'Early morning'),
    ('Meter', '10:00', '12:00', 6, NULL, 120, 2, true, 'Morning ramp'),
    ('Meter', '12:00', '20:30', 11, NULL, 510, 3, true, 'Main coverage period'),
    
    -- Helpdesk Rules
    ('Helpdesk', '08:00', '10:00', 1, NULL, 120, 1, true, 'Early morning'),
    ('Helpdesk', '10:00', '20:30', 2, NULL, 630, 2, true, 'Main coverage period')
ON CONFLICT DO NOTHING;

-- Verify the new rules
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
WHERE is_active = true
ORDER BY job_function_name, priority, time_slot_start;

