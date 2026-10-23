import { query } from './db'
import { teamToday } from './teamTime'

/**
 * What deleting — or deactivating — an employee, job function or shift would do.
 * Team Setup shows this BEFORE anything happens, with "Deactivate instead" next to
 * "Delete permanently".
 *
 * Delete mirrors the ON DELETE rules in the schema:
 *   CASCADE   → rows ERASED with it           (erases)
 *   SET NULL  → rows kept but unlinked        (changes)
 *   NO ACTION → rows that stop the delete     (blockers)
 * The *_archive tables have no foreign keys, so archived rows survive but point at
 * nothing; the schedule export then prints them with a blank name.
 *
 * Deactivate keeps everything. `deactivate.notes` says what still refers to the item
 * from `from` (the viewer's today) onwards; `deactivate.blockers` are the things
 * PUT refuses to deactivate over (see server/api/shifts/[id].put.ts and
 * server/utils/jobFunctionInput.ts — keep these in step with those guards).
 *
 * When a migration adds a table that references employees, job_functions or
 * shifts, add it here — this is the only place the delete window learns about it.
 */
export interface ImpactLine {
  count: number
  /** Ready to show after the count: "schedule assignments (every date)". */
  label: string
}
export interface DeleteImpact {
  name: string
  erases: ImpactLine[]
  changes: ImpactLine[]
  blockers: ImpactLine[]
  deactivate: { notes: ImpactLine[]; blockers: ImpactLine[] }
}

const count = async (sql: string, params: unknown[]): Promise<number> => {
  const r = await query<{ n: number }>(sql, params)
  return r.rows[0]?.n ?? 0
}

/** [count, singular, plural] → a line, or nothing when the count is 0. */
type Spec = [number, string, string]
const lines = (specs: Spec[]): ImpactLine[] =>
  specs.filter(([n]) => n > 0).map(([n, one, many]) => ({ count: n, label: n === 1 ? one : many }))

/** "Thu Sep 24 · Fri Sep 25" for up to three dates, then "and N more days". */
const dayList = (dates: string[]): string => {
  const fmt = (d: string) => {
    const [y, m, day] = d.split('-').map(Number)
    const dt = new Date(y!, m! - 1, day!)
    const wd = dt.toLocaleDateString('en-US', { weekday: 'short' })
    const md = dt.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
    return `${wd} ${md}`
  }
  const shown = dates.slice(0, 3).map(fmt).join(' · ')
  return dates.length > 3 ? `${shown} and ${dates.length - 3} more days` : shown
}
const upcomingDates = async (sql: string, params: unknown[]): Promise<string[]> =>
  (await query<{ d: string }>(sql, params)).rows.map((r) => r.d)

export async function employeeDeleteImpact(id: string, name: string, from: string): Promise<DeleteImpact> {
  const q = (table: string) => count(`SELECT count(*)::int AS n FROM ${table} WHERE employee_id = $1`, [id])
  const [assignments, pto, requests, swaps, notes, errors, points, training, pins, archived, accounts] = await Promise.all([
    q('schedule_assignments'), q('pto_days'), q('schedule_requests'), q('shift_swaps'),
    q('performance_notes'), q('performance_errors'), q('attendance_points'), q('employee_training'),
    q('preferred_assignments'), q('schedule_assignments_archive'), q('user_profiles'),
  ])
  const [upDates, upPto, pending, upSwaps] = await Promise.all([
    upcomingDates(`SELECT DISTINCT schedule_date::text AS d FROM schedule_assignments WHERE employee_id = $1 AND schedule_date >= $2 ORDER BY 1`, [id, from]),
    count(`SELECT count(*)::int AS n FROM pto_days WHERE employee_id = $1 AND pto_date >= $2`, [id, from]),
    count(`SELECT count(*)::int AS n FROM schedule_requests WHERE employee_id = $1 AND status = 'pending'`, [id]),
    count(`SELECT count(*)::int AS n FROM shift_swaps WHERE employee_id = $1 AND swap_date >= $2`, [id, from]),
  ])
  return {
    name,
    erases: lines([
      [assignments, 'schedule assignment (every date)', 'schedule assignments (every date)'],
      [pto, 'time-off day or call-in', 'time-off days and call-ins'],
      [requests, 'request (time off or shift swap)', 'requests (time off and shift swaps)'],
      [swaps, 'shift swap', 'shift swaps'],
      [notes, 'performance note', 'performance notes'],
      [errors, 'logged error', 'logged errors'],
      [points, 'attendance point entry', 'attendance point entries'],
      [training, 'training record', 'training records'],
      [pins, 'required or preferred assignment', 'required or preferred assignments'],
    ]),
    changes: lines([
      [archived, 'archived assignment stays but will show no name', 'archived assignments stay but will show no name'],
      [accounts, 'sign-in account stays but is unlinked from them', 'sign-in accounts stay but are unlinked from them'],
    ]),
    blockers: [],
    deactivate: {
      notes: [
        ...(upDates.length ? [{ count: upDates.length, label: `upcoming ${upDates.length === 1 ? 'day has' : 'days have'} them scheduled (${dayList(upDates)}) — those stay, but they won't show on the edit grid; reassign them first` }] : []),
        ...lines([
          [upPto, 'upcoming time-off day stays on record', 'upcoming time-off days stay on record'],
          [pending, 'pending request is left waiting', 'pending requests are left waiting'],
          [upSwaps, 'upcoming shift swap stays', 'upcoming shift swaps stay'],
        ]),
      ],
      blockers: [],
    },
  }
}

