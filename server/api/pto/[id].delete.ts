import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  // Nitro may register the param as 'id' or 'date' depending on sibling route files
  const id = getRouterParam(event, 'id') || getRouterParam(event, 'date')
  if (!id) {
    throw createError({ statusCode: 400, message: 'Missing PTO record ID' })
  }

  let sql = 'DELETE FROM pto_days WHERE id = $1'
  const params: unknown[] = [id]
  if (teamId) {
    sql += ` AND team_id = $${params.length + 1}`
    params.push(teamId)
  }
  sql += ' RETURNING id'

  const result = await query(sql, params)
  if (result.rowCount === 0) {
    throw createError({ statusCode: 404, message: 'PTO record not found' })
  }
  return { success: true }
})
