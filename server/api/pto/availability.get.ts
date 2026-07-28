import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'
import { countBusinessDaysBetween, fmtDate, ptoCapForDate } from '../../utils/ptoHours'
import { getUsedHoursByDate } from '../../utils/ptoUsage'

/**
 * Per-day PTO availability for a date range — the numbers behind the request modal's
 * "Week Availability" strip.
 *
 * This deliberately reuses the same cap lookup and hours math as the auto-approval
 * rule in /api/schedule-requests (POST), so what the strip shows is what the rule
 * will actually do. Do not reimplement either on the client.
 *
 * Query params:
 *   date_from, date_to  (required, YYYY-MM-DD)
 *   employee_id         (optional) — scopes to that employee's team, which is the
 *                       team the approval rule will measure against
 */
export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const params = getQuery(event)
  const dateFrom = String(params.date_from ?? '')
  const dateTo = String(params.date_to ?? '')

  if (!/^\d{4}-\d{2}-\d{2}$/.test(dateFrom) || !/^\d{4}-\d{2}-\d{2}$/.test(dateTo)) {
    throw createError({ statusCode: 400, message: 'date_from and date_to are required (YYYY-MM-DD)' })
  }
  if (dateTo < dateFrom) {
    throw createError({ statusCode: 400, message: 'date_to must be on or after date_from' })
  }

  // Which team's budget applies. The rule always scopes to the requesting employee's
  // team, so prefer that; otherwise the viewer's own team. A super admin with no team
  // assignment falls through to null (all teams), matching the other read endpoints.
  let teamId: string | null = getTeamFilter(user) ?? user.team_id ?? null
  if (params.employee_id) {
    const emp = await query<{ team_id: string | null }>(
      'SELECT team_id FROM employees WHERE id = $1',
      [params.employee_id]
    )
    if (!emp.rows[0]) {
      throw createError({ statusCode: 404, message: 'Employee not found' })
    }
    teamId = emp.rows[0].team_id
  }

  const [settingsResult, blockedResult] = await Promise.all([
    query<{ setting_key: string; setting_value: string }>(
      teamId
        ? 'SELECT setting_key, setting_value FROM team_settings WHERE team_id = $1'
        : 'SELECT setting_key, setting_value FROM team_settings',
      teamId ? [teamId] : []
    ),
    query<{ blocked_date: string; reason: string | null }>(
      `SELECT blocked_date::text AS blocked_date, reason
       FROM team_blocked_dates
       WHERE blocked_date BETWEEN $1 AND $2
         AND ($3::uuid IS NULL OR team_id = $3::uuid)`,
      [dateFrom, dateTo, teamId]
    ),
  ])

  const settings: Record<string, string> = {}
  for (const row of settingsResult.rows) settings[row.setting_key] = row.setting_value

  const blockedByDate: Record<string, string | null> = {}
  for (const row of blockedResult.rows) blockedByDate[row.blocked_date] = row.reason

  const usedByDate = await getUsedHoursByDate({ query }, teamId, dateFrom, dateTo)

  const minNotice = (() => {
    const v = parseInt(settings['min_business_days_notice'] ?? '', 10)
    return isNaN(v) ? 1 : v
  })()

  const now = new Date()
  const today = fmtDate(now)

  const days: any[] = []
  const [fy, fm, fd] = dateFrom.split('-').map(Number)
  const cursor = new Date(fy, fm - 1, fd)

  while (fmtDate(cursor) <= dateTo) {
    const date = fmtDate(cursor)
    const cap = ptoCapForDate(settings, date)
    const used = usedByDate[date] ?? 0
    const isBlocked = Object.prototype.hasOwnProperty.call(blockedByDate, date)
    const businessDaysNotice = countBusinessDaysBetween(now, cursor)
    const hasNotice = businessDaysNotice >= minNotice
    const isPast = date < today

    // Mirrors the rule engine's pass/fail for a same-day submission, so the strip can
    // grey out days nothing can be booked on instead of advertising free hours.
    let ineligibleReason: string | null = null
    if (isBlocked) ineligibleReason = blockedByDate[date] ? `Blocked: ${blockedByDate[date]}` : 'Blocked — no requests allowed'
    else if (isPast) ineligibleReason = 'Date has passed'
    else if (!hasNotice) ineligibleReason = `Needs ${minNotice} business day(s) notice`

    days.push({
      date,
      cap,
      used: Math.round(used * 100) / 100,
      remaining: Math.round(Math.max(0, cap - used) * 100) / 100,
      isBlocked,
      blockReason: isBlocked ? blockedByDate[date] : null,
      isToday: date === today,
      isPast,
      hasNotice,
      eligible: !isBlocked && !isPast && hasNotice,
      ineligibleReason,
    })

    cursor.setDate(cursor.getDate() + 1)
  }

  return { days, minBusinessDaysNotice: minNotice }
})