export async function jobFunctionDeleteImpact(id: string, name: string, teamId: string, from: string): Promise<DeleteImpact> {
  const q = (table: string) => count(`SELECT count(*)::int AS n FROM ${table} WHERE job_function_id = $1`, [id])
  const [assignments, training, hourly, targetHours, daily, pins, pinBlocks, errors, halfPins, archived, dailyArchived] = await Promise.all([
    q('schedule_assignments'), q('employee_training'), q('staffing_targets'), q('target_hours'),
    q('daily_targets'), q('preferred_assignments'), q('preferred_assignment_blocks'), q('performance_errors'),
    count('SELECT count(*)::int AS n FROM preferred_assignments WHERE (am_job_function_id = $1 OR pm_job_function_id = $1) AND job_function_id <> $1', [id]),
    q('schedule_assignments_archive'), q('daily_targets_archive'),
  ])
  const upDates = await upcomingDates(
    `SELECT DISTINCT schedule_date::text AS d FROM schedule_assignments WHERE job_function_id = $1 AND schedule_date >= $2 ORDER BY 1`,
    [id, from]
  )
  // Numbered children ("Meter 1") take their targets and training from this parent.
  const esc = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  const childName = new RegExp(`^${esc} \\d+$`)
  const activeChildren = (await query<{ name: string }>(
    'SELECT name FROM job_functions WHERE team_id = $1 AND is_active', [teamId]
  )).rows.filter((r) => childName.test(r.name)).length
  return {
    name,
    erases: lines([
      [assignments, 'schedule assignment (every date)', 'schedule assignments (every date)'],
      [training, 'training record', 'training records'],
      [hourly, 'hourly staffing target', 'hourly staffing targets'],
      [targetHours, 'target-hours setting', 'target-hours settings'],
      [daily, 'daily unit target', 'daily unit targets'],
      [pins, 'required or preferred assignment (with its time blocks)', 'required or preferred assignments (with their time blocks)'],
      [pinBlocks, 'time block inside another required assignment', 'time blocks inside other required assignments'],
    ]),
    changes: lines([
      [errors, 'logged error stays but loses its job', 'logged errors stay but lose their job'],
      [halfPins, 'morning/afternoon pin loses this job', 'morning/afternoon pins lose this job'],
      [archived + dailyArchived, 'archived row stays but will show no job', 'archived rows stay but will show no job'],
    ]),
    blockers: [],
    deactivate: {
      notes: upDates.length
        ? [{ count: upDates.length, label: `upcoming ${upDates.length === 1 ? 'day uses' : 'days use'} this job (${dayList(upDates)}) — those assignments stay, but the builder won't add new ones` }]
        : [],
      blockers: lines([[activeChildren, `numbered ${name} job is still active and takes its targets and training from ${name}`, `numbered ${name} jobs are still active and take their targets and training from ${name}`]]),
    },
  }
}

export async function shiftDeleteImpact(id: string, name: string, teamId: string, from: string): Promise<DeleteImpact> {
  const siteToday = await teamToday({ query }, teamId)
  const [assignments, swaps, people, activePeople, archived, requests, upSwaps] = await Promise.all([
    count('SELECT count(*)::int AS n FROM schedule_assignments WHERE shift_id = $1', [id]),
    count('SELECT count(*)::int AS n FROM shift_swaps WHERE original_shift_id = $1 OR swapped_shift_id = $1', [id]),
    count('SELECT count(*)::int AS n FROM employees WHERE shift_id = $1', [id]),
    count('SELECT count(*)::int AS n FROM employees WHERE shift_id = $1 AND is_active AND team_id = $2', [id, teamId]),
    count('SELECT count(*)::int AS n FROM schedule_assignments_archive WHERE shift_id = $1', [id]),
    count('SELECT count(*)::int AS n FROM schedule_requests WHERE original_shift_id = $1 OR requested_shift_id = $1', [id]),
    // At least the PUT guard's window (the site's today onwards), whatever the browser's clock says.
    count(`SELECT count(*)::int AS n FROM shift_swaps WHERE (original_shift_id = $1 OR swapped_shift_id = $1) AND swap_date >= LEAST($2::date, $3::date)`, [id, from, siteToday]),
  ])
  return {
    name,
    erases: lines([
      [assignments, 'schedule assignment (every date)', 'schedule assignments (every date)'],
      [swaps, 'shift swap', 'shift swaps'],
    ]),
    changes: lines([
      [people, 'person on this shift would be left with no shift (the builder skips them)', 'people on this shift would be left with no shift (the builder skips them)'],
      [archived, 'archived assignment stays but will show no shift', 'archived assignments stay but will show no shift'],
    ]),
    blockers: lines([
      [requests, 'shift-swap request (including past ones) names this shift', 'shift-swap requests (including past ones) name this shift'],
    ]),
    deactivate: {
      notes: [],
      blockers: lines([
        [activePeople, 'active person has this as their shift — move them to another shift first', 'active people have this as their shift — move them to another shift first'],
        [upSwaps, 'upcoming shift swap uses this shift', 'upcoming shift swaps use this shift'],
      ]),
    },
  }
}
