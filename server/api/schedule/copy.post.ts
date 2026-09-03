import { query, transaction } from '../../utils/db'
import { requireAuth, getWriteTeamId } from '../../utils/authorize'
import { describePto, subtractPto, ptoTimeToMinutes } from '../../../utils/ptoDisplay'
import { DB_MIN_BLOCK_MINUTES } from '../../../utils/scheduleEngineV2/types'

/**
 * Copy one day's schedule onto another, for the caller's team.
 *
 * This is a REPLACE, like the builder's write path: the target day is cleared and
 * rewritten inside one transaction. It used to append, which meant the overlap
 * trigger rejected the first duplicate whenever the target day already had a
 * schedule (its normal state) and left the rows inserted before the failure
 * behind as a half-copied day.
 *
 * Absences on the target date come from the shared PTO helpers rather than a
 * local reading of start_time/end_time — the old clip ignored leave-early rows
 * (NULL end), copied a mid-shift absence unchanged, and could emit a sliver the
 * 15-minute CHECK then rejected.
 */
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/

const minsToTime = (n: number): string =>
  `${String(Math.floor(n / 60)).padStart(2, '0')}:${String(n % 60).padStart(2, '0')}`

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getWriteTeamId(user)
  const body = await readBody(event)
  const from_date = String(body?.from_date ?? '')
  const to_date = String(body?.to_date ?? '')

  if (!DATE_RE.test(from_date) || !DATE_RE.test(to_date)) {
    throw createError({ statusCode: 400, message: 'from_date and to_date are required (YYYY-MM-DD)' })
  }
  if (from_date === to_date) {
    throw createError({ statusCode: 400, message: 'Source and target dates are the same' })
  }

  const [source, pto, swaps, employees] = await Promise.all([
    query(
      `SELECT employee_id, job_function_id, shift_id, assignment_order, start_time, end_time
       FROM schedule_assignments WHERE schedule_date = $1 AND team_id = $2
       ORDER BY employee_id, start_time`,
      [from_date, teamId]
    ),
    query(`SELECT * FROM pto_days WHERE pto_date = $1 AND team_id = $2`, [to_date, teamId]),
    query(`SELECT employee_id FROM shift_swaps WHERE swap_date = $1 AND team_id = $2`, [to_date, teamId]),
    query(`SELECT id, first_name, last_name, is_active FROM employees WHERE team_id = $1`, [teamId]),
  ])

  if (source.rows.length === 0) {
    return { success: true, source_empty: true, copied: 0, replaced: 0, excluded: 0, adjusted: 0, inactive: 0, swapped: [] }
  }

  // Every absence window per employee. An employee can carry more than one row
  // for a date (arrive late AND leave early), so this is a list, not last-wins.
  const windowsByEmployee = new Map<string, { startMin: number; endMin: number }[]>()
  const outAllDay = new Set<string>()
  for (const row of pto.rows as any[]) {
    const d = describePto(row)
    if (!d || !row.employee_id) continue
    if (d.allDay) { outAllDay.add(row.employee_id); continue }
    ;(windowsByEmployee.get(row.employee_id) ?? windowsByEmployee.set(row.employee_id, []).get(row.employee_id)!)
      .push({ startMin: d.startMin, endMin: d.endMin })
  }

  const swappedIds = new Set((swaps.rows as any[]).map((s) => s.employee_id))
  const employeeById = new Map((employees.rows as any[]).map((e) => [e.id, e]))

  let excluded = 0   // whole assignments removed for time off
  let adjusted = 0   // assignments trimmed around a partial absence
  let inactive = 0   // source rows for people no longer active
  const swappedNames = new Set<string>()
  const rows: { employee_id: string; job_function_id: string; shift_id: string; assignment_order: number; start: string; end: string }[] = []

  for (const a of source.rows as any[]) {
    if (!a.employee_id || !a.job_function_id || !a.shift_id || !a.start_time || !a.end_time) continue

    const emp = employeeById.get(a.employee_id)
    if (!emp || emp.is_active === false) { inactive++; continue }

    // A swap changes which hours this person works on the target day. Copying
    // the source day's shift and times would put them on hours they are not
    // working — and the display board groups by the swapped shift, so those rows
    // would vanish from it. Leave them off and say so; a person adds them.
    if (swappedIds.has(a.employee_id)) {
      swappedNames.add(`${emp.first_name} ${emp.last_name}`.trim())
      continue
    }

    if (outAllDay.has(a.employee_id)) { excluded++; continue }

    const start = ptoTimeToMinutes(a.start_time)
    const end = ptoTimeToMinutes(a.end_time)
    if (start == null || end == null || end <= start) continue

    const windows = windowsByEmployee.get(a.employee_id)
    const pieces = windows
      ? subtractPto(start, end, windows).filter((p) => p.end - p.start >= DB_MIN_BLOCK_MINUTES)
      : [{ start, end }]

    if (!pieces.length) { excluded++; continue }
    if (pieces.length !== 1 || pieces[0]!.start !== start || pieces[0]!.end !== end) adjusted++

    for (const p of pieces) {
      rows.push({
        employee_id: a.employee_id,
        job_function_id: a.job_function_id,
        shift_id: a.shift_id,
        assignment_order: a.assignment_order ?? 1,
        start: minsToTime(p.start),
        end: minsToTime(p.end),
      })
    }
  }

  try {
    const replaced = await transaction(async (client) => {
      const del = await client.query(
        `DELETE FROM schedule_assignments WHERE schedule_date = $1 AND team_id = $2`,
        [to_date, teamId]
      )
      for (let i = 0; i < rows.length; i++) {
        const r = rows[i]!
        try {
          await client.query(
            `INSERT INTO schedule_assignments
               (employee_id, job_function_id, shift_id, schedule_date, assignment_order, start_time, end_time, team_id)
             VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
            [r.employee_id, r.job_function_id, r.shift_id, to_date, r.assignment_order, r.start, r.end, teamId]
          )
        } catch (insertErr: any) {
          const emp = employeeById.get(r.employee_id)
          const who = emp ? `${emp.first_name} ${emp.last_name}`.trim() : r.employee_id
          console.error(`[schedule-copy] row ${i + 1} failed:`, insertErr)
          throw createError({
            statusCode: 500,
            message: `Assignment ${i + 1} of ${rows.length} (${who}, ${r.start}-${r.end}) failed: ${insertErr?.message || String(insertErr)}`,
          })
        }
      }
      return del.rowCount ?? 0
    })

    return {
      success: true,
      source_empty: false,
      copied: rows.length,
      replaced,
      excluded,
      adjusted,
      inactive,
      swapped: [...swappedNames].sort(),
    }
  } catch (e: any) {
    if (e.statusCode) throw e
    console.error('[schedule-copy] Error:', e)
    throw createError({ statusCode: 500, message: e?.message || 'Failed to copy schedule' })
  }
})
