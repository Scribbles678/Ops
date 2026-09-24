/**
 * Phase A — turn raw DB rows into the slot model the engine consumes.
 *
 * The domain rules here are carried over from V1 deliberately: Meter parent/child
 * training, fan-out of parent targets across numbered children, full/partial PTO,
 * and break + lunch carve-out. Those were correct; only the time model changed.
 */
import {
  SLOTS_PER_DAY,
  type EngineAction,
  type EngineEmployee,
  type EngineFunction,
} from './types'
import { fillSlots, slotCeil, slotOf, slotToTime, toMinutes } from './slots'
import { describePto, type PtoDescription } from '../ptoDisplay'

const METER_CHILD = /^(.+) (\d+)$/

/**
 * Canonical input order.
 *
 * The engine breaks ties in favour of whoever comes first, so the order the caller
 * happened to fetch rows in used to change the schedule: the harness (unordered
 * SQL) and the app (the API's ORDER BYs) disagreed on 10+ people's days for the
 * same data. prepare() therefore sorts its own inputs, and the output depends on
 * the data alone.
 *
 * Plain code-unit comparison rather than localeCompare, so the browser and Node
 * sort identically. It also matches the byte-order ORDER BY the API returns today,
 * so live schedules did not change when this was added.
 */
const compareText = (a: unknown, b: unknown): number => {
  const x = String(a ?? '')
  const y = String(b ?? '')
  return x < y ? -1 : x > y ? 1 : 0
}
/** Same order as GET /api/employees: last name, first name. */
const byEmployeeOrder = (a: any, b: any): number =>
  compareText(a.last_name, b.last_name) || compareText(a.first_name, b.first_name) || compareText(a.id, b.id)
/** Same order as GET /api/job-functions: sort_order (unset last), then name. */
const sortOrderOf = (j: any): number => (j.sort_order == null ? Number.MAX_SAFE_INTEGER : Number(j.sort_order))
const byFunctionOrder = (a: any, b: any): number =>
  sortOrderOf(a) - sortOrderOf(b) || compareText(a.name, b.name) || compareText(a.id, b.id)

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
  /** employeeId -> every pto_days row for that employee on the date (there can be several) */
  ptoByEmployee: Record<string, any[]>
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
  actions: EngineAction[]
  /** Informational only. */
  warnings: string[]
  /** People off for the whole day (full-day time off or a call-in). */
  offAllDay: number
}

