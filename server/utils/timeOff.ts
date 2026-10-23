import type { AuthUser } from './authorize'
import { HOUR_CONSUMING_TYPES } from './ptoHours'
import { logChange, employeeDisplayName, describeRequest, describePtoDay } from './auditLog'
import { teamTimeZone } from './teamTime'
import { describePto, ptoTypeLabel, ptoTimeLabel } from '../../utils/ptoDisplay'

/**
 * One person, one absence at a time (Oct 2026).
 *
 * Nothing used to ask "is this person already off then?". The approval rules only
 * checked the team's daily hours budget, so the same day off could be approved
 * twice (the form's "Submit another", the kiosk and a supervisor at once, a range
 * over a day already booked) and every copy was charged to the budget — one test
 * day read 52h used where people were really off for 33.5h, and that phantom time
 * got other people's requests refused. Every path that records time off checks
 * here: the request submit and its dry run (via requestRules.ts), a supervisor's
 * approval, and PTO entered on the schedule page.
 *
 * "Already off" is what the hours budget charges (server/utils/ptoUsage.ts):
 * approved requests, plus pto_days rows no request created. Two absences conflict
 * when their time windows overlap (utils/ptoDisplay.ts describePto), so an
 * arrive-late plus a leave-early on one day, or two separate partials, still pass.
 */

interface Queryable {
  query(sql: string, params?: unknown[]): Promise<{ rows: any[] }>
}

/** A pto_days row's type and times, in the storage convention of utils/ptoDisplay.ts. */
export interface PtoShape {
  pto_type: string
  start_time: string | null
  end_time: string | null
}

/**
 * The pto_days.pto_type each hour-consuming request type becomes. The submit and
 * the supervisor override are two paths to the same row and once disagreed (the
 * override wrote `pto_partial` where the submit wrote `partial`).
 */
export const PTO_TYPE_FOR_REQUEST: Record<string, string> = {
  pto_full_day: 'full_day',
  pto_partial: 'partial',
  leave_early: 'leave_early',
  arrive_late: 'arrive_late',
}

/** The pto_days row an approved request materialises; null for a type that makes none. */
export function ptoShapeForRequest(
  requestType: string,
  startTime: string | null | undefined,
  endTime: string | null | undefined
): PtoShape | null {
  switch (requestType) {
    case 'pto_full_day':
      return { pto_type: 'full_day', start_time: null, end_time: null }
    case 'pto_partial':
      return { pto_type: 'partial', start_time: startTime || null, end_time: endTime || null }
    case 'leave_early':
      return { pto_type: 'leave_early', start_time: startTime || null, end_time: null }
    case 'arrive_late':
      // The request keeps the arrival in start_time; the row keeps it in end_time.
      return { pto_type: 'arrive_late', start_time: '00:00:00', end_time: startTime || null }
    default:
      return null
  }
}

/**
 * The reverse, for a request-created row edited on the schedule page: the budget
 * prices the approved REQUEST, so it has to keep saying what the row says.
 */
export function requestShapeForPto(
  shape: PtoShape
): { request_type: string; start_time: string | null; end_time: string | null } | null {
  switch (shape.pto_type) {
    case 'full_day':
      return { request_type: 'pto_full_day', start_time: null, end_time: null }
    case 'partial':
      return { request_type: 'pto_partial', start_time: shape.start_time, end_time: shape.end_time }
    case 'leave_early':
      return { request_type: 'leave_early', start_time: shape.start_time, end_time: null }
    case 'arrive_late':
      return { request_type: 'arrive_late', start_time: shape.end_time, end_time: null }
    default:
      return null
  }
}

/** Advisory-lock class for time-off writes (bootstrap's single-key lock is a separate space). */
const TIME_OFF_LOCK_CLASS = 7301

/**
 * Serialise time-off writes for one team until the transaction ends. Without it,
 * two submits in the same instant both pass the check below (and both fit under
 * the daily cap) before either is saved.
 */
export async function lockTeamTimeOff(db: Queryable, teamId: string): Promise<void> {
  await db.query('SELECT pg_advisory_xact_lock($1::int, hashtext($2::text))', [TIME_OFF_LOCK_CLASS, teamId])
}

