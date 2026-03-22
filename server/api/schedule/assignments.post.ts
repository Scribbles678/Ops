import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const body = await readBody(event)
  const { employee_id, job_function_id, shift_id, schedule_date, start_time, end_time, assignment_order = 1 } = body

  if (!employee_id || !job_function_id || !shift_id || !schedule_date || !start_time || !end_time) {
    throw createError({ statusCode: 400, message: 'Missing required assignment fields' })
  }

  const result = await query(
    `INSERT INTO schedule_assignments
       (employee_id, job_function_id, shift_id, schedule_date, start_time, end_time, assignment_order, team_id)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
     RETURNING *`,
    [employee_id, job_function_id, shift_id, schedule_date, start_time, end_time, assignment_order, teamId ?? null]
  )
  return result.rows[0]
})
