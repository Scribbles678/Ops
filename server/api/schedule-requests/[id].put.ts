import { query, transaction } from '../../utils/db'
import { requireTeamLead, getTeamFilter } from '../../utils/authorize'
import { logChange, employeeDisplayName, describeRequest } from '../../utils/auditLog'

/**
 * How a request type materializes into pto_days.pto_type.
 *
 * This MUST match what POST /api/schedule-requests writes — they are two paths to
 * the same state. It previously wrote `request.request_type` verbatim for anything
 * that wasn't a full day, so an admin-approved partial landed as `pto_partial`
 * where the submit path writes `partial`. Nothing crashed because describePto()
 * and hoursForPtoDay() both have a catch-all branch, so the row simply read as an
 * untyped legacy record everywhere.
 */
const PTO_TYPE_FOR_REQUEST: Record<string, string> = {
  pto_full_day: 'full_day',
  pto_partial: 'partial',
  leave_early: 'leave_early',
  arrive_late: 'arrive_late',
}

/**
 * Admin override: approve or reject a request, regardless of rules.
 * If approving a previously rejected request, creates the downstream record.
 * If rejecting a previously approved request, deletes the downstream record.
 */
export default defineEventHandler(async (event) => {
  const user = requireTeamLead(event)
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
            PTO_TYPE_FOR_REQUEST[request.request_type] ?? request.request_type,
            request.notes || 'Admin-approved request',
            request.team_id,
          ]
        )
        createdPtoId = (ptoResult.rows[0] as any).id
      } else if (request.request_type === 'arrive_late') {
        // Absence from start of shift to the arrival time (stored in start_time).
        const ptoResult = await client.query(
          `INSERT INTO pto_days (employee_id, pto_date, start_time, end_time, pto_type, notes, team_id)
           VALUES ($1, $2, '00:00:00', $3, 'arrive_late', $4, $5) RETURNING id`,
          [
            request.employee_id, request.request_date,
            request.start_time,
            request.notes || 'Admin-approved request',
            request.team_id,
          ]
        )
        createdPtoId = (ptoResult.rows[0] as any).id
      }
      // 'leave_on_time' is informational — no downstream record.
      else if (request.request_type === 'shift_swap') {
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

    // Change log: who overrode what, and from which status.
    const who = await employeeDisplayName(client, request.employee_id)
    const verb = status === 'approved' ? 'Approved' : 'Rejected'
    await logChange(client, {
      teamId: request.team_id,
      actor: user,
      action: status === 'approved' ? 'approve' : 'reject',
      entity: 'request',
      entityId: request.id,
      employeeId: request.employee_id,
      employeeName: who,
      summary:
        `${verb} ${who}'s ${describeRequest(request)}` +
        (oldStatus !== status ? ` (was ${oldStatus})` : ' (already ' + status + ')') +
        (status === 'rejected' && rejection_reason ? `: ${rejection_reason}` : ''),
      before: request,
      after: updated.rows[0],
    })

    return updated.rows[0]
  })

  return result
})
