import {
  HOUR_CONSUMING_TYPES,
  countBusinessDaysBetween,
  fmtDate,
  hoursForRequest,
  ptoCapForDate,
} from './ptoHours'
import { getEffectiveShift, getUsedHoursForDate } from './ptoUsage'

/**
 * The auto-approval rule engine, in one reusable place.
 *
 * Both the real submit (POST /api/schedule-requests) and the dry run
 * (POST /api/schedule-requests/preview) call `evaluateRequest`, so a preview can
 * never promise something the submit then refuses. Do not inline these rules
 * anywhere else.
 *
 * Note a preview is a point-in-time answer: another admin can consume the day's
 * budget between the preview and the submit. The submit re-runs these rules and
 * remains the authority.
 */

export interface RuleResults {
  [key: string]: boolean
}

export interface RuleVerdict {
  status: 'approved' | 'rejected'
  ruleResults: RuleResults
  rejectionReason: string | null
  /** Hours this request would draw from the day's team budget. */
  requestedHours: number
  /** Team-wide cap that applies to this date. */
  cap: number
  /** Hours already committed on this date before this request. */
  usedHours: number
}

export interface RuleInput {
  employee_id: string
  request_type: string
  request_date: string
  start_time?: string | null
  end_time?: string | null
}

interface Queryable {
  query(sql: string, params?: unknown[]): Promise<{ rows: any[] }>
}

const BLOCKABLE_TYPES = ['pto_full_day', 'pto_partial', 'leave_early', 'arrive_late', 'leave_on_time']

/** Load a team's settings as a flat key/value map. */
export async function loadTeamSettings(
  db: Queryable,
  teamId: string | null
): Promise<Record<string, string>> {
  const result = await db.query(
    'SELECT setting_key, setting_value FROM team_settings WHERE team_id = $1',
    [teamId]
  )
  const settings: Record<string, string> = {}
  for (const row of result.rows as { setting_key: string; setting_value: string }[]) {
    settings[row.setting_key] = row.setting_value
  }
  return settings
}

/**
 * Evaluate every auto-approval rule for one request. Read-only — writes nothing.
 */
export async function evaluateRequest(
  db: Queryable,
  teamId: string | null,
  settings: Record<string, string>,
  input: RuleInput,
  now: Date = new Date()
): Promise<RuleVerdict> {
  const { employee_id, request_type, request_date, start_time, end_time } = input

  const getSetting = (key: string, defaultValue: number): number => {
    const val = parseInt(settings[key] ?? '', 10)
    return isNaN(val) ? defaultValue : val
  }

  const ruleResults: RuleResults = {}
  const reqDate = new Date(request_date + 'T00:00:00')

  // Rule 1: advance notice in BUSINESS days (Mon–Fri). Counts full working days
  // strictly between today and the requested date — weekends don't count, so a
  // Friday request for Monday gives 0 business days' notice.
  const minBusinessDaysNotice = getSetting('min_business_days_notice', 1)
  ruleResults['advance_notice'] = countBusinessDaysBetween(now, reqDate) >= minBusinessDaysNotice

  // Mon–Sun week bounds containing the requested date (shared by per-week rules).
  const reqDow = reqDate.getDay() // 0 Sun..6 Sat
  const weekStart = new Date(reqDate)
  weekStart.setDate(reqDate.getDate() + (reqDow === 0 ? -6 : 1 - reqDow)) // Monday
  const weekEnd = new Date(weekStart)
  weekEnd.setDate(weekStart.getDate() + 6) // Sunday

  // Count an employee's approved requests of a type within that week.
  const countEmployeeWeek = async (type: string): Promise<number> => {
    const r = await db.query(
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
  let cap = 0
  let usedHours = 0
  let requestedHours = 0
  if (HOUR_CONSUMING_TYPES.includes(request_type)) {
    cap = ptoCapForDate(settings, request_date)
    usedHours = await getUsedHoursForDate(db, teamId, request_date)
    const shift = await getEffectiveShift(db, employee_id, request_date)
    requestedHours = hoursForRequest(request_type, start_time ?? null, end_time ?? null, shift)
    ruleResults['max_pto_hours_per_day'] = usedHours + requestedHours <= cap
  }

  // Rule 5: Max shift swaps per day (team-wide)
  if (request_type === 'shift_swap') {
    const maxSwapsPerDay = getSetting('max_shift_swaps_per_day', 3)
    const countResult = await db.query(
      `SELECT COUNT(*)::int as cnt FROM schedule_requests
       WHERE team_id = $1 AND request_type = 'shift_swap' AND status = 'approved'
         AND request_date = $2`,
      [teamId, request_date]
    )
    ruleResults['max_shift_swaps_per_day'] = (countResult.rows[0] as any).cnt < maxSwapsPerDay
  }

  // Rule 6: Date is not blocked (PTO / leave-early only).
  // If the employee has a team, check that team's blocked dates. If the employee has
  // no team (orphaned super-admin-created records), match ANY team's blocked dates —
  // safer default than silently letting the request through.
  let blockedReason: string | null = null
  if (BLOCKABLE_TYPES.includes(request_type)) {
    const blockedResult = await db.query(
      `SELECT reason FROM team_blocked_dates
       WHERE blocked_date = $2
         AND ($1::uuid IS NULL OR team_id = $1::uuid)
       LIMIT 1`,
      [teamId, request_date]
    )
    const isBlocked = blockedResult.rows.length > 0
    ruleResults['date_not_blocked'] = !isBlocked
    if (isBlocked) blockedReason = (blockedResult.rows[0] as any).reason || null
  }

  const allPassed = Object.values(ruleResults).every((v) => v === true)
  const status: 'approved' | 'rejected' = allPassed ? 'approved' : 'rejected'

  let rejectionReason: string | null = null
  if (!allPassed) {
    const failed = Object.entries(ruleResults).filter(([, v]) => !v).map(([k]) => k)
    const labels: Record<string, string> = {
      advance_notice: `Requests must be made at least ${minBusinessDaysNotice} business day(s) in advance`,
      max_shift_change_per_week: 'Max shift changes for this employee this week reached',
      max_leave_on_time_per_week: 'Max leave-on-time requests for this employee this week reached',
      max_pto_hours_per_day: `Team PTO hours limit for the day exceeded (${usedHours}h of ${cap}h used, this needs ${requestedHours}h)`,
      max_shift_swaps_per_day: 'Max shift swaps for the day exceeded',
      date_not_blocked: blockedReason
        ? `Requests not allowed on this date: ${blockedReason}`
        : 'Requests not allowed on this date',
    }
    rejectionReason = failed.map((k) => labels[k] || k).join('; ')
  }

  return { status, ruleResults, rejectionReason, requestedHours, cap, usedHours }
}
