import { transaction } from '../../../utils/db'
import { requireTeamLead, getTeamFilter } from '../../../utils/authorize'
import { logChange, employeeDisplayName, describeError } from '../../../utils/auditLog'

/** Delete a logged error (correcting a mistake). ADMIN ONLY, team-scoped. */
export default defineEventHandler(async (event) => {
  const user = requireTeamLead(event)
  const teamId = getTeamFilter(user)
  const id = getRouterParam(event, 'id')

  await transaction(async (client) => {
    const existing = await client.query(
      `SELECT pe.*, pe.error_date::text AS error_date, jf.name AS job_function_name
       FROM performance_errors pe LEFT JOIN job_functions jf ON jf.id = pe.job_function_id
       WHERE pe.id = $1`,
      [id]
    )
    const row = existing.rows[0]
    if (!row || (teamId && row.team_id !== teamId)) {
      throw createError({ statusCode: 404, message: 'Error record not found' })
    }
    await client.query('DELETE FROM performance_errors WHERE id = $1', [id])

    const who = await employeeDisplayName(client, row.employee_id)
    await logChange(client, {
      teamId: row.team_id,
      actor: user,
      action: 'delete',
      entity: 'performance_error',
      entityId: row.id,
      employeeId: row.employee_id,
      employeeName: who,
      summary: `Removed ${describeError(row, row.job_function_name)} from ${who}`,
      before: row,
    })
  })
  return { success: true }
})
