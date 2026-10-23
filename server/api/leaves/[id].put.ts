import { transaction } from '../../utils/db'
import { requireSupervisor, getWriteTeamId } from '../../utils/authorize'
import { logChange, employeeDisplayName } from '../../utils/auditLog'
import { teamToday } from '../../utils/teamTime'
import { LEAVE_COLUMNS, cancelledNote, findOverlappingLeave, isUuid, leaveSpan, overlapMessage, readLeaveInput } from '../../utils/leave'
import { lockTeamTimeOff, cancelTimeOffForLeave } from '../../utils/timeOff'

/**
 * Change a leave of absence: end it early, extend it, set the return date, edit the
 * note. Supervisor and up. Body: any of { start_date, end_date (null = not known), notes }.
 *
 * Days it now covers lose the time off booked on them, from today on — the same rule
 * as a new leave. Days it no longer covers get nothing back: time off cancelled when
 * the leave was saved stays cancelled (the window says so).
 * Returns { leave, cancelled }.
 */
export default defineEventHandler(async (event) => {
  const user = requireSupervisor(event)
  const teamId = getWriteTeamId(user)
  const id = getRouterParam(event, 'id')
  if (!isUuid(id)) throw createError({ statusCode: 404, message: 'Leave not found' })
  const body = await readBody(event)

  return transaction(async (client) => {
    await lockTeamTimeOff(client, teamId)
    const before = (await client.query(
      `SELECT ${LEAVE_COLUMNS} FROM employee_leaves WHERE id = $1 AND team_id = $2 FOR UPDATE`,
      [id, teamId]
    )).rows[0]
    if (!before) throw createError({ statusCode: 404, message: 'That leave is no longer there. Close the window and open it again.' })

    const input = await readLeaveInput(client, teamId, body, before)
    const who = await employeeDisplayName(client, before.employee_id)
    const other = await findOverlappingLeave(client, {
      teamId, employeeId: before.employee_id, start: input.start_date, end: input.end_date, ignoreId: id,
    })
    if (other) throw createError({ statusCode: 409, message: overlapMessage(who, other) })

    const sameDates = input.start_date === before.start_date && input.end_date === before.end_date
    if (sameDates && input.notes === before.notes) return { leave: before, cancelled: [] }

    const leave = (await client.query(
      `UPDATE employee_leaves SET start_date = $1, end_date = $2, notes = $3, updated_at = now()
       WHERE id = $4 RETURNING ${LEAVE_COLUMNS}`,
      [input.start_date, input.end_date, input.notes, id]
    )).rows[0]

    const today = await teamToday(client, teamId)
    const cancelled = sameDates
      ? []
      : await cancelTimeOffForLeave(client, {
          teamId,
          employeeId: leave.employee_id,
          from: leave.start_date > today ? leave.start_date : today,
          to: leave.end_date,
          actor: user,
        })

    await logChange(client, {
      teamId,
      actor: user,
      action: 'edit',
      entity: 'leave',
      entityId: leave.id,
      employeeId: leave.employee_id,
      employeeName: who,
      summary: sameDates
        ? `Changed the note on ${who}'s leave of absence ${leaveSpan(leave)}`
        : `Changed ${who}'s leave of absence: was ${leaveSpan(before)}, now ${leaveSpan(leave)}${cancelledNote(cancelled)}`,
      before,
      after: leave,
    })

    return { leave, cancelled }
  })
})
