import { transaction } from '../../utils/db'
import { requireTeamLead, getTeamFilter } from '../../utils/authorize'
import { logChange, employeeDisplayName, describePtoDay } from '../../utils/auditLog'
import { deleteRequestWithRecords } from '../../utils/timeOff'
import { isLeaveDayId } from '../../utils/leave'

/**
 * Remove a PTO day / call-in by hand (the schedule page). Logged to the change log.
 *
 * A day off an approved request created is removed WITH that request. Deleting only
 * the row left the request approved and pointing at nothing: still charged to the
 * day's hours, still on the PTO calendar, though the person was back on the board.
 */
export default defineEventHandler(async (event) => {
  const user = requireTeamLead(event)
  const teamId = getTeamFilter(user)
  // Nitro may register the param as 'id' or 'date' depending on sibling route files
  const id = getRouterParam(event, 'id') || getRouterParam(event, 'date')
  if (!id) {
    throw createError({ statusCode: 400, message: 'Missing PTO record ID' })
  }
  if (isLeaveDayId(id)) {
    throw createError({ statusCode: 400, message: "That's a day of a leave of absence, not time off. Change the leave on Team Setup." })
  }

  await transaction(async (client) => {
    const existing = await client.query('SELECT * FROM pto_days WHERE id = $1 AND team_id = $2', [id, teamId])
    const row = existing.rows[0]
    if (!row) {
      throw createError({ statusCode: 404, message: 'PTO record not found' })
    }

    const fromRequest = await client.query(
      'SELECT * FROM schedule_requests WHERE created_pto_id = $1 AND team_id = $2',
      [id, teamId]
    )
    if (fromRequest.rows[0]) {
      await deleteRequestWithRecords(client, fromRequest.rows[0], user, 'was approved; removed on the schedule page')
      return
    }

    await client.query('DELETE FROM pto_days WHERE id = $1', [id])

    const who = await employeeDisplayName(client, row.employee_id)
    await logChange(client, {
      teamId,
      actor: user,
      action: 'delete',
      entity: 'pto_day',
      entityId: row.id,
      employeeId: row.employee_id,
      employeeName: who,
      summary: `Removed ${describePtoDay(row)} for ${who}${row.notes ? ` (${row.notes})` : ''}`,
      before: row,
    })
  })
  return { success: true }
})
