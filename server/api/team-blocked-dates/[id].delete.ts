import { query } from '../../utils/db'
import { requireAdmin, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAdmin(event)
  const teamId = getTeamFilter(user) || user.team_id
  const id = getRouterParam(event, 'id')

  if (!id) {
    throw createError({ statusCode: 400, message: 'id is required' })
  }

  const sql = teamId
    ? `DELETE FROM team_blocked_dates WHERE id = $1 AND team_id = $2`
    : `DELETE FROM team_blocked_dates WHERE id = $1`
  const params = teamId ? [id, teamId] : [id]

  const result = await query(sql, params)
  if (result.rowCount === 0) {
    throw createError({ statusCode: 404, message: 'Blocked date not found' })
  }
  return { success: true }
})
