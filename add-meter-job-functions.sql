-- Add individual meter job functions (Meter 1-20)
-- Run this script to add the meter job functions to your existing database

INSERT INTO job_functions (name, color_code, productivity_rate, unit_of_measure, sort_order) VALUES
('Meter 1', '#87CEEB', 150, 'boxes/hour', 3),
('Meter 2', '#87CEEB', 150, 'boxes/hour', 4),
('Meter 3', '#87CEEB', 150, 'boxes/hour', 5),
('Meter 4', '#87CEEB', 150, 'boxes/hour', 6),
('Meter 5', '#87CEEB', 150, 'boxes/hour', 7),
('Meter 6', '#87CEEB', 150, 'boxes/hour', 8),
('Meter 7', '#87CEEB', 150, 'boxes/hour', 9),
('Meter 8', '#87CEEB', 150, 'boxes/hour', 10),
('Meter 9', '#87CEEB', 150, 'boxes/hour', 11),
('Meter 10', '#87CEEB', 150, 'boxes/hour', 12),
('Meter 11', '#87CEEB', 150, 'boxes/hour', 13),
('Meter 12', '#87CEEB', 150, 'boxes/hour', 14),
('Meter 13', '#87CEEB', 150, 'boxes/hour', 15),
('Meter 14', '#87CEEB', 150, 'boxes/hour', 16),
('Meter 15', '#87CEEB', 150, 'boxes/hour', 17),
('Meter 16', '#87CEEB', 150, 'boxes/hour', 18),
('Meter 17', '#87CEEB', 150, 'boxes/hour', 19),
('Meter 18', '#87CEEB', 150, 'boxes/hour', 20),
('Meter 19', '#87CEEB', 150, 'boxes/hour', 21),
('Meter 20', '#87CEEB', 150, 'boxes/hour', 22);

-- Update sort_order for existing job functions to make room
UPDATE job_functions SET sort_order = sort_order + 20 WHERE name NOT LIKE 'Meter %' AND name != 'Meter';
