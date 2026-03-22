import { query } from '../../utils/db'
import { requireSuperAdmin } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  requireSuperAdmin(event)
  const id = getRouterParam(event, 'id')
  const body = await readBody(event)
  const { name } = body

  const result = await query(
    `UPDATE teams SET name = COALESCE($1, name), updated_at = NOW() WHERE id = $2 RETURNING *`,
    [name ?? null, id]
  )
  if (result.rows.length === 0) {
    throw createError({ statusCode: 404, message: 'Team not found' })
  }
  return result.rows[0]
})
