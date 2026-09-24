import { query } from './db'

/**
 * What deleting an employee, job function or shift would do — the counts Team
 * Setup's delete window shows BEFORE anything is erased, next to "Deactivate
 * instead". It mirrors the ON DELETE rules in the schema:
 *
 *   CASCADE   → the rows are ERASED with it           (erases)
 *   SET NULL  → the rows stay but lose the link        (changes)
 *   NO ACTION → the rows stop the delete altogether    (blockers)
 *
 * The *_archive tables have no foreign keys at all, so archived rows survive a
 * delete but point at nothing — the schedule export then prints them with no
 * name. They are listed under `changes`.
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
}

const count = async (sql: string, params: unknown[]): Promise<number> => {
  const r = await query<{ n: number }>(sql, params)
  return r.rows[0]?.n ?? 0
}

/** [count, singular, plural, note?] → a line, or nothing when the count is 0. */
type Spec = [number, string, string, string?]
const lines = (specs: Spec[]): ImpactLine[] =>
  specs
    .filter(([n]) => n > 0)
    .map(([n, one, many, note]) => ({ count: n, label: `${n === 1 ? one : many}${note ? ` (${note})` : ''}` }))

export async function employeeDeleteImpact(id: string, name: string): Promise<DeleteImpact> {
  const q = (table: string) => count(`SELECT count(*)::int AS n FROM ${table} WHERE employee_id = $1`, [id])
  const [assignments, pto, requests, swaps, notes, errors, points, training, pins, archived, accounts] = await Promise.all([
    q('schedule_assignments'),
    q('pto_days'),
    q('schedule_requests'),
    q('shift_swaps'),
    q('performance_notes'),
    q('performance_errors'),
    q('attendance_points'),
    q('employee_training'),
    q('preferred_assignments'),
    q('schedule_assignments_archive'),
    q('user_profiles'),
  ])
  return {
    name,
    erases: lines([
      [assignments, 'schedule assignment', 'schedule assignments', 'every date'],
      [pto, 'time-off day or call-in', 'time-off days and call-ins'],
      [requests, 'time-off request', 'time-off requests'],
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
  }
}

export async function jobFunctionDeleteImpact(id: string, name: string): Promise<DeleteImpact> {
  const q = (table: string, col = 'job_function_id') => count(`SELECT count(*)::int AS n FROM ${table} WHERE ${col} = $1`, [id])
  const [assignments, training, hourly, targetHours, daily, pins, pinBlocks, errors, halfPins, archived, dailyArchived] = await Promise.all([
    q('schedule_assignments'),
    q('employee_training'),
    q('staffing_targets'),
    q('target_hours'),
    q('daily_targets'),
    q('preferred_assignments'),
    q('preferred_assignment_blocks'),
    q('performance_errors'),
    count('SELECT count(*)::int AS n FROM preferred_assignments WHERE (am_job_function_id = $1 OR pm_job_function_id = $1) AND job_function_id <> $1', [id]),
    q('schedule_assignments_archive'),
    q('daily_targets_archive'),
  ])
  return {
    name,
    erases: lines([
      [assignments, 'schedule assignment', 'schedule assignments', 'every date'],
      [training, 'training record', 'training records'],
      [hourly, 'hourly staffing target', 'hourly staffing targets'],
      [targetHours + daily, 'target-hours setting', 'target-hours settings'],
      [pins + pinBlocks, 'required or preferred assignment', 'required or preferred assignments'],
    ]),
    changes: lines([
      [errors, 'logged error stays but loses its job', 'logged errors stay but lose their job'],
      [halfPins, 'morning/afternoon pin loses this job', 'morning/afternoon pins lose this job'],
      [archived + dailyArchived, 'archived row stays but will show no job', 'archived rows stay but will show no job'],
    ]),
    blockers: [],
  }
}

export async function shiftDeleteImpact(id: string, name: string): Promise<DeleteImpact> {
  const [assignments, swaps, people, archived, requests] = await Promise.all([
    count('SELECT count(*)::int AS n FROM schedule_assignments WHERE shift_id = $1', [id]),
    count('SELECT count(*)::int AS n FROM shift_swaps WHERE original_shift_id = $1 OR swapped_shift_id = $1', [id]),
    count('SELECT count(*)::int AS n FROM employees WHERE shift_id = $1', [id]),
    count('SELECT count(*)::int AS n FROM schedule_assignments_archive WHERE shift_id = $1', [id]),
    count('SELECT count(*)::int AS n FROM schedule_requests WHERE original_shift_id = $1 OR requested_shift_id = $1', [id]),
  ])
  return {
    name,
    erases: lines([
      [assignments, 'schedule assignment', 'schedule assignments', 'every date'],
      [swaps, 'shift swap', 'shift swaps'],
    ]),
    changes: lines([
      [people, 'person on this shift would be left with no shift (the builder skips them)', 'people on this shift would be left with no shift (the builder skips them)'],
      [archived, 'archived assignment stays but will show no shift', 'archived assignments stay but will show no shift'],
    ]),
    blockers: lines([
      [requests, 'time-off request uses this shift', 'time-off requests use this shift'],
    ]),
  }
}
