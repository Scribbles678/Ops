import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const body = await readBody(event)
  const { from_date, to_date } = body

  if (!from_date || !to_date) {
    throw createError({ statusCode: 400, message: 'from_date and to_date are required' })
  }

  let sql = `SELECT * FROM schedule_assignments WHERE schedule_date = $1`
  const params: unknown[] = [from_date]

  if (teamId) {
    params.push(teamId)
    sql += ` AND team_id = $${params.length}`
  }

  const source = await query(sql, params)

  if (source.rows.length === 0) {
    return { success: true, copied: 0 }
  }

  const validRows = source.rows.filter(
    (a) => a.employee_id && a.job_function_id && a.shift_id && a.start_time && a.end_time
  )

  let copied = 0
  for (const a of validRows) {
    await query(
      `INSERT INTO schedule_assignments
         (employee_id, job_function_id, shift_id, schedule_date, assignment_order, start_time, end_time, team_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
      [a.employee_id, a.job_function_id, a.shift_id, to_date, a.assignment_order, a.start_time, a.end_time, a.team_id]
    )
    copied++
  }

  return { success: true, copied }
})
