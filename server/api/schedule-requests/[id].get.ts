import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const id = getRouterParam(event, 'id')

  let sql = `SELECT sr.*, e.last_name || ', ' || e.first_name as employee_name
     FROM schedule_requests sr
     LEFT JOIN employees e ON e.id = sr.employee_id
     WHERE sr.id = $1`
  const params: unknown[] = [id]

  if (teamId) {
    sql += ` AND sr.team_id = $${params.length + 1}`
    params.push(teamId)
  }

  const result = await query(sql, params)

  if (!result.rows[0]) {
    throw createError({ statusCode: 404, message: 'Request not found' })
  }

  return result.rows[0]
})
