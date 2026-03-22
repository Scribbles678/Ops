/**
 * AI Schedule Builder Composable
 *
 * Extracted from tomorrow.vue for testability and maintainability.
 * Generates optimized schedules from business rules, training, and preferred assignments.
 */

// ---------------------------------------------------------------------------
// Time utilities
// ---------------------------------------------------------------------------

const timeToMinutes = (time: string): number => {
  const parts = time.split(':').map(Number)
  const hours = parts[0] || 0
  const minutes = parts[1] || 0
  return hours * 60 + minutes
}

const minutesToTime = (minutes: number): string => {
  const hours = Math.floor(minutes / 60)
  const mins = minutes % 60
  return `${hours.toString().padStart(2, '0')}:${mins.toString().padStart(2, '0')}`
}

// ---------------------------------------------------------------------------
// Helper: Get parent Meter job function (for "Meter N" -> "Meter" training/assignment lookup)
// ---------------------------------------------------------------------------

const getParentMeterJobFunction = (jobFunctions: any[], teamId?: string | null) => {
  return jobFunctions.find(
    (jf: any) => jf?.name === 'Meter' && (teamId == null || jf.team_id === teamId)
  )
}

// ---------------------------------------------------------------------------
// Helper: Get effective preferred assignment (exact match or parent Meter for Meter N)
// ---------------------------------------------------------------------------

const getPreferredForJobFunction = (
  employeeId: string,
  jobFunctionName: string,
  jobFunctions: any[],
  preferredAssignmentsMap: Record<string, Record<string, any>>
): any => {
  const preferred = preferredAssignmentsMap[employeeId]
  if (!preferred) return null
  const jf = jobFunctions.find((jf: any) => jf?.name === jobFunctionName)
  if (!jf) return null
  if (preferred[jf.id]) return preferred[jf.id]
  // For "Meter N", check parent "Meter"
  if (/^Meter [0-9]+$/.test(jf.name || '')) {
    const parent = getParentMeterJobFunction(jobFunctions, jf.team_id)
    if (parent && preferred[parent.id]) return preferred[parent.id]
  }
  return null
}

// ---------------------------------------------------------------------------
// Core algorithm helpers
// ---------------------------------------------------------------------------

const distributeCounts = (total: number | null, count: number): number[] | null => {
  if (total === null || total === undefined) return null
  if (count <= 0) return null
  const base = Math.floor(total / count)
  const remainder = total % count
  return Array.from({ length: count }, (_, idx) => base + (idx < remainder ? 1 : 0))
}

const expandBusinessRulesForFanOut = (
  rules: any[],
  jobFunctions: any[],
  warnings: string[] = []
) => {
  if (!Array.isArray(rules)) return []
  const activeJobFunctions = Array.isArray(jobFunctions) ? jobFunctions : []
  const expanded: any[] = []

  for (const rule of rules) {
    if (rule?.fan_out_enabled && rule?.fan_out_prefix) {
      const prefix = String(rule.fan_out_prefix)
      const matches = activeJobFunctions.filter((jf: any) => {
        const name = jf?.name || ''
        return (
          name &&
          name !== rule.job_function_name &&
          name.startsWith(prefix) &&
          jf.is_active !== false
        )
      })

      if (matches.length === 0) {
        warnings.push(
          `No active job functions match prefix "${prefix}" for rule "${rule.job_function_name}".`
        )
        expanded.push(rule)
        continue
      }

      const originalMin = typeof rule.min_staff === 'number' ? rule.min_staff : null
      const originalMax = typeof rule.max_staff === 'number' ? rule.max_staff : null
      const minDistribution = distributeCounts(originalMin, matches.length)
      const maxDistribution = distributeCounts(originalMax, matches.length)

      matches
        .sort((a: any, b: any) => (a.name || '').localeCompare(b.name || ''))
        .forEach((match: any, idx: number) => {
          const minStaff = minDistribution ? minDistribution[idx] : null
          let maxStaff = maxDistribution ? maxDistribution[idx] : null
          if (maxStaff !== null && minStaff !== null && maxStaff < minStaff) maxStaff = minStaff
          expanded.push({
            ...rule,
            job_function_name: match.name,
            min_staff: minStaff,
            max_staff: maxStaff,
            fan_out_enabled: false,
            fan_out_prefix: null,
          })
        })
    } else {
      expanded.push(rule)
    }
  }
  return expanded
}

// ---------------------------------------------------------------------------
// Create 15-minute assignments for a time block
// ---------------------------------------------------------------------------

