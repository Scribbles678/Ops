import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

/**
 * Aggregated PTO calendar view.
 * Returns approved PTO days + approved/pending schedule requests for a date range.
 * Query params: date_from, date_to (required, YYYY-MM-DD)
 */
export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const params = getQuery(event)

  const { date_from, date_to } = params
  if (!date_from || !date_to) {
    throw createError({ statusCode: 400, message: 'date_from and date_to are required' })
  }

  const conditions: string[] = []
  const values: unknown[] = [date_from, date_to]
  let idx = 2

  if (teamId) {
    idx++
    conditions.push(`team_id = $${idx}`)
    values.push(teamId)
  }

  const teamWhere = conditions.length > 0 ? ' AND ' + conditions.join(' AND ') : ''

  // Fetch approved PTO days
  const ptoResult = await query(
    `SELECT p.*, e.last_name || ', ' || e.first_name as employee_name
     FROM pto_days p
     LEFT JOIN employees e ON e.id = p.employee_id
     WHERE p.pto_date BETWEEN $1 AND $2 ${teamWhere.replace(/team_id/g, 'p.team_id')}
     ORDER BY p.pto_date, e.last_name, e.first_name`,
    values
  )

  // Fetch schedule requests (approved + pending)
  const requestResult = await query(
    `SELECT sr.*, e.last_name || ', ' || e.first_name as employee_name
     FROM schedule_requests sr
     LEFT JOIN employees e ON e.id = sr.employee_id
     WHERE sr.request_date BETWEEN $1 AND $2
       AND sr.status IN ('approved', 'pending')
       ${teamWhere.replace(/team_id/g, 'sr.team_id')}
     ORDER BY sr.request_date, e.last_name, e.first_name`,
    values
  )

  return {
    pto_days: ptoResult.rows,
    requests: requestResult.rows,
  }
})
