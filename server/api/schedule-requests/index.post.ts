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

    // Rule 1: advance notice in BUSINESS days (Mon–Fri). Counts full working days
    // strictly between today and the requested date — weekends don't count, so a
    // Friday request for Monday gives 0 business days' notice.
    const minBusinessDaysNotice = getSetting('min_business_days_notice', 1)
    const countBusinessDaysBetween = (from: Date, to: Date): number => {
      let count = 0
      const d = new Date(from.getFullYear(), from.getMonth(), from.getDate())
      d.setDate(d.getDate() + 1) // strictly after `from`
      const end = new Date(to.getFullYear(), to.getMonth(), to.getDate())
      while (d < end) {
        const dow = d.getDay()
        if (dow !== 0 && dow !== 6) count++
        d.setDate(d.getDate() + 1)
      }
      return count
    }
    const businessDaysNotice = countBusinessDaysBetween(now, reqDate)
    ruleResults['advance_notice'] = businessDaysNotice >= minBusinessDaysNotice

    // Mon–Sun week bounds containing the requested date (shared by per-week rules).
    const pad = (n: number) => String(n).padStart(2, '0')
    const fmtDate = (d: Date) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
    const reqDow = reqDate.getDay() // 0 Sun..6 Sat
    const weekStart = new Date(reqDate)
    weekStart.setDate(reqDate.getDate() + (reqDow === 0 ? -6 : 1 - reqDow)) // Monday
    const weekEnd = new Date(weekStart)
    weekEnd.setDate(weekStart.getDate() + 6) // Sunday

    // Count an employee's approved requests of a type within that week.
    const countEmployeeWeek = async (type: string): Promise<number> => {
      const r = await client.query(
        `SELECT COUNT(*)::int as cnt FROM schedule_requests
         WHERE employee_id = $1 AND request_type = $2 AND status = 'approved'
           AND request_date BETWEEN $3 AND $4`,
        [employee_id, type, fmtDate(weekStart), fmtDate(weekEnd)]
      )
      return (r.rows[0] as any).cnt
    }

    // Rule 2: Shift change — max per employee per WEEK.
    if (request_type === 'shift_swap') {
      const maxShiftChange = getSetting('max_shift_change_per_employee_per_week', 1)
      ruleResults['max_shift_change_per_week'] = (await countEmployeeWeek('shift_swap')) < maxShiftChange
    }

    // Rule 2b: Leave on time — max per employee per WEEK.
    if (request_type === 'leave_on_time') {
      const maxLeaveOnTime = getSetting('max_leave_on_time_per_employee_per_week', 5)
      ruleResults['max_leave_on_time_per_week'] = (await countEmployeeWeek('leave_on_time')) < maxLeaveOnTime
    }

    // Rule 4: Max PTO hours per day (team-wide). Counts hour-reducing requests only —
    // 'leave_on_time' is informational (0 hours) and is intentionally excluded.
    if (['pto_full_day', 'pto_partial', 'leave_early', 'arrive_late'].includes(request_type)) {
      // Per-weekday team-wide cap (max_pto_hours_by_dow JSON, keyed mon..fri);
      // weekends (and any unset weekday) fall back to the legacy single setting.
      const maxPtoHours = (() => {
        const dowName = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'][reqDate.getDay()]
        try {
          const raw = settings['max_pto_hours_by_dow']
          if (raw) {
            const map = JSON.parse(raw)
            const v = Number(map?.[dowName])
            if (!isNaN(v)) return v
          }
        } catch { /* fall through to default */ }
        return getSetting('max_pto_hours_per_day', 8)
      })()

      // Sum existing approved PTO hours for this team on this day
      const existingResult = await client.query(
        `SELECT COALESCE(SUM(
          CASE
            WHEN request_type = 'pto_full_day' THEN 8
            WHEN request_type = 'pto_partial' AND start_time IS NOT NULL AND end_time IS NOT NULL
              THEN EXTRACT(EPOCH FROM (end_time - start_time)) / 3600
            WHEN request_type = 'leave_early' THEN 2
            WHEN request_type = 'arrive_late' THEN 2
            ELSE 0
          END
        ), 0)::numeric as total_hours
        FROM schedule_requests
        WHERE team_id = $1 AND status = 'approved'
          AND request_type IN ('pto_full_day', 'pto_partial', 'leave_early', 'arrive_late')
          AND request_date = $2`,
        [teamId, request_date]
      )
      const existingHours = parseFloat((existingResult.rows[0] as any).total_hours) || 0

      let requestedHours = 0
      if (request_type === 'pto_full_day') requestedHours = 8
      else if (request_type === 'leave_early') requestedHours = 2
      else if (request_type === 'arrive_late') requestedHours = 2
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

    // Rule 6: Date is not blocked (PTO / leave-early only).
    // If the employee has a team, check that team's blocked dates.
    // If the employee has no team (orphaned super-admin-created records), match ANY
    // team's blocked dates — safer default than silently letting the request through.
    let blockedReason: string | null = null
    if (['pto_full_day', 'pto_partial', 'leave_early', 'arrive_late', 'leave_on_time'].includes(request_type)) {
      const blockedResult = await client.query(
        `SELECT reason FROM team_blocked_dates
         WHERE blocked_date = $2
           AND ($1::uuid IS NULL OR team_id = $1::uuid)
         LIMIT 1`,
        [teamId, request_date]
      )
      const isBlocked = blockedResult.rows.length > 0
      ruleResults['date_not_blocked'] = !isBlocked
      if (isBlocked) {
        blockedReason = (blockedResult.rows[0] as any).reason || null
      }
    }

    // Determine status
    const allPassed = Object.values(ruleResults).every(v => v === true)
    const status = allPassed ? 'approved' : 'rejected'

    // Build rejection reason from failed rules
    let rejectionReason: string | null = null
    if (!allPassed) {
      const failed = Object.entries(ruleResults).filter(([, v]) => !v).map(([k]) => k)
      const labels: Record<string, string> = {
        'advance_notice': `Requests must be made at least ${minBusinessDaysNotice} business day(s) in advance`,
        'max_shift_change_per_week': 'Max shift changes for this employee this week reached',
        'max_leave_on_time_per_week': 'Max leave-on-time requests for this employee this week reached',
        'max_pto_hours_per_day': 'Team PTO hours limit for the day exceeded',
        'max_shift_swaps_per_day': 'Max shift swaps for the day exceeded',
        'date_not_blocked': blockedReason
          ? `Requests not allowed on this date: ${blockedReason}`
          : 'Requests not allowed on this date',
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
