import { query, transaction } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

interface RuleResults {
  [key: string]: boolean
}

/**
 * Submit a schedule request (leave early, PTO, shift swap).
 * Runs auto-approval rules in a transaction — instantly approves or rejects.
 * On approval, creates the downstream pto_days or shift_swaps record.
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

  const validTypes = ['leave_early', 'pto_full_day', 'pto_partial', 'shift_swap']
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
    // Load team settings
    const settingsResult = await client.query(
      'SELECT setting_key, setting_value FROM team_settings WHERE team_id = $1',
      [teamId]
    )
    const settings: Record<string, string> = {}
    for (const row of settingsResult.rows as { setting_key: string; setting_value: string }[]) {
      settings[row.setting_key] = row.setting_value
    }

    const getSetting = (key: string, defaultValue: number): number => {
      const val = parseInt(settings[key] ?? '', 10)
      return isNaN(val) ? defaultValue : val
    }

    // Evaluate rules
    const ruleResults: RuleResults = {}
    const reqDate = new Date(request_date + 'T00:00:00')
    const now = new Date()

    // Rule 1: 24-hour advance notice
    const hoursUntil = (reqDate.getTime() - now.getTime()) / (1000 * 60 * 60)
    ruleResults['24h_advance'] = hoursUntil >= 24

    // Rule 2: Leave early — max per employee per day
    if (request_type === 'leave_early') {
      const maxLeaveEarly = getSetting('max_leave_early_per_employee_per_day', 1)
      const countResult = await client.query(
        `SELECT COUNT(*)::int as cnt FROM schedule_requests
         WHERE employee_id = $1 AND request_type = 'leave_early' AND status = 'approved'
           AND request_date = $2`,
        [employee_id, request_date]
      )
      ruleResults['max_leave_early_per_day'] = (countResult.rows[0] as any).cnt < maxLeaveEarly
    }

    // Rule 3: Shift swap — max per employee per day
    if (request_type === 'shift_swap') {
      const maxShiftChange = getSetting('max_shift_change_per_employee_per_day', 1)
      const countResult = await client.query(
        `SELECT COUNT(*)::int as cnt FROM schedule_requests
         WHERE employee_id = $1 AND request_type = 'shift_swap' AND status = 'approved'
           AND request_date = $2`,
        [employee_id, request_date]
      )
      ruleResults['max_shift_swap_per_day'] = (countResult.rows[0] as any).cnt < maxShiftChange
    }

    // Rule 4: Max PTO hours per day (team-wide)
    if (['pto_full_day', 'pto_partial', 'leave_early'].includes(request_type)) {
      const maxPtoHours = getSetting('max_pto_hours_per_day', 8)

      // Sum existing approved PTO hours for this team on this day
      const existingResult = await client.query(
        `SELECT COALESCE(SUM(
          CASE
            WHEN request_type = 'pto_full_day' THEN 8
            WHEN request_type = 'pto_partial' AND start_time IS NOT NULL AND end_time IS NOT NULL
              THEN EXTRACT(EPOCH FROM (end_time - start_time)) / 3600
            WHEN request_type = 'leave_early' THEN 2
            ELSE 0
          END
        ), 0)::numeric as total_hours
        FROM schedule_requests
        WHERE team_id = $1 AND status = 'approved'
          AND request_type IN ('pto_full_day', 'pto_partial', 'leave_early')
          AND request_date = $2`,
        [teamId, request_date]
      )
      const existingHours = parseFloat((existingResult.rows[0] as any).total_hours) || 0

      let requestedHours = 0
      if (request_type === 'pto_full_day') requestedHours = 8
      else if (request_type === 'leave_early') requestedHours = 2
      else if (request_type === 'pto_partial' && start_time && end_time) {
        const [sh, sm] = start_time.split(':').map(Number)
        const [eh, em] = end_time.split(':').map(Number)
        requestedHours = (eh * 60 + em - sh * 60 - sm) / 60
      }

      ruleResults['max_pto_hours_per_day'] = (existingHours + requestedHours) <= maxPtoHours
    }

    // Rule 5: Max shift swaps per day (team-wide)
    if (request_type === 'shift_swap') {
      const maxSwapsPerDay = getSetting('max_shift_swaps_per_day', 3)
      const countResult = await client.query(
        `SELECT COUNT(*)::int as cnt FROM schedule_requests
         WHERE team_id = $1 AND request_type = 'shift_swap' AND status = 'approved'
           AND request_date = $2`,
        [teamId, request_date]
      )
      ruleResults['max_shift_swaps_per_day'] = (countResult.rows[0] as any).cnt < maxSwapsPerDay
    }

    // Determine status
    const allPassed = Object.values(ruleResults).every(v => v === true)
    const status = allPassed ? 'approved' : 'rejected'

    // Build rejection reason from failed rules
    let rejectionReason: string | null = null
    if (!allPassed) {
      const failed = Object.entries(ruleResults).filter(([, v]) => !v).map(([k]) => k)
      const labels: Record<string, string> = {
        '24h_advance': 'Requests must be made at least 24 hours in advance',
        'max_leave_early_per_day': 'Max leave-early requests for the day reached',
        'max_shift_swap_per_day': 'Max shift change requests for the day reached',
        'max_pto_hours_per_day': 'Team PTO hours limit for the day exceeded',
        'max_shift_swaps_per_day': 'Max shift swaps for the day exceeded',
      }
      rejectionReason = failed.map(k => labels[k] || k).join('; ')
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
      } else if (request_type === 'shift_swap') {
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
