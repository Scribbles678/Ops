import { query } from '../../utils/db'
import { requireAuth } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  requireAuth(event)
  const id = getRouterParam(event, 'id')
  const body = await readBody(event)
  const { is_required, priority, notes } = body

  const result = await query(
    `UPDATE preferred_assignments
     SET is_required = COALESCE($1, is_required),
         priority    = COALESCE($2, priority),
         notes       = $3,
         updated_at  = NOW()
     WHERE id = $4
     RETURNING *`,
    [is_required ?? null, priority ?? null, notes ?? null, id]
  )

  if (result.rows.length === 0) {
    throw createError({ statusCode: 404, message: 'Preferred assignment not found' })
  }
  return result.rows[0]
})