export interface TimeOffEntry {
  source: 'request' | 'pto_day'
  /** The approved request, for source 'request'. */
  requestId: string | null
  /** The pto_days row — for a request, its created_pto_id (which may since have gone). */
  ptoId: string | null
  shape: PtoShape
  /** When it was approved or entered. */
  recordedAt: Date
  /** The row as stored, for the change log. */
  row: any
}

/** Everything that already counts as this person being off on `date` (YYYY-MM-DD). */
export async function timeOffOnDay(
  db: Queryable,
  teamId: string,
  employeeId: string,
  date: string
): Promise<TimeOffEntry[]> {
  const entries: TimeOffEntry[] = []

  const requests = await db.query(
    `SELECT * FROM schedule_requests
     WHERE team_id = $1 AND employee_id = $2 AND request_date = $3
       AND status = 'approved' AND request_type = ANY($4::text[])
     ORDER BY created_at`,
    [teamId, employeeId, date, HOUR_CONSUMING_TYPES]
  )
  for (const r of requests.rows) {
    const shape = ptoShapeForRequest(r.request_type, r.start_time, r.end_time)
    if (!shape) continue
    entries.push({
      source: 'request',
      requestId: r.id,
      ptoId: r.created_pto_id ?? null,
      shape,
      recordedAt: r.admin_override ? r.updated_at : r.created_at,
      row: r,
    })
  }

  const ptoDays = await db.query(
    `SELECT p.* FROM pto_days p
     WHERE p.team_id = $1 AND p.employee_id = $2 AND p.pto_date = $3
       AND NOT EXISTS (SELECT 1 FROM schedule_requests sr WHERE sr.created_pto_id = p.id)
     ORDER BY p.created_at`,
    [teamId, employeeId, date]
  )
  for (const p of ptoDays.rows) {
    entries.push({
      source: 'pto_day',
      requestId: null,
      ptoId: p.id,
      shape: { pto_type: p.pto_type, start_time: p.start_time, end_time: p.end_time },
      recordedAt: p.created_at,
      row: p,
    })
  }

  return entries
}

/** "Partial Day, 9:00 AM – 11:00 AM", "Leave Early, leaves 2:00 PM", "Call-In". */
export const timeOffLabel = (shape: PtoShape): string => {
  const time = ptoTimeLabel(shape)
  return `${ptoTypeLabel(shape.pto_type)}${time ? `, ${time}` : ''}`
}

/** "Tue, Nov 10" from a YYYY-MM-DD. */
const dayLabel = (date: string): string => {
  const [y, m, d] = date.split('-').map(Number)
  if (!y || !m || !d) return date
  return new Date(y, m - 1, d).toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' })
}

/**
 * The first absence the person already has on `date` that overlaps `shape`, as a
 * sentence for the person at the screen — or null when there is none.
 * `ignorePtoId` leaves out the row being edited (and the request that created it).
 */
export async function findTimeOffConflict(
  db: Queryable,
  opts: { teamId: string; employeeId: string; date: string; shape: PtoShape; ignorePtoId?: string | null }
): Promise<string | null> {
  const wanted = describePto(opts.shape)
  if (!wanted) return null

  const entries = await timeOffOnDay(db, opts.teamId, opts.employeeId, opts.date)
  const hit = entries.find((e) => {
    if (opts.ignorePtoId && e.ptoId === opts.ignorePtoId) return false
    const w = describePto(e.shape)
    return w != null && w.startMin < wanted.endMin && wanted.startMin < w.endMin
  })
  if (!hit) return null

  const who = await employeeDisplayName(db, opts.employeeId)
  const tz = await teamTimeZone(db, opts.teamId)
  const when = new Date(hit.recordedAt).toLocaleDateString('en-US', { month: 'short', day: 'numeric', timeZone: tz })
  const how = hit.source === 'request' ? `approved ${when}` : `entered ${when}`
  return `${who} already has time off on ${dayLabel(opts.date)}: ${timeOffLabel(hit.shape)} (${how}).`
}

