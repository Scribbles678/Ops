import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)

  let sql = `SELECT st.*, jf.name as job_function_name
    FROM staffing_targets st
    JOIN job_functions jf ON jf.id = st.job_function_id
    WHERE st.is_active = true`
  const params: unknown[] = []

  if (teamId) {
    params.push(teamId)
    sql += ` AND st.team_id = $${params.length}`
  }
  sql += ` ORDER BY jf.name, st.hour_start`

  const result = await query(sql, params)
  return result.rows
})
