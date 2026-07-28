import { query } from '../../../utils/db'
import { requireAdmin, getTeamFilter } from '../../../utils/authorize'

/**
 * List logged performance errors.
 *
 * ADMIN ONLY. This is review material about named people — regular Users and
 * Display/kiosk accounts must never reach it.
 *
 * Query params: employee_id, date_from, date_to
 */
export default defineEventHandler(async (event) => {
  const user = requireAdmin(event)
  const teamId = getTeamFilter(user)
  const params = getQuery(event)

  const conditions: string[] = []
  const values: unknown[] = []

  if (teamId) {
    values.push(teamId)
    conditions.push(`pe.team_id = $${values.length}`)
  }
  if (params.employee_id) {
    values.push(params.employee_id)
    conditions.push(`pe.employee_id = $${values.length}`)
  }
  if (params.date_from) {
    values.push(params.date_from)
    conditions.push(`pe.error_date >= $${values.length}`)
  }
  if (params.date_to) {
    values.push(params.date_to)
    conditions.push(`pe.error_date <= $${values.length}`)
  }

  const where = conditions.length ? 'WHERE ' + conditions.join(' AND ') : ''

  const result = await query(
    `SELECT pe.id, pe.employee_id, pe.job_function_id, pe.error_date::text AS error_date,
            pe.error_count, pe.error_type, pe.notes, pe.created_at,
            e.last_name || ', ' || e.first_name AS employee_name,
            jf.name AS job_function_name,
            u.full_name AS logged_by
     FROM performance_errors pe
     LEFT JOIN employees e ON e.id = pe.employee_id
     LEFT JOIN job_functions jf ON jf.id = pe.job_function_id
     LEFT JOIN user_profiles u ON u.id = pe.created_by
     ${where}
     ORDER BY pe.error_date DESC, pe.created_at DESC
     LIMIT 500`,
    values
  )
  return result.rows
})
