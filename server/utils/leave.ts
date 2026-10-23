import { teamToday } from './teamTime'
import { isCalendarDate } from '../../utils/localDate'
import { openWeekendDays, isWorkingDay } from '../../utils/requestRuleSettings'
import { leaveDay, leaveSpan } from '../../utils/leaveDisplay'

/**
 * Leave of absence (migration 028): someone away for a stretch, as a date range.
 *
 * Leaves are NOT pto_days rows. Every read of "who is off on this date" adds them in
 * as one all-day row per working day (`leaveDayRows`, pto_type 'leave', read by
 * utils/ptoDisplay.ts like any day off), so the schedule builder, the schedule page,
 * the display board and copy schedule all leave the person off without knowing about
 * leaves. The rest:
 *   - time off and requests on a leave day are refused (server/utils/timeOff.ts);
 *   - saving a leave cancels time off already booked inside it, from today on
 *     (cancelTimeOffForLeave, same file);
 *   - leave days count toward the daily time-off limit only if the team says so
 *     (count_leave_in_pto_limit, server/utils/ptoUsage.ts).
 * Supervisors and up set leaves (server/api/leaves/*); Team Leads see them.
 */

interface Queryable {
  query(sql: string, params?: unknown[]): Promise<{ rows: any[] }>
}

export interface Leave {
  id: string
  team_id: string
  employee_id: string
  /** YYYY-MM-DD, the first day off. */
  start_date: string
  /** YYYY-MM-DD, the last day off; null while the return date isn't known. */
  end_date: string | null
  notes: string | null
  created_by: string | null
  created_at: string
  updated_at: string
}

/** Dates as text, so a leave never moves a day passing through a JS Date. */
export const LEAVE_COLUMNS = `id, team_id, employee_id, start_date::text AS start_date, end_date::text AS end_date,
  notes, created_by, created_at, updated_at`

/** A uuid, checked before it reaches a query (Postgres answers anything else with a 500). */
export const isUuid = (v: unknown): v is string =>
  typeof v === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v)

/** Longest note; the column refuses more (migration 028). */
export const MAX_LEAVE_NOTES = 500
/** How far from today a leave date may be set, either way — about two years, like requests. */
const MAX_DAYS_FROM_TODAY = 730

// "Nov 2 – Dec 15": the same words the screens use (utils/leaveDisplay.ts).
export { leaveSpan }

/** The person's leave covering `date`, if any. */
export async function leaveOnDay(db: Queryable, teamId: string, employeeId: string, date: string): Promise<Leave | null> {
  const r = await db.query(
    `SELECT ${LEAVE_COLUMNS} FROM employee_leaves
     WHERE team_id = $1 AND employee_id = $2 AND start_date <= $3::date AND (end_date IS NULL OR end_date >= $3::date)
     ORDER BY start_date LIMIT 1`,
    [teamId, employeeId, date]
  )
  return r.rows[0] ?? null
}

/** Another leave of the same person that shares a day with start..end (end null = open-ended). */
export async function findOverlappingLeave(
  db: Queryable,
  opts: { teamId: string; employeeId: string; start: string; end: string | null; ignoreId?: string | null }
): Promise<Leave | null> {
  const r = await db.query(
    `SELECT ${LEAVE_COLUMNS} FROM employee_leaves
     WHERE team_id = $1 AND employee_id = $2 AND ($5::uuid IS NULL OR id <> $5::uuid)
       AND start_date <= COALESCE($4::date, 'infinity'::date)
       AND (end_date IS NULL OR end_date >= $3::date)
     ORDER BY start_date LIMIT 1`,
    [opts.teamId, opts.employeeId, opts.start, opts.end, opts.ignoreId ?? null]
  )
  return r.rows[0] ?? null
}

/**
 * Every working day of every leave between `from` and `to` (inclusive), as rows shaped
 * like pto_days: pto_type 'leave', no times — off all day. Active people only: someone
 * deactivated is off every screen already, and an open-ended leave would otherwise sit
 * on the PTO calendar every day. No notes: these rows go to
 * the kiosk and the display board with the rest of the day's time off. `id` is
 * "leave:<leave id>:<date>", never a pto_days id, so nothing can edit one as time off.
 */
