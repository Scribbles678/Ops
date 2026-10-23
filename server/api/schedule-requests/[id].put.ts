import { query, transaction } from '../../utils/db'
import { requireTeamLead, getTeamFilter } from '../../utils/authorize'
import { logChange, employeeDisplayName, describeRequest } from '../../utils/auditLog'
import { lockTeamTimeOff, findRequestConflict, ptoShapeForRequest } from '../../utils/timeOff'
import { fmtDate } from '../../utils/ptoHours'

/**
 * Admin override: approve or reject a request, regardless of rules.
 * If approving a previously rejected request, creates the downstream record.
 * If rejecting a previously approved request, deletes the downstream record.
 *
 * The rules can be overridden; a duplicate cannot. Approving time off the person
 * already has (server/utils/timeOff.ts) is refused with a 409.
 *
 * The pto_days row is built by the same ptoShapeForRequest() as the submit: they
 * are two paths to the same state, and this one used to write `request_type`
 * verbatim, so an admin-approved partial landed as `pto_partial` where the submit
 * writes `partial` (it read as an untyped legacy row everywhere).
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
    await lockTeamTimeOff(client, teamId)

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

    if (oldStatus !== 'approved' && status === 'approved') {
      // pg hands a DATE back as a local-midnight Date; fmtDate reads it back as one.
      const conflict = await findRequestConflict(client, request.team_id, {
        ...request,
        request_date: fmtDate(request.request_date),
      })
      if (conflict) throw createError({ statusCode: 409, message: conflict })
    }

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
      // 'leave_on_time' is informational — no downstream record.
      const pto = ptoShapeForRequest(request.request_type, request.start_time, request.end_time)
      if (pto) {
        const ptoResult = await client.query(
          `INSERT INTO pto_days (employee_id, pto_date, start_time, end_time, pto_type, notes, team_id)
           VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id`,
          [
            request.employee_id, request.request_date,
            pto.start_time, pto.end_time, pto.pto_type,
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
           WHERE shift_swaps.team_id = EXCLUDED.team_id
           RETURNING id, (xmax = 0) AS inserted`,
          [
            request.employee_id, request.request_date,
            request.original_shift_id, request.requested_shift_id,
            request.notes || 'Admin-approved request',
            request.team_id,
          ]
        )
        // Record the swap as this request's own only if the request created it, so
        // rejecting or deleting the request never removes a swap someone else entered.
        const swap = swapResult.rows[0] as { id: string; inserted: boolean } | undefined
        if (!swap) {
          throw createError({ statusCode: 409, message: 'A shift swap for that person and day belongs to another team.' })
        }
        createdSwapId = swap.inserted ? swap.id : null
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
