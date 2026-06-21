import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

/**
 * List pto_days for one employee (all dates), optionally filtered by pto_type.
 * Used by the PTO Calendar history modal to surface call-ins (pto_type='call_in'),
 * which aren't schedule_requests. Team-scoped; super admins see all teams.
 */
export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const q = getQuery(event)

  const conditions: string[] = []
  const params: unknown[] = []
  if (q.employee_id) {
    params.push(q.employee_id)
    conditions.push(`p.employee_id = $${params.length}`)
  }
  if (q.pto_type) {
    params.push(q.pto_type)
    conditions.push(`p.pto_type = $${params.length}`)
  }
  if (teamId) {
    params.push(teamId)
    conditions.push(`p.team_id = $${params.length}`)
  }

  const where = conditions.length ? 'WHERE ' + conditions.join(' AND ') : ''
  const sql = `
    SELECT p.*, e.last_name || ', ' || e.first_name AS employee_name
    FROM pto_days p
    LEFT JOIN employees e ON e.id = p.employee_id
    ${where}
    ORDER BY p.pto_date DESC
    LIMIT 500
  `
  const result = await query(sql, params)
  return result.rows
})
