import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const date = getRouterParam(event, 'date')

  let sql = `SELECT * FROM pto_days WHERE pto_date = $1`
  const params: unknown[] = [date]

  if (teamId) {
    params.push(teamId)
    sql += ` AND team_id = $${params.length}`
  }

  const result = await query(sql, params)
  return result.rows
})