/**
 * The same question for a request about to be decided. Hour-consuming types go
 * through the overlap check; a leave-on-time or a shift change refuses a second
 * one for the same day (a second swap used to overwrite the first in place).
 */
export async function findRequestConflict(
  db: Queryable,
  teamId: string,
  r: { employee_id: string; request_type: string; request_date: string; start_time?: string | null; end_time?: string | null }
): Promise<string | null> {
  const shape = ptoShapeForRequest(r.request_type, r.start_time, r.end_time)
  if (shape) {
    return findTimeOffConflict(db, { teamId, employeeId: r.employee_id, date: r.request_date, shape })
  }

  let exists = false
  let what = ''
  if (r.request_type === 'leave_on_time') {
    const q = await db.query(
      `SELECT 1 FROM schedule_requests
       WHERE team_id = $1 AND employee_id = $2 AND request_date = $3
         AND request_type = 'leave_on_time' AND status = 'approved'
       LIMIT 1`,
      [teamId, r.employee_id, r.request_date]
    )
    exists = q.rows.length > 0
    what = 'an approved Leave on Time'
  } else if (r.request_type === 'shift_swap') {
    const q = await db.query(
      'SELECT 1 FROM shift_swaps WHERE team_id = $1 AND employee_id = $2 AND swap_date = $3 LIMIT 1',
      [teamId, r.employee_id, r.request_date]
    )
    exists = q.rows.length > 0
    what = 'a shift change'
  }
  if (!exists) return null
  const who = await employeeDisplayName(db, r.employee_id)
  return `${who} already has ${what} on ${dayLabel(r.request_date)}.`
}

/**
 * Delete a request with the rows it created, and log it — the Requests table's
 * delete, a call-in replacing it, and removing its day off on the schedule page.
 * `why` ends the change-log sentence; it defaults to the status it had.
 */
export async function deleteRequestWithRecords(
  db: Queryable,
  request: any,
  actor: AuthUser,
  why?: string
): Promise<void> {
  if (request.created_pto_id) {
    await db.query('DELETE FROM pto_days WHERE id = $1', [request.created_pto_id])
  }
  if (request.created_swap_id) {
    await db.query('DELETE FROM shift_swaps WHERE id = $1', [request.created_swap_id])
  }
  await db.query('DELETE FROM schedule_requests WHERE id = $1', [request.id])

  // A deleted request leaves nothing else behind, so this entry (with the full
  // row in `before`) is the only record it ever existed.
  const who = await employeeDisplayName(db, request.employee_id)
  await logChange(db, {
    teamId: request.team_id,
    actor,
    action: 'delete',
    entity: 'request',
    entityId: request.id,
    employeeId: request.employee_id,
    employeeName: who,
    summary: `Deleted ${who}'s ${describeRequest(request)} (${why ?? `was ${request.status}`})`,
    before: request,
  })
}

/**
 * A call-in covers the whole day, so it REPLACES whatever time off the person
 * already had that day (a leave-early, a partial, an earlier call-in) instead of
 * being charged on top of it. Returns what it replaced, for the confirmation.
 */
export async function replaceTimeOffForCallIn(
  db: Queryable,
  opts: { teamId: string; employeeId: string; date: string; actor: AuthUser }
): Promise<string[]> {
  const entries = await timeOffOnDay(db, opts.teamId, opts.employeeId, opts.date)
  const who = await employeeDisplayName(db, opts.employeeId)
  for (const e of entries) {
    if (e.source === 'request') {
      await deleteRequestWithRecords(db, e.row, opts.actor, 'replaced by a call-in')
    } else {
      await db.query('DELETE FROM pto_days WHERE id = $1', [e.ptoId])
      await logChange(db, {
        teamId: opts.teamId,
        actor: opts.actor,
        action: 'delete',
        entity: 'pto_day',
        entityId: e.ptoId,
        employeeId: opts.employeeId,
        employeeName: who,
        summary: `Removed ${describePtoDay(e.row)} for ${who} (replaced by a call-in)`,
        before: e.row,
      })
    }
  }
  return entries.map((e) => timeOffLabel(e.shape))
}
