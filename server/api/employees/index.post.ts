import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user) ?? (await readBody(event)).team_id
  const body = await readBody(event)
  const { first_name, last_name, shift_id, is_active = true } = body

  if (!first_name?.trim() || !last_name?.trim()) {
    throw createError({ statusCode: 400, message: 'first_name and last_name are required' })
  }

  const result = await query(
    `INSERT INTO employees (first_name, last_name, shift_id, is_active, team_id)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING *`,
    [first_name.trim(), last_name.trim(), shift_id ?? null, is_active, teamId ?? null]
  )
  return result.rows[0]
})
