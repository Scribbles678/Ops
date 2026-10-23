import { transaction } from '../../utils/db'
import { requireSupervisor, getWriteTeamId } from '../../utils/authorize'
import { logChange, employeeDisplayName } from '../../utils/auditLog'
import { LEAVE_COLUMNS, isUuid, leaveSpan } from '../../utils/leave'
import { lockTeamTimeOff } from '../../utils/timeOff'

/**
 * Remove a leave of absence entered by mistake. Supervisor and up. To end a real
 * leave early, change its last day instead, so the record of it stays.
 * Time off cancelled when it was saved is not brought back.
 */
export default defineEventHandler(async (event) => {
  const user = requireSupervisor(event)
  const teamId = getWriteTeamId(user)
  const id = getRouterParam(event, 'id')
  if (!isUuid(id)) throw createError({ statusCode: 404, message: 'Leave not found' })

  return transaction(async (client) => {
    await lockTeamTimeOff(client, teamId)
    const leave = (await client.query(
      `DELETE FROM employee_leaves WHERE id = $1 AND team_id = $2 RETURNING ${LEAVE_COLUMNS}`,
      [id, teamId]
    )).rows[0]
    if (!leave) throw createError({ statusCode: 404, message: 'That leave is no longer there.' })

    const who = await employeeDisplayName(client, leave.employee_id)
    await logChange(client, {
      teamId,
      actor: user,
      action: 'delete',
      entity: 'leave',
      entityId: leave.id,
      employeeId: leave.employee_id,
      employeeName: who,
      summary: `Removed ${who}'s leave of absence ${leaveSpan(leave)}`,
      before: leave,
    })
    return { ok: true }
  })
})
