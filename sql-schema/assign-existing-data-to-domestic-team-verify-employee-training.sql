-- Verification: Employee Training by Team
SELECT 
  t.name as team_name,
  COUNT(DISTINCT et.id) as employee_training_records
FROM teams t
LEFT JOIN employee_training et ON et.team_id = t.id
GROUP BY t.id, t.name
ORDER BY t.name;

