import { query, transaction } from '../../utils/db'
import { requireTeamLead, getTeamFilter } from '../../utils/authorize'
import { logChange, employeeDisplayName, describeRequest } from '../../utils/auditLog'

/**
 * Cancel/delete a schedule request. Also deletes any downstream pto_days or shift_swaps records.
 */
export default defineEventHandler(async (event) => {
  const user = requireTeamLead(event)
  const teamId = getTeamFilter(user)
  const id = getRouterParam(event, 'id')

  await transaction(async (client) => {
    const current = await client.query('SELECT * FROM schedule_requests WHERE id = $1', [id])
    const request = (current.rows as any[])[0]
    if (!request) {
      throw createError({ statusCode: 404, message: 'Request not found' })
    }
    if (teamId && request.team_id !== teamId) {
      throw createError({ statusCode: 404, message: 'Request not found' })
    }

    // Clean up downstream records
    if (request.created_pto_id) {
      await client.query('DELETE FROM pto_days WHERE id = $1', [request.created_pto_id])
    }
    if (request.created_swap_id) {
      await client.query('DELETE FROM shift_swaps WHERE id = $1', [request.created_swap_id])
    }

    await client.query('DELETE FROM schedule_requests WHERE id = $1', [id])

    // Change log: a deleted request leaves nothing else behind, so this entry
    // (with the full row in `before`) is the only record it ever existed.
    const who = await employeeDisplayName(client, request.employee_id)
    await logChange(client, {
      teamId: request.team_id,
      actor: user,
      action: 'delete',
      entity: 'request',
      entityId: request.id,
      employeeId: request.employee_id,
      employeeName: who,
      summary: `Deleted ${who}'s ${describeRequest(request)} (was ${request.status})`,
      before: request,
    })
  })

  return { success: true }
})