const createBlockAssignments = (
  employee: any,
  jobFunction: string,
  startTime: string,
  endTime: string,
  blockSizeMinutes: number
) => {
  const assignments: any[] = []
  const startMinutes = timeToMinutes(startTime)
  const endMinutes = timeToMinutes(endTime)
  const blockSize = blockSizeMinutes || endMinutes - startMinutes

  let currentMinutes = startMinutes
  while (currentMinutes < endMinutes) {
    const nextMinutes = Math.min(currentMinutes + 15, endMinutes)
    assignments.push({
      id: `${employee.id}-${jobFunction}-${currentMinutes}`,
      employee_id: employee.id,
      job_function: jobFunction,
      start_time: minutesToTime(currentMinutes),
      end_time: minutesToTime(nextMinutes),
    })
    currentMinutes = nextMinutes
  }
  return assignments
}

// ---------------------------------------------------------------------------
// Find available employees (with parent Meter training + preferred assignment support)
// ---------------------------------------------------------------------------

const findAvailableEmployees = (
  employees: any[],
  shifts: any[],
  trainingData: any,
  jobFunctions: any[],
  jobFunction: string,
  startTime: string,
  endTime: string,
  existingAssignments: any[] = [],
  preferredAssignmentsMap: Record<string, Record<string, any>> = {}
) => {
  const startMinutes = timeToMinutes(startTime)
  const endMinutes = timeToMinutes(endTime)
  const jobFunctionObj = jobFunctions.find((jf: any) => jf.name === jobFunction)
  if (!jobFunctionObj) {
    console.log(`Job function ${jobFunction} not found`)
    return []
  }

  const isTrainedForJob = (empId: string, jf: any): boolean => {
    if (trainingData[empId]?.includes(jf.id)) return true
    if (/^Meter [0-9]+$/.test(jf.name || '')) {
      const parent = getParentMeterJobFunction(jobFunctions, jf.team_id)
      if (parent && trainingData[empId]?.includes(parent.id)) return true
    }
    return false
  }

  const available = employees.filter((employee: any) => {
    if (!isTrainedForJob(employee.id, jobFunctionObj)) {
      return false
    }

    const prefForCurrent = getPreferredForJobFunction(
      employee.id,
      jobFunction,
      jobFunctions,
      preferredAssignmentsMap
    )
    const requiredForCurrent = prefForCurrent?.is_required === true

    const preferredForEmployee = preferredAssignmentsMap[employee.id]
    const requiredElsewhere =
      preferredForEmployee &&
      Object.values(preferredForEmployee).some((pa: any) => {
        if (!pa?.is_required) return false
        if (pa.job_function_id === jobFunctionObj.id) return false
        const parentMeter = getParentMeterJobFunction(jobFunctions, jobFunctionObj.team_id)
        if (parentMeter && pa.job_function_id === parentMeter.id) return false
        return true
      })

    if (!requiredForCurrent && requiredElsewhere) return false

    const shift = shifts.find((s: any) => s.id === employee.shift_id)
    if (!shift) return false

    const timeCovered = startTime < shift.end_time && endTime > shift.start_time
    if (!timeCovered) return false

    const hasConflict = existingAssignments.some((a: any) => {
      if (a.employee_id !== employee.id) return false
      const aStart = timeToMinutes(a.start_time)
      const aEnd = timeToMinutes(a.end_time)
      return !(endMinutes <= aStart || startMinutes >= aEnd)
    })
    if (hasConflict) return false

    return true
  })

  available.sort((a: any, b: any) => {
    const aPref = getPreferredForJobFunction(
      a.id,
      jobFunction,
      jobFunctions,
      preferredAssignmentsMap
    )
    const bPref = getPreferredForJobFunction(
      b.id,
      jobFunction,
      jobFunctions,
      preferredAssignmentsMap
    )
    if (aPref?.is_required && !bPref?.is_required) return -1
    if (!aPref?.is_required && bPref?.is_required) return 1
    if (aPref && bPref) return (bPref.priority || 0) - (aPref.priority || 0)
    if (aPref && !bPref) return -1
    if (!aPref && bPref) return 1
    return 0
  })

  return available
}

// ---------------------------------------------------------------------------
// Assign Startup to 6am employees (6am-8am)
// ---------------------------------------------------------------------------

