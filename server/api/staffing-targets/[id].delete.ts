import { query } from '../../utils/db'
import { requireAuth } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  requireAuth(event)
  const id = getRouterParam(event, 'id')
  if (!id) {
    throw createError({ statusCode: 400, message: 'Missing staffing target ID' })
  }
  const result = await query('DELETE FROM staffing_targets WHERE id = $1 RETURNING id', [id])
  if (result.rowCount === 0) {
    throw createError({ statusCode: 404, message: 'Staffing target not found' })
  }
  return { success: true }
})
