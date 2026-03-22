import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)

  const cutoffDate = new Date()
  cutoffDate.setDate(cutoffDate.getDate() - 7)
  const cutoff = cutoffDate.toISOString().split('T')[0]

  let sql = `
    SELECT
      sa.*,
      e.first_name, e.last_name,
      jf.name AS job_function_name,
      s.name  AS shift_name
    FROM schedule_assignments sa
    LEFT JOIN employees e ON e.id = sa.employee_id
    LEFT JOIN job_functions jf ON jf.id = sa.job_function_id
    LEFT JOIN shifts s ON s.id = sa.shift_id
    WHERE sa.schedule_date < $1`

  const params: unknown[] = [cutoff]

  if (teamId) {
    params.push(teamId)
    sql += ` AND sa.team_id = $${params.length}`
  }
  sql += ` ORDER BY sa.schedule_date, sa.start_time`

  const result = await query(sql, params)
  return result.rows
})
