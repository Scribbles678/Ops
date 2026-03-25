import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const id = getRouterParam(event, 'id')
  const body = await readBody(event)
  const { name, color_code, productivity_rate, sort_order, unit_of_measure, custom_unit, is_active } = body

  const params: unknown[] = [name ?? null, color_code ?? null, productivity_rate ?? null, sort_order ?? null,
     unit_of_measure ?? null, custom_unit ?? null, is_active ?? null, id]

  let sql = `UPDATE job_functions
     SET name             = COALESCE($1, name),
         color_code       = COALESCE($2, color_code),
         productivity_rate = $3,
         sort_order       = COALESCE($4, sort_order),
         unit_of_measure  = $5,
         custom_unit      = $6,
         is_active        = COALESCE($7, is_active),
         updated_at       = NOW()
     WHERE id = $8`

  if (teamId) {
    sql += ` AND team_id = $${params.length + 1}`
    params.push(teamId)
  }
  sql += ' RETURNING *'

  const result = await query(sql, params)

  if (result.rows.length === 0) {
    throw createError({ statusCode: 404, message: 'Job function not found' })
  }
  return result.rows[0]
})
