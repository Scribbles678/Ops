import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const qs = getQuery(event)
  const activeOnly = qs.active === 'true'

  let sql = `SELECT * FROM employees`
  const params: unknown[] = []
  const conditions: string[] = []

  if (teamId) {
    conditions.push(`team_id = $${params.length + 1}`)
    params.push(teamId)
  }
  if (activeOnly) {
    conditions.push(`is_active = true`)
  }
  if (conditions.length) sql += ` WHERE ` + conditions.join(' AND ')
  sql += ` ORDER BY last_name, first_name`

  const result = await query(sql, params)
  return result.rows
})
