import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const date = getRouterParam(event, 'date')

  let sql = `
    SELECT ss.*,
      row_to_json(e.*) AS employee,
      row_to_json(os.*) AS original_shift,
      row_to_json(ns.*) AS swapped_shift
    FROM shift_swaps ss
    LEFT JOIN employees e ON e.id = ss.employee_id
    LEFT JOIN shifts os ON os.id = ss.original_shift_id
    LEFT JOIN shifts ns ON ns.id = ss.swapped_shift_id
    WHERE ss.swap_date = $1`

  const params: unknown[] = [date]

  if (teamId) {
    params.push(teamId)
    sql += ` AND ss.team_id = $${params.length}`
  }

  const result = await query(sql, params)
  return result.rows
})
