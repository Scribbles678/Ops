/**
 * Schedule Engine V2 — a 15-minute-resolution scheduler.
 *
 * Why this exists: V1 models coverage in hourly buckets. When a whole shift takes
 * its break together (measured: 26 of 28 people at 19:00-19:15), coverage collapses
 * for one 15-minute slot and recovers. Averaged over the hour it looks fine, so an
 * hourly engine never sees the hole — and V1's 30-minute floor could not have filled
 * it anyway.
 *
 * Design stance: V2 works at 15-minute RESOLUTION but optimises for CONTIGUITY.
 * Short blocks are expensive and appear essentially only in phase E, where they
 * patch a cliff nothing longer can reach. The goal remains 2-3 functions per person
 * in long stretches.
 *
 * This module is pure and fully exported — every function here is unit-testable
 * without a database, a browser or Nuxt.
 */
import {
  DEFAULT_WEIGHTS,
  ENGINE_MIN_BLOCK_MINUTES,
  LOWEST_PRIORITY,
  PREFERRED_MIN_MINUTES,
  SLOTS_PER_DAY,
  SLOT_MINUTES,
  type EngineAssignment,
  type EngineEmployee,
  type EngineFunction,
  type EngineGap,
  type EngineResult,
  type EngineWeights,
  type FeasibilityIssue,
} from './types'
import { longestFreeRun, runsWhere, slotToTime, slotsToMinutesLength } from './slots'

export interface EngineInput {
  employees: EngineEmployee[]
  functions: EngineFunction[]
  /** employeeId -> Set of functionIds they prefer. */
  preferred: Map<string, Set<string>>
  /** Pre-resolved required pins (phase B input). */
  requiredPins: { employeeId: string; functionId: string; startSlot: number; endSlot: number }[]
  weights?: EngineWeights
}

// ---------------------------------------------------------------------------
// Phase C — feasibility (runs BEFORE any assignment)
// ---------------------------------------------------------------------------

/**
 * For every slot with demand, compare it against the trained people actually free.
 * Emits "19:00 needs 19, only 2 trained people are available" up front, which is
 * the diagnostic that would have surfaced the break cliff months ago.
 */
export function analyseFeasibility(
  employees: EngineEmployee[],
  functions: EngineFunction[]
): FeasibilityIssue[] {
  const issues: FeasibilityIssue[] = []

  for (const fn of functions) {
    // Collapse consecutive slots with the same shortfall into one issue.
    let runStart = -1
    let runRequired = 0
    let runAvailable = 0

    const flush = (endSlot: number) => {
      if (runStart < 0) return
      issues.push({
        functionName: fn.name,
        time: `${slotToTime(runStart)}–${slotToTime(endSlot)}`,
        required: runRequired,
        trainedAvailable: runAvailable,
        detail:
          runAvailable === 0
            ? `nobody trained for ${fn.name} is available`
            : `needs ${runRequired}, only ${runAvailable} trained ${runAvailable === 1 ? 'person is' : 'people are'} free`,
      })
      runStart = -1
    }

    for (let s = 0; s < SLOTS_PER_DAY; s++) {
      const need = fn.demand[s] ?? 0
      if (need <= 0) { flush(s); continue }
      let avail = 0
      for (const e of employees) if (e.trained.has(fn.id) && e.free[s] === 1) avail++
      if (avail >= need) { flush(s); continue }
      if (runStart < 0) { runStart = s; runRequired = need; runAvailable = avail }
      else { runRequired = Math.max(runRequired, need); runAvailable = Math.min(runAvailable, avail) }
    }
    flush(SLOTS_PER_DAY)
  }

  return issues
}

// ---------------------------------------------------------------------------
// Cost function — the single place every trade-off lives
// ---------------------------------------------------------------------------

interface CandidateContext {
  employee: EngineEmployee
  fn: EngineFunction
  startSlot: number
  endSlot: number
  distinctFunctions: Set<string>
  hasAdjacent: boolean
  preferred: boolean
}

