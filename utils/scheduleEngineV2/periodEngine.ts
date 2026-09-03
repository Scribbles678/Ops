/**
 * Period engine — the "Automated Schedule Builder V2" card.
 *
 * The team lead's complaint about the slot engine: people are moved between job
 * functions inside a couple of hours. Measured on real days, 13-14% of a person's
 * stretches between breaks carried two functions, and nearly every switch sat on an
 * hour boundary where a target changed — the engine chasing hourly targets inside a
 * two-hour stretch.
 *
 * This engine assigns by PERIOD instead. A period is a maximal on-clock stretch
 * between breaks, lunch, PTO and required pins — exactly the unit a supervisor
 * thinks in. Each step picks the single best (person, period, function) across the
 * whole floor and commits the whole period. Period-first, not function-first: the
 * period goes to whichever need is biggest inside it, rather than to whichever
 * function happened to come first in the priority order (function-first was
 * measured at +29h unmet; this form is within 1-3h of the slot engine).
 *
 * One split per period is allowed, at an hour boundary, only when both pieces are
 * at least PERIOD_MIN_STINT_MINUTES long. Measured: the 7AM shift's first period
 * runs 07:00-08:45 and startup is a one-hour job, so a strict rule left startup
 * empty every day, while a 60-minute floor could not cut 07:00-08:45 either. At
 * 45 minutes the only splits left are that startup case.
 *
 * Trade to know about: coverage moves between functions. A function whose target
 * rises for a single hour mid-period (Locus at 11:00) no longer gets a person
 * hopping over for that hour. Raising or per-slot-scaling the priority weight did
 * not recover it and doubled the switching, so no new knob was added.
 *
 * Everything not about placement — pins, feasibility, the cost weights, merge, gap
 * explanation, stats — is shared with the slot engine in `engine.ts`.
 */
import {
  DEFAULT_WEIGHTS,
  ENGINE_MIN_BLOCK_MINUTES,
  LOWEST_PRIORITY,
  PERIOD_MIN_STINT_MINUTES,
  SLOTS_PER_DAY,
  SLOT_MINUTES,
  type EngineAssignment,
  type EngineEmployee,
  type EngineFunction,
  type EngineResult,
} from './types'
import { runsWhere, slotsToMinutesLength } from './slots'
import {
  analyseFeasibility,
  applyRequiredPins,
  buildStats,
  capRoom,
  commitAssignment,
  explainGaps,
  hasCountedUnmet,
  mergeAssignments,
  newBoard,
  snapshotFree,
  type EngineInput,
} from './engine'

const SLOTS_PER_HOUR = 60 / SLOT_MINUTES

/** A stretch of one person's day that gets one job function. */
interface Period {
  emp: EngineEmployee
  start: number
  end: number
  /** True once this is the remainder of a split; it can no longer be split again. */
  split: boolean
}
interface Block { start: number; end: number }

