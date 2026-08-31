/**
 * Phase A — turn raw DB rows into the slot model the engine consumes.
 *
 * The domain rules here are carried over from V1 deliberately: Meter parent/child
 * training, fan-out of parent targets across numbered children, full/partial PTO,
 * and break + lunch carve-out. Those were correct; only the time model changed.
 */
import {
  SLOTS_PER_DAY,
  type EngineEmployee,
  type EngineFunction,
} from './types'
import { fillSlots, slotCeil, slotOf, toMinutes } from './slots'

const METER_CHILD = /^(.+) (\d+)$/

/** True if `trained` qualifies the employee for `fn`, honouring Meter parents. */
export function isTrainedFor(
  trainedIds: string[],
  fn: { id: string; name: string; team_id?: string | null },
  allFunctions: any[]
): boolean {
  if (trainedIds.includes(fn.id)) return true
  const m = METER_CHILD.exec(fn.name || '')
  if (!m) return false
  const parentName = m[1]
  const parent = allFunctions.find(
    (j: any) => j.name === parentName && (j.team_id ?? null) === (fn.team_id ?? null)
  )
  return !!parent && trainedIds.includes(parent.id)
}

/**
 * Expand a parent function's targets across its numbered children (Meter -> Meter 1..N),
 * distributing headcount evenly. Sorted numerically so Meter 2 precedes Meter 10.
 */
export function expandFanOut(targets: any[], jobFunctions: any[]): any[] {
  const byFunction = new Map<string, any[]>()
  for (const t of targets) {
    if (!byFunction.has(t.job_function_id)) byFunction.set(t.job_function_id, [])
    byFunction.get(t.job_function_id)!.push(t)
  }

  const out: any[] = []
  for (const [jfId, fnTargets] of byFunction) {
    const jf = jobFunctions.find((j: any) => j.id === jfId)
    if (!jf) continue

    const byName = new Map<string, any>()
    for (const child of jobFunctions) {
      if (child.id === jfId || child.is_active === false || !child.name) continue
      if (!child.name.startsWith(jf.name + ' ') || !/\d+$/.test(child.name)) continue
      const existing = byName.get(child.name)
      if (!existing) byName.set(child.name, child)
      else {
        const a = existing.created_at ? new Date(existing.created_at).getTime() : Infinity
        const b = child.created_at ? new Date(child.created_at).getTime() : Infinity
        if (b < a) byName.set(child.name, child)
      }
    }
    const children = Array.from(byName.values()).sort((a, b) => {
      const na = parseInt(/(\d+)$/.exec(a.name)?.[1] ?? '0', 10)
      const nb = parseInt(/(\d+)$/.exec(b.name)?.[1] ?? '0', 10)
      return na !== nb ? na - nb : String(a.name).localeCompare(String(b.name))
    })

    if (!children.length) { out.push(...fnTargets); continue }

    for (const t of fnTargets) {
      const base = Math.floor(t.headcount / children.length)
      const rem = t.headcount % children.length
      children.forEach((child: any, i: number) => {
        out.push({
          job_function_id: child.id,
          job_function_name: child.name,
          hour_start: t.hour_start,
          headcount: base + (i < rem ? 1 : 0),
        })
      })
    }
  }
  return out
}

export interface PrepareInput {
  employees: any[]
  jobFunctions: any[]
  shifts: any[]
  /** employeeId -> jobFunctionId[] */
  training: Record<string, string[]>
  staffingTargets: any[]
  /** employeeId -> { jobFunctionId -> preferred_assignment row (with .blocks) } */
  preferredAssignments: Record<string, Record<string, any>>
  /** employeeId -> pto_days row */
  ptoByEmployee: Record<string, any>
  /**
   * employeeId -> the shift they are actually working today, when it differs from
   * their default. Without this the builder schedules a swapped employee against
   * the shift they did NOT work, and stamps the assignment with the wrong shift.
   */
  swappedShiftByEmployee?: Record<string, string | null>
}

export interface PreparedInput {
  employees: EngineEmployee[]
  functions: EngineFunction[]
  preferred: Map<string, Set<string>>
  requiredPins: { employeeId: string; functionId: string; startSlot: number; endSlot: number }[]
  /** Someone must fix these in the app. See EngineResult.actions. */
  actions: string[]
  /** Informational only. */
  warnings: string[]
}

