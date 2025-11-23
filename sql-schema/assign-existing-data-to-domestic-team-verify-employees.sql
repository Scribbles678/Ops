-- Verification: Employees by Team
SELECT 
  t.name as team_name,
  COUNT(DISTINCT e.id) as employees
FROM teams t
LEFT JOIN employees e ON e.team_id = t.id
GROUP BY t.id, t.name
ORDER BY t.name;

