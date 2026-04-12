import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const body = await readBody(event)
  const { from_date, to_date } = body

  if (!from_date || !to_date) {
    throw createError({ statusCode: 400, message: 'from_date and to_date are required' })
  }

  let sql = `SELECT * FROM schedule_assignments WHERE schedule_date = $1`
  const params: unknown[] = [from_date]

  if (teamId) {
    params.push(teamId)
    sql += ` AND team_id = $${params.length}`
  }

  const source = await query(sql, params)

  if (source.rows.length === 0) {
    return { success: true, copied: 0, excluded: 0, adjusted: 0 }
  }

  // Fetch PTO records for the target date to exclude/clip affected employees
  let ptoDaysSql = `SELECT * FROM pto_days WHERE pto_date = $1`
  const ptoParams: unknown[] = [to_date]
  if (teamId) {
    ptoParams.push(teamId)
    ptoDaysSql += ` AND team_id = $${ptoParams.length}`
  }
  const ptoDays = await query(ptoDaysSql, ptoParams)
  const ptoDayMap = new Map<string, any>()
  for (const pto of ptoDays.rows) {
    if (pto.employee_id) ptoDayMap.set(pto.employee_id, pto)
  }

  // Time helpers for clipping
  const timeToMins = (t: string): number => {
    const [h, m] = t.split(':').map(Number)
    return h * 60 + (m || 0)
  }
  const minsToTime = (n: number): string =>
    `${Math.floor(n / 60).toString().padStart(2, '0')}:${(n % 60).toString().padStart(2, '0')}`

  const validRows = source.rows.filter(
    (a) => a.employee_id && a.job_function_id && a.shift_id && a.start_time && a.end_time
  )

  let copied = 0
  let excluded = 0
  let adjusted = 0

  for (const a of validRows) {
    const pto = ptoDayMap.get(a.employee_id)

    if (pto) {
      // Full-day PTO → skip this assignment
      if (pto.pto_type === 'full_day' || (!pto.start_time && !pto.end_time)) {
        excluded++
        continue
      }

      // Partial-day PTO → clip start/end times
      if (pto.start_time && pto.end_time) {
        const ptoStart = timeToMins(pto.start_time)
        const ptoEnd = timeToMins(pto.end_time)
        let aStart = timeToMins(a.start_time)
        let aEnd = timeToMins(a.end_time)

        // Late start: PTO covers beginning of assignment
        if (ptoStart <= aStart && ptoEnd > aStart) {
          aStart = ptoEnd
        }
        // Early leave: PTO covers end of assignment
        if (ptoEnd >= aEnd && ptoStart < aEnd) {
          aEnd = ptoStart
        }

        // Nothing remains → skip
        if (aStart >= aEnd) {
          excluded++
          continue
        }

        await query(
          `INSERT INTO schedule_assignments
             (employee_id, job_function_id, shift_id, schedule_date, assignment_order, start_time, end_time, team_id)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
          [a.employee_id, a.job_function_id, a.shift_id, to_date, a.assignment_order,
           minsToTime(aStart), minsToTime(aEnd), a.team_id]
        )
        adjusted++
        copied++
        continue
      }
    }

    // No PTO → copy as-is
    await query(
      `INSERT INTO schedule_assignments
         (employee_id, job_function_id, shift_id, schedule_date, assignment_order, start_time, end_time, team_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
      [a.employee_id, a.job_function_id, a.shift_id, to_date, a.assignment_order, a.start_time, a.end_time, a.team_id]
    )
    copied++
  }

  return { success: true, copied, excluded, adjusted }
})
