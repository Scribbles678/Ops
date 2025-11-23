-- Verification: Job Functions by Team
SELECT 
  t.name as team_name,
  COUNT(DISTINCT jf.id) as job_functions
FROM teams t
LEFT JOIN job_functions jf ON jf.team_id = t.id
GROUP BY t.id, t.name
ORDER BY t.name;

