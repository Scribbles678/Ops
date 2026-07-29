import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'
import { prepare } from '../../../utils/scheduleEngineV2/prepare'
import { SLOTS_PER_DAY } from '../../../utils/scheduleEngineV2/types'

/**
 * Coverage preview for a date — what the day looks like BEFORE building.
 *
 * Reuses the V2 engine's own prepare() so availability is computed by exactly the
 * code that schedules it: shift span minus PTO, lunch and breaks. Writing this
 * math a second time is how the PTO strip and sim-builder drifted, so it isn't
 * repeated here.
 *
 * Each hour reports BOTH the typical free headcount and the WORST 15-minute slot
 * inside it. That difference is the whole point: an hour can look adequately
 * staffed while containing a 15-minute cliff where a whole shift is on break.
 *
 * Query params: date (YYYY-MM-DD, required)
 */
export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const params = getQuery(event)
  const date = String(params.date ?? '')

  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    throw createError({ statusCode: 400, message: 'date is required (YYYY-MM-DD)' })
  }

  const teamClause = teamId ? 'AND team_id = $1' : ''
  const teamArgs = teamId ? [teamId] : []

  const [employees, jobFunctions, shifts, targets, training, pto] = await Promise.all([
    query(`SELECT * FROM employees WHERE is_active = true ${teamClause}`, teamArgs),
    query(`SELECT * FROM job_functions WHERE 1=1 ${teamClause}`, teamArgs),
    query(`SELECT * FROM shifts WHERE 1=1 ${teamClause}`, teamArgs),
    query(
      `SELECT st.* FROM staffing_targets st WHERE st.is_active = true
       ${teamId ? 'AND st.team_id = $1' : ''}`,
      teamArgs
    ),
    query(
      `SELECT t.employee_id, t.job_function_id FROM employee_training t
       ${teamId ? 'WHERE t.team_id = $1' : ''}`,
      teamArgs
    ),
    query(
      `SELECT * FROM pto_days WHERE pto_date = $${teamId ? 2 : 1}
       ${teamId ? 'AND team_id = $1' : ''}`,
      teamId ? [teamId, date] : [date]
    ),
  ])

  const trainingMap: Record<string, string[]> = {}
  for (const t of training.rows as any[]) {
    ;(trainingMap[t.employee_id] ??= []).push(t.job_function_id)
  }
  const ptoByEmployee: Record<string, any> = {}
  for (const p of pto.rows as any[]) ptoByEmployee[p.employee_id] = p

  const prepared = prepare({
    employees: employees.rows,
    jobFunctions: jobFunctions.rows,
    shifts: shifts.rows,
    training: trainingMap,
    staffingTargets: targets.rows,
    preferredAssignments: {},
    ptoByEmployee,
  })

  // Which hours to show: those with any demand or anybody on the clock.
  const slotHasInterest = new Array(SLOTS_PER_DAY).fill(false)
  for (const fn of prepared.functions) {
    for (let s = 0; s < SLOTS_PER_DAY; s++) if ((fn.demand[s] ?? 0) > 0) slotHasInterest[s] = true
  }
  for (const e of prepared.employees) {
    for (let s = 0; s < SLOTS_PER_DAY; s++) if (e.free[s] === 1) slotHasInterest[s] = true
  }
  const hourSet = new Set<number>()
  for (let s = 0; s < SLOTS_PER_DAY; s++) if (slotHasInterest[s]) hourSet.add(Math.floor(s / 4))
  const hours = [...hourSet].sort((a, b) => a - b)

  const fnMeta = new Map((jobFunctions.rows as any[]).map((j) => [j.id, j]))

  // Per-function rows. Note trained-free is NOT additive across functions — one
  // person qualified for five functions counts as free for all five — so a row
  // passing is necessary, not sufficient. The totals row is the binding check.
  const functions = prepared.functions
    .filter((fn) => {
      for (let s = 0; s < SLOTS_PER_DAY; s++) if ((fn.demand[s] ?? 0) > 0) return true
      return false
    })
    .map((fn) => {
      const cells = hours.map((h) => {
        let target = 0
        let minFree = Infinity
        let maxFree = 0
        for (let s = h * 4; s < h * 4 + 4; s++) {
          target = Math.max(target, fn.demand[s] ?? 0)
          let free = 0
          for (const e of prepared.employees) if (e.trained.has(fn.id) && e.free[s] === 1) free++
          minFree = Math.min(minFree, free)
          maxFree = Math.max(maxFree, free)
        }
        if (minFree === Infinity) minFree = 0
        return {
          hour: h,
          target,
          trainedFree: maxFree,
          worstTrainedFree: minFree,
          slack: maxFree - target,
          worstSlack: minFree - target,
          // An hour that reads fine but contains a sub-hour dip — the failure
          // mode an hourly model cannot see.
          dip: maxFree !== minFree,
        }
      })
      const meta = fnMeta.get(fn.id)
      return {
        id: fn.id,
        name: fn.name,
        color: meta?.color_code || '#6b7280',
        totalTarget: cells.reduce((s, c) => s + c.target, 0),
        cells,
      }
    })
    .sort((a, b) => a.name.localeCompare(b.name))

  // Totals row — the hard ceiling. Demand across all functions vs people free.
  const totals = hours.map((h) => {
    let demand = 0
    let minFree = Infinity
    let maxFree = 0
    for (let s = h * 4; s < h * 4 + 4; s++) {
      let d = 0
      for (const fn of prepared.functions) d += fn.demand[s] ?? 0
      demand = Math.max(demand, d)
      let free = 0
      for (const e of prepared.employees) if (e.free[s] === 1) free++
      minFree = Math.min(minFree, free)
      maxFree = Math.max(maxFree, free)
    }
    if (minFree === Infinity) minFree = 0
    return {
      hour: h,
      demand,
      onClock: maxFree,
      worstOnClock: minFree,
      slack: maxFree - demand,
      worstSlack: minFree - demand,
      dip: maxFree !== minFree,
    }
  })

  // The hard ceiling, at true 15-minute resolution.
  let impossibleSlots = 0
  const worstMoments: { time: string; demand: number; free: number; short: number }[] = []
  for (let s = 0; s < SLOTS_PER_DAY; s++) {
    let d = 0
    for (const fn of prepared.functions) d += fn.demand[s] ?? 0
    if (d === 0) continue
    let free = 0
    for (const e of prepared.employees) if (e.free[s] === 1) free++
    const short = Math.max(0, d - free)
    if (short > 0) {
      impossibleSlots += short
      worstMoments.push({
        time: `${String(Math.floor((s * 15) / 60)).padStart(2, '0')}:${String((s * 15) % 60).padStart(2, '0')}`,
        demand: d,
        free,
        short,
      })
    }
  }
  worstMoments.sort((a, b) => b.short - a.short)

  return {
    date,
    hours,
    functions,
    totals,
    summary: {
      totalDemandHours: prepared.functions.reduce((sum, fn) => {
        let t = 0
        for (let s = 0; s < SLOTS_PER_DAY; s++) t += fn.demand[s] ?? 0
        return sum + t / 4
      }, 0),
      totalLabourHours: prepared.employees.reduce((sum, e) => sum + e.onClockSlots / 4, 0),
      schedulableEmployees: prepared.employees.length,
      impossibleHeadcountHours: Math.round((impossibleSlots / 4) * 10) / 10,
      worstMoments: worstMoments.slice(0, 6),
      warnings: prepared.warnings,
    },
  }
})
