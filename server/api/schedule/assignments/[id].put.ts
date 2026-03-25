import { query } from '../../../utils/db'
import { requireAuth, getTeamFilter } from '../../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const id = getRouterParam(event, 'id')
  const body = await readBody(event)
  const { employee_id, job_function_id, shift_id, schedule_date, start_time, end_time, assignment_order } = body

  const params: unknown[] = [employee_id ?? null, job_function_id ?? null, shift_id ?? null,
     schedule_date ?? null, start_time ?? null, end_time ?? null,
     assignment_order ?? null, id]

  let sql = `UPDATE schedule_assignments
     SET employee_id     = COALESCE($1, employee_id),
         job_function_id = COALESCE($2, job_function_id),
         shift_id        = COALESCE($3, shift_id),
         schedule_date   = COALESCE($4, schedule_date),
         start_time      = COALESCE($5, start_time),
         end_time        = COALESCE($6, end_time),
         assignment_order = COALESCE($7, assignment_order),
         updated_at      = NOW()
     WHERE id = $8`

  if (teamId) {
    sql += ` AND team_id = $${params.length + 1}`
    params.push(teamId)
  }
  sql += ' RETURNING *'

  const result = await query(sql, params)

  if (result.rows.length === 0) {
    throw createError({ statusCode: 404, message: 'Assignment not found' })
  }
  return result.rows[0]
})
