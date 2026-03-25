import { query } from '../../utils/db'
import { requireAuth } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  requireAuth(event)
  const id = getRouterParam(event, 'id')

  const result = await query(
    `SELECT sr.*, e.name as employee_name
     FROM schedule_requests sr
     LEFT JOIN employees e ON e.id = sr.employee_id
     WHERE sr.id = $1`,
    [id]
  )

  if (!result.rows[0]) {
    throw createError({ statusCode: 404, message: 'Request not found' })
  }

  return result.rows[0]
})
