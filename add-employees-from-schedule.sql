-- Add employees from current schedule to the database
-- This script adds all the employee names visible in the current schedule

INSERT INTO employees (first_name, last_name, is_active) VALUES
-- Employees from the current schedule
('Hayley', 'Williams', true),
('Jeffery', 'Lee', true),
('Chang', 'Moua', true),
('Kevin', 'Aldana', true),
('Tong', 'Vang', true),
('Ronald', 'Murph', true),
('Phillip', 'Kishchun', true),
('Sarah', 'Johnson', true),
('Michael', 'Davis', true),
('Lisa', 'Wilson', true),
('Tom', 'Brown', true),
('Emma', 'Garcia', true),
('Chris', 'Martinez', true),
('Amy', 'Anderson', true),
('David', 'Taylor', true),
('Jessica', 'Thomas', true),
('Kevin', 'Jackson', true),
('Rachel', 'White', true),
('Mark', 'Harris', true),
('Nicole', 'Martin', true),
('Steve', 'Thompson', true),
('Michelle', 'Garcia', true),
('Ryan', 'Martinez', true),
('Stephanie', 'Robinson', true),
('Brian', 'Clark', true),
('Jennifer', 'Rodriguez', true),
('Jason', 'Lewis', true),
('Amanda', 'Lee', true),
('Daniel', 'Walker', true),
('Laura', 'Hall', true),
('Robert', 'Allen', true),
('Heather', 'Young', true),
('Michael', 'King', true),
('Melissa', 'Wright', true),
('Andrew', 'Lopez', true),
('Kimberly', 'Hill', true),
('James', 'Scott', true),
('Ashley', 'Green', true),
('Joshua', 'Adams', true),
('Brittany', 'Baker', true),
('Christopher', 'Gonzalez', true),
('Samantha', 'Nelson', true),
('Matthew', 'Carter', true),
('Stephanie', 'Mitchell', true),
('Joshua', 'Perez', true),
('Lauren', 'Roberts', true),
('Andrew', 'Turner', true),
('Megan', 'Phillips', true),
('Daniel', 'Campbell', true),
('Nicole', 'Parker', true);

-- Update existing employees if they already exist (in case of duplicates)
UPDATE employees SET is_active = true WHERE first_name = 'John' AND last_name = 'Smith';
UPDATE employees SET is_active = true WHERE first_name = 'Sarah' AND last_name = 'Johnson';
UPDATE employees SET is_active = true WHERE first_name = 'Mike' AND last_name = 'Davis';
UPDATE employees SET is_active = true WHERE first_name = 'Lisa' AND last_name = 'Wilson';
UPDATE employees SET is_active = true WHERE first_name = 'Tom' AND last_name = 'Brown';
UPDATE employees SET is_active = true WHERE first_name = 'Emma' AND last_name = 'Garcia';
UPDATE employees SET is_active = true WHERE first_name = 'Chris' AND last_name = 'Martinez';
UPDATE employees SET is_active = true WHERE first_name = 'Amy' AND last_name = 'Anderson';
UPDATE employees SET is_active = true WHERE first_name = 'David' AND last_name = 'Taylor';
UPDATE employees SET is_active = true WHERE first_name = 'Jessica' AND last_name = 'Thomas';
UPDATE employees SET is_active = true WHERE first_name = 'Kevin' AND last_name = 'Jackson';
UPDATE employees SET is_active = true WHERE first_name = 'Rachel' AND last_name = 'White';
UPDATE employees SET is_active = true WHERE first_name = 'Mark' AND last_name = 'Harris';
UPDATE employees SET is_active = true WHERE first_name = 'Nicole' AND last_name = 'Martin';
UPDATE employees SET is_active = true WHERE first_name = 'Steve' AND last_name = 'Thompson';
UPDATE employees SET is_active = true WHERE first_name = 'Michelle' AND last_name = 'Garcia';
UPDATE employees SET is_active = true WHERE first_name = 'Ryan' AND last_name = 'Martinez';
UPDATE employees SET is_active = true WHERE first_name = 'Stephanie' AND last_name = 'Robinson';
UPDATE employees SET is_active = true WHERE first_name = 'Brian' AND last_name = 'Clark';
UPDATE employees SET is_active = true WHERE first_name = 'Jennifer' AND last_name = 'Rodriguez';
UPDATE employees SET is_active = true WHERE first_name = 'Jason' AND last_name = 'Lewis';
UPDATE employees SET is_active = true WHERE first_name = 'Amanda' AND last_name = 'Lee';
UPDATE employees SET is_active = true WHERE first_name = 'Daniel' AND last_name = 'Walker';
UPDATE employees SET is_active = true WHERE first_name = 'Laura' AND last_name = 'Hall';
UPDATE employees SET is_active = true WHERE first_name = 'Robert' AND last_name = 'Allen';
UPDATE employees SET is_active = true WHERE first_name = 'Heather' AND last_name = 'Young';
UPDATE employees SET is_active = true WHERE first_name = 'Michael' AND last_name = 'King';
UPDATE employees SET is_active = true WHERE first_name = 'Melissa' AND last_name = 'Wright';
UPDATE employees SET is_active = true WHERE first_name = 'Andrew' AND last_name = 'Lopez';
UPDATE employees SET is_active = true WHERE first_name = 'Kimberly' AND last_name = 'Hill';