/** Higher is better. Returns -Infinity for inadmissible candidates. */
export function scoreCandidate(ctx: CandidateContext, w: EngineWeights): number {
  const { fn, startSlot, endSlot, distinctFunctions } = ctx
  const minutes = slotsToMinutesLength(startSlot, endSlot)
  if (minutes < ENGINE_MIN_BLOCK_MINUTES) return -Infinity

  // How much genuine unmet demand this run closes.
  let unmetClosed = 0
  for (let s = startSlot; s < endSlot; s++) {
    if ((fn.covered[s] ?? 0) < (fn.demand[s] ?? 0)) unmetClosed++
  }

  let score = unmetClosed * w.unmet

  // Slots consumed that were already covered. Penalising these stops the engine
  // spending a whole shift on a function that only needed its first hour.
  const wasted = endSlot - startSlot - unmetClosed
  score -= wasted * w.waste

  // Spend specialists before generalists: a person trained on two functions can
  // only ever plug two kinds of hole, so using the eleven-function person here
  // costs the schedule its flexibility for the next one.
  score -= ctx.employee.trained.size * w.flexibility

  const isNewFunction = !distinctFunctions.has(fn.id)
  if (isNewFunction) {
    score -= w.newFunction
    const projected = distinctFunctions.size + 1
    const excess = Math.max(0, projected - w.comfortableFunctions)
    score -= excess * excess * w.functionCount
  }

  // Short blocks are expensive — this is what keeps 15-minute assignments rare.
  if (minutes < PREFERRED_MIN_MINUTES) score -= (PREFERRED_MIN_MINUTES - minutes) * w.shortBlock

  if (ctx.hasAdjacent) score += w.adjacent
  if (ctx.preferred) score += w.preferred

  // Prefer hard-to-staff functions while their scarce people are still free.
  score += (1 - Math.min(1, fn.scarcity)) * w.scarce

  // Business priority. Without this the engine only knows how hard a function is
  // to staff, not how much the floor cares about it — which is how a low-value
  // function can win a scarce person from a high-value one.
  score += (LOWEST_PRIORITY - fn.priority) * w.priority

  // Mild preference for longer runs at equal value.
  score += minutes / 60

  return score
}

// ---------------------------------------------------------------------------
// The engine
// ---------------------------------------------------------------------------