const assignStartupTo6amEmployees = async (
  employees: any[],
  shifts: any[],
  jobFunctions: any[],
  trainingData: any,
  assignments: any[],
  employeeAssignments: Map<string, any[]>,
  employeeHours: Map<string, number>
) => {
  const sixAMShift = shifts.find((s: any) => timeToMinutes(s.start_time) === timeToMinutes('06:00'))
  if (!sixAMShift) return

  const startupJobFunction = jobFunctions.find((jf: any) => jf.name === 'Startup')
  if (!startupJobFunction) return

  const sixAMEmployees = employees.filter((emp: any) => emp.shift_id === sixAMShift.id)

  for (const employee of sixAMEmployees) {
    const isTrained =
      !startupJobFunction.requires_training ||
      trainingData[employee.id]?.includes(startupJobFunction.id)

    if (isTrained) {
      assignments.push(
        ...createBlockAssignments(employee, 'Startup', '06:00', '08:00', 120)
      )
      if (!employeeAssignments.has(employee.id)) employeeAssignments.set(employee.id, [])
      employeeAssignments.get(employee.id)!.push('Startup')
      employeeHours.set(employee.id, (employeeHours.get(employee.id) || 0) + 2)
    }
  }
}

// ---------------------------------------------------------------------------
// Add lunch coverage for Locus and X4 (passes preferredAssignmentsMap)
// ---------------------------------------------------------------------------

const addBreakCoverage = async (
  employees: any[],
  shifts: any[],
  trainingData: any,
  jobFunctions: any[],
  assignments: any[],
  employeeAssignments: Map<string, any[]>,
  preferredAssignmentsMap: Record<string, Record<string, any>>
) => {
  const lunchTime = { start: '12:30', end: '13:00' }
  const priorityFunctions = ['Locus', 'X4']

  for (const priorityFunction of priorityFunctions) {
    const employeesOnFunction = assignments
      .filter(
        (a: any) =>
          a.job_function === priorityFunction &&
          a.start_time <= lunchTime.start &&
          a.end_time > lunchTime.start
      )
      .map((a: any) => a.employee_id)

    const availableCoverage = findAvailableEmployees(
      employees,
      shifts,
      trainingData,
      jobFunctions,
      priorityFunction,
      lunchTime.start,
      lunchTime.end,
      assignments,
      preferredAssignmentsMap
    ).filter((emp: any) => !employeesOnFunction.includes(emp.id))

    if (availableCoverage.length > 0) {
      const coverageEmployee = availableCoverage[0]
      assignments.push(
        ...createBlockAssignments(
          coverageEmployee,
          priorityFunction,
          lunchTime.start,
          lunchTime.end,
          30
        )
      )
      if (!employeeAssignments.has(coverageEmployee.id)) {
        employeeAssignments.set(coverageEmployee.id, [])
      }
      employeeAssignments.get(coverageEmployee.id)!.push(priorityFunction)
    }
  }
}

// ---------------------------------------------------------------------------
// Consolidate assignments into 2-4 hour blocks
// ---------------------------------------------------------------------------

