import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user) || user.team_id

  let sql = `SELECT * FROM team_settings`
  const params: unknown[] = []

  if (teamId) {
    params.push(teamId)
    sql += ` WHERE team_id = $${params.length}`
  }
  sql += ` ORDER BY setting_key`

  const result = await query(sql, params)
  return result.rows
})
