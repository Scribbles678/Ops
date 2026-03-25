import { query, transaction } from '../../utils/db'
import { requireAdmin } from '../../utils/authorize'

/**
 * Cancel/delete a schedule request. Also deletes any downstream pto_days or shift_swaps records.
 */
export default defineEventHandler(async (event) => {
  requireAdmin(event)
  const id = getRouterParam(event, 'id')

  await transaction(async (client) => {
    const current = await client.query('SELECT * FROM schedule_requests WHERE id = $1', [id])
    const request = (current.rows as any[])[0]
    if (!request) {
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
  })

  return { success: true }
})
