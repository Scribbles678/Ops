import { query } from '../../../utils/db'
import { requireTeamLead, getTeamFilter } from '../../../utils/authorize'

/**
 * List performance notes. ADMIN ONLY — review material about named people.
 *
 * Query params: employee_id, date_from, date_to, category
 */
export default defineEventHandler(async (event) => {
  const user = requireTeamLead(event)
  const teamId = getTeamFilter(user)
  const params = getQuery(event)

  const conditions: string[] = []
  const values: unknown[] = []

  if (teamId) {
    values.push(teamId)
    conditions.push(`pn.team_id = $${values.length}`)
  }
  if (params.employee_id) {
    values.push(params.employee_id)
    conditions.push(`pn.employee_id = $${values.length}`)
  }
  if (params.date_from) {
    values.push(params.date_from)
    conditions.push(`pn.note_date >= $${values.length}`)
  }
  if (params.date_to) {
    values.push(params.date_to)
    conditions.push(`pn.note_date <= $${values.length}`)
  }
  if (params.category) {
    values.push(params.category)
    conditions.push(`pn.category = $${values.length}`)
  }

  const where = conditions.length ? 'WHERE ' + conditions.join(' AND ') : ''

  const result = await query(
    `SELECT pn.id, pn.employee_id, pn.note_date::text AS note_date, pn.category, pn.body, pn.tag,
            pn.created_at, pn.updated_at,
            e.last_name || ', ' || e.first_name AS employee_name,
            COALESCE(u.full_name, u.username, 'Unknown') AS author
     FROM performance_notes pn
     LEFT JOIN employees e ON e.id = pn.employee_id
     LEFT JOIN user_profiles u ON u.id = pn.created_by
     ${where}
     ORDER BY pn.note_date DESC, pn.created_at DESC
     LIMIT 500`,
    values
  )
  return result.rows
})
