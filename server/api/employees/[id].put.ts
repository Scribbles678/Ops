import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const id = getRouterParam(event, 'id')
  const body = await readBody(event)
  const { first_name, last_name, shift_id, is_active } = body

  let sql = `UPDATE employees
     SET first_name = COALESCE($1, first_name),
         last_name  = COALESCE($2, last_name),
         shift_id   = $3,
         is_active  = COALESCE($4, is_active),
         updated_at = NOW()
     WHERE id = $5`
  const params: unknown[] = [first_name ?? null, last_name ?? null, shift_id ?? null, is_active ?? null, id]

  if (teamId) {
    sql += ` AND team_id = $${params.length + 1}`
    params.push(teamId)
  }
  sql += ' RETURNING *'

  const result = await query(sql, params)

  if (result.rows.length === 0) {
    throw createError({ statusCode: 404, message: 'Employee not found' })
  }
  return result.rows[0]
})