export function prepare(input: PrepareInput): PreparedInput {
  const warnings: string[] = []
  const actions: string[] = []
  const shiftById = new Map(input.shifts.map((s: any) => [s.id, s]))
  const activeFunctions = input.jobFunctions.filter((j: any) => j.is_active !== false)

  // ---- functions + demand grid --------------------------------------------
  const expanded = expandFanOut(input.staffingTargets, input.jobFunctions)
  const demandByFn = new Map<string, Int16Array>()
  for (const t of expanded) {
    const mins = toMinutes(t.hour_start)
    if (mins == null) continue
    let arr = demandByFn.get(t.job_function_id)
    if (!arr) { arr = new Int16Array(SLOTS_PER_DAY); demandByFn.set(t.job_function_id, arr) }
    // An hourly target holds across its four 15-minute slots.
    const start = slotOf(mins)
    for (let s = start; s < start + 4 && s < SLOTS_PER_DAY; s++) arr[s] = Number(t.headcount) || 0
  }

  // Clip demand to the hours the building is actually open.
  //
  // Targets are stored hourly and are not cross-checked against shifts, so the grid
  // can ask for people at times nobody works. Two ways that happens, both measured:
  //   - a stale row survives a shift change (a 06:00 startup target after the 6am
  //     shift was retired), and
  //   - an hourly row over-extends a real target (20:00 covers 20:00-21:00, but the
  //     last shift ends 20:30, so the final half-hour is unstaffable by definition).
  // Chasing either produces permanent phantom gaps the floor can do nothing about.
  // Demand outside the shift envelope is dropped and reported, not silently ignored.
  const openSlots = new Uint8Array(SLOTS_PER_DAY)
  let anyShift = false
  for (const sh of input.shifts) {
    if (sh?.is_active === false) continue
    const s = toMinutes(sh?.start_time)
    let e = toMinutes(sh?.end_time)
    if (s == null || e == null) continue
    if (e <= s) e += 1440
    fillSlots(openSlots, s, e, 1)
    anyShift = true
  }
  if (anyShift) {
    // Only a target whose WHOLE hour falls outside the envelope is worth reporting:
    // that is a stale row someone needs to delete. A target hour that merely runs
    // past the last shift (20:00 covering 20:00-21:00 when shifts end 20:30) is a
    // side effect of storing targets hourly, is not fixable from the grid, and would
    // otherwise warn on every single build until the team lead stopped reading them.
    const staleHours = new Map<string, number>()
    for (const [fnId, arr] of demandByFn) {
      for (let h = 0; h < SLOTS_PER_DAY; h += 4) {
        let clipped = 0
        let anyOpen = false
        for (let s = h; s < h + 4 && s < SLOTS_PER_DAY; s++) {
          if (openSlots[s] === 1) { anyOpen = true; continue }
          clipped += arr[s]
          arr[s] = 0
        }
        if (clipped > 0 && !anyOpen) staleHours.set(fnId, (staleHours.get(fnId) ?? 0) + clipped)
      }
    }
    for (const [fnId, units] of staleHours) {
      const name = input.jobFunctions.find((j: any) => j.id === fnId)?.name ?? 'a job function'
      actions.push(
        `${name} has staffing targets set for hours nobody works. Clear those cells in the Target Hours grid.`
      )
    }
  }

  const functions: EngineFunction[] = activeFunctions.map((j: any) => ({
    id: j.id,
    name: j.name,
    demand: demandByFn.get(j.id) ?? new Int16Array(SLOTS_PER_DAY),
    covered: new Int16Array(SLOTS_PER_DAY),
    maxHeadcount: j.max_headcount == null ? null : Number(j.max_headcount),
    isOverflow: !!j.surplus_overflow,
    excludeFromTargets: !!j.exclude_from_targets,
    scarcity: 1,
    // 3 = normal, so a function with no explicit priority behaves as before.
    priority: Number(j.staffing_priority) >= 1 && Number(j.staffing_priority) <= 5
      ? Number(j.staffing_priority)
      : 3,
  }))

  // ---- employees + availability grid ---------------------------------------
  const employees: EngineEmployee[] = []
  let noShift = 0
  let noTraining = 0
  let fullDayPto = 0

  for (const e of input.employees) {
    if (e.is_active === false) continue
    // A shift swap replaces the employee's shift for this date only. PTO hour
    // accounting has always honoured it (see getEffectiveShift in ptoUsage.ts);
    // the builder did not, so a swapped person was scheduled against the hours
    // they were not working and their assignment carried the wrong shift_id.
    const effectiveShiftId = input.swappedShiftByEmployee?.[e.id] ?? e.shift_id
    const shift = effectiveShiftId ? shiftById.get(effectiveShiftId) : null
    if (!shift) { noShift++; continue }

    const trainedIds = input.training[e.id] ?? []
    if (!trainedIds.length) { noTraining++; continue }

    const pto = input.ptoByEmployee[e.id]
    if (pto?.pto_type === 'full_day' || pto?.pto_type === 'call_in') { fullDayPto++; continue }

    const free = new Uint8Array(SLOTS_PER_DAY)
    const start = toMinutes(shift.start_time)
    let end = toMinutes(shift.end_time)
    if (start == null || end == null) { noShift++; continue }
    if (end <= start) end += 1440
    fillSlots(free, start, end, 1)

    // Lunch and breaks are unavailable. Modelling breaks explicitly on the grid is
    // what makes the whole-shift break cliff visible to the engine.
    for (const [a, b] of [
      [shift.lunch_start, shift.lunch_end],
      [shift.break_1_start, shift.break_1_end],
      [shift.break_2_start, shift.break_2_end],
    ]) {
      const s = toMinutes(a)
      const t = toMinutes(b)
      if (s != null && t != null && t > s) fillSlots(free, s, t, 0)
    }

    // Partial PTO clips availability.
    if (pto && pto.pto_type !== 'full_day') {
      const ps = toMinutes(pto.start_time)
      const pe = toMinutes(pto.end_time)
      if (ps != null && pe != null && pe > ps) fillSlots(free, ps, pe, 0)
      else if (pto.pto_type === 'leave_early' && ps != null) fillSlots(free, ps, end, 0)
      else if (pto.pto_type === 'arrive_late' && pe != null) fillSlots(free, start, pe, 0)
    }

    let onClock = 0
    for (let s = 0; s < SLOTS_PER_DAY; s++) if (free[s] === 1) onClock++

    const trained = new Set<string>()
    for (const fn of activeFunctions) {
      if (isTrainedFor(trainedIds, fn, input.jobFunctions)) trained.add(fn.id)
    }

    employees.push({
      id: e.id,
      name: `${e.last_name}, ${e.first_name}`,
      displayName: `${e.first_name} ${e.last_name}`.trim(),
      // The shift actually worked today — swapped where a swap exists.
      shiftId: effectiveShiftId,
      free,
      trained,
      onClockSlots: onClock,
    })
  }

  if (noShift) actions.push(`${noShift} ${noShift === 1 ? 'person has' : 'people have'} no shift assigned, so ${noShift === 1 ? 'they were' : 'they were'} left out. Set a shift on the Employees page.`)
  if (noTraining) actions.push(`${noTraining} ${noTraining === 1 ? 'person has' : 'people have'} no training recorded, so ${noTraining === 1 ? 'they were' : 'they were'} left out. Add training on the Training page.`)
  if (fullDayPto) warnings.push(`${fullDayPto} ${fullDayPto === 1 ? 'person is' : 'people are'} off for the whole day.`)

  // ---- scarcity: trained supply ÷ total demand ------------------------------
  for (const fn of functions) {
    let demandSlots = 0
    for (let s = 0; s < SLOTS_PER_DAY; s++) demandSlots += fn.demand[s] ?? 0
    if (demandSlots === 0) { fn.scarcity = Infinity; continue }
    let supply = 0
    for (const e of employees) if (e.trained.has(fn.id)) supply += e.onClockSlots
    fn.scarcity = supply / demandSlots
  }

  // ---- preferred + required pins -------------------------------------------
  const preferred = new Map<string, Set<string>>()
  const requiredPins: PreparedInput['requiredPins'] = []
  const empIds = new Set(employees.map((e) => e.id))

  for (const [empId, byFn] of Object.entries(input.preferredAssignments ?? {})) {
    if (!empIds.has(empId)) continue
    const set = new Set<string>()
    for (const [fnId, pa] of Object.entries(byFn ?? {})) {
      set.add(fnId)
      if (!pa?.is_required) continue

      const blocks = Array.isArray(pa.blocks) ? pa.blocks : []
      if (blocks.length) {
        for (const b of blocks) {
          const bs = toMinutes(b.start_time)
          const be = toMinutes(b.end_time)
          if (bs == null || be == null || be <= bs) continue
          requiredPins.push({ employeeId: empId, functionId: fnId, startSlot: slotOf(bs), endSlot: slotCeil(be) })
        }
      } else {
        // Legacy whole-day pin.
        requiredPins.push({ employeeId: empId, functionId: fnId, startSlot: 0, endSlot: SLOTS_PER_DAY })
      }
    }
    preferred.set(empId, set)
  }

  return { employees, functions, preferred, requiredPins, actions, warnings }
}