export function runPeriodEngine(input: EngineInput): EngineResult {
  const w = input.weights ?? DEFAULT_WEIGHTS
  const { employees, functions, preferred } = input
  const warnings: string[] = []
  const actions: string[] = []

  const board = newBoard(employees)
  const { assignments, distinctByEmp } = board
  const originallyFree = snapshotFree(employees)
  const feasibility = analyseFeasibility(employees, functions)
  const minStintSlots = PERIOD_MIN_STINT_MINUTES == null ? null : Math.ceil(PERIOD_MIN_STINT_MINUTES / SLOT_MINUTES)

  // Per-employee index of what they already do, for the continuity bonus.
  const byEmp = new Map<string, EngineAssignment[]>(employees.map((e) => [e.id, []]))
  const commit = (emp: EngineEmployee, fn: EngineFunction, start: number, end: number, reason: EngineAssignment['reason']) => {
    commitAssignment(board, emp, fn, start, end, reason)
    byEmp.get(emp.id)!.push(assignments[assignments.length - 1]!)
  }

  // ---- Phase B: required pins ----------------------------------------------
  applyRequiredPins(board, input.requiredPins, employees, functions, actions)
  for (const a of assignments) byEmp.get(a.employeeId)!.push(a)

  // ---- Periods: maximal free runs per employee, after pins -------------------
  let periods: Period[] = []
  for (const emp of employees) {
    for (const run of runsWhere(SLOTS_PER_DAY, (s) => emp.free[s] === 1)) {
      if (slotsToMinutesLength(run.start, run.end) < ENGINE_MIN_BLOCK_MINUTES) {
        for (let s = run.start; s < run.end; s++) emp.free[s] = 0
        continue
      }
      periods.push({ emp, start: run.start, end: run.end, split: false })
    }
  }
  const originalPeriods = periods.map((p) => ({ emp: p.emp, start: p.start, end: p.end }))

  /**
   * Is this person already on `fnId` right next to this block — the previous or
   * next stint, or across a break/lunch (within an hour either side)?
   */
  const touches = (emp: EngineEmployee, start: number, end: number, fnId: string): boolean =>
    byEmp.get(emp.id)!.some(
      (a) =>
        a.functionId === fnId &&
        ((a.endSlot <= start && a.endSlot >= start - SLOTS_PER_HOUR) ||
          (a.startSlot >= end && a.startSlot <= end + SLOTS_PER_HOUR))
    )

  /** Same trade-offs and weights as scoreCandidate(), applied to a whole block. */
  const score = (emp: EngineEmployee, b: Block, fn: EngineFunction): number => {
    // Same rule as scoreCandidate(): only shortfalls that COUNT, with a bonus for
    // holding a flagged function through a break/lunch window.
    let unmetClosed = 0
    let keepClosed = 0
    for (let s = b.start; s < b.end; s++) {
      if (fn.mustCover[s] === 1 && (fn.covered[s] ?? 0) < (fn.demand[s] ?? 0)) {
        unmetClosed++
        if (fn.keepCovered[s] === 1) keepClosed++
      }
    }
    const wasted = b.end - b.start - unmetClosed
    let sc = unmetClosed * w.unmet + keepClosed * w.breakCover - wasted * w.waste - emp.trained.size * w.flexibility
    const distinct = distinctByEmp.get(emp.id)!
    if (!distinct.has(fn.id)) {
      sc -= w.newFunction
      const excess = Math.max(0, distinct.size + 1 - w.comfortableFunctions)
      sc -= excess * excess * w.functionCount
    }
    if (touches(emp, b.start, b.end, fn.id)) sc += w.adjacent
    if (preferred.get(emp.id)?.has(fn.id)) sc += w.preferred
    sc += (1 - Math.min(1, fn.scarcity)) * w.scarce
    sc += (LOWEST_PRIORITY - fn.priority) * w.priority
    sc += slotsToMinutesLength(b.start, b.end) / 60
    return sc
  }

  /** The blocks a period may be assigned as: itself, or (once) a prefix/suffix cut at an hour boundary. */
  const blocksOf = (p: Period): Block[] => {
    const out: Block[] = [{ start: p.start, end: p.end }]
    if (minStintSlots == null || p.split) return out
    for (let cut = p.start + 1; cut < p.end; cut++) {
      if (cut % SLOTS_PER_HOUR !== 0) continue
      if (cut - p.start >= minStintSlots && p.end - cut >= minStintSlots) {
        out.push({ start: p.start, end: cut }, { start: cut, end: p.end })
      }
    }
    return out
  }

  // ---- Phase D: coverage — the single best (period, block, function) each step ----
  const GUARD_LIMIT = 20000
  let guard = 0
  while (guard++ < GUARD_LIMIT) {
    let best: { p: Period; b: Block; fn: EngineFunction; sc: number } | null = null
    for (const p of periods) {
      for (const fn of functions) {
        if (!p.emp.trained.has(fn.id)) continue
        for (const b of blocksOf(p)) {
          if (!capRoom(fn, b.start, b.end)) continue
          if (!hasCountedUnmet(fn, b.start, b.end)) continue
          const sc = score(p.emp, b, fn)
          // Net-positive only: never burn a whole period on a sliver of unmet demand.
          if (sc > 0 && (!best || sc > best.sc)) best = { p, b, fn, sc }
        }
      }
    }
    if (!best) break
    commit(best.p.emp, best.fn, best.b.start, best.b.end, 'coverage')
    periods = periods.filter((x) => x !== best!.p)
    // The remainder of a split period stays as a period that can no longer be split.
    if (best.b.start > best.p.start) periods.push({ emp: best.p.emp, start: best.p.start, end: best.b.start, split: true })
    if (best.b.end < best.p.end) periods.push({ emp: best.p.emp, start: best.b.end, end: best.p.end, split: true })
  }
  if (guard >= GUARD_LIMIT) actions.push('The builder stopped early and the schedule may be incomplete. Please check it before using it.')

  // ---- Phase F: surplus — every remaining period gets one function, whole ----
  // Targets are a minimum, not a cap. Zero-target functions are eligible, so
  // someone trained only on TL or coordinator still gets a day.
  for (const p of periods) {
    const b: Block = { start: p.start, end: p.end }
    const eligible = functions.filter((f) => p.emp.trained.has(f.id) && capRoom(f, b.start, b.end))
    if (!eligible.length) continue
    const underTarget = eligible.filter((f) => hasCountedUnmet(f, b.start, b.end))
    const continuation = eligible.filter((f) => touches(p.emp, b.start, b.end, f.id) || distinctByEmp.get(p.emp.id)!.has(f.id))
    const overflow = eligible.filter((f) => f.isOverflow)
    let pool = underTarget
    let reason: EngineAssignment['reason'] = 'surplus-under-target'
    if (!pool.length && continuation.length) { pool = continuation; reason = 'surplus-continuation' }
    if (!pool.length && overflow.length) { pool = overflow; reason = 'surplus-overflow' }
    if (!pool.length) { pool = eligible; reason = 'surplus-continuation' }
    let bestFn: { fn: EngineFunction; sc: number } | null = null
    for (const fn of pool) {
      const sc = score(p.emp, b, fn)
      if (!bestFn || sc > bestFn.sc) bestFn = { fn, sc }
    }
    if (bestFn) commit(p.emp, bestFn.fn, b.start, b.end, reason)
  }

  // ---- Phase G/H: merge, then explain -------------------------------------
  const final = mergeAssignments(assignments)
  const { gaps, overTarget, actions: gapActions } = explainGaps(employees, functions, originallyFree)
  actions.push(...gapActions)

  // How many stretches ended up with two functions — the number this engine exists
  // to keep small. Only the startup-style split should remain.
  let switched = 0
  for (const p of originalPeriods) {
    const fns = new Set<string>()
    for (const a of final) if (a.employeeId === p.emp.id && a.startSlot < p.end && a.endSlot > p.start) fns.add(a.functionId)
    if (fns.size > 1) switched++
  }
  if (switched > 0) {
    warnings.push(
      `${switched} ${switched === 1 ? 'person changes' : 'people change'} job once between breaks (never for less than ${PERIOD_MIN_STINT_MINUTES} minutes). Everyone else keeps one job per stretch.`
    )
  }

  return {
    assignments: final,
    gaps,
    overTarget,
    feasibility,
    actions,
    warnings,
    stats: buildStats(employees, final),
  }
}
