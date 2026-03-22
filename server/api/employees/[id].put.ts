import { query } from '../../utils/db'
import { requireAuth } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  requireAuth(event)
  const id = getRouterParam(event, 'id')
  const body = await readBody(event)
  const { first_name, last_name, shift_id, is_active } = body

  const result = await query(
    `UPDATE employees
     SET first_name = COALESCE($1, first_name),
         last_name  = COALESCE($2, last_name),
         shift_id   = $3,
         is_active  = COALESCE($4, is_active),
         updated_at = NOW()
     WHERE id = $5
     RETURNING *`,
    [first_name ?? null, last_name ?? null, shift_id ?? null, is_active ?? null, id]
  )

  if (result.rows.length === 0) {
    throw createError({ statusCode: 404, message: 'Employee not found' })
  }
  return result.rows[0]
})
