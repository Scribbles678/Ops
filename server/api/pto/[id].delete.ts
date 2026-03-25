import { query } from '../../utils/db'
import { requireAuth } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  requireAuth(event)
  // Nitro may register the param as 'id' or 'date' depending on sibling route files
  const id = getRouterParam(event, 'id') || getRouterParam(event, 'date')
  if (!id) {
    throw createError({ statusCode: 400, message: 'Missing PTO record ID' })
  }
  const result = await query('DELETE FROM pto_days WHERE id = $1 RETURNING id', [id])
  if (result.rowCount === 0) {
    throw createError({ statusCode: 404, message: 'PTO record not found' })
  }
  return { success: true }
})