const consolidateAssignmentsStrategy = (
  employees: any[],
  shifts: any[],
  rawAssignments: any[],
  employeeAssignments: Map<string, any[]>,
  employeeHours: Map<string, number>
) => {
  const consolidated: any[] = []
  const employeeTimeBlocks = new Map<
    string,
    Array<{ start: number; end: number; function: string }>
  >()
  const lunchSplit = timeToMinutes('12:00')
  const lunchEnd = timeToMinutes('13:00')

  for (const employee of employees) {
    const shift = shifts.find((s: any) => s.id === employee.shift_id)
    if (!shift) continue

    const empAssignments = rawAssignments
      .filter((a: any) => a.employee_id === employee.id)
      .map((a: any) => ({
        start: timeToMinutes(a.start_time),
        end: timeToMinutes(a.end_time),
        function: a.job_function,
      }))
    empAssignments.sort((a: any, b: any) => a.start - b.start)

    const merged: Array<{ start: number; end: number; function: string }> = []
    for (const assign of empAssignments) {
      const last = merged[merged.length - 1]
      if (last && last.function === assign.function && last.end === assign.start) {
        last.end = assign.end
      } else {
        merged.push({ ...assign })
      }
    }

    const beforeLunch: Array<{ start: number; end: number; function: string }> = []
    const afterLunch: Array<{ start: number; end: number; function: string }> = []

    for (const block of merged) {
      if (block.function === 'Startup') {
        beforeLunch.push(block)
        continue
      }
      if (block.end <= lunchSplit) beforeLunch.push(block)
      else if (block.start >= lunchEnd) afterLunch.push(block)
      else {
        if (block.start < lunchSplit) {
          beforeLunch.push({ start: block.start, end: lunchSplit, function: block.function })
        }
        if (block.end > lunchEnd) {
          afterLunch.push({ start: lunchEnd, end: block.end, function: block.function })
        }
      }
    }

    const consolidatePeriod = (
      blocks: Array<{ start: number; end: number; function: string }>
    ): Array<{ start: number; end: number; function: string }> => {
      const blocksByFunction: Record<string, Array<{ start: number; end: number }>> = {}
      for (const block of blocks) {
        if (!blocksByFunction[block.function]) blocksByFunction[block.function] = []
        blocksByFunction[block.function].push({ start: block.start, end: block.end })
      }
      const result: Array<{ start: number; end: number; function: string }> = []
      for (const [func, funcBlocks] of Object.entries(blocksByFunction)) {
        funcBlocks.sort((a, b) => a.start - b.start)
        let currentBlock: { start: number; end: number } | null = null
        for (const block of funcBlocks) {
          if (!currentBlock) currentBlock = { ...block }
          else if (block.start <= currentBlock.end + 60) {
            currentBlock.end = Math.max(currentBlock.end, block.end)
          } else {
            result.push({ ...currentBlock, function: func })
            currentBlock = { ...block }
          }
        }
        if (currentBlock) result.push({ ...currentBlock, function: func })
      }
      result.sort((a, b) => a.start - b.start)
      const uniqueFunctions = new Set(result.map((b) => b.function))
      if (uniqueFunctions.size > 4) {
        const seen = new Set<string>()
        return result.filter((b) => {
          if (seen.has(b.function)) return true
          if (seen.size >= 4) return false
          seen.add(b.function)
          return true
        })
      }
      return result
    }

    const beforeConsolidated = consolidatePeriod(beforeLunch)
    const afterConsolidated = consolidatePeriod(afterLunch)
    const allBlocks = [...beforeConsolidated, ...afterConsolidated].sort(
      (a, b) => a.start - b.start
    )

    const finalBlocks: Array<{ start: number; end: number; function: string }> = []
    for (const block of allBlocks) {
      const blockDuration = block.end - block.start
      const last = finalBlocks[finalBlocks.length - 1]
      if (blockDuration < 120 && last?.function === block.function && block.start - last.end <= 60) {
        last.end = block.end
      } else {
        finalBlocks.push(block)
      }
    }
    employeeTimeBlocks.set(employee.id, finalBlocks)
  }

  for (const [employeeId, blocks] of employeeTimeBlocks.entries()) {
    const emp = employees.find((e: any) => e.id === employeeId)
    if (!emp) continue
    for (const block of blocks) {
      consolidated.push(
        ...createBlockAssignments(
          emp,
          block.function,
          minutesToTime(block.start),
          minutesToTime(block.end),
          block.end - block.start
        )
      )
    }
  }
  return consolidated
}

// ---------------------------------------------------------------------------
// Fill remaining hours with Flex (2-4 hour blocks)
// ---------------------------------------------------------------------------

