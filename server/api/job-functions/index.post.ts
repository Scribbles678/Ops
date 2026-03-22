import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const body = await readBody(event)
  const { name, color_code = '#3B82F6', productivity_rate, sort_order = 0, unit_of_measure, custom_unit } = body

  if (!name?.trim()) {
    throw createError({ statusCode: 400, message: 'name is required' })
  }

  const result = await query(
    `INSERT INTO job_functions (name, color_code, productivity_rate, sort_order, unit_of_measure, custom_unit, team_id)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING *`,
    [name.trim(), color_code, productivity_rate ?? null, sort_order, unit_of_measure ?? null, custom_unit ?? null, teamId ?? null]
  )
  return result.rows[0]
})
