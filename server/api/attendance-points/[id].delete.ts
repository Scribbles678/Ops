import { transaction } from '../../utils/db'
import { requireTeamLead, getTeamFilter } from '../../utils/authorize'
import { logChange, employeeDisplayName, pointsWord, shortDate } from '../../utils/auditLog'

/** Remove an attendance point (correcting a mistake). TEAM LEAD AND ABOVE, team-scoped. Logged. */
export default defineEventHandler(async (event) => {
  const user = requireTeamLead(event)
  const teamId = getTeamFilter(user)
  const id = getRouterParam(event, 'id')

  await transaction(async (client) => {
    const existing = await client.query(
      `SELECT id, employee_id, point_date::text AS point_date, points, notes, team_id
       FROM attendance_points WHERE id = $1`,
      [id]
    )
    const row = existing.rows[0]
    if (!row || (teamId && row.team_id !== teamId)) {
      throw createError({ statusCode: 404, message: 'Attendance point not found' })
    }
    await client.query('DELETE FROM attendance_points WHERE id = $1', [id])

    const who = await employeeDisplayName(client, row.employee_id)
    await logChange(client, {
      teamId: row.team_id,
      actor: user,
      action: 'delete',
      entity: 'attendance_point',
      entityId: row.id,
      employeeId: row.employee_id,
      employeeName: who,
      summary: `Removed ${pointsWord(Number(row.points))} from ${who} for ${shortDate(row.point_date)}${row.notes ? ` (${row.notes})` : ''}`,
      before: row,
    })
  })
  return { success: true }
})
