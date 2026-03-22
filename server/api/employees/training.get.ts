import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)

  let sql = `SELECT et.* FROM employee_training et
             JOIN employees e ON e.id = et.employee_id`
  const params: unknown[] = []

  if (teamId) {
    sql += ` WHERE et.team_id = $1`
    params.push(teamId)
  }

  const result = await query(sql, params)
  return result.rows
})
