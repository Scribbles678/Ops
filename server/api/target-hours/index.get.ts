import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)

  let sql = `SELECT job_function_id, target_hours FROM target_hours WHERE 1=1`
  const params: unknown[] = []
  if (teamId) {
    params.push(teamId)
    sql += ` AND team_id = $${params.length}`
  }

  const result = await query(sql, params)
  return result.rows
})
