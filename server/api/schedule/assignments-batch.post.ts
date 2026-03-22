import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const body = await readBody(event)
  const { assignments } = body as { assignments: Array<{
    employee_id: string
    job_function_id: string
    shift_id: string
    schedule_date: string
    start_time: string
    end_time: string
    assignment_order?: number
  }> }

  if (!Array.isArray(assignments) || assignments.length === 0) {
    throw createError({ statusCode: 400, message: 'assignments array is required and must not be empty' })
  }

  const inserted: any[] = []
  for (const a of assignments) {
    const { employee_id, job_function_id, shift_id, schedule_date, start_time, end_time, assignment_order = 1 } = a
    if (!employee_id || !job_function_id || !shift_id || !schedule_date || !start_time || !end_time) {
      throw createError({ statusCode: 400, message: 'Each assignment must have employee_id, job_function_id, shift_id, schedule_date, start_time, end_time' })
    }
    const result = await query(
      `INSERT INTO schedule_assignments
         (employee_id, job_function_id, shift_id, schedule_date, start_time, end_time, assignment_order, team_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
       RETURNING *`,
      [employee_id, job_function_id, shift_id, schedule_date, start_time, end_time, assignment_order, teamId ?? null]
    )
    inserted.push(result.rows[0])
  }
  return { inserted, count: inserted.length }
})
