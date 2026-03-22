import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const date = getRouterParam(event, 'date')

  let sql = `
    SELECT dt.*, row_to_json(jf.*) AS job_function
    FROM daily_targets dt
    LEFT JOIN job_functions jf ON jf.id = dt.job_function_id
    WHERE dt.schedule_date = $1`

  const params: unknown[] = [date]

  if (teamId) {
    params.push(teamId)
    sql += ` AND dt.team_id = $${params.length}`
  }

  const result = await query(sql, params)
  return result.rows
})
