import {
  HOUR_CONSUMING_TYPES,
  hoursForPtoDay,
  hoursForRequest,
  type ShiftInfo,
} from './ptoHours'

/**
 * Team-wide PTO hours already committed, per date.
 *
 * Counts two things, which together are "who is already off":
 *   1. approved schedule_requests of an hour-consuming type
 *   2. pto_days rows NOT materialized by a request — manual entries and call-ins
 *
 * (2) is deduped against (1) via schedule_requests.created_pto_id so an approved
 * request and the pto_days row it created are never both charged.
 *
 * Each row is priced against the employee's effective shift for that date, honouring
 * a shift_swap if one exists.
 */

/** Anything with .query — the pool helper or an in-transaction client. */
interface Queryable {
  query(sql: string, params?: unknown[]): Promise<{ rows: any[] }>
}

interface PricedRow {
  date: string
  shift: ShiftInfo
}

const shiftFrom = (r: any): ShiftInfo => ({
  start_time: r.shift_start,
  end_time: r.shift_end,
  lunch_start: r.lunch_start,
  lunch_end: r.lunch_end,
})

// Effective shift for the employee on the row's date: the swapped shift if one is
// on file for that date, otherwise their default shift.
const SHIFT_JOIN = `
  JOIN employees e ON e.id = src.employee_id
  LEFT JOIN shift_swaps sw ON sw.employee_id = src.employee_id AND sw.swap_date = src.the_date
  LEFT JOIN shifts sh ON sh.id = COALESCE(sw.swapped_shift_id, e.shift_id)
`

const SHIFT_COLS = `
  sh.start_time::text  AS shift_start,
  sh.end_time::text    AS shift_end,
  sh.lunch_start::text AS lunch_start,
  sh.lunch_end::text   AS lunch_end
`

/**
 * Returns a map of YYYY-MM-DD -> hours already used, for every date in the inclusive
 * range that has any usage. Dates with no absences are simply absent from the map.
 *
 * `teamId` null means no team filter (super admin viewing every team) — note the
 * approval rule itself is always single-team, so callers that need the two to agree
 * should pass a concrete team.
 */
export async function getUsedHoursByDate(
  db: Queryable,
  teamId: string | null,
  dateFrom: string,
  dateTo: string
): Promise<Record<string, number>> {
  const breakdown = await getUsedHoursBreakdownByDate(db, teamId, dateFrom, dateTo)
  const used: Record<string, number> = {}
  for (const [date, b] of Object.entries(breakdown)) used[date] = b.total
  return used
}

/** How a date's committed hours split by where they came from. */
export interface UsedHoursBreakdown {
  /** Approved schedule_requests - time off that went through the request workflow. */
  approved: number
  /** Unplanned call-ins: pto_days with pto_type 'call_in' and no originating request. */
  callIn: number
  /** Any other pto_days entered by hand, with no originating request. */
  manual: number
  /** approved + callIn + manual. */
  total: number
}

/**
 * The same accounting as getUsedHoursByDate, itemised by source.
 *
 * getUsedHoursByDate is a thin wrapper over this, so the total a supervisor reads
 * on the calendar is by construction the same number the approval rule measures
 * against the cap - they cannot drift apart, which is the failure this whole area
 * has already suffered twice.
 *
 * The `manual` bucket exists because "approved + call-ins" does NOT add up: an
 * admin can enter a pto_days row directly, and rows with no pto_type at all exist
 * in real data. Dropping them would quietly understate the day.
 */
export async function getUsedHoursBreakdownByDate(
  db: Queryable,
  teamId: string | null,
  dateFrom: string,
  dateTo: string
): Promise<Record<string, UsedHoursBreakdown>> {
  const used: Record<string, UsedHoursBreakdown> = {}
  const round2 = (n: number) => Math.round(n * 100) / 100
  const bucket = (date: string): UsedHoursBreakdown =>
    (used[date] ??= { approved: 0, callIn: 0, manual: 0, total: 0 })
  const add = (date: string, hours: number, kind: 'approved' | 'callIn' | 'manual' = 'approved') => {
    if (!hours) return
    const b = bucket(date)
    b[kind] = round2(b[kind] + hours)
    b.total = round2(b.approved + b.callIn + b.manual)
  }

  // ---- 1. Approved schedule_requests -------------------------------------------
  const reqParams: unknown[] = [dateFrom, dateTo]
  let reqTeamClause = ''
  if (teamId) {
    reqParams.push(teamId)
    reqTeamClause = `AND src.team_id = $${reqParams.length}`
  }

  const requests = await db.query(
    `SELECT src.the_date::text AS date, src.request_type,
            src.start_time::text AS start_time,
            src.end_time::text   AS end_time,
            ${SHIFT_COLS}
     FROM (
       SELECT id, employee_id, team_id, request_type, start_time, end_time,
              request_date AS the_date
       FROM schedule_requests
       WHERE status = 'approved'
         AND request_type = ANY($${reqParams.length + 1}::text[])
         AND request_date BETWEEN $1 AND $2
     ) src
     ${SHIFT_JOIN}
     WHERE TRUE ${reqTeamClause}`,
    [...reqParams, HOUR_CONSUMING_TYPES]
  )

  for (const r of requests.rows) {
    add(r.date, hoursForRequest(r.request_type, r.start_time, r.end_time, shiftFrom(r)))
  }

  // ---- 2. pto_days with no originating request ---------------------------------
  const ptoParams: unknown[] = [dateFrom, dateTo]
  let ptoTeamClause = ''
  if (teamId) {
    ptoParams.push(teamId)
    ptoTeamClause = `AND src.team_id = $${ptoParams.length}`
  }

  const ptoDays = await db.query(
    `SELECT src.the_date::text AS date, src.pto_type,
            src.start_time::text AS start_time,
            src.end_time::text   AS end_time,
            ${SHIFT_COLS}
     FROM (
       SELECT p.id, p.employee_id, p.team_id, p.pto_type, p.start_time, p.end_time,
              p.pto_date AS the_date
       FROM pto_days p
       WHERE p.pto_date BETWEEN $1 AND $2
         AND NOT EXISTS (
           SELECT 1 FROM schedule_requests sr WHERE sr.created_pto_id = p.id
         )
     ) src
     ${SHIFT_JOIN}
     WHERE TRUE ${ptoTeamClause}`,
    ptoParams
  )

  for (const r of ptoDays.rows) {
    add(
      r.date,
      hoursForPtoDay(r.pto_type, r.start_time, r.end_time, shiftFrom(r)),
      r.pto_type === 'call_in' ? 'callIn' : 'manual'
    )
  }

  return used
}

