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
  jobFunctions: any[],
  warnings: string[]
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

    // Distribute headcount evenly across children
    childFunctions.sort((a: any, b: any) => a.name.localeCompare(b.name))
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
  amAssigned: string | null  // job_function_id
  pmAssigned: string | null
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
      amAssigned: null,
      pmAssigned: null,
      trainedFunctionIds: trained,
    })
  }

  // Apply PTO adjustments: remove full-day employees, clip partial-day blocks
  if (Object.keys(ptoByEmployee).length > 0) {
    let fullDayCount = 0
    let partialDayCount = 0

    for (let i = empInfos.length - 1; i >= 0; i--) {
      const emp = empInfos[i]
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
  const expandedTargets = expandFanOutTargets(staffingTargets, jobFunctions, warnings)

  // Build demand matrix: { jf_id: { hour: headcount } }
  const demand: Record<string, Record<string, number>> = {}
  for (const t of expandedTargets) {
    if (!demand[t.job_function_id]) demand[t.job_function_id] = {}
    demand[t.job_function_id][t.hour_start] = t.headcount
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
      if ((jfDemand[h] || 0) > 0) total += jfDemand[h]
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

  // Helper: count training options for an employee (fewer = more constrained)
  const trainingCount = (emp: EmployeeScheduleInfo): number => emp.trainedFunctionIds.length

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

  // STEP 1: Assign required employees
  // Supports separate AM and PM functions via am_job_function_id / pm_job_function_id.
  // Falls back to job_function_id for both halves when specific halves aren't set.
  for (const emp of empInfos) {
    const preferred = preferredAssignmentsMap[emp.id]
    if (!preferred) continue

    for (const pa of Object.values(preferred)) {
      if (!pa?.is_required) continue

      // Determine the intended function for each half
      const amJfIdRaw: string = pa.am_job_function_id ?? pa.job_function_id
      const pmJfIdRaw: string = pa.pm_job_function_id ?? pa.job_function_id

      // Validate training for AM (using Meter parent lookup)
      if (!isTrainedFor(emp.id, amJfIdRaw, jobFunctions, trainingData)) continue

      // Resolve Meter parent → best child for each half (only if block has duration)
      if (emp.amEnd > emp.amStart) {
        const amJfId = resolveMeterChild(amJfIdRaw, emp.amStart, emp.amEnd)
        emp.amAssigned = amJfId
        decrementDemand(amJfId, emp.amStart, emp.amEnd)
      }

      if (emp.pmStart != null && emp.pmEnd != null) {
        const pmJfId = resolveMeterChild(pmJfIdRaw, emp.pmStart, emp.pmEnd)
        emp.pmAssigned = pmJfId
        decrementDemand(pmJfId, emp.pmStart, emp.pmEnd)
      }
      break // Only one required assignment record per employee
    }
  }

  // STEP 2: Assign remaining employees by demand — hour-by-hour greedy coverage.
  // Each iteration picks the most-constrained unassigned employee (fewest functions
  // with remaining demand they can cover), then assigns them to whichever function
  // fills the most unmet hours in their shift block.
  const assignHalf = (half: 'am' | 'pm') => {
    const skipped = new Set<string>() // employees with no fillable demand this pass
    let madeAssignment = true

    while (madeAssignment) {
      madeAssignment = false

      const unassigned = empInfos.filter(emp => {
        if (skipped.has(emp.id)) return false
        if (half === 'am') return emp.amAssigned == null
        return emp.pmAssigned == null && emp.pmStart != null
      })

      if (unassigned.length === 0) break

      // Score each employee: count functions with remaining demand they can cover
      const scored = unassigned.map(emp => {
        const start = half === 'am' ? emp.amStart : emp.pmStart!
        const end   = half === 'am' ? emp.amEnd   : emp.pmEnd!
        const hours = getHoursCovered(start, end)
        const options = Object.keys(demand).filter(jfId =>
          isTrainedFor(emp.id, jfId, jobFunctions, trainingData) &&
          hours.some(h => (demand[jfId]?.[h] ?? 0) > 0)
        )
        return { emp, start, end, hours, options }
      })

      // Most constrained first (fewest demand-relevant options)
      scored.sort((a, b) => a.options.length - b.options.length)

      const { emp, start, end, hours, options } = scored[0]

      if (options.length === 0) {
        skipped.add(emp.id)
        continue
      }

      // Pick the function where this employee fills the most remaining demand hours.
      // Preferred assignments get a large bonus to ensure they're respected.
      let bestJfId: string | null = null
      let bestScore = 0

      for (const jfId of options) {
        let score = 0
        for (const h of hours) {
          score += Math.max(0, demand[jfId]?.[h] ?? 0)
        }

        // Preferred assignment bonus
        if (preferredAssignmentsMap[emp.id]?.[jfId]) score += 10000

        // Meter parent preference bonus
        const jf = jobFunctions.find((j: any) => j.id === jfId)
        if (jf && /^Meter [0-9]+$/.test(jf.name || '')) {
          const parent = jobFunctions.find(
            (j: any) => j.name === 'Meter' && (jf.team_id == null || j.team_id === jf.team_id)
          )
          if (parent && preferredAssignmentsMap[emp.id]?.[parent.id]) score += 10000
        }

        if (score > bestScore) {
          bestScore = score
          bestJfId = jfId
        }
      }

      if (!bestJfId) {
        skipped.add(emp.id)
        continue
      }

      if (half === 'am') emp.amAssigned = bestJfId
      else emp.pmAssigned = bestJfId

      decrementDemand(bestJfId, start, end)
      madeAssignment = true
    }
  }

  assignHalf('am')
  assignHalf('pm')

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

  // STEP 4: Convert to schedule assignments
  const jfNameById = new Map<string, string>()
  for (const jf of jobFunctions) {
    jfNameById.set(jf.id, jf.name)
  }

  const schedule: ScheduleAssignment[] = []
  for (const emp of empInfos) {
    if (emp.amAssigned && emp.amEnd > emp.amStart) {
      const name = jfNameById.get(emp.amAssigned)
      if (name) {
        schedule.push({
          employee_id: emp.id,
          job_function: name,
          start_time: minutesToTime(emp.amStart),
          end_time: minutesToTime(emp.amEnd),
        })
      }
    }
    if (emp.pmAssigned && emp.pmStart != null && emp.pmEnd != null) {
      const name = jfNameById.get(emp.pmAssigned)
      if (name) {
        schedule.push({
          employee_id: emp.id,
          job_function: name,
          start_time: minutesToTime(emp.pmStart),
          end_time: minutesToTime(emp.pmEnd),
        })
      }
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
