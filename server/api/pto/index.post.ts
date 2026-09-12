import { transaction } from '../../utils/db'
import { requireAuth, getWriteTeamId } from '../../utils/authorize'
import { logChange, employeeDisplayName, describePtoDay } from '../../utils/auditLog'

/**
 * Add a PTO day / call-in by hand (the schedule page). Logged to the change log:
 * hand-entered time off is exactly the record that used to change without a trace.
 */
export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getWriteTeamId(user)
  const body = await readBody(event)
  const { employee_id, pto_date, start_time, end_time, pto_type, notes } = body

  if (!employee_id || !pto_date) {
    throw createError({ statusCode: 400, message: 'employee_id and pto_date are required' })
  }

  return transaction(async (client) => {
    const result = await client.query(
      `INSERT INTO pto_days (employee_id, pto_date, start_time, end_time, pto_type, notes, team_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7)
       RETURNING *`,
      [employee_id, pto_date, start_time ?? null, end_time ?? null, pto_type ?? null, notes ?? null, teamId ?? null]
    )
    const row = result.rows[0]
    const who = await employeeDisplayName(client, employee_id)
    await logChange(client, {
      teamId,
      actor: user,
      action: 'add',
      entity: 'pto_day',
      entityId: row.id,
      employeeId: employee_id,
      employeeName: who,
      summary: `Added ${describePtoDay(row)} for ${who}${notes ? `: ${notes}` : ''}`,
      after: row,
    })
    return row
  })
})
