import { transaction } from '../../utils/db'
import { requireAuth, getWriteTeamId } from '../../utils/authorize'
import { evaluateRequest, loadTeamSettings, assertRequestDate } from '../../utils/requestRules'
import { assertEmployeeOnTeam, assertShiftsOnTeam } from '../../utils/teamOwnership'
import { lockTeamTimeOff, ptoShapeForRequest } from '../../utils/timeOff'

/**
 * Submit a schedule request (leave early, PTO, shift swap).
 * Runs auto-approval rules in a transaction — instantly approves or rejects.
 * On approval, creates the downstream pto_days or shift_swaps record.
 *
 * The rules themselves live in server/utils/requestRules.ts so the preview
 * endpoint evaluates exactly the same conditions.
 *
 * Time off the person already has (server/utils/timeOff.ts) is refused with a 409
 * and nothing is saved: a duplicate is a mistake, not a request to record.
 */
export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const body = await readBody(event)

  const {
    employee_id,
    request_type,
    request_date,
    start_time,
    end_time,
    original_shift_id,
    requested_shift_id,
    notes,
  } = body ?? {}

  // Validate required fields
  if (!employee_id || !request_type || !request_date) {
    throw createError({ statusCode: 400, message: 'employee_id, request_type, and request_date are required' })
  }

  const validTypes = ['leave_early', 'pto_full_day', 'pto_partial', 'shift_swap', 'leave_on_time', 'arrive_late']
  if (!validTypes.includes(request_type)) {
    throw createError({ statusCode: 400, message: `request_type must be one of: ${validTypes.join(', ')}` })
  }

  if (request_type === 'shift_swap' && (!original_shift_id || !requested_shift_id)) {
    throw createError({ statusCode: 400, message: 'Shift swap requires original_shift_id and requested_shift_id' })
  }

  if (request_type === 'pto_partial' && (!start_time || !end_time)) {
    throw createError({ statusCode: 400, message: 'Partial PTO requires start_time and end_time' })
  }

  if (request_type === 'leave_early' && !start_time) {
    throw createError({ statusCode: 400, message: 'Leave early requires start_time (the new end time)' })
  }

  if (request_type === 'arrive_late' && !start_time) {
    throw createError({ statusCode: 400, message: 'Arrive late requires start_time (the new arrival time)' })
  }

  assertRequestDate(request_date)

  // The request belongs to the submitter's team, and the employee (and any shifts
  // in a swap) must be on it. The team used to come from the employee's row, so any
  // account — the kiosk included — could file an auto-approved request straight into
  // another site's data, given that employee's id (Sep 2026 audit).
  const teamId = getWriteTeamId(user)
  await assertEmployeeOnTeam(employee_id, teamId)
  if (request_type === 'shift_swap') {
    await assertShiftsOnTeam([original_shift_id, requested_shift_id], teamId)
  }

  // Run auto-approval in a transaction
  const result = await transaction(async (client) => {
    await lockTeamTimeOff(client, teamId)
    const settings = await loadTeamSettings(client, teamId)

    const { status, ruleResults, rejectionReason, conflict, closedDay } = await evaluateRequest(
      client,
      teamId,
      settings,
      { employee_id, request_type, request_date, start_time, end_time }
    )
    // A day the site doesn't work: nothing to ask for, so nothing is saved.
    if (closedDay) {
      throw createError({ statusCode: 400, message: closedDay })
    }
    if (conflict) {
      throw createError({ statusCode: 409, message: conflict })
    }

    // Insert the request
    const insertResult = await client.query(
      `INSERT INTO schedule_requests
       (employee_id, team_id, request_type, status, request_date, start_time, end_time,
        original_shift_id, requested_shift_id, approval_rule_results, rejection_reason,
        notes, submitted_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
       RETURNING *`,
      [
        employee_id, teamId, request_type, status, request_date,
        start_time || null, end_time || null,
        original_shift_id || null, requested_shift_id || null,
        JSON.stringify(ruleResults), rejectionReason,
        notes || null, user.id,
      ]
    )
    const request = (insertResult.rows as any[])[0]

    // If approved, create downstream records
    if (status === 'approved') {
      // The time-off row the board, the builder and the calendar read. An
      // arrive-late runs from the start of the shift to the arrival, so the
      // builder clips the morning. 'leave_on_time' is informational: no row.
      const pto = ptoShapeForRequest(request_type, start_time, end_time)
      if (pto) {
        const ptoResult = await client.query(
          `INSERT INTO pto_days (employee_id, pto_date, start_time, end_time, pto_type, notes, team_id)
           VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id`,
          [employee_id, request_date, pto.start_time, pto.end_time, pto.pto_type, notes || 'Auto-approved request', teamId]
        )
        await client.query(
          'UPDATE schedule_requests SET created_pto_id = $1 WHERE id = $2',
          [(ptoResult.rows[0] as any).id, request.id]
        )
        request.created_pto_id = (ptoResult.rows[0] as any).id
      } else if (request_type === 'shift_swap') {
        // Only this team's row may be updated, and only a swap this request actually
        // CREATED is recorded as its own — otherwise rejecting or deleting the request
        // later deleted a swap somebody else had entered.
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
          [employee_id, request_date, original_shift_id, requested_shift_id, notes || 'Auto-approved request', teamId]
        )
        const swap = swapResult.rows[0] as { id: string; inserted: boolean } | undefined
        if (!swap) {
          throw createError({ statusCode: 409, message: 'A shift swap for that person and day belongs to another team.' })
        }
        if (swap.inserted) {
          await client.query('UPDATE schedule_requests SET created_swap_id = $1 WHERE id = $2', [swap.id, request.id])
          request.created_swap_id = swap.id
        }
      }
    }

    return { request, ruleResults, status }
  })

  return result
})