export async function leaveDayRows(db: Queryable, teamId: string, from: string, to: string): Promise<any[]> {
  const [days, weekend] = await Promise.all([
    db.query(
      `SELECT l.id AS leave_id, l.employee_id, l.team_id, d::date::text AS pto_date,
              l.start_date::text AS leave_start, l.end_date::text AS leave_end
       FROM employee_leaves l
       JOIN employees e ON e.id = l.employee_id AND e.is_active
       CROSS JOIN LATERAL generate_series(
         GREATEST(l.start_date, $2::date), LEAST(COALESCE(l.end_date, $3::date), $3::date), interval '1 day'
       ) AS d
       WHERE l.team_id = $1 AND l.start_date <= $3::date AND (l.end_date IS NULL OR l.end_date >= $2::date)
       ORDER BY 4`,
      [teamId, from, to]
    ),
    db.query(`SELECT setting_value FROM team_settings WHERE team_id = $1 AND setting_key = 'open_weekend_days'`, [teamId]),
  ])
  // A weekend day the site doesn't work isn't a day off from anything.
  const open = openWeekendDays(weekend.rows[0]?.setting_value)
  return days.rows
    .filter((r) => isWorkingDay(r.pto_date, open))
    .map((r) => ({
      id: `leave:${r.leave_id}:${r.pto_date}`,
      leave_id: r.leave_id,
      employee_id: r.employee_id,
      team_id: r.team_id,
      pto_date: r.pto_date,
      pto_type: 'leave',
      start_time: null,
      end_time: null,
      notes: null,
      leave_start: r.leave_start,
      leave_end: r.leave_end,
    }))
}

/** True for an id leaveDayRows made — not a pto_days row. */
export const isLeaveDayId = (id: unknown): boolean => typeof id === 'string' && id.startsWith('leave:')

/** Days (YYYY-MM-DD, from `from` on) the person is on the schedule inside start..end. */
export async function scheduledDaysInLeave(
  db: Queryable,
  opts: { teamId: string; employeeId: string; from: string; end: string | null }
): Promise<string[]> {
  const r = await db.query(
    `SELECT DISTINCT schedule_date::text AS d FROM schedule_assignments
     WHERE team_id = $1 AND employee_id = $2 AND schedule_date >= $3::date
       AND schedule_date <= COALESCE($4::date, 'infinity'::date)
     ORDER BY 1`,
    [opts.teamId, opts.employeeId, opts.from, opts.end]
  )
  return r.rows.map((x) => x.d)
}

export interface LeaveInput {
  start_date: string
  end_date: string | null
  notes: string | null
}

/**
 * A leave's fields from a request body, checked: real dates, the last day on or after
 * the first, both within two years of the site's today, a note of at most 500 characters.
 * `current` fills in what an edit leaves out; only the dates it sends are range-checked,
 * so a long-running leave stays editable. Throws a 400 with a sentence on anything wrong.
 */
export async function readLeaveInput(
  db: Queryable,
  teamId: string,
  body: any,
  current?: LeaveInput
): Promise<LeaveInput> {
  const has = (k: string) => body != null && Object.prototype.hasOwnProperty.call(body, k)
  const bad = (message: string) => createError({ statusCode: 400, message })

  const start = has('start_date') ? body.start_date : current?.start_date
  const rawEnd = has('end_date') ? body.end_date : current?.end_date
  const end = rawEnd == null || rawEnd === '' ? null : rawEnd
  const rawNotes = has('notes') ? body.notes : current?.notes
  const notes = rawNotes == null ? null : String(rawNotes).trim() || null

  if (!isCalendarDate(start)) throw bad('Enter the first day of the leave.')
  if (end !== null && !isCalendarDate(end)) throw bad('Enter the last day of the leave, or tick "Return date not known yet".')
  if (end !== null && end < start) throw bad('The last day of the leave is before the first day.')
  if (notes && notes.length > MAX_LEAVE_NOTES) throw bad(`The note can be at most ${MAX_LEAVE_NOTES} characters.`)

  const today = Date.parse(`${await teamToday(db, teamId)}T00:00:00Z`)
  const tooFar = (d: string) => Math.abs(Date.parse(`${d}T00:00:00Z`) - today) / 86_400_000 > MAX_DAYS_FROM_TODAY
  if ((has('start_date') || !current) && tooFar(start)) throw bad(`${leaveDay(start, true)} is more than two years from today.`)
  if ((has('end_date') || !current) && end !== null && tooFar(end)) throw bad(`${leaveDay(end, true)} is more than two years from today.`)

  return { start_date: start, end_date: end, notes }
}

/** "; cancelled the time off booked inside it (Fri, Nov 20 — Full Day …)" for a change-log sentence, or ''. */
export const cancelledNote = (cancelled: string[]): string =>
  cancelled.length
    ? `; cancelled the time off booked inside it (${cancelled.slice(0, 3).join('; ')}${cancelled.length > 3 ? ` and ${cancelled.length - 3} more` : ''})`
    : ''

/** Why `other` stops a leave from being saved over it. */
export const overlapMessage = (who: string, other: Pick<Leave, 'start_date' | 'end_date'>): string =>
  `${who} already has a leave of absence ${leaveSpan(other)} that shares days with this one. Change that leave instead.`
