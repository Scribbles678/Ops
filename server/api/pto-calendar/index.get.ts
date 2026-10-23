import { query } from '../../utils/db'
import { requireTeamLead, getTeamFilter } from '../../utils/authorize'
import { getUsedHoursBreakdownByDate } from '../../utils/ptoUsage'
import { leaveDayRows } from '../../utils/leave'
import { isCalendarDate } from '../../../utils/localDate'

const MAX_RANGE_DAYS = 100

/**
 * Aggregated PTO calendar view.
 * Returns approved PTO days + approved/pending schedule requests for a date range,
 * the working days of any leave of absence in it (leave_days), plus the per-day hours
 * those absences cost, itemised by source.
 *
 * The hours come from getUsedHoursBreakdownByDate, which is the same accounting the
 * auto-approval rule measures against the daily cap. The calendar must never total
 * hours itself: this area has twice been broken by a second implementation drifting
 * from the first.
 *
 * Query params: date_from, date_to (required, YYYY-MM-DD, at most 100 days)
 */
export default defineEventHandler(async (event) => {
  const user = requireTeamLead(event)
  const teamId = getTeamFilter(user)
  const params = getQuery(event)

  const { date_from, date_to } = params
  if (!isCalendarDate(date_from) || !isCalendarDate(date_to)) {
    throw createError({ statusCode: 400, message: 'date_from and date_to are required (YYYY-MM-DD)' })
  }
  // A leave with no end date runs to date_to, a row per day: an open range
  // (…&date_to=9999-12-31) would build millions. A month view is 42 days.
  const span = (Date.parse(`${date_to}T00:00:00Z`) - Date.parse(`${date_from}T00:00:00Z`)) / 86_400_000
  if (span < 0 || span >= MAX_RANGE_DAYS) {
    throw createError({ statusCode: 400, message: `Ask for 1 to ${MAX_RANGE_DAYS} days at a time` })
  }

  const conditions: string[] = []
  const values: unknown[] = [date_from, date_to]
  let idx = 2

  if (teamId) {
    idx++
    conditions.push(`team_id = $${idx}`)
    values.push(teamId)
  }

  const teamWhere = conditions.length > 0 ? ' AND ' + conditions.join(' AND ') : ''

  // Fetch approved PTO days
  const ptoResult = await query(
    `SELECT p.*, e.last_name || ', ' || e.first_name as employee_name
     FROM pto_days p
     LEFT JOIN employees e ON e.id = p.employee_id
     WHERE p.pto_date BETWEEN $1 AND $2 ${teamWhere.replace(/team_id/g, 'p.team_id')}
     ORDER BY p.pto_date, e.last_name, e.first_name`,
    values
  )

  // Fetch schedule requests (approved + pending)
  const requestResult = await query(
    `SELECT sr.*, e.last_name || ', ' || e.first_name as employee_name
     FROM schedule_requests sr
     LEFT JOIN employees e ON e.id = sr.employee_id
     WHERE sr.request_date BETWEEN $1 AND $2
       AND sr.status IN ('approved', 'pending')
       ${teamWhere.replace(/team_id/g, 'sr.team_id')}
     ORDER BY sr.request_date, e.last_name, e.first_name`,
    values
  )

  const hoursByDate = await getUsedHoursBreakdownByDate(
    { query },
    teamId,
    String(date_from),
    String(date_to)
  )

  // Each working day of a leave of absence, named like the rows above. No note: the
  // calendar shows that someone is on leave, never why.
  const leaveDays = await leaveDayRows({ query }, teamId, String(date_from), String(date_to))
  const names = leaveDays.length
    ? new Map(
        (await query<any>(
          `SELECT id, last_name || ', ' || first_name AS name FROM employees WHERE id = ANY($1::uuid[])`,
          [[...new Set(leaveDays.map((d) => d.employee_id))]]
        )).rows.map((e) => [e.id, e.name])
      )
    : new Map()

  return {
    pto_days: ptoResult.rows,
    leave_days: leaveDays.map((d) => ({ ...d, employee_name: names.get(d.employee_id) ?? null })),
    requests: requestResult.rows,
    hours_by_date: hoursByDate,
  }
})
