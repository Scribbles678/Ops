import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

/**
 * List schedule requests with optional filters: status, date_from, date_to, employee_id
 */
export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const params = getQuery(event)

  const conditions: string[] = []
  const values: unknown[] = []
  let idx = 0

  if (teamId) {
    conditions.push(`sr.team_id = $${++idx}`)
    values.push(teamId)
  }

  if (params.status) {
    conditions.push(`sr.status = $${++idx}`)
    values.push(params.status)
  }

  if (params.date_from) {
    conditions.push(`sr.request_date >= $${++idx}`)
    values.push(params.date_from)
  }

  if (params.date_to) {
    conditions.push(`sr.request_date <= $${++idx}`)
    values.push(params.date_to)
  }

  if (params.employee_id) {
    conditions.push(`sr.employee_id = $${++idx}`)
    values.push(params.employee_id)
  }

  const where = conditions.length > 0 ? 'WHERE ' + conditions.join(' AND ') : ''

  const sql = `
    SELECT sr.*, e.last_name || ', ' || e.first_name as employee_name
    FROM schedule_requests sr
    LEFT JOIN employees e ON e.id = sr.employee_id
    ${where}
    ORDER BY sr.created_at DESC
    LIMIT 200
  `

  const result = await query(sql, values)
  return result.rows
})
