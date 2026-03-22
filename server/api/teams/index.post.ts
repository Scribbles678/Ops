import { query } from '../../utils/db'
import { requireSuperAdmin } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  requireSuperAdmin(event)
  const body = await readBody(event)
  const { name } = body

  if (!name?.trim()) {
    throw createError({ statusCode: 400, message: 'name is required' })
  }

  const result = await query(
    `INSERT INTO teams (name) VALUES ($1) RETURNING *`,
    [name.trim()]
  )
  return result.rows[0]
})