const fillRemainingHoursWithFlex = (
  employees: any[],
  shifts: any[],
  assignments: any[],
  employeeAssignments: Map<string, any[]>,
  employeeHours: Map<string, number>
) => {
  for (const employee of employees) {
    const shift = shifts.find((s: any) => s.id === employee.shift_id)
    if (!shift) continue

    const shiftStart = timeToMinutes(shift.start_time)
    const shiftEnd = timeToMinutes(shift.end_time)
    const assignedTimes = new Set<number>()
    assignments
      .filter((a: any) => a.employee_id === employee.id)
      .forEach((a: any) => {
        const start = timeToMinutes(a.start_time)
        const end = timeToMinutes(a.end_time)
        for (let t = start; t < end; t += 15) assignedTimes.add(t)
      })

    let currentTime = shiftStart
    while (currentTime < shiftEnd) {
      if (!assignedTimes.has(currentTime)) {
        let gapEnd = currentTime
        while (gapEnd < shiftEnd && !assignedTimes.has(gapEnd)) gapEnd += 15

        let flexTime = currentTime
        while (flexTime < gapEnd) {
          const remaining = gapEnd - flexTime
          let blockDuration = Math.min(180, remaining)
          if (remaining >= 120 && remaining <= 240) blockDuration = remaining
          else if (remaining > 240) blockDuration = 180
          else if (remaining < 120) blockDuration = Math.max(120, remaining)

          const flexEnd = Math.min(flexTime + blockDuration, gapEnd)
          assignments.push(
            ...createBlockAssignments(
              employee,
              'Flex',
              minutesToTime(flexTime),
              minutesToTime(flexEnd),
              flexEnd - flexTime
            )
          )
          flexTime = flexEnd
        }
        currentTime = gapEnd
      } else {
        currentTime += 15
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Fallback schedule
// ---------------------------------------------------------------------------

const createFallbackSchedule = (
  employees: any[],
  jobFunctions: any[],
  shifts: any[],
  trainingData: any
) => {
  const assignments: any[] = []
  for (const employee of employees) {
    const shift = shifts.find((s: any) => s.id === employee.shift_id)
    if (!shift) continue
    const trainedFunctions = trainingData[employee.id] || []
    if (trainedFunctions.length === 0) continue
    const jobFunction = jobFunctions.find((jf: any) => trainedFunctions.includes(jf.id))
    if (!jobFunction) continue

    const shiftStart = timeToMinutes(shift.start_time)
    const shiftEnd = timeToMinutes(shift.end_time)
    const workDuration = Math.min(480, shiftEnd - shiftStart)

    assignments.push(
      ...createBlockAssignments(
        employee,
        jobFunction.name,
        minutesToTime(shiftStart),
        minutesToTime(shiftStart + workDuration),
        workDuration
      )
    )
  }
  return assignments
}

// ---------------------------------------------------------------------------
// Check if job function has any required employees (for processing order)
// ---------------------------------------------------------------------------

const jobFunctionHasRequiredAssignments = (
  jobFunction: string,
  jobFunctions: any[],
  preferredAssignmentsMap: Record<string, Record<string, any>>
): boolean => {
  const jf = jobFunctions.find((jf: any) => jf.name === jobFunction)
  if (!jf) return false
  for (const empId of Object.keys(preferredAssignmentsMap)) {
    const pref = getPreferredForJobFunction(empId, jobFunction, jobFunctions, preferredAssignmentsMap)
    if (pref?.is_required) return true
  }
  return false
}

// ---------------------------------------------------------------------------
// Main builder
// ---------------------------------------------------------------------------

const buildOptimalSchedule = async (
  employees: any[],
  jobFunctions: any[],
  shifts: any[],
  trainingData: any,
  dbRules: any[],
  warnings: string[],
  preferredAssignmentsMap: Record<string, Record<string, any>>
) => {
  const assignments: any[] = []
  const employeeAssignments = new Map<string, any[]>()
  const employeeHours = new Map<string, number>()

  await assignStartupTo6amEmployees(
    employees,
    shifts,
    jobFunctions,
    trainingData,
    assignments,
    employeeAssignments,
    employeeHours
  )

  const processedRules = expandBusinessRulesForFanOut(dbRules, jobFunctions, warnings)

  const globalMaxLimits = new Map<string, number>()
  const timeSlotRules: Record<string, any[]> = {}

  for (const dbRule of processedRules) {
    const jfName = dbRule.job_function_name
    if (dbRule.min_staff === null && dbRule.max_staff !== null) {
      globalMaxLimits.set(jfName, dbRule.max_staff)
      continue
    }
    if (!timeSlotRules[jfName]) timeSlotRules[jfName] = []
    timeSlotRules[jfName].push({
      start: dbRule.time_slot_start,
      end: dbRule.time_slot_end,
      minStaff: dbRule.min_staff,
      maxStaff: dbRule.max_staff,
      blockSize: dbRule.block_size_minutes,
      priority: dbRule.priority || 0,
    })
  }

  for (const jfName of Object.keys(timeSlotRules)) {
    timeSlotRules[jfName].sort((a: any, b: any) => {
      if (a.priority !== b.priority) return a.priority - b.priority
      return a.start.localeCompare(b.start)
    })
  }

  const jobFunctionEntries = Object.entries(timeSlotRules) as [string, any[]][]
  jobFunctionEntries.sort(([a], [b]) => {
    const aHasRequired = jobFunctionHasRequiredAssignments(a, jobFunctions, preferredAssignmentsMap)
    const bHasRequired = jobFunctionHasRequiredAssignments(b, jobFunctions, preferredAssignmentsMap)
    if (aHasRequired && !bHasRequired) return -1
    if (!aHasRequired && bHasRequired) return 1
    return 0
  })

  const jobFunctionObjFor = (name: string) => jobFunctions.find((jf: any) => jf.name === name)
  const isTrainedForFallback = (empId: string, jf: any, jfName: string): boolean => {
    if (trainingData[empId]?.includes(jf.id)) return true
    if (/^Meter [0-9]+$/.test(jfName)) {
      const parent = getParentMeterJobFunction(jobFunctions, jf.team_id)
      if (parent && trainingData[empId]?.includes(parent.id)) return true
    }
    return false
  }

  for (const [jobFunction, timeSlots] of jobFunctionEntries) {
    const globalMax = globalMaxLimits.get(jobFunction)
    let currentStaffCount = 0
    const jobFunctionObj = jobFunctionObjFor(jobFunction)

    for (const timeSlot of timeSlots) {
      const requiredStaff = timeSlot.minStaff
      const maxStaff = timeSlot.maxStaff || requiredStaff

      if (globalMax !== undefined && currentStaffCount >= globalMax) continue

      let effectiveMaxStaff = maxStaff || 0
      if (globalMax !== undefined) {
        effectiveMaxStaff = Math.min(effectiveMaxStaff || 999, globalMax - currentStaffCount)
      }

      const availableEmployees = findAvailableEmployees(
        employees,
        shifts,
        trainingData,
        jobFunctions,
        jobFunction,
        timeSlot.start,
        timeSlot.end,
        assignments,
        preferredAssignmentsMap
      )

      const staffToAssign = Math.min(
        requiredStaff || 0,
        availableEmployees.length,
        effectiveMaxStaff
      )

      if (availableEmployees.length === 0) {
        warnings.push(
          `No trained employees available for ${jobFunction} at ${timeSlot.start}-${timeSlot.end} (Required: ${requiredStaff || 0})`
        )
      } else if (availableEmployees.length < (requiredStaff || 0)) {
        warnings.push(
          `Insufficient trained employees for ${jobFunction} at ${timeSlot.start}-${timeSlot.end} (Available: ${availableEmployees.length}, Required: ${requiredStaff || 0})`
        )
      }

      const slotDurationMinutes =
        timeToMinutes(timeSlot.end) - timeToMinutes(timeSlot.start)
      const slotHours = slotDurationMinutes / 60

      for (let i = 0; i < staffToAssign; i++) {
        const employee = availableEmployees[i]
        if (employee) {
          assignments.push(
            ...createBlockAssignments(
              employee,
              jobFunction,
              timeSlot.start,
              timeSlot.end,
              timeSlot.blockSize || 0
            )
          )
          if (!employeeAssignments.has(employee.id)) employeeAssignments.set(employee.id, [])
          employeeAssignments.get(employee.id)!.push(jobFunction)
          employeeHours.set(
            employee.id,
            (employeeHours.get(employee.id) || 0) + slotHours
          )
          currentStaffCount++
        }
      }

      if (staffToAssign < (requiredStaff || 0) && globalMax === undefined && jobFunctionObj) {
        const usedEmployeeIds = new Set(availableEmployees.map((e: any) => e.id))
        const fallbackCandidates = employees.filter((emp: any) => {
          if (usedEmployeeIds.has(emp.id)) return false
          if (!isTrainedForFallback(emp.id, jobFunctionObj, jobFunction)) return false
          const shift = shifts.find((s: any) => s.id === emp.shift_id)
          if (!shift) return false
          if (timeSlot.start >= shift.end_time || timeSlot.end <= shift.start_time) return false

          const pref = preferredAssignmentsMap[emp.id]
          const prefForCurrent = getPreferredForJobFunction(
            emp.id,
            jobFunction,
            jobFunctions,
            preferredAssignmentsMap
          )
          const requiredForCurrent = prefForCurrent?.is_required === true
          const requiredElsewhere =
            pref &&
            Object.values(pref).some((pa: any) => {
              if (!pa?.is_required) return false
              if (pa.job_function_id === jobFunctionObj.id) return false
              const parent = getParentMeterJobFunction(jobFunctions, jobFunctionObj.team_id)
              if (parent && pa.job_function_id === parent.id) return false
              return true
            })
          if (!requiredForCurrent && requiredElsewhere) return false

          const hasConflict = assignments.some((a: any) => {
            if (a.employee_id !== emp.id) return false
            const aStart = timeToMinutes(a.start_time)
            const aEnd = timeToMinutes(a.end_time)
            return !(
              timeToMinutes(timeSlot.end) <= aStart ||
              timeToMinutes(timeSlot.start) >= aEnd
            )
          })
          return !hasConflict
        })

        let filled = staffToAssign
        for (const employee of fallbackCandidates) {
          if (filled >= (requiredStaff || 0)) break
          if (globalMax !== undefined && currentStaffCount >= globalMax) break

          assignments.push(
            ...createBlockAssignments(
              employee,
              jobFunction,
              timeSlot.start,
              timeSlot.end,
              timeSlot.blockSize || 0
            )
          )
          if (!employeeAssignments.has(employee.id)) employeeAssignments.set(employee.id, [])
          employeeAssignments.get(employee.id)!.push(jobFunction)
          employeeHours.set(
            employee.id,
            (employeeHours.get(employee.id) || 0) + slotHours
          )
          currentStaffCount++
          filled++
        }
      }
    }
  }

  await addBreakCoverage(
    employees,
    shifts,
    trainingData,
    jobFunctions,
    assignments,
    employeeAssignments,
    preferredAssignmentsMap
  )

  const consolidatedAssignments = consolidateAssignmentsStrategy(
    employees,
    shifts,
    assignments,
    employeeAssignments,
    employeeHours
  )

  fillRemainingHoursWithFlex(
    employees,
    shifts,
    consolidatedAssignments,
    employeeAssignments,
    employeeHours
  )

  if (consolidatedAssignments.length === 0) {
    return {
      schedule: createFallbackSchedule(employees, jobFunctions, shifts, trainingData),
      warnings,
    }
  }

  return { schedule: consolidatedAssignments, warnings }
}

// ---------------------------------------------------------------------------
// Composable API
// ---------------------------------------------------------------------------

export function useAIScheduleBuilder() {
  const { fetchEmployees, getAllEmployeeTraining } = useEmployees()
  const { jobFunctions, fetchJobFunctions } = useJobFunctions()
  const { fetchShifts, createAssignmentsBatch } = useSchedule()
  const { fetchBusinessRules } = useBusinessRules()
  const { fetchPreferredAssignments, getPreferredAssignmentsMap } = usePreferredAssignments()

  const generateAISchedule = async (): Promise<{
    schedule: any[]
    warnings: string[]
    errors: string[]
  }> => {
    const warnings: string[] = []
    const errors: string[] = []

    try {
      const [employeesData, jobFunctionsData, shiftsData, businessRulesData] = await Promise.all([
        fetchEmployees(),
        fetchJobFunctions(),
        fetchShifts(),
        fetchBusinessRules(),
      ])
      await fetchPreferredAssignments()

      const employees = Array.isArray(employeesData) ? employeesData : []
      const jobFunctionsList = Array.isArray(jobFunctionsData) ? jobFunctionsData : []
      const shifts = Array.isArray(shiftsData) ? shiftsData : []
      const businessRules = Array.isArray(businessRulesData) ? businessRulesData : []

      const activeEmployees = employees.filter((e: any) => e && e.is_active !== false)
      const activeShifts = shifts.filter((s: any) => s && s.is_active !== false)

      if (!employees.length) {
        errors.push('No employees found in the system.')
      }
      if (!activeEmployees.length) {
        errors.push('No active employees found.')
      }
      if (!shifts.length) {
        errors.push('No shifts configured.')
      }
      if (!activeShifts.length) {
        errors.push('No active shifts found.')
      }
      if (!jobFunctionsList.length) {
        errors.push('No job functions configured.')
      }
      if (!businessRules.length) {
        errors.push('No business rules configured. Please set up business rules in the "Manage Business Rules" page.')
      }

      if (errors.length) return { schedule: [], warnings: [], errors }

      const employeeIds = employees.filter((e: any) => e?.id).map((e: any) => e.id)
      if (!employeeIds.length) {
        errors.push('No valid employee IDs found.')
        return { schedule: [], warnings: [], errors }
      }

      let trainingData: Record<string, string[]> = {}
      try {
        trainingData = (await getAllEmployeeTraining(employeeIds)) || {}
      } catch (e: any) {
        errors.push(`Error loading employee training: ${e?.message || 'Unknown error'}`)
        return { schedule: [], warnings: [], errors }
      }

      const employeesWithTraining = Object.keys(trainingData).filter(
        (id) => trainingData[id] && trainingData[id].length > 0
      )
      if (!employeesWithTraining.length) {
        errors.push(
          'No employees have any job function training assigned. Please assign training in "Details & Settings".'
        )
      } else if (employeesWithTraining.length < activeEmployees.length) {
        warnings.push(
          `${activeEmployees.length - employeesWithTraining.length} employees have no training and will not be scheduled.`
        )
      }

      const employeesWithShifts = activeEmployees.filter((e: any) => e?.shift_id)
      if (!employeesWithShifts.length) {
        errors.push('No employees are assigned to shifts.')
      } else if (employeesWithShifts.length < activeEmployees.length) {
        warnings.push(
          `${activeEmployees.length - employeesWithShifts.length} employees are not assigned to any shift.`
        )
      }

      if (errors.length) return { schedule: [], warnings: [...warnings, ...errors], errors }

      const preferredAssignmentsMap = getPreferredAssignmentsMap()
      const { schedule, warnings: scheduleWarnings } = await buildOptimalSchedule(
        employees,
        jobFunctionsList,
        shifts,
        trainingData,
        businessRules,
        warnings,
        preferredAssignmentsMap
      )

      if (!schedule.length) {
        errors.push('No schedule assignments could be created.')
        errors.push('• No employees available during the required time slots')
        errors.push('• Employees not trained in the job functions specified in business rules')
        errors.push('• Employee shift times not overlapping with business rule time slots')
      }

      return {
        schedule,
        warnings: [...warnings, ...scheduleWarnings],
        errors,
      }
    } catch (e: any) {
      errors.push(`Error occurred: ${e?.message || 'Unknown error'}`)
      return { schedule: [], warnings: [], errors }
    }
  }

  const applyAISchedule = async (schedule: any[], scheduleDate: string) => {
    const [shiftsData, employeesData] = await Promise.all([fetchShifts(), fetchEmployees()])

    const employeeShiftMap = new Map<string, string | null>()
    if (Array.isArray(employeesData)) {
      employeesData.forEach((emp: any) => {
        if (emp?.id) employeeShiftMap.set(emp.id, emp.shift_id || null)
      })
    }

    const jfList = jobFunctions.value || []
    const enriched = schedule
      .map((a: any) => {
        const jf = jfList.find((jf: any) => jf.name === a.job_function) as any
        if (!jf) return null
        const preferredShiftId = employeeShiftMap.get(a.employee_id) || null
        let shift = preferredShiftId
          ? (shiftsData || []).find((s: any) => s.id === preferredShiftId)
          : null
        if (!shift) {
          shift = (shiftsData || []).find((s: any) => {
            const t = timeToMinutes(a.start_time)
            return t >= timeToMinutes(s.start_time) && t < timeToMinutes(s.end_time)
          }) as any
        }
        if (!shift) return null
        return { ...a, job_function_id: jf.id, shift_id: shift.id }
      })
      .filter(Boolean) as any[]

    const keyFor = (empId: string, jobId: string, shiftId: string) => `${empId}|${jobId}|${shiftId}`
    const grouped: Record<string, any[]> = {}
    for (const a of enriched) {
      const k = keyFor(a.employee_id, a.job_function_id, a.shift_id)
      if (!grouped[k]) grouped[k] = []
      grouped[k].push(a)
    }

    const ranges: any[] = []
    const timeAsc = (a: string, b: string) => timeToMinutes(a) - timeToMinutes(b)

    for (const [k, items] of Object.entries(grouped)) {
      items.sort((a, b) => timeAsc(a.start_time, b.start_time))
      let curStart = ''
      let curEnd = ''
      for (const it of items) {
        if (!curStart) {
          curStart = it.start_time
          curEnd = it.end_time
        } else if (it.start_time === curEnd) {
          curEnd = it.end_time
        } else {
          const [empId, jobId, shiftId] = k.split('|')
          ranges.push({
            employee_id: empId,
            job_function_id: jobId,
            shift_id: shiftId,
            start_time: curStart,
            end_time: curEnd,
            schedule_date: scheduleDate,
          })
          curStart = it.start_time
          curEnd = it.end_time
        }
      }
      if (curStart) {
        const [empId, jobId, shiftId] = k.split('|')
        ranges.push({
          employee_id: empId,
          job_function_id: jobId,
          shift_id: shiftId,
          start_time: curStart,
          end_time: curEnd,
          schedule_date: scheduleDate,
        })
      }
    }

    const batchSize = 200
    for (let i = 0; i < ranges.length; i += batchSize) {
      const batch = ranges.slice(i, i + batchSize)
      const result = await createAssignmentsBatch(batch)
      if (!result) throw new Error('Failed to create assignments batch')
    }
  }

  return { generateAISchedule, applyAISchedule }
}
