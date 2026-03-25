import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const id = getRouterParam(event, 'id') || getRouterParam(event, 'date')
  if (!id) {
    throw createError({ statusCode: 400, message: 'Missing shift swap ID' })
  }

  let sql = 'DELETE FROM shift_swaps WHERE id = $1'
  const params: unknown[] = [id]
  if (teamId) {
    sql += ` AND team_id = $${params.length + 1}`
    params.push(teamId)
  }
  sql += ' RETURNING id'

  const result = await query(sql, params)
  if (result.rowCount === 0) {
    throw createError({ statusCode: 404, message: 'Shift swap not found' })
  }
  return { success: true }
})
