import { transaction } from '../../utils/db'
import { requireTeamLead, getWriteTeamId } from '../../utils/authorize'
import { logChange, employeeDisplayName, describePtoDay } from '../../utils/auditLog'
import { assertEmployeeOnTeam } from '../../utils/teamOwnership'
import { lockTeamTimeOff, findTimeOffConflict, replaceTimeOffForCallIn } from '../../utils/timeOff'
import { describePto } from '../../../utils/ptoDisplay'

/**
 * Add a PTO day / call-in by hand (the schedule page). Logged to the change log:
 * hand-entered time off is exactly the record that used to change without a trace.
 * Team Lead and up, for an employee on the writer's own team.
 *
 * One absence at a time (server/utils/timeOff.ts): time off that overlaps what the
 * person already has that day is refused with a 409. A call-in covers the whole day,
 * so it REPLACES what they had instead; `replaced` lists it for the confirmation.
 */
export default defineEventHandler(async (event) => {
  const user = requireTeamLead(event)
  const teamId = getWriteTeamId(user)
  const body = await readBody(event)
  const { employee_id, pto_date, start_time, end_time, pto_type, notes } = body

  if (!employee_id || !pto_date) {
    throw createError({ statusCode: 400, message: 'employee_id and pto_date are required' })
  }
  if (typeof pto_date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(pto_date)) {
    throw createError({ statusCode: 400, message: `Invalid date: ${String(pto_date)} (use YYYY-MM-DD)` })
  }
  const shape = { pto_type: pto_type ?? null, start_time: start_time ?? null, end_time: end_time ?? null }
  if (!describePto(shape)) {
    throw createError({ statusCode: 400, message: 'Those times do not describe an absence — check the start and end.' })
  }
  await assertEmployeeOnTeam(employee_id, teamId)

  return transaction(async (client) => {
    await lockTeamTimeOff(client, teamId)

    let replaced: string[] = []
    if (pto_type === 'call_in') {
      replaced = await replaceTimeOffForCallIn(client, { teamId, employeeId: employee_id, date: pto_date, actor: user })
    } else {
      const conflict = await findTimeOffConflict(client, { teamId, employeeId: employee_id, date: pto_date, shape })
      if (conflict) throw createError({ statusCode: 409, message: conflict })
    }

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
    return { ...row, replaced }
  })
})