/** Convenience wrapper for the single-date case used by the approval rule. */
export async function getUsedHoursForDate(
  db: Queryable,
  teamId: string | null,
  date: string
): Promise<number> {
  const map = await getUsedHoursByDate(db, teamId, date, date)
  return map[date] ?? 0
}

export interface PricedAbsence {
  date: string
  /** Normalized bucket: full_day | partial | leave_early | arrive_late | call_in */
  kind: string
  hours: number
  source: 'request' | 'pto_day'
  startTime: string | null
  endTime: string | null
  notes: string | null
}

const REQUEST_KIND: Record<string, string> = {
  pto_full_day: 'full_day',
  pto_partial: 'partial',
  leave_early: 'leave_early',
  arrive_late: 'arrive_late',
}

/**
 * One employee's absences over a range, each priced in paid hours by the same
 * helpers the approval rule uses. Approved requests plus any pto_days with no
 * originating request (manual entries and call-ins), deduped via created_pto_id.
 */
export async function getEmployeeAbsences(
  db: Queryable,
  employeeId: string,
  dateFrom: string,
  dateTo: string
): Promise<PricedAbsence[]> {
  const out: PricedAbsence[] = []

  const requests = await db.query(
    `SELECT src.the_date::text AS date, src.request_type,
            src.start_time::text AS start_time,
            src.end_time::text   AS end_time,
            src.notes,
            ${SHIFT_COLS}
     FROM (
       SELECT id, employee_id, request_type, start_time, end_time, notes,
              request_date AS the_date
       FROM schedule_requests
       WHERE employee_id = $3 AND status = 'approved'
         AND request_type = ANY($4::text[])
         AND request_date BETWEEN $1 AND $2
     ) src
     ${SHIFT_JOIN}`,
    [dateFrom, dateTo, employeeId, HOUR_CONSUMING_TYPES]
  )
  for (const r of requests.rows) {
    out.push({
      date: r.date,
      kind: REQUEST_KIND[r.request_type] ?? r.request_type,
      hours: hoursForRequest(r.request_type, r.start_time, r.end_time, shiftFrom(r)),
      source: 'request',
      startTime: r.start_time,
      endTime: r.end_time,
      notes: r.notes,
    })
  }

  const ptoDays = await db.query(
    `SELECT src.the_date::text AS date, src.pto_type,
            src.start_time::text AS start_time,
            src.end_time::text   AS end_time,
            src.notes,
            ${SHIFT_COLS}
     FROM (
       SELECT p.id, p.employee_id, p.pto_type, p.start_time, p.end_time, p.notes,
              p.pto_date AS the_date
       FROM pto_days p
       WHERE p.employee_id = $3 AND p.pto_date BETWEEN $1 AND $2
         AND NOT EXISTS (
           SELECT 1 FROM schedule_requests sr WHERE sr.created_pto_id = p.id
         )
     ) src
     ${SHIFT_JOIN}`,
    [dateFrom, dateTo, employeeId]
  )
  for (const r of ptoDays.rows) {
    out.push({
      date: r.date,
      kind: r.pto_type || 'full_day',
      hours: hoursForPtoDay(r.pto_type, r.start_time, r.end_time, shiftFrom(r)),
      source: 'pto_day',
      startTime: r.start_time,
      endTime: r.end_time,
      notes: r.notes,
    })
  }

  return out.sort((a, b) => (a.date < b.date ? 1 : a.date > b.date ? -1 : 0))
}

/** The effective shift for one employee on one date (swap-aware). */
export async function getEffectiveShift(
  db: Queryable,
  employeeId: string,
  date: string
): Promise<ShiftInfo | null> {
  const r = await db.query(
    `SELECT ${SHIFT_COLS}
     FROM (SELECT $1::uuid AS employee_id, $2::date AS the_date) src
     ${SHIFT_JOIN}`,
    [employeeId, date]
  )
  const row = r.rows[0]
  if (!row || !row.shift_start) return null
  return shiftFrom(row)
}
