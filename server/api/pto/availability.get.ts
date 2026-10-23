import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'
import { countBusinessDaysBetween, fmtDate, ptoCapForDate } from '../../utils/ptoHours'
import { getUsedHoursByDate } from '../../utils/ptoUsage'
import { assertRequestDate } from '../../utils/requestRules'
import { assertEmployeeOnTeam } from '../../utils/teamOwnership'
import { teamToday, dateOnly } from '../../utils/teamTime'
import { openWeekendDays, isWorkingDay } from '../../../utils/requestRuleSettings'

/** Longest range one call may ask for. The strip asks for a week, the schedule page a month. */
const MAX_RANGE_DAYS = 93

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
  // Each day in the range walks the business days from today, so an unbounded range
  // (…&date_to=9999-12-31) used to freeze the whole server for every site.
  assertRequestDate(dateFrom)
  assertRequestDate(dateTo)
  if ((Date.parse(`${dateTo}T00:00:00Z`) - Date.parse(`${dateFrom}T00:00:00Z`)) / 86_400_000 >= MAX_RANGE_DAYS) {
    throw createError({ statusCode: 400, message: `Ask for at most ${MAX_RANGE_DAYS} days at a time` })
  }

  // Always the caller's own team's budget. A named employee must be on that team:
  // this used to switch to the employee's team — any team, given an id — and, for an
  // employee with no team, fall back to every team's settings and usage combined.
  const teamId = getTeamFilter(user)
  if (params.employee_id) await assertEmployeeOnTeam(params.employee_id, teamId)

  const [settingsResult, blockedResult] = await Promise.all([
    query<{ setting_key: string; setting_value: string }>(
      'SELECT setting_key, setting_value FROM team_settings WHERE team_id = $1',
      [teamId]
    ),
    query<{ blocked_date: string; reason: string | null }>(
      `SELECT blocked_date::text AS blocked_date, reason
       FROM team_blocked_dates
       WHERE blocked_date BETWEEN $1 AND $2 AND team_id = $3`,
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

  // Today at the team's site: the server's own clock is UTC and marked today as
  // "past" every evening in the US.
  const today = await teamToday({ query }, teamId)
  const now = dateOnly(today)

  // Weekend days the site works (open_weekend_days; none by default). The strip shows
  // only working days, and the request form skips the others in a multi-day request.
  const openWeekend = openWeekendDays(settings['open_weekend_days'])

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
    const open = isWorkingDay(date, openWeekend)
    let ineligibleReason: string | null = null
    if (!open) ineligibleReason = 'Not a working day'
    else if (isBlocked) ineligibleReason = blockedByDate[date] ? `Blocked: ${blockedByDate[date]}` : 'Blocked — no requests allowed'
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
      open,
      eligible: open && !isBlocked && !isPast && hasNotice,
      ineligibleReason,
    })

    cursor.setDate(cursor.getDate() + 1)
  }

  return { days, minBusinessDaysNotice: minNotice, openWeekendDays: openWeekend }
})
