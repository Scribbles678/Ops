import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const date = getRouterParam(event, 'date')

  let sql = `
    SELECT
      sa.*,
      row_to_json(e.*) AS employee,
      row_to_json(jf.*) AS job_function,
      row_to_json(s.*) AS shift
    FROM schedule_assignments sa
    LEFT JOIN employees e ON e.id = sa.employee_id
    LEFT JOIN job_functions jf ON jf.id = sa.job_function_id
    LEFT JOIN shifts s ON s.id = sa.shift_id
    WHERE sa.schedule_date = $1`

  const params: unknown[] = [date]

  if (teamId) {
    params.push(teamId)
    sql += ` AND sa.team_id = $${params.length}`
  }
  sql += ` ORDER BY sa.start_time`

  const result = await query(sql, params)
  return result.rows
})
