import { query, transaction } from '../../utils/db'
import { requireTeamLead, getTeamFilter } from '../../utils/authorize'
import { deleteRequestWithRecords } from '../../utils/timeOff'

/**
 * Cancel/delete a schedule request. Also deletes any downstream pto_days or shift_swaps
 * records, through the same deleteRequestWithRecords() the schedule page and call-ins use.
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

    await deleteRequestWithRecords(client, request, user)
  })

  return { success: true }
})
