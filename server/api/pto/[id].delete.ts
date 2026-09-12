import { transaction } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'
import { logChange, employeeDisplayName, describePtoDay } from '../../utils/auditLog'

/** Remove a PTO day / call-in by hand (the schedule page). Logged to the change log. */
export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  // Nitro may register the param as 'id' or 'date' depending on sibling route files
  const id = getRouterParam(event, 'id') || getRouterParam(event, 'date')
  if (!id) {
    throw createError({ statusCode: 400, message: 'Missing PTO record ID' })
  }

  await transaction(async (client) => {
    const existing = await client.query('SELECT * FROM pto_days WHERE id = $1 AND team_id = $2', [id, teamId])
    const row = existing.rows[0]
    if (!row) {
      throw createError({ statusCode: 404, message: 'PTO record not found' })
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
