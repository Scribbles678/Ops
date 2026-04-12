/**
 * Automated Schedule Builder Composable
 *
 * Two-halves algorithm: each employee gets an AM block (shift start → lunch)
 * and a PM block (lunch → shift end), with at most 2 job functions per day.
 * Driven by staffing_targets (headcount per function per hour).
 */

// ---------------------------------------------------------------------------
// Time utilities
// ---------------------------------------------------------------------------

const timeToMinutes = (time: string): number => {
  const parts = time.split(':').map(Number)
  return (parts[0] || 0) * 60 + (parts[1] || 0)
}

const minutesToTime = (minutes: number): string => {
  const h = Math.floor(minutes / 60)
  const m = minutes % 60
  return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}`
}

// ---------------------------------------------------------------------------
// Fan-out expansion (Meter → Meter 1, Meter 2, etc.)
// ---------------------------------------------------------------------------

interface StaffingTarget {
  job_function_id: string
  job_function_name: string
  hour_start: string
  headcount: number
}

const expandFanOutTargets = (
  targets: StaffingTarget[],
  jobFunctions: any[]
): StaffingTarget[] => {
  const expanded: StaffingTarget[] = []

  // Group targets by job_function_id
  const byFunction = new Map<string, StaffingTarget[]>()
  for (const t of targets) {
    if (!byFunction.has(t.job_function_id)) byFunction.set(t.job_function_id, [])
    byFunction.get(t.job_function_id)!.push(t)
  }

  for (const [jfId, fnTargets] of byFunction) {
    const jf = jobFunctions.find((j: any) => j.id === jfId)
    if (!jf) continue

    // Check if this function is a fan-out parent (e.g., "Meter" with children "Meter 1", "Meter 2")
    const childFunctions = jobFunctions.filter(
      (j: any) =>
        j.id !== jfId &&
        j.is_active !== false &&
        j.name &&
        j.name.startsWith(jf.name + ' ') &&
        /\d+$/.test(j.name)
    )

    if (childFunctions.length === 0) {
      // Not a fan-out parent, keep as-is
      expanded.push(...fnTargets)
      continue
    }

    // Distribute headcount evenly across children.
    // Sort numerically by the trailing digits so Meter 2 comes before Meter 10.
    // An alphabetical sort would put Meter 10 before Meter 2, misdirecting the
    // remainder when headcount doesn't divide evenly.
    const trailingNum = (name: string): number => {
      const m = /(\d+)$/.exec(name || '')
      return m && m[1] ? parseInt(m[1], 10) : 0
    }
    childFunctions.sort((a: any, b: any) => {
      const diff = trailingNum(a.name) - trailingNum(b.name)
      return diff !== 0 ? diff : (a.name || '').localeCompare(b.name || '')
    })
    for (const t of fnTargets) {
      const total = t.headcount
      const base = Math.floor(total / childFunctions.length)
      const remainder = total % childFunctions.length
      childFunctions.forEach((child: any, idx: number) => {
        expanded.push({
          job_function_id: child.id,
          job_function_name: child.name,
          hour_start: t.hour_start,
          headcount: base + (idx < remainder ? 1 : 0),
        })
      })
    }
  }

  return expanded
}

// ---------------------------------------------------------------------------
// Meter parent training lookup
// ---------------------------------------------------------------------------

const isTrainedFor = (
  employeeId: string,
  jobFunctionId: string,
  jobFunctions: any[],
  trainingData: Record<string, string[]>
): boolean => {
  const trained = trainingData[employeeId]
  if (!trained) return false
  if (trained.includes(jobFunctionId)) return true

  // For "Meter N", check if trained for parent "Meter"
  const jf = jobFunctions.find((j: any) => j.id === jobFunctionId)
  if (jf && /^Meter [0-9]+$/.test(jf.name || '')) {
    const parent = jobFunctions.find(
      (j: any) => j.name === 'Meter' && (jf.team_id == null || j.team_id === jf.team_id)
    )
    if (parent && trained.includes(parent.id)) return true
  }
  return false
}

// ---------------------------------------------------------------------------
// Core two-halves algorithm
// ---------------------------------------------------------------------------

interface EmployeeScheduleInfo {
  id: string
  shift_id: string
  shiftStart: number  // minutes
  shiftEnd: number
  lunchStart: number | null
  lunchEnd: number | null
  amStart: number
  amEnd: number
  pmStart: number | null
  pmEnd: number | null
  trainedFunctionIds: string[]
}

interface ScheduleAssignment {
  employee_id: string
  job_function: string  // name, for compatibility with applyAISchedule
  start_time: string
  end_time: string
}

interface Gap {
  job_function_name: string
  hour: string
  shortfall: number
}

const buildSchedule = (
  employees: any[],
  jobFunctions: any[],
  shifts: any[],
  trainingData: Record<string, string[]>,
  staffingTargets: StaffingTarget[],
  preferredAssignmentsMap: Record<string, Record<string, any>>,
  warnings: string[],
  ptoByEmployee: Record<string, any> = {}
): { schedule: ScheduleAssignment[]; gaps: Gap[] } => {
  const gaps: Gap[] = []

  // STEP 0: Prepare employee info
  const activeEmployees = employees.filter((e: any) => e.is_active !== false && e.shift_id)
  const empInfos: EmployeeScheduleInfo[] = []

  for (const emp of activeEmployees) {
    const shift = shifts.find((s: any) => s.id === emp.shift_id)
    if (!shift) continue

    const trained = trainingData[emp.id]
    if (!trained || trained.length === 0) continue

    const shiftStart = timeToMinutes(shift.start_time)
    const shiftEnd = timeToMinutes(shift.end_time)
    const lunchStart = shift.lunch_start ? timeToMinutes(shift.lunch_start) : null
    const lunchEnd = shift.lunch_end ? timeToMinutes(shift.lunch_end) : null

    empInfos.push({
      id: emp.id,
      shift_id: emp.shift_id,
      shiftStart,
      shiftEnd,
      lunchStart,
      lunchEnd,
      amStart: shiftStart,
      amEnd: lunchStart ?? shiftEnd,
      pmStart: lunchEnd ?? null,
      pmEnd: lunchEnd ? shiftEnd : null,
      trainedFunctionIds: trained,
    })
  }

  // Apply PTO adjustments: remove full-day employees, clip partial-day blocks
  if (Object.keys(ptoByEmployee).length > 0) {
    let fullDayCount = 0
    let partialDayCount = 0

    for (let i = empInfos.length - 1; i >= 0; i--) {
      const emp = empInfos[i]
      if (!emp) continue
      const pto = ptoByEmployee[emp.id]
      if (!pto) continue

      // Full-day PTO → exclude entirely
      if (pto.pto_type === 'full_day' || (!pto.start_time && !pto.end_time)) {
        empInfos.splice(i, 1)
        fullDayCount++
        continue
      }

      // Partial-day PTO → clip blocks
      if (pto.start_time && pto.end_time) {
        const ptoStart = timeToMinutes(pto.start_time)
        const ptoEnd = timeToMinutes(pto.end_time)

        // If PTO covers entire shift → treat as full-day
        if (ptoStart <= emp.shiftStart && ptoEnd >= emp.shiftEnd) {
          empInfos.splice(i, 1)
          fullDayCount++
          continue
        }

        // Clip AM block
        if (ptoStart <= emp.amStart && ptoEnd > emp.amStart) {
          // Late start: PTO covers beginning of AM block
          emp.amStart = Math.min(ptoEnd, emp.amEnd)
        } else if (ptoStart > emp.amStart && ptoStart < emp.amEnd) {
          // Early leave from AM: PTO cuts into end of AM block
          emp.amEnd = ptoStart
        }

        // Clip PM block if it exists
        if (emp.pmStart != null && emp.pmEnd != null) {
          if (ptoStart <= emp.pmStart && ptoEnd > emp.pmStart) {
            emp.pmStart = Math.min(ptoEnd, emp.pmEnd)
          } else if (ptoStart > emp.pmStart && ptoStart < emp.pmEnd) {
            emp.pmEnd = ptoStart
          }
          // Invalidate PM if too short (< 30 min)
          if (emp.pmEnd! - emp.pmStart! < 30) {
            emp.pmStart = null
            emp.pmEnd = null
          }
        }

        // Invalidate AM if too short (< 30 min) — zero-duration = skipped by algorithm
        if (emp.amEnd - emp.amStart < 30) {
          emp.amStart = emp.amEnd
        }

        // If both blocks are now empty → remove employee
        const amOk = emp.amEnd > emp.amStart
        const pmOk = emp.pmStart != null && emp.pmEnd != null
        if (!amOk && !pmOk) {
          empInfos.splice(i, 1)
          fullDayCount++
          continue
        }

        partialDayCount++
      }
    }

    if (fullDayCount > 0) {
      warnings.push(`${fullDayCount} employee(s) on PTO will not be scheduled.`)
    }
    if (partialDayCount > 0) {
      warnings.push(`${partialDayCount} employee(s) have adjusted hours due to partial-day PTO.`)
    }
  }

  // Expand fan-out targets
  // Normalize hour_start: DB returns "HH:MM:SS", algorithm uses "HH:MM"
  const normalizedTargets = staffingTargets.map(t => ({
    ...t,
    hour_start: typeof t.hour_start === 'string' && t.hour_start.length > 5
      ? t.hour_start.substring(0, 5)
      : t.hour_start,
  }))

  const expandedTargets = expandFanOutTargets(normalizedTargets, jobFunctions)

  // Build demand matrix: { jf_id: { hour: headcount } }
  const demand: Record<string, Record<string, number>> = {}
  for (const t of expandedTargets) {
    const slot = demand[t.job_function_id] ?? (demand[t.job_function_id] = {})
    slot[t.hour_start] = t.headcount
  }

  // Helper: get hours an employee covers in a given half
  const getHoursCovered = (start: number, end: number): string[] => {
    const hours: string[] = []
    // Each full hour that overlaps with the block
    const firstHour = Math.floor(start / 60) * 60
    for (let h = firstHour; h < end; h += 60) {
      if (h + 60 > start && h < end) {
        hours.push(minutesToTime(h))
      }
    }
    return hours
  }

  // Helper: compute how much demand an employee would fill for a function in a given half
  const computeDemandFilled = (jfId: string, start: number, end: number): number => {
    const jfDemand = demand[jfId]
    if (!jfDemand) return 0
    const hours = getHoursCovered(start, end)
    let total = 0
    for (const h of hours) {
      const v = jfDemand[h] ?? 0
      if (v > 0) total += v
    }
    return total
  }

  // Helper: decrement demand for hours an employee covers
  const decrementDemand = (jfId: string, start: number, end: number) => {
    const jfDemand = demand[jfId]
    if (!jfDemand) return
    const hours = getHoursCovered(start, end)
    for (const h of hours) {
      if (jfDemand[h] != null && jfDemand[h] > 0) {
        jfDemand[h]--
      }
    }
  }

  // Helper: resolve a job function ID — if it's a Meter parent, pick the child
  // with the highest remaining demand for the given time block.
  const resolveMeterChild = (jfId: string, blockStart: number, blockEnd: number): string => {
    const jf = jobFunctions.find((j: any) => j.id === jfId)
    if (!jf || jf.name !== 'Meter') return jfId
    const children = jobFunctions.filter(
      (j: any) => j.id !== jfId && j.is_active !== false && /^Meter [0-9]+$/.test(j.name || '') &&
        (jf.team_id == null || j.team_id === jf.team_id)
    )
    let bestChild = children[0]
    let bestDemand = -1
    for (const child of children) {
      const d = computeDemandFilled(child.id, blockStart, blockEnd)
      if (d > bestDemand) { bestDemand = d; bestChild = child }
    }
    return bestChild ? bestChild.id : jfId
  }

  // Core tracking structures for multi-block assignment
  const empAvailable = new Map<string, {start: number, end: number}[]>()
  const allAssignments: {empId: string, jfId: string, start: number, end: number}[] = []

  // Helper: pull non-null break windows (minutes) from a shift record.
  const getShiftBreaks = (shift: any): {start: number, end: number}[] => {
    if (!shift) return []
    const out: {start: number, end: number}[] = []
    if (shift.break_1_start && shift.break_1_end) {
      out.push({ start: timeToMinutes(shift.break_1_start), end: timeToMinutes(shift.break_1_end) })
    }
    if (shift.break_2_start && shift.break_2_end) {
      out.push({ start: timeToMinutes(shift.break_2_start), end: timeToMinutes(shift.break_2_end) })
    }
    return out
  }

  // Helper: split a [start, end] range around break windows, dropping segments < 30 min.
  // Used to carve breaks out of AM/PM blocks so employees aren't scheduled through breaks.
  const splitAroundBreaks = (
    start: number,
    end: number,
    breaks: {start: number, end: number}[]
  ): {start: number, end: number}[] => {
    if (end <= start) return []
    let segments: {start: number, end: number}[] = [{ start, end }]
    for (const b of breaks) {
      const next: {start: number, end: number}[] = []
      for (const s of segments) {
        if (b.end <= s.start || b.start >= s.end) {
          next.push(s)
        } else {
          if (b.start > s.start) next.push({ start: s.start, end: b.start })
          if (b.end < s.end) next.push({ start: b.end, end: s.end })
        }
      }
      segments = next
    }
    return segments.filter(s => s.end - s.start >= 30)
  }

  // Initialize empAvailable from each employee's shift blocks, minus breaks.
  for (const emp of empInfos) {
    const shift = shifts.find((s: any) => s.id === emp.shift_id)
    const breaks = getShiftBreaks(shift)
    const windows: {start: number, end: number}[] = []
    if (emp.amEnd > emp.amStart) windows.push(...splitAroundBreaks(emp.amStart, emp.amEnd, breaks))
    if (emp.pmStart != null && emp.pmEnd != null) {
      windows.push(...splitAroundBreaks(emp.pmStart, emp.pmEnd, breaks))
    }
    if (windows.length > 0) empAvailable.set(emp.id, windows)
  }

  // Helper: carve a used time window out of an employee's remaining availability
  const useEmpTime = (empId: string, aStart: number, aEnd: number) => {
    const windows = empAvailable.get(empId) ?? []
    const updated: {start: number, end: number}[] = []
    for (const w of windows) {
      if (aEnd <= w.start || aStart >= w.end) {
        updated.push(w)
      } else {
        if (aStart > w.start) updated.push({start: w.start, end: aStart})
        if (aEnd < w.end) updated.push({start: aEnd, end: w.end})
      }
    }
    if (updated.length === 0) empAvailable.delete(empId)
    else empAvailable.set(empId, updated)
  }

  // Helper: find first contiguous demand block for jfId within [wStart, wEnd]
  const findDemandWindow = (jfId: string, wStart: number, wEnd: number): {start: number, end: number} | null => {
    const jfDemand = demand[jfId]
    if (!jfDemand) return null
    let blockStart: number | null = null
    let blockEnd = 0
    for (const h of getHoursCovered(wStart, wEnd)) {
      const hMin = timeToMinutes(h)
      if ((jfDemand[h] ?? 0) > 0) {
        if (blockStart === null) blockStart = hMin
        blockEnd = hMin + 60
      } else if (blockStart !== null) {
        break // stop at first gap in demand
      }
    }
    if (blockStart === null) return null
    return {start: Math.max(wStart, blockStart), end: Math.min(wEnd, blockEnd)}
  }

  // STEP 1: Assign required employees (AM/PM blocks pinned to configured function,
  // split around breaks so the primary isn't "working" during their own break time).
  for (const emp of empInfos) {
    const preferred = preferredAssignmentsMap[emp.id]
    if (!preferred) continue

    for (const pa of Object.values(preferred)) {
      if (!pa?.is_required) continue

      const amJfIdRaw: string = pa.am_job_function_id ?? pa.job_function_id
      const pmJfIdRaw: string = pa.pm_job_function_id ?? pa.job_function_id

      if (!isTrainedFor(emp.id, amJfIdRaw, jobFunctions, trainingData)) continue

      const shift = shifts.find((s: any) => s.id === emp.shift_id)
      const breaks = getShiftBreaks(shift)

      if (emp.amEnd > emp.amStart) {
        for (const seg of splitAroundBreaks(emp.amStart, emp.amEnd, breaks)) {
          const amJfId = resolveMeterChild(amJfIdRaw, seg.start, seg.end)
          allAssignments.push({ empId: emp.id, jfId: amJfId, start: seg.start, end: seg.end })
          decrementDemand(amJfId, seg.start, seg.end)
          useEmpTime(emp.id, seg.start, seg.end)
        }
      }

      if (emp.pmStart != null && emp.pmEnd != null) {
        for (const seg of splitAroundBreaks(emp.pmStart, emp.pmEnd, breaks)) {
          const pmJfId = resolveMeterChild(pmJfIdRaw, seg.start, seg.end)
          allAssignments.push({ empId: emp.id, jfId: pmJfId, start: seg.start, end: seg.end })
          decrementDemand(pmJfId, seg.start, seg.end)
          useEmpTime(emp.id, seg.start, seg.end)
        }
      }
      break // only one required assignment record per employee
    }
  }

  // STEP 2: Multi-block demand assignment.
  // Each iteration picks the most-constrained employee (fewest demand-fillable function
  // options across all their remaining time windows), assigns them for exactly the first
  // contiguous demand block within their best window, then re-evaluates. This allows an
  // employee to receive multiple assignments per day — e.g. startup 6–8 AM, then pick
  // 8 AM–12 PM — so per-hour grid targets are strictly honored.
  interface CandidateOption {
    jfId: string
    demandWindow: {start: number, end: number}
    score: number
  }

  while (true) {
    const candidates: {empId: string, options: CandidateOption[]}[] = []

    for (const [empId, windows] of empAvailable) {
      const empOptions: CandidateOption[] = []

      for (const window of windows) {
        if (window.end - window.start < 30) continue

        for (const jfId of Object.keys(demand)) {
          if (!isTrainedFor(empId, jfId, jobFunctions, trainingData)) continue
          const dw = findDemandWindow(jfId, window.start, window.end)
          if (!dw || dw.end <= dw.start) continue

          let score = 0
          for (const h of getHoursCovered(dw.start, dw.end)) {
            score += demand[jfId]?.[h] ?? 0
          }
          if (score <= 0) continue

          // Preferred assignment bonus
          if (preferredAssignmentsMap[empId]?.[jfId]) score += 10000
          // Meter parent preferred bonus
          const jf = jobFunctions.find((j: any) => j.id === jfId)
          if (jf && /^Meter [0-9]+$/.test(jf.name || '')) {
            const parent = jobFunctions.find(
              (j: any) => j.name === 'Meter' && (jf.team_id == null || j.team_id === jf.team_id)
            )
            if (parent && preferredAssignmentsMap[empId]?.[parent.id]) score += 10000
          }

          empOptions.push({jfId, demandWindow: dw, score})
        }
      }

      if (empOptions.length > 0) {
        candidates.push({empId, options: empOptions})
      }
    }

    if (candidates.length === 0) break

    // Most constrained first (fewest distinct function options)
    candidates.sort((a, b) => a.options.length - b.options.length)
    const top = candidates[0]
    if (!top) break
    const {empId, options} = top

    // Best option: highest demand score
    options.sort((a: CandidateOption, b: CandidateOption) => b.score - a.score)
    const best = options[0]
    if (!best) break

    allAssignments.push({empId, jfId: best.jfId, start: best.demandWindow.start, end: best.demandWindow.end})
    decrementDemand(best.jfId, best.demandWindow.start, best.demandWindow.end)
    useEmpTime(empId, best.demandWindow.start, best.demandWindow.end)
  }

  // STEP 2.5: Lunch/break coverage pass.
  // For job functions flagged as lunch_coverage_required or break_coverage_required,
  // find another trained, available employee to cover the primary employee's lunch/break
  // window. Coverage assignments don't decrement demand (demand is already counted by the
  // primary assignment) — they just insert a short assignment so the function has continuous
  // coverage through the primary's lunch/break.

  interface CoverageGap {
    jfId: string
    primaryEmpId: string
    start: number
    end: number
    label: string // 'lunch', 'break 1', 'break 2'
  }

  const hasBreakOverlap = (shift: any, start: number, end: number): boolean => {
    if (!shift) return false
    const ranges: [any, any][] = [
      [shift.break_1_start, shift.break_1_end],
      [shift.break_2_start, shift.break_2_end],
    ]
    for (const [bs, be] of ranges) {
      if (!bs || !be) continue
      const bsMin = timeToMinutes(bs)
      const beMin = timeToMinutes(be)
      if (bsMin < end && beMin > start) return true
    }
    return false
  }

  // Find the best coverer for a gap — greedy pick of the longest overlap from empAvailable
  // that also doesn't fall on the coverer's own break time.
  const findCoverer = (
    jfId: string,
    gapStart: number,
    gapEnd: number,
    excludeEmpId: string
  ): { empId: string; coverStart: number; coverEnd: number } | null => {
    let best: { empId: string; coverStart: number; coverEnd: number } | null = null
    for (const [empId, windows] of empAvailable) {
      if (empId === excludeEmpId) continue
      if (!isTrainedFor(empId, jfId, jobFunctions, trainingData)) continue

      const covEmp = employees.find((e: any) => e?.id === empId)
      const covShift = covEmp ? shifts.find((s: any) => s.id === covEmp.shift_id) : null

      for (const w of windows) {
        const overlapS = Math.max(w.start, gapStart)
        const overlapE = Math.min(w.end, gapEnd)
        if (overlapE <= overlapS) continue
        // Skip if the coverer is on their own break during this overlap
        if (hasBreakOverlap(covShift, overlapS, overlapE)) continue
        if (!best || (overlapE - overlapS) > (best.coverEnd - best.coverStart)) {
          best = { empId, coverStart: overlapS, coverEnd: overlapE }
        }
      }
    }
    return best
  }

  // Build deduped set of gaps to cover
  const gapsSeen = new Set<string>()
  const gapsToFill: CoverageGap[] = []
  const empNameById = new Map<string, string>()
  for (const e of employees) {
    if (e?.id) empNameById.set(e.id, `${e.last_name || ''}, ${e.first_name || ''}`.trim().replace(/^,\s*/, ''))
  }

  for (const a of allAssignments) {
    const jf = jobFunctions.find((j: any) => j.id === a.jfId)
    if (!jf) continue
    if (!jf.lunch_coverage_required && !jf.break_coverage_required) continue

    const primary = employees.find((e: any) => e?.id === a.empId)
    const shift = primary ? shifts.find((s: any) => s.id === primary.shift_id) : null
    if (!shift) continue

    const candidateGaps: { start: number; end: number; label: string }[] = []
    if (jf.lunch_coverage_required && shift.lunch_start && shift.lunch_end) {
      candidateGaps.push({
        start: timeToMinutes(shift.lunch_start),
        end: timeToMinutes(shift.lunch_end),
        label: 'lunch',
      })
    }
    if (jf.break_coverage_required) {
      if (shift.break_1_start && shift.break_1_end) {
        candidateGaps.push({
          start: timeToMinutes(shift.break_1_start),
          end: timeToMinutes(shift.break_1_end),
          label: 'break 1',
        })
      }
      if (shift.break_2_start && shift.break_2_end) {
        candidateGaps.push({
          start: timeToMinutes(shift.break_2_start),
          end: timeToMinutes(shift.break_2_end),
          label: 'break 2',
        })
      }
    }

    for (const g of candidateGaps) {
      const key = `${a.jfId}|${a.empId}|${g.start}|${g.end}`
      if (gapsSeen.has(key)) continue
      gapsSeen.add(key)
      gapsToFill.push({ jfId: a.jfId, primaryEmpId: a.empId, start: g.start, end: g.end, label: g.label })
    }
  }

  // Fill each gap greedily
  for (const g of gapsToFill) {
    let remaining = g.start
    const jf = jobFunctions.find((j: any) => j.id === g.jfId)
    const primaryName = empNameById.get(g.primaryEmpId) || 'employee'

    while (remaining < g.end) {
      const found = findCoverer(g.jfId, remaining, g.end, g.primaryEmpId)
      if (!found) {
        warnings.push(
          `No coverage available for ${jf?.name || g.jfId} during ${primaryName}'s ${g.label} (${minutesToTime(remaining)}–${minutesToTime(g.end)})`
        )
        break
      }
      allAssignments.push({
        empId: found.empId,
        jfId: g.jfId,
        start: found.coverStart,
        end: found.coverEnd,
      })
      useEmpTime(found.empId, found.coverStart, found.coverEnd)
      remaining = found.coverEnd
    }
  }

  // STEP 3: Detect gaps
  for (const [jfId, hours] of Object.entries(demand)) {
    const jf = jobFunctions.find((j: any) => j.id === jfId)
    const jfName = jf?.name || jfId
    for (const [hour, count] of Object.entries(hours)) {
      if (count > 0) {
        gaps.push({ job_function_name: jfName, hour, shortfall: count })
        warnings.push(`Need ${count} more for ${jfName} at ${hour}`)
      }
    }
  }

  // STEP 4: Convert allAssignments to schedule output
  const jfNameById = new Map<string, string>()
  for (const jf of jobFunctions) {
    jfNameById.set(jf.id, jf.name)
  }

  const schedule: ScheduleAssignment[] = []
  for (const {empId, jfId, start, end} of allAssignments) {
    const name = jfNameById.get(jfId)
    if (name && end > start) {
      schedule.push({
        employee_id: empId,
        job_function: name,
        start_time: minutesToTime(start),
        end_time: minutesToTime(end),
      })
    }
  }

  return { schedule, gaps }
}

