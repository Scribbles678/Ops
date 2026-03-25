import { query } from '../../utils/db'
import { requireAuth } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  requireAuth(event)
  const id = getRouterParam(event, 'id') || getRouterParam(event, 'date')
  if (!id) {
    throw createError({ statusCode: 400, message: 'Missing shift swap ID' })
  }
  const result = await query('DELETE FROM shift_swaps WHERE id = $1 RETURNING id', [id])
  if (result.rowCount === 0) {
    throw createError({ statusCode: 404, message: 'Shift swap not found' })
  }
  return { success: true }
})
