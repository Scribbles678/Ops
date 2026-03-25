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
  warnings: string[]
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

  // STEP 1: Assign required employees
  for (const emp of empInfos) {
    const preferred = preferredAssignmentsMap[emp.id]
    if (!preferred) continue

    for (const pa of Object.values(preferred)) {
      if (!pa?.is_required) continue

      const jfId = pa.job_function_id
      // Check if trained (including Meter parent lookup)
      if (!isTrainedFor(emp.id, jfId, jobFunctions, trainingData)) continue

      // For Meter parent requirement, find actual child function to assign
      const jf = jobFunctions.find((j: any) => j.id === jfId)
      let assignJfId = jfId
      if (jf && jf.name === 'Meter') {
        // Find a Meter N child that has demand
        const children = jobFunctions.filter(
          (j: any) => j.id !== jfId && j.is_active !== false && /^Meter [0-9]+$/.test(j.name || '') &&
            (jf.team_id == null || j.team_id === jf.team_id)
        )
        // Pick the child with highest remaining demand
        let bestChild = children[0]
        let bestDemand = -1
        for (const child of children) {
          const d = computeDemandFilled(child.id, emp.amStart, emp.amEnd)
          if (d > bestDemand) { bestDemand = d; bestChild = child }
        }
        if (bestChild) assignJfId = bestChild.id
      }

      emp.amAssigned = assignJfId
      decrementDemand(assignJfId, emp.amStart, emp.amEnd)

      if (emp.pmStart != null && emp.pmEnd != null) {
        emp.pmAssigned = assignJfId
        decrementDemand(assignJfId, emp.pmStart, emp.pmEnd)
      }
      break // Only one required assignment per employee
    }
  }

  // STEP 2: Assign remaining employees by demand (AM pass, then PM pass)
  const assignHalf = (half: 'am' | 'pm') => {
    // Get all functions with remaining demand for this half
    const functionDemands: { jfId: string; totalDemand: number }[] = []
    for (const [jfId, hours] of Object.entries(demand)) {
      let total = 0
      for (const [, count] of Object.entries(hours)) {
        if (count > 0) total += count
      }
      if (total > 0) functionDemands.push({ jfId, totalDemand: total })
    }
    // Sort by highest demand first
    functionDemands.sort((a, b) => b.totalDemand - a.totalDemand)

    for (const { jfId } of functionDemands) {
      // Find unassigned employees for this half who are trained
      const candidates = empInfos.filter((emp) => {
        if (half === 'am' && emp.amAssigned != null) return false
        if (half === 'pm' && (emp.pmAssigned != null || emp.pmStart == null)) return false
        return isTrainedFor(emp.id, jfId, jobFunctions, trainingData)
      })

      if (candidates.length === 0) continue

      // Sort: preferred first, then most-constrained (fewest training options)
      candidates.sort((a, b) => {
        const aPref = preferredAssignmentsMap[a.id]?.[jfId]
        const bPref = preferredAssignmentsMap[b.id]?.[jfId]
        // Check Meter parent preferred too
        const jf = jobFunctions.find((j: any) => j.id === jfId)
        let aHasPref = !!aPref
        let bHasPref = !!bPref
        if (jf && /^Meter [0-9]+$/.test(jf.name || '')) {
          const parent = jobFunctions.find(
            (j: any) => j.name === 'Meter' && (jf.team_id == null || j.team_id === jf.team_id)
          )
          if (parent) {
            if (!aHasPref && preferredAssignmentsMap[a.id]?.[parent.id]) aHasPref = true
            if (!bHasPref && preferredAssignmentsMap[b.id]?.[parent.id]) bHasPref = true
          }
        }
        if (aHasPref && !bHasPref) return -1
        if (!aHasPref && bHasPref) return 1
        // Most constrained first
        return trainingCount(a) - trainingCount(b)
      })

      // Determine how many we need for this function in this half
      const jfDemand = demand[jfId] || {}
      let needed = 0
      for (const [, count] of Object.entries(jfDemand)) {
        if (count > needed) needed = count  // peak demand
      }

      // Count already assigned for this function in this half
      let alreadyAssigned = 0
      for (const emp of empInfos) {
        if (half === 'am' && emp.amAssigned === jfId) alreadyAssigned++
        if (half === 'pm' && emp.pmAssigned === jfId) alreadyAssigned++
      }

      const toFill = needed - alreadyAssigned
      if (toFill <= 0) continue

      let filled = 0
      for (const emp of candidates) {
        if (filled >= toFill) break

        const start = half === 'am' ? emp.amStart : emp.pmStart!
        const end = half === 'am' ? emp.amEnd : emp.pmEnd!

        if (half === 'am') {
          emp.amAssigned = jfId
        } else {
          emp.pmAssigned = jfId
        }
        decrementDemand(jfId, start, end)
        filled++
      }
    }
  }

  assignHalf('am')
  assignHalf('pm')

  // STEP 3: Fill unassigned halves with Flex
  const flexJf = jobFunctions.find((jf: any) => jf.name === 'Flex' && jf.is_active !== false)
  const flexJfId = flexJf?.id || 'flex'

  for (const emp of empInfos) {
    if (emp.amAssigned == null) emp.amAssigned = flexJfId
    if (emp.pmStart != null && emp.pmEnd != null && emp.pmAssigned == null) {
      emp.pmAssigned = flexJfId
    }
  }

  // STEP 4: Detect gaps
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

  // STEP 5: Convert to schedule assignments
  const jfNameById = new Map<string, string>()
  for (const jf of jobFunctions) {
    jfNameById.set(jf.id, jf.name)
  }

  const schedule: ScheduleAssignment[] = []
  for (const emp of empInfos) {
    if (emp.amAssigned) {
      const name = jfNameById.get(emp.amAssigned) || 'Flex'
      schedule.push({
        employee_id: emp.id,
        job_function: name,
        start_time: minutesToTime(emp.amStart),
        end_time: minutesToTime(emp.amEnd),
      })
    }
    if (emp.pmAssigned && emp.pmStart != null && emp.pmEnd != null) {
      const name = jfNameById.get(emp.pmAssigned) || 'Flex'
      schedule.push({
        employee_id: emp.id,
        job_function: name,
        start_time: minutesToTime(emp.pmStart),
        end_time: minutesToTime(emp.pmEnd),
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

  const generateAISchedule = async (): Promise<{
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
      const { schedule, gaps } = buildSchedule(
        employees,
        jobFunctionsList,
        shifts,
        trainingData,
        staffingTargets,
        preferredAssignmentsMap,
        warnings
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

    // Convert schedule items to assignment records
    const assignments = schedule
      .map((a) => {
        const jf = jfList.find((jf: any) => jf.name === a.job_function) as any
        if (!jf) return null
        const shiftId = employeeShiftMap.get(a.employee_id)
        const shift = shiftId
          ? (shiftsData || []).find((s: any) => s.id === shiftId)
          : null
        if (!shift) return null
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

    // Use atomic replace (delete existing + insert new in one transaction)
    const result = await replaceScheduleForDate(scheduleDate, assignments)
    if (!result) throw new Error('Failed to save schedule')
  }

  return { generateAISchedule, applyAISchedule }
}