export function runEngine(input: EngineInput): EngineResult {
  const w = input.weights ?? DEFAULT_WEIGHTS
  const { employees, functions, preferred } = input
  const warnings: string[] = []
  const assignments: EngineAssignment[] = []

  const fnById = new Map(functions.map((f) => [f.id, f]))
  const empById = new Map(employees.map((e) => [e.id, e]))
  const distinctByEmp = new Map<string, Set<string>>(employees.map((e) => [e.id, new Set<string>()]))

  // Snapshot availability BEFORE anything is assigned. Without this the gap
  // explanations can't tell "everyone was on break" from "everyone was busy" —
  // both look identical once `free` has been consumed by assignment.
  const originallyFree = new Map(employees.map((e) => [e.id, Uint8Array.from(e.free)]))

  // ---- Phase C: feasibility, before anything is decided --------------------
  const feasibility = analyseFeasibility(employees, functions)

  // ---- helpers -------------------------------------------------------------
  const capRoom = (fn: EngineFunction, start: number, end: number): boolean => {
    if (fn.maxHeadcount == null) return true
    for (let s = start; s < end; s++) if ((fn.covered[s] ?? 0) >= fn.maxHeadcount) return false
    return true
  }

  const commit = (
    emp: EngineEmployee,
    fn: EngineFunction,
    start: number,
    end: number,
    reason: EngineAssignment['reason']
  ) => {
    for (let s = start; s < end; s++) {
      emp.free[s] = 0
      fn.covered[s] = (fn.covered[s] ?? 0) + 1
    }
    assignments.push({ employeeId: emp.id, functionId: fn.id, startSlot: start, endSlot: end, reason })
    distinctByEmp.get(emp.id)!.add(fn.id)
  }

  const hasAdjacent = (empId: string, fnId: string, start: number, end: number): boolean =>
    assignments.some(
      (a) => a.employeeId === empId && a.functionId === fnId && (a.endSlot === start || a.startSlot === end)
    )

  // ---- Phase B: required pins ---------------------------------------------
  for (const pin of input.requiredPins) {
    const emp = empById.get(pin.employeeId)
    const fn = fnById.get(pin.functionId)
    if (!emp || !fn) continue

    // A required assignment does NOT override training. The database enforces
    // training with a trigger, so honouring such a pin would build a schedule
    // that cannot be saved at all — one bad pin failed the entire write.
    // Skip it and say so, rather than poisoning the whole day.
    if (!emp.trained.has(fn.id)) {
      warnings.push(
        `${emp.name} has a required assignment for "${fn.name}" but is not trained for it — the pin was skipped. Add the training or remove the required assignment.`
      )
      continue
    }
    // Only the parts of the pin the employee is actually free for.
    for (const run of runsWhere(SLOTS_PER_DAY, (s) => s >= pin.startSlot && s < pin.endSlot && emp.free[s] === 1)) {
      if (slotsToMinutesLength(run.start, run.end) < ENGINE_MIN_BLOCK_MINUTES) continue
      commit(emp, fn, run.start, run.end, 'required-pin')
    }
  }

  // ---- Phase D: coverage fill, scarcest function first ---------------------
  // Repeat until no positive-value move exists. Each round re-sorts, because
  // filling one function changes what is scarce.
  let guard = 0
  const GUARD_LIMIT = 20000
  let progressed = true

  while (progressed && guard++ < GUARD_LIMIT) {
    progressed = false
    // Business priority leads; scarcity breaks ties inside a priority band, so
    // hard-to-staff roles are still protected relative to their peers.
    const ordered = [...functions]
      .filter((f) => f.demand.some((d) => d > 0))
      .sort((a, b) => a.priority - b.priority || a.scarcity - b.scarcity)

    for (const fn of ordered) {
      const unmetRuns = runsWhere(SLOTS_PER_DAY, (s) => (fn.covered[s] ?? 0) < (fn.demand[s] ?? 0))
      if (!unmetRuns.length) continue

      // HARDEST run first, not longest.
      //
      // Measured failure this fixes: V2 used to fill the easy multi-hour runs
      // first, committing everyone to long blocks, and then had nobody free for
      // the 15 minutes when a whole shift was on break. Every cell V2 lost to V1
      // sat on a break or lunch boundary (13:45, 16:00, 19:00 …).
      //
      // A run only a handful of people can cover has to be claimed while those
      // people are still free; the long easy runs will still find someone later.
      const candidateCount = (run: { start: number; end: number }): number => {
        let n = 0
        for (const emp of employees) {
          if (!emp.trained.has(fn.id)) continue
          for (let s = run.start; s < run.end; s++) {
            if (emp.free[s] === 1) { n++; break }
          }
        }
        return n
      }
      const difficulty = new Map(unmetRuns.map((r) => [r, candidateCount(r)]))
      unmetRuns.sort(
        (a, b) => (difficulty.get(a)! - difficulty.get(b)!) || (b.end - b.start - (a.end - a.start))
      )

      for (const gapRun of unmetRuns) {
        let best: { emp: EngineEmployee; start: number; end: number; score: number } | null = null

        for (const emp of employees) {
          if (!emp.trained.has(fn.id)) continue
          const run = longestFreeRun(emp.free, gapRun.start, gapRun.end)
          if (!run) continue
          // Short runs are allowed here rather than deferred: the cost function's
          // short-block penalty keeps them rare, but deferring them meant the
          // critical break-boundary slots were never fillable at all.
          if (slotsToMinutesLength(run.start, run.end) < ENGINE_MIN_BLOCK_MINUTES) continue
          if (!capRoom(fn, run.start, run.end)) continue

          const score = scoreCandidate(
            {
              employee: emp,
              fn,
              startSlot: run.start,
              endSlot: run.end,
              distinctFunctions: distinctByEmp.get(emp.id)!,
              hasAdjacent: hasAdjacent(emp.id, fn.id, run.start, run.end),
              preferred: preferred.get(emp.id)?.has(fn.id) ?? false,
            },
            w
          )
          if (score > -Infinity && (!best || score > best.score)) {
            best = { emp, start: run.start, end: run.end, score }
          }
        }

        if (best) {
          commit(best.emp, fn, best.start, best.end, 'coverage')
          progressed = true
          break // re-evaluate scarcity after every placement
        }
      }
      if (progressed) break
    }
  }
  if (guard >= GUARD_LIMIT) warnings.push('Coverage fill hit its iteration limit; the schedule may be incomplete.')

  // ---- Phase E: cliff patching --------------------------------------------
  // The new capability. Whatever unmet runs remain are shorter than the preferred
  // minimum — the break/lunch cliffs. Fill them with short blocks, accepting the
  // cost penalty, because a covered 15 minutes beats an open hole.
  let cliffPatches = 0
  // Same priority-then-scarcity order as phase D: whatever labour is left over
  // after coverage should patch the cliffs that matter most first.
  const cliffOrder = [...functions].sort((a, b) => a.priority - b.priority || a.scarcity - b.scarcity)
  for (const fn of cliffOrder) {
    if (!fn.demand.some((d) => d > 0)) continue
    for (const gapRun of runsWhere(SLOTS_PER_DAY, (s) => (fn.covered[s] ?? 0) < (fn.demand[s] ?? 0))) {
      let filled = true
      while (filled) {
        filled = false
        let best: { emp: EngineEmployee; start: number; end: number; score: number } | null = null
        for (const emp of employees) {
          if (!emp.trained.has(fn.id)) continue
          const run = longestFreeRun(emp.free, gapRun.start, gapRun.end)
          if (!run) continue
          if (slotsToMinutesLength(run.start, run.end) < ENGINE_MIN_BLOCK_MINUTES) continue
          if (!capRoom(fn, run.start, run.end)) continue
          const score = scoreCandidate(
            {
              employee: emp,
              fn,
              startSlot: run.start,
              endSlot: run.end,
              distinctFunctions: distinctByEmp.get(emp.id)!,
              hasAdjacent: hasAdjacent(emp.id, fn.id, run.start, run.end),
              preferred: preferred.get(emp.id)?.has(fn.id) ?? false,
            },
            w
          )
          if (score > -Infinity && (!best || score > best.score)) {
            best = { emp, start: run.start, end: run.end, score }
          }
        }
        if (best) {
          commit(best.emp, fn, best.start, best.end, 'cliff-patch')
          cliffPatches++
          filled = true
        }
      }
    }
  }

  // ---- Phase F: surplus deployment ----------------------------------------
  // Unlike V1, ZERO-TARGET functions are eligible here. In V1 anyone trained only
  // on such a function (TL, coordinator) got a silently empty day — reproduced
  // against the real engine during the audit.
  let surplusGuard = 0
  progressed = true
  while (progressed && surplusGuard++ < GUARD_LIMIT) {
    progressed = false
    for (const emp of employees) {
      const run = longestFreeRun(emp.free, 0, SLOTS_PER_DAY)
      if (!run) continue
      if (slotsToMinutesLength(run.start, run.end) < PREFERRED_MIN_MINUTES) continue

      const distinct = distinctByEmp.get(emp.id)!
      const eligible = functions.filter(
        (f) => emp.trained.has(f.id) && capRoom(f, run.start, run.end)
      )
      if (!eligible.length) { for (let s = run.start; s < run.end; s++) emp.free[s] = 0; continue }

      const underTarget = eligible.filter((f) => {
        for (let s = run.start; s < run.end; s++) if ((f.covered[s] ?? 0) < (f.demand[s] ?? 0)) return true
        return false
      })
      const overflow = eligible.filter((f) => f.isOverflow)
      const continuation = eligible.filter((f) => distinct.has(f.id))

      let pool = underTarget
      let reason: EngineAssignment['reason'] = 'surplus-under-target'
      if (!pool.length && overflow.length) { pool = overflow; reason = 'surplus-overflow' }
      if (!pool.length && continuation.length) { pool = continuation; reason = 'surplus-continuation' }
      if (!pool.length) { pool = eligible; reason = 'surplus-continuation' }

      let best: { fn: EngineFunction; score: number } | null = null
      for (const fn of pool) {
        const score = scoreCandidate(
          {
            employee: emp,
            fn,
            startSlot: run.start,
            endSlot: run.end,
            distinctFunctions: distinct,
            hasAdjacent: hasAdjacent(emp.id, fn.id, run.start, run.end),
            preferred: preferred.get(emp.id)?.has(fn.id) ?? false,
          },
          w
        )
        if (score > -Infinity && (!best || score > best.score)) best = { fn, score }
      }
      if (best) {
        commit(emp, best.fn, run.start, run.end, reason)
        progressed = true
      } else {
        for (let s = run.start; s < run.end; s++) emp.free[s] = 0
      }
    }
  }

  // ---- Phase G: merge touching blocks --------------------------------------
  assignments.sort((a, b) =>
    a.employeeId === b.employeeId
      ? a.functionId === b.functionId
        ? a.startSlot - b.startSlot
        : a.functionId.localeCompare(b.functionId)
      : a.employeeId.localeCompare(b.employeeId)
  )
  const merged: EngineAssignment[] = []
  for (const a of assignments) {
    const prev = merged[merged.length - 1]
    if (prev && prev.employeeId === a.employeeId && prev.functionId === a.functionId && prev.endSlot === a.startSlot) {
      prev.endSlot = a.endSlot
    } else {
      merged.push({ ...a })
    }
  }

  // Drop anything still under the hard minimum (defensive — the DB enforces it too).
  const final = merged.filter(
    (a) => slotsToMinutesLength(a.startSlot, a.endSlot) >= ENGINE_MIN_BLOCK_MINUTES
  )
  if (final.length !== merged.length) {
    warnings.push(`${merged.length - final.length} assignment(s) under ${ENGINE_MIN_BLOCK_MINUTES} minutes were dropped.`)
  }

  // ---- Phase H: gaps, over-target, explanations ---------------------------
  //
  // Was the whole floor short at this moment? Total demand across every function
  // versus every person actually available. When that is negative, the shortfall
  // is arithmetic, not allocation — no schedule can fix it, and it should not be
  // presented to a supervisor as something to act on. This is the same test the
  // Coverage Preview uses for its "impossible" figure.
  const totalDemandAt = new Int16Array(SLOTS_PER_DAY)
  const totalFreeAt = new Int16Array(SLOTS_PER_DAY)
  for (const fn of functions) {
    for (let s = 0; s < SLOTS_PER_DAY; s++) totalDemandAt[s] += fn.demand[s] ?? 0
  }
  for (const e of employees) {
    const base = originallyFree.get(e.id)!
    for (let s = 0; s < SLOTS_PER_DAY; s++) if (base[s] === 1) totalFreeAt[s]++
  }
  const floorWasShort = (start: number, end: number): boolean => {
    for (let s = start; s < end; s++) {
      if ((totalDemandAt[s] ?? 0) > (totalFreeAt[s] ?? 0)) return true
    }
    return false
  }

  const gaps: EngineGap[] = []
  const overTarget: { functionName: string; time: string; surplus: number }[] = []

  for (const fn of functions) {
    for (const run of runsWhere(SLOTS_PER_DAY, (s) => (fn.covered[s] ?? 0) < (fn.demand[s] ?? 0))) {
      let shortfall = 0
      for (let s = run.start; s < run.end; s++) {
        shortfall = Math.max(shortfall, (fn.demand[s] ?? 0) - (fn.covered[s] ?? 0))
      }
      // Explain it, using the pre-assignment snapshot so "on break" is not
      // mistaken for "busy".
      let trainedAnyone = 0        // trained for this function at all
      let trainedOnFloor = 0       // trained AND rostered-and-free at some point in the run
      let trainedStillFree = 0     // trained AND still unassigned now
      for (const e of employees) {
        if (!e.trained.has(fn.id)) continue
        trainedAnyone++
        const base = originallyFree.get(e.id)!
        let onFloor = false
        let stillFree = false
        for (let s = run.start; s < run.end; s++) {
          if (base[s] === 1) onFloor = true
          if (e.free[s] === 1) stillFree = true
        }
        if (onFloor) trainedOnFloor++
        if (stillFree) trainedStillFree++
      }

      let cause: EngineGap['cause']
      let detail: string
      if (trainedAnyone === 0) {
        cause = 'no-one-trained-on-shift'
        detail = `nobody is trained for ${fn.name}`
      } else if (floorWasShort(run.start, run.end)) {
        // Arithmetic, not allocation: more work is being asked for than there are
        // people present. Usually a whole shift on break, or a target set for an
        // hour nobody is rostered.
        cause = 'no-one-trained-on-shift'
        detail = `the whole floor is short at this time — more staffing is being asked for than there are people available`
      } else if (trainedOnFloor === 0) {
        // The decisive case: they exist, but not one of them is on the floor for
        // any part of this window — a break, a lunch, or outside shift hours.
        cause = 'no-one-trained-on-shift'
        detail = `nobody trained for ${fn.name} is on the floor then — break, lunch, or outside shift hours`
      } else if (fn.maxHeadcount != null && !capRoom(fn, run.start, run.end)) {
        cause = 'capped'
        detail = `${fn.name} is at its max headcount of ${fn.maxHeadcount}`
      } else if (trainedStillFree > 0) {
        cause = 'no-availability'
        detail = `${trainedStillFree} trained staff free but the remaining window is too short to assign`
      } else {
        cause = 'all-trained-busy'
        detail = `all ${trainedOnFloor} trained staff on the floor are already on other work`
      }

      gaps.push({
        functionId: fn.id,
        functionName: fn.name,
        time: `${slotToTime(run.start)}–${slotToTime(run.end)}`,
        startSlot: run.start,
        endSlot: run.end,
        shortfall,
        cause,
        detail,
      })
    }

    if (!fn.excludeFromTargets) {
      for (const run of runsWhere(SLOTS_PER_DAY, (s) => (fn.covered[s] ?? 0) > (fn.demand[s] ?? 0) && (fn.demand[s] ?? 0) > 0)) {
        let surplus = 0
        for (let s = run.start; s < run.end; s++) {
          surplus = Math.max(surplus, (fn.covered[s] ?? 0) - (fn.demand[s] ?? 0))
        }
        overTarget.push({ functionName: fn.name, time: `${slotToTime(run.start)}–${slotToTime(run.end)}`, surplus })
      }
    }
  }

  // ---- stats ---------------------------------------------------------------
  const assignedByEmp = new Map<string, number>()
  const fnsByEmp = new Map<string, Set<string>>()
  for (const a of final) {
    assignedByEmp.set(a.employeeId, (assignedByEmp.get(a.employeeId) ?? 0) + (a.endSlot - a.startSlot))
    if (!fnsByEmp.has(a.employeeId)) fnsByEmp.set(a.employeeId, new Set())
    fnsByEmp.get(a.employeeId)!.add(a.functionId)
  }
  let slotsAvailable = 0
  let employeesWithNoWork = 0
  const functionsPerPerson: Record<number, number> = {}
  for (const e of employees) {
    slotsAvailable += e.onClockSlots
    const n = fnsByEmp.get(e.id)?.size ?? 0
    functionsPerPerson[n] = (functionsPerPerson[n] ?? 0) + 1
    if (n === 0 && e.onClockSlots > 0) employeesWithNoWork++
  }
  const slotsAssigned = [...assignedByEmp.values()].reduce((s, n) => s + n, 0)
  const shortBlocks = final.filter(
    (a) => slotsToMinutesLength(a.startSlot, a.endSlot) < PREFERRED_MIN_MINUTES
  ).length

  if (cliffPatches > 0) {
    warnings.push(`${cliffPatches} short coverage block(s) were used to patch break/lunch cliffs.`)
  }

  return {
    assignments: final,
    gaps,
    overTarget,
    feasibility,
    warnings,
    stats: {
      slotsAvailable,
      slotsAssigned,
      idleSlots: Math.max(0, slotsAvailable - slotsAssigned),
      employeesWithNoWork,
      functionsPerPerson,
      shortBlocks,
    },
  }
}
