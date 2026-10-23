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
  // The kiosk (the shared wall iPad) loads this list for its request form. Everyone's
  // UPI in it would defeat "check my requests", which uses the UPI as a soft gate
  // (POST /api/schedule-requests/lookup checks it server-side). Team Setup and the
  // other lead screens still get it.
  if (user.is_display_user) return result.rows.map(({ upi, ...rest }) => rest)
  return result.rows
})