// ---------------------------------------------------------------------------
// Composable API
// ---------------------------------------------------------------------------

export function useAIScheduleBuilder() {
  const { fetchEmployees, getAllEmployeeTraining } = useEmployees()
  const { jobFunctions, fetchJobFunctions } = useJobFunctions()
  const { fetchShifts, replaceScheduleForDate } = useSchedule()
  const { fetchPreferredAssignments, getPreferredAssignmentsMap } = usePreferredAssignments()
  const { fetchTargets: fetchStaffingTargets } = useStaffingTargets()

  const generateAISchedule = async (scheduleDate: string = ''): Promise<{
    schedule: ScheduleAssignment[]
    warnings: string[]
    errors: string[]
    gaps: Gap[]
  }> => {
    const warnings: string[] = []
    const errors: string[] = []

    try {
      const [employeesData, jobFunctionsData, shiftsData, staffingTargetsData] = await Promise.all([
        fetchEmployees(),
        fetchJobFunctions(),
        fetchShifts(),
        fetchStaffingTargets(),
      ])
      await fetchPreferredAssignments()

      const employees = Array.isArray(employeesData) ? employeesData : []
      const jobFunctionsList = Array.isArray(jobFunctionsData) ? jobFunctionsData : []
      const shifts = Array.isArray(shiftsData) ? shiftsData : []
      const staffingTargets = Array.isArray(staffingTargetsData) ? staffingTargetsData : []

      const activeEmployees = employees.filter((e: any) => e && e.is_active !== false)
      const activeShifts = shifts.filter((s: any) => s && s.is_active !== false)

      if (!activeEmployees.length) errors.push('No active employees found.')
      if (!activeShifts.length) errors.push('No active shifts found.')
      if (!jobFunctionsList.length) errors.push('No job functions configured.')
      if (!staffingTargets.length) {
        errors.push('No staffing targets configured. Please set up staffing targets in the admin page.')
      }

      if (errors.length) return { schedule: [], warnings: [], errors, gaps: [] }

      const employeeIds = employees.filter((e: any) => e?.id).map((e: any) => e.id)
      let trainingData: Record<string, string[]> = {}
      try {
        trainingData = (await getAllEmployeeTraining(employeeIds)) || {}
      } catch (e: any) {
        errors.push(`Error loading employee training: ${e?.message || 'Unknown error'}`)
        return { schedule: [], warnings: [], errors, gaps: [] }
      }

      const employeesWithTraining = Object.keys(trainingData).filter(
        (id) => trainingData[id] && trainingData[id].length > 0
      )
      if (!employeesWithTraining.length) {
        errors.push('No employees have any job function training assigned.')
        return { schedule: [], warnings: [], errors, gaps: [] }
      }
      if (employeesWithTraining.length < activeEmployees.length) {
        warnings.push(
          `${activeEmployees.length - employeesWithTraining.length} employees have no training and will not be scheduled.`
        )
      }

      const employeesWithShifts = activeEmployees.filter((e: any) => e?.shift_id)
      if (!employeesWithShifts.length) {
        errors.push('No employees are assigned to shifts.')
        return { schedule: [], warnings: [], errors, gaps: [] }
      }
      if (employeesWithShifts.length < activeEmployees.length) {
        warnings.push(
          `${activeEmployees.length - employeesWithShifts.length} employees are not assigned to any shift.`
        )
      }

      const preferredAssignmentsMap = getPreferredAssignmentsMap()

      // Fetch PTO records for the schedule date
      let ptoByEmployee: Record<string, any> = {}
      if (scheduleDate) {
        try {
          const ptoDays = await $fetch<any[]>(`/api/pto/${scheduleDate}`)
          if (Array.isArray(ptoDays)) {
            for (const pto of ptoDays) {
              if (pto?.employee_id) ptoByEmployee[pto.employee_id] = pto
            }
          }
        } catch (e: any) {
          warnings.push(`Could not load PTO data: ${e?.message || 'Unknown error'}`)
        }
      }

      const { schedule, gaps } = buildSchedule(
        employees,
        jobFunctionsList,
        shifts,
        trainingData,
        staffingTargets,
        preferredAssignmentsMap,
        warnings,
        ptoByEmployee
      )

      if (!schedule.length) {
        errors.push('No schedule assignments could be created.')
      }

      return { schedule, warnings, errors, gaps }
    } catch (e: any) {
      errors.push(`Error occurred: ${e?.message || 'Unknown error'}`)
      return { schedule: [], warnings: [], errors, gaps: [] }
    }
  }

  const applyAISchedule = async (schedule: ScheduleAssignment[], scheduleDate: string) => {
    const [shiftsData, employeesData] = await Promise.all([fetchShifts(), fetchEmployees()])

    const employeeShiftMap = new Map<string, string | null>()
    if (Array.isArray(employeesData)) {
      employeesData.forEach((emp: any) => {
        if (emp?.id) employeeShiftMap.set(emp.id, emp.shift_id || null)
      })
    }

    const jfList = jobFunctions.value || []

    // Convert schedule items to assignment records — surface any mapping failures
    const dropped: string[] = []
    const assignments = schedule
      .map((a) => {
        const jf = jfList.find((jf: any) => jf.name === a.job_function) as any
        if (!jf) {
          dropped.push(`Unknown job function "${a.job_function}"`)
          return null
        }
        const shiftId = employeeShiftMap.get(a.employee_id)
        const shift = shiftId
          ? (shiftsData || []).find((s: any) => s.id === shiftId)
          : null
        if (!shift) {
          dropped.push(`Employee ${a.employee_id} has no valid shift assigned`)
          return null
        }
        return {
          employee_id: a.employee_id,
          job_function_id: jf.id,
          shift_id: shift.id,
          start_time: a.start_time,
          end_time: a.end_time,
          schedule_date: scheduleDate,
        }
      })
      .filter(Boolean) as any[]

    if (dropped.length > 0) {
      const preview = dropped.slice(0, 5).join('\n')
      const extra = dropped.length > 5 ? `\n...and ${dropped.length - 5} more` : ''
      throw new Error(`${dropped.length} assignment(s) could not be applied:\n${preview}${extra}`)
    }

    // Use atomic replace (delete existing + insert new in one transaction)
    const result = await replaceScheduleForDate(scheduleDate, assignments)
    if (!result) throw new Error('Failed to save schedule')
  }

  return { generateAISchedule, applyAISchedule }
}
