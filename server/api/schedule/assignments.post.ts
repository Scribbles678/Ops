import { query } from '../../utils/db'
import { requireTeamLead, getWriteTeamId } from '../../utils/authorize'
import { assertScheduleRowsOnTeam } from '../../utils/teamOwnership'

// Team Lead and up: the kiosk account can sign in anywhere, so it must not edit the floor.
export default defineEventHandler(async (event) => {
  const user = requireTeamLead(event)
  const teamId = getWriteTeamId(user)
  const body = await readBody(event)
  const { employee_id, job_function_id, shift_id, schedule_date, start_time, end_time, assignment_order = 1 } = body

  if (!employee_id || !job_function_id || !shift_id || !schedule_date || !start_time || !end_time) {
    throw createError({ statusCode: 400, message: 'Missing required assignment fields' })
  }
  await assertScheduleRowsOnTeam([body], teamId)

  const result = await query(
    `INSERT INTO schedule_assignments
       (employee_id, job_function_id, shift_id, schedule_date, start_time, end_time, assignment_order, team_id)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
     RETURNING *`,
    [employee_id, job_function_id, shift_id, schedule_date, start_time, end_time, assignment_order, teamId ?? null]
  )
  return result.rows[0]
})
