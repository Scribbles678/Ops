import { query, transaction } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'
import { evaluateRequest, loadTeamSettings } from '../../utils/requestRules'

/**
 * Submit a schedule request (leave early, PTO, shift swap).
 * Runs auto-approval rules in a transaction — instantly approves or rejects.
 * On approval, creates the downstream pto_days or shift_swaps record.
 *
 * The rules themselves live in server/utils/requestRules.ts so the preview
 * endpoint evaluates exactly the same conditions.
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

  // Resolve team_id from the employee
  const empResult = await query<{ team_id: string | null }>(
    'SELECT team_id FROM employees WHERE id = $1',
    [employee_id]
  )
  if (!empResult.rows[0]) {
    throw createError({ statusCode: 404, message: 'Employee not found' })
  }
  const teamId = empResult.rows[0].team_id

  // Run auto-approval in a transaction
  const result = await transaction(async (client) => {
    const settings = await loadTeamSettings(client, teamId)

    const { status, ruleResults, rejectionReason } = await evaluateRequest(
      client,
      teamId,
      settings,
      { employee_id, request_type, request_date, start_time, end_time }
    )

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
      if (request_type === 'pto_full_day') {
        const ptoResult = await client.query(
          `INSERT INTO pto_days (employee_id, pto_date, pto_type, notes, team_id)
           VALUES ($1, $2, $3, $4, $5) RETURNING id`,
          [employee_id, request_date, 'full_day', notes || 'Auto-approved request', teamId]
        )
        await client.query(
          'UPDATE schedule_requests SET created_pto_id = $1 WHERE id = $2',
          [(ptoResult.rows[0] as any).id, request.id]
        )
        request.created_pto_id = (ptoResult.rows[0] as any).id
      } else if (request_type === 'pto_partial') {
        const ptoResult = await client.query(
          `INSERT INTO pto_days (employee_id, pto_date, start_time, end_time, pto_type, notes, team_id)
           VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id`,
          [employee_id, request_date, start_time, end_time, 'partial', notes || 'Auto-approved request', teamId]
        )
        await client.query(
          'UPDATE schedule_requests SET created_pto_id = $1 WHERE id = $2',
          [(ptoResult.rows[0] as any).id, request.id]
        )
        request.created_pto_id = (ptoResult.rows[0] as any).id
      } else if (request_type === 'leave_early') {
        const ptoResult = await client.query(
          `INSERT INTO pto_days (employee_id, pto_date, start_time, pto_type, notes, team_id)
           VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
          [employee_id, request_date, start_time, 'leave_early', notes || 'Auto-approved request', teamId]
        )
        await client.query(
          'UPDATE schedule_requests SET created_pto_id = $1 WHERE id = $2',
          [(ptoResult.rows[0] as any).id, request.id]
        )
        request.created_pto_id = (ptoResult.rows[0] as any).id
      } else if (request_type === 'arrive_late') {
        // Absence runs from the start of the shift until the arrival time, so the
        // builder clips the morning. start_time holds the arrival time.
        const ptoResult = await client.query(
          `INSERT INTO pto_days (employee_id, pto_date, start_time, end_time, pto_type, notes, team_id)
           VALUES ($1, $2, '00:00:00', $3, 'arrive_late', $4, $5) RETURNING id`,
          [employee_id, request_date, start_time, notes || 'Auto-approved request', teamId]
        )
        await client.query(
          'UPDATE schedule_requests SET created_pto_id = $1 WHERE id = $2',
          [(ptoResult.rows[0] as any).id, request.id]
        )
        request.created_pto_id = (ptoResult.rows[0] as any).id
      }
      // 'leave_on_time' is informational — no downstream record is created.
      else if (request_type === 'shift_swap') {
        const swapResult = await client.query(
          `INSERT INTO shift_swaps (employee_id, swap_date, original_shift_id, swapped_shift_id, notes, team_id)
           VALUES ($1, $2, $3, $4, $5, $6)
           ON CONFLICT (employee_id, swap_date) DO UPDATE SET
             original_shift_id = EXCLUDED.original_shift_id,
             swapped_shift_id = EXCLUDED.swapped_shift_id,
             notes = EXCLUDED.notes,
             updated_at = NOW()
           RETURNING id`,
          [employee_id, request_date, original_shift_id, requested_shift_id, notes || 'Auto-approved request', teamId]
        )
        await client.query(
          'UPDATE schedule_requests SET created_swap_id = $1 WHERE id = $2',
          [(swapResult.rows[0] as any).id, request.id]
        )
        request.created_swap_id = (swapResult.rows[0] as any).id
      }
    }

    return { request, ruleResults, status }
  })

  return result
})