export function prepare(input: PrepareInput): PreparedInput {
  const warnings: string[] = []
  const actions: EngineAction[] = []
  // One line per problem, however many rows or blocks share it.
  const report = (message: string, fix?: EngineAction['fix']): void => {
    if (!actions.some((a) => a.message === message)) actions.push({ message, fix })
  }
  const shiftById = new Map(input.shifts.map((s: any) => [s.id, s]))
  const activeFunctions = [...input.jobFunctions].sort(byFunctionOrder).filter((j: any) => j.is_active !== false)

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
      report(`${name} has targets set for hours nobody works. Clear those cells.`, 'rules-and-targets')
    }
  }

  // Break and lunch windows across all active shifts. A shortfall inside one does
  // not count for any job: the floor does not expect the builder to staff a job
  // through a 15-minute break, and listing every such hole buried the two or three
  // gaps a supervisor could act on. (Per-job "keep covered" flags that overrode
  // this were removed in Sep 2026; the job_functions columns are no longer read.)
  const mustCover = new Uint8Array(SLOTS_PER_DAY).fill(1)
  for (const sh of input.shifts) {
    if (sh?.is_active === false) continue
    for (const [a, b] of [
      [sh.break_1_start, sh.break_1_end],
      [sh.break_2_start, sh.break_2_end],
      [sh.lunch_start, sh.lunch_end],
    ]) {
      const s = toMinutes(a)
      const t = toMinutes(b)
      if (s != null && t != null && t > s) fillSlots(mustCover, s, t, 0)
    }
  }

  const functions: EngineFunction[] = activeFunctions.map((j: any) => {
    return {
      id: j.id,
      name: j.name,
      demand: demandByFn.get(j.id) ?? new Int16Array(SLOTS_PER_DAY),
      covered: new Int16Array(SLOTS_PER_DAY),
      maxHeadcount: j.max_headcount == null ? null : Number(j.max_headcount),
      isOverflow: !!j.surplus_overflow,
      // Read-only, and the same for every job.
      mustCover,
      scarcity: 1,
      // 3 = normal, so a function with no explicit priority behaves as before.
      priority: Number(j.staffing_priority) >= 1 && Number(j.staffing_priority) <= 5
        ? Number(j.staffing_priority)
        : 3,
    }
  })

  // ---- employees + availability grid ---------------------------------------
  const employees: EngineEmployee[] = []
  // Per employee: shift hours, and shift hours minus breaks and lunch (before time
  // off). Only used to explain a required assignment that cannot be placed.
  const shiftShape = new Map<string, { span: Uint8Array; workable: Uint8Array }>()
  let noShift = 0
  let noTraining = 0
  let fullDayPto = 0

  for (const e of [...input.employees].sort(byEmployeeOrder)) {
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

    // Every absence that day, read the one way the rest of the app reads them
    // (utils/ptoDisplay.ts). This used to keep a single pto_days row per person and
    // interpret it itself, so an arrive-late plus a leave-early on the same day
    // honoured only one of them, and an untyped row the display board shows as
    // "off all day" was scheduled all day.
    const absences = (input.ptoByEmployee[e.id] ?? [])
      .map((row) => describePto(row))
      .filter((d): d is PtoDescription => d != null)
    if (absences.some((d) => d.allDay)) { fullDayPto++; continue }

    const free = new Uint8Array(SLOTS_PER_DAY)
    const start = toMinutes(shift.start_time)
    let end = toMinutes(shift.end_time)
    if (start == null || end == null) { noShift++; continue }
    if (end <= start) end += 1440
    fillSlots(free, start, end, 1)
    const span = Uint8Array.from(free)

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
    shiftShape.set(e.id, { span, workable: Uint8Array.from(free) })

    // Partial absences clip availability: leave early runs to the end of the day,
    // arrive late from the start of it.
    for (const d of absences) fillSlots(free, d.startMin, d.endMin, 0)

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

  if (noShift) report(`${noShift} ${noShift === 1 ? 'person has' : 'people have'} no shift, so they were left out.`, 'employees')
  if (noTraining) report(`${noTraining} ${noTraining === 1 ? 'person has' : 'people have'} no training recorded, so they were left out.`, 'employees')

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
  const activeFnIds = new Set(activeFunctions.map((j: any) => j.id))
  const fnName = (id: string): string => input.jobFunctions.find((j: any) => j.id === id)?.name ?? 'a job function'

  for (const emp of employees) {
    const byFn = input.preferredAssignments?.[emp.id]
    if (!byFn) continue
    const set = new Set<string>()
    const shape = shiftShape.get(emp.id)!

    /**
     * Queue one required block, or say why it cannot be placed. Silence here is
     * what made required assignments look ignored: a block outside the person's
     * shift, inside their break, or on an inactive function simply vanished.
     */
    const pin = (functionId: string, startSlot: number, endSlot: number): void => {
      const fn = fnName(functionId)
      const who = `${emp.displayName}'s required ${fn} ${slotToTime(startSlot)}–${slotToTime(endSlot)}`
      if (!activeFnIds.has(functionId)) {
        report(`${who} was skipped because ${fn} is not active.`, 'job-functions')
        return
      }
      let onShift = false
      let workable = false
      let free = false
      for (let s = startSlot; s < Math.min(endSlot, SLOTS_PER_DAY); s++) {
        if (shape.span[s] === 1) onShift = true
        if (shape.workable[s] === 1) workable = true
        if (emp.free[s] === 1) free = true
      }
      if (!onShift) {
        report(`${who} is outside their shift today, so it was skipped.`, 'required-assignments')
        return
      }
      if (!workable) {
        report(`${who} falls entirely in their break or lunch, so it was skipped.`, 'required-assignments')
        return
      }
      if (!free) return // off for that part of the day: nothing to fix
      requiredPins.push({ employeeId: emp.id, functionId, startSlot, endSlot })
      set.add(functionId)
    }

    for (const [fnId, pa] of Object.entries(byFn)) {
      set.add(fnId)
      if (!pa?.is_required) continue

      const blocks = Array.isArray(pa.blocks) ? pa.blocks : []
      if (blocks.length) {
        for (const b of blocks) {
          const bs = toMinutes(b.start_time)
          const be = toMinutes(b.end_time)
          if (bs == null || be == null || be <= bs) continue
          // Each block carries its own job function ("X4 mornings, EM9
          // afternoons"). Until Sep 2026 every block was pinned to the row's base
          // function, which the form sets to the FIRST block's, so the afternoon
          // ran X4 as well — the main reason required assignments looked ignored.
          pin(b.job_function_id || fnId, slotOf(bs), slotCeil(be))
        }
      } else {
        // Legacy row with no time blocks: the AM/PM columns decide. Same rule the
        // Rules & Targets page applies when it converts such a row on edit —
        // AM = shift start to lunch, PM = lunch end to shift end; both columns
        // NULL means the base function all day (pre-migration-012 rows); one NULL
        // means that half is simply not pinned.
        //
        // Until Sep 2026 this pinned the BASE function for the whole day and never
        // read the PM column, so "X4 mornings, EM9 afternoons" ran X4 all day. On
        // the dev data 4 of 7 live pins were affected.
        const shift = emp.shiftId ? shiftById.get(emp.shiftId) : null
        const sStart = toMinutes(shift?.start_time)
        let sEnd = toMinutes(shift?.end_time)
        if (sStart != null && sEnd != null && sEnd <= sStart) sEnd += 1440
        const lunchStart = toMinutes(shift?.lunch_start)
        const lunchEnd = toMinutes(shift?.lunch_end)
        const bothNull = !pa.am_job_function_id && !pa.pm_job_function_id
        const amFn: string | null = pa.am_job_function_id ?? (bothNull ? fnId : null)
        const pmFn: string | null = pa.pm_job_function_id ?? (bothNull ? fnId : null)

        if (sStart == null || sEnd == null) {
          // No usable shift times: fall back to the base function all day.
          pin(fnId, 0, SLOTS_PER_DAY)
        } else {
          const amEnd = lunchStart ?? sEnd
          if (amFn && amEnd > sStart) pin(amFn, slotOf(sStart), slotCeil(amEnd))
          if (pmFn && lunchEnd != null && sEnd > lunchEnd) pin(pmFn, slotOf(lunchEnd), slotCeil(sEnd))
        }
      }
    }
    preferred.set(emp.id, set)
  }

  // Per person, earliest first: where two of someone's required assignments
  // overlap, the earlier one wins, whatever order the rows were fetched in.
  const empRank = new Map(employees.map((e, i) => [e.id, i]))
  requiredPins.sort(
    (a, b) =>
      empRank.get(a.employeeId)! - empRank.get(b.employeeId)! ||
      a.startSlot - b.startSlot ||
      compareText(a.functionId, b.functionId)
  )

  return { employees, functions, preferred, requiredPins, actions, warnings, offAllDay: fullDayPto }
}
