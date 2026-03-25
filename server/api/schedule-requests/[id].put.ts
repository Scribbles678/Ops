import { query, transaction } from '../../utils/db'
import { requireAdmin, getTeamFilter } from '../../utils/authorize'

/**
 * Admin override: approve or reject a request, regardless of rules.
 * If approving a previously rejected request, creates the downstream record.
 * If rejecting a previously approved request, deletes the downstream record.
 */
export default defineEventHandler(async (event) => {
  const user = requireAdmin(event)
  const teamId = getTeamFilter(user)
  const id = getRouterParam(event, 'id')
  const body = await readBody(event)

  const { status, rejection_reason } = body ?? {}

  if (!status || !['approved', 'rejected'].includes(status)) {
    throw createError({ statusCode: 400, message: 'status must be "approved" or "rejected"' })
  }

  const result = await transaction(async (client) => {
    // Fetch the current request
    const current = await client.query('SELECT * FROM schedule_requests WHERE id = $1', [id])
    const request = (current.rows as any[])[0]
    if (!request) {
      throw createError({ statusCode: 404, message: 'Request not found' })
    }
    if (teamId && request.team_id !== teamId) {
      throw createError({ statusCode: 404, message: 'Request not found' })
    }

    const oldStatus = request.status

    // If changing from approved → rejected, clean up downstream records
    if (oldStatus === 'approved' && status === 'rejected') {
      if (request.created_pto_id) {
        await client.query('DELETE FROM pto_days WHERE id = $1', [request.created_pto_id])
      }
      if (request.created_swap_id) {
        await client.query('DELETE FROM shift_swaps WHERE id = $1', [request.created_swap_id])
      }
    }

    // If changing from rejected/pending → approved, create downstream records
    let createdPtoId = request.created_pto_id
    let createdSwapId = request.created_swap_id

    if (oldStatus !== 'approved' && status === 'approved') {
      if (['pto_full_day', 'pto_partial', 'leave_early'].includes(request.request_type)) {
        const ptoResult = await client.query(
          `INSERT INTO pto_days (employee_id, pto_date, start_time, end_time, pto_type, notes, team_id)
           VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id`,
          [
            request.employee_id, request.request_date,
            request.start_time || null, request.end_time || null,
            request.request_type === 'pto_full_day' ? 'full_day' : request.request_type,
            request.notes || 'Admin-approved request',
            request.team_id,
          ]
        )
        createdPtoId = (ptoResult.rows[0] as any).id
      } else if (request.request_type === 'shift_swap') {
        const swapResult = await client.query(
          `INSERT INTO shift_swaps (employee_id, swap_date, original_shift_id, swapped_shift_id, notes, team_id)
           VALUES ($1, $2, $3, $4, $5, $6)
           ON CONFLICT (employee_id, swap_date) DO UPDATE SET
             original_shift_id = EXCLUDED.original_shift_id,
             swapped_shift_id = EXCLUDED.swapped_shift_id,
             notes = EXCLUDED.notes,
             updated_at = NOW()
           RETURNING id`,
          [
            request.employee_id, request.request_date,
            request.original_shift_id, request.requested_shift_id,
            request.notes || 'Admin-approved request',
            request.team_id,
          ]
        )
        createdSwapId = (swapResult.rows[0] as any).id
      }
    }

    // Update the request
    const updated = await client.query(
      `UPDATE schedule_requests
       SET status = $1, rejection_reason = $2, approved_by = $3, admin_override = true,
           created_pto_id = $4, created_swap_id = $5, updated_at = NOW()
       WHERE id = $6
       RETURNING *`,
      [
        status,
        status === 'rejected' ? (rejection_reason || null) : null,
        user.id,
        status === 'approved' ? createdPtoId : null,
        status === 'approved' ? createdSwapId : null,
        id,
      ]
    )

    return updated.rows[0]
  })

  return result
})
