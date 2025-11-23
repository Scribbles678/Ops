-- Verification: Schedule Assignments by Team
SELECT 
  t.name as team_name,
  COUNT(DISTINCT sa.id) as schedule_assignments
FROM teams t
LEFT JOIN schedule_assignments sa ON sa.team_id = t.id
GROUP BY t.id, t.name
ORDER BY t.name;

