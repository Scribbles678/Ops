import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const body = await readBody(event)
  const { employee_id, job_function_id, is_required = false, priority = 0, notes } = body

  if (!employee_id || !job_function_id) {
    throw createError({ statusCode: 400, message: 'employee_id and job_function_id are required' })
  }

  const result = await query(
    `INSERT INTO preferred_assignments (employee_id, job_function_id, is_required, priority, notes, team_id)
     VALUES ($1,$2,$3,$4,$5,$6)
     RETURNING *`,
    [employee_id, job_function_id, is_required, priority, notes ?? null, teamId ?? null]
  )
  return result.rows[0]
})
