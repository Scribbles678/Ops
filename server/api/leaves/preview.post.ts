import { query } from '../../utils/db'
import { requireSupervisor, getWriteTeamId } from '../../utils/authorize'
import { assertEmployeeOnTeam } from '../../utils/teamOwnership'
import { employeeDisplayName } from '../../utils/auditLog'
import { teamToday } from '../../utils/teamTime'
import { LEAVE_COLUMNS, findOverlappingLeave, isUuid, overlapMessage, readLeaveInput, scheduledDaysInLeave } from '../../utils/leave'
import { timeOffBetween, timeOffDayLabels } from '../../utils/timeOff'

/**
 * What saving a leave of absence would do, before it's saved — the leave window on
 * Team Setup shows it under the dates. Read-only. Supervisor and up, like saving.
 *
 * Body: { employee_id, start_date, end_date (null = return date not known), leave_id? }
 * (leave_id when changing an existing leave). Bad dates are a 400 with a sentence.
 * Returns:
 *   problem    why it can't be saved (another leave shares days, the person is inactive), or null
 *   cancels    their time off saving would cancel, from today on ("Fri, Nov 20 — Full Day")
 *   scheduled  days (YYYY-MM-DD) from today on they're already on the schedule inside it
 */
export default defineEventHandler(async (event) => {
  const user = requireSupervisor(event)
  const teamId = getWriteTeamId(user)
  const body = await readBody(event)
  const employeeId = body?.employee_id
  await assertEmployeeOnTeam(employeeId, teamId)

  let current
  if (body?.leave_id) {
    if (!isUuid(body.leave_id)) throw createError({ statusCode: 400, message: 'leave_id must be a leave id' })
    current = (await query<any>(
      `SELECT ${LEAVE_COLUMNS} FROM employee_leaves WHERE id = $1 AND team_id = $2 AND employee_id = $3`,
      [body.leave_id, teamId, employeeId]
    )).rows[0]
    if (!current) throw createError({ statusCode: 404, message: 'That leave is no longer there. Close the window and open it again.' })
  }
  const input = await readLeaveInput({ query }, teamId, body, current)

  const who = await employeeDisplayName(query, employeeId)
  const active = (await query<{ is_active: boolean }>('SELECT is_active FROM employees WHERE id = $1', [employeeId])).rows[0]?.is_active
  const other = await findOverlappingLeave({ query }, {
    teamId, employeeId, start: input.start_date, end: input.end_date, ignoreId: current?.id,
  })
  const problem = active === false
    ? `${who} is inactive. Reactivate them on Team Setup first.`
    : other ? overlapMessage(who, other) : null

  const today = await teamToday({ query }, teamId)
  const from = input.start_date > today ? input.start_date : today
  const [timeOff, scheduled] = await Promise.all([
    timeOffBetween({ query }, { teamId, employeeId, from, to: input.end_date }),
    scheduledDaysInLeave({ query }, { teamId, employeeId, from, end: input.end_date }),
  ])
  return { problem, cancels: timeOffDayLabels(timeOff), scheduled }
})
