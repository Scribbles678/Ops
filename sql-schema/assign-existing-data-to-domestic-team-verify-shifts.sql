-- Verification: Shifts by Team
SELECT 
  t.name as team_name,
  COUNT(DISTINCT s.id) as shifts
FROM teams t
LEFT JOIN shifts s ON s.team_id = t.id
GROUP BY t.id, t.name
ORDER BY t.name;

