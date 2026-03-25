import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const id = getRouterParam(event, 'id')
  if (!id) {
    throw createError({ statusCode: 400, message: 'Missing staffing target ID' })
  }

  let sql = 'DELETE FROM staffing_targets WHERE id = $1'
  const params: unknown[] = [id]
  if (teamId) {
    sql += ` AND team_id = $${params.length + 1}`
    params.push(teamId)
  }
  sql += ' RETURNING id'

  const result = await query(sql, params)
  if (result.rowCount === 0) {
    throw createError({ statusCode: 404, message: 'Staffing target not found' })
  }
  return { success: true }
})
