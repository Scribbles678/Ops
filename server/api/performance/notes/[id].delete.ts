import { transaction } from '../../../utils/db'
import { requireTeamLead, getTeamFilter } from '../../../utils/authorize'
import { logChange, employeeDisplayName, describeNote } from '../../../utils/auditLog'

/** Delete a performance note. ADMIN ONLY, team-scoped. */
export default defineEventHandler(async (event) => {
  const user = requireTeamLead(event)
  const teamId = getTeamFilter(user)
  const id = getRouterParam(event, 'id')

  await transaction(async (client) => {
    const existing = await client.query(
      'SELECT id, employee_id, note_date::text AS note_date, category, body, tag, team_id FROM performance_notes WHERE id = $1',
      [id]
    )
    const row = existing.rows[0]
    if (!row || (teamId && row.team_id !== teamId)) {
      throw createError({ statusCode: 404, message: 'Note not found' })
    }
    await client.query('DELETE FROM performance_notes WHERE id = $1', [id])

    const who = await employeeDisplayName(client, row.employee_id)
    await logChange(client, {
      teamId: row.team_id,
      actor: user,
      action: 'delete',
      entity: 'performance_note',
      entityId: row.id,
      employeeId: row.employee_id,
      employeeName: who,
      summary: `Deleted a ${describeNote(row)} for ${who}`,
      before: row,
    })
  })
  return { success: true }
})
