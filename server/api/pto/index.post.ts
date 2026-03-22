import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const body = await readBody(event)
  const { employee_id, pto_date, start_time, end_time, pto_type, notes } = body

  if (!employee_id || !pto_date) {
    throw createError({ statusCode: 400, message: 'employee_id and pto_date are required' })
  }

  const result = await query(
    `INSERT INTO pto_days (employee_id, pto_date, start_time, end_time, pto_type, notes, team_id)
     VALUES ($1,$2,$3,$4,$5,$6,$7)
     RETURNING *`,
    [employee_id, pto_date, start_time ?? null, end_time ?? null, pto_type ?? null, notes ?? null, teamId ?? null]
  )
  return result.rows[0]
})
