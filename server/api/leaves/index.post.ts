import { transaction } from '../../utils/db'
import { requireSupervisor, getWriteTeamId } from '../../utils/authorize'
import { assertEmployeeOnTeam } from '../../utils/teamOwnership'
import { logChange, employeeDisplayName } from '../../utils/auditLog'
import { teamToday } from '../../utils/teamTime'
import { LEAVE_COLUMNS, cancelledNote, findOverlappingLeave, leaveSpan, overlapMessage, readLeaveInput } from '../../utils/leave'
import { lockTeamTimeOff, cancelTimeOffForLeave } from '../../utils/timeOff'

/**
 * Put someone on a leave of absence (Team Setup → Leave). Supervisor and up.
 *
 * Body: { employee_id, start_date, end_date (null = return date not known), notes? }
 * Refused: bad dates (400), an inactive person or another leave sharing days (409).
 * Time off they had booked inside the leave, from today on, is cancelled in the same
 * transaction (server/utils/timeOff.ts cancelTimeOffForLeave) and each removal logged.
 * Returns { leave, cancelled: ["Fri, Nov 20 — Full Day", ...] }.
 */
export default defineEventHandler(async (event) => {
  const user = requireSupervisor(event)
  const teamId = getWriteTeamId(user)
  const body = await readBody(event)
  const employeeId = body?.employee_id
  await assertEmployeeOnTeam(employeeId, teamId)

  return transaction(async (client) => {
    // The same lock as every time-off write: a request submitted in the same instant
    // waits, then finds the leave and is refused.
    await lockTeamTimeOff(client, teamId)
    const input = await readLeaveInput(client, teamId, body)
    const who = await employeeDisplayName(client, employeeId)

    const active = (await client.query('SELECT is_active FROM employees WHERE id = $1', [employeeId])).rows[0]?.is_active
    if (active === false) {
      throw createError({ statusCode: 409, message: `${who} is inactive. Reactivate them on Team Setup first.` })
    }
    const other = await findOverlappingLeave(client, { teamId, employeeId, start: input.start_date, end: input.end_date })
    if (other) throw createError({ statusCode: 409, message: overlapMessage(who, other) })

    const leave = (await client.query(
      `INSERT INTO employee_leaves (team_id, employee_id, start_date, end_date, notes, created_by)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING ${LEAVE_COLUMNS}`,
      [teamId, employeeId, input.start_date, input.end_date, input.notes, user.id]
    )).rows[0]

    const today = await teamToday(client, teamId)
    const cancelled = await cancelTimeOffForLeave(client, {
      teamId,
      employeeId,
      from: leave.start_date > today ? leave.start_date : today,
      to: leave.end_date,
      actor: user,
    })

    // The note can be personal: it goes in the entry's record, not its sentence.
    await logChange(client, {
      teamId,
      actor: user,
      action: 'add',
      entity: 'leave',
      entityId: leave.id,
      employeeId,
      employeeName: who,
      summary: `Put ${who} on leave of absence ${leaveSpan(leave)}${cancelledNote(cancelled)}`,
      after: leave,
    })

    return { leave, cancelled }
  })
})
