import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)

  let sql = `SELECT * FROM shifts WHERE is_active = true`
  const params: unknown[] = []

  if (teamId) {
    params.push(teamId)
    sql += ` AND team_id = $${params.length}`
  }
  sql += ` ORDER BY start_time`

  const result = await query(sql, params)
  return result.rows
})
