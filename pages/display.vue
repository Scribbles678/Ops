<template>
  <div class="min-h-screen bg-gray-900 text-white">
    <!-- Header -->
    <div class="bg-gray-800 border-b border-gray-700 px-1.5 py-0.5">
      <div class="flex justify-between items-center">
        <div>
          <h1 class="text-[11px] font-bold">OPERATIONS SCHEDULE</h1>
          <p class="text-gray-400 text-[9px]">{{ formattedDate }}</p>
        </div>
        <div class="flex items-center space-x-1.5">
          <div class="text-right">
            <p class="text-[8px] text-gray-400">Last Updated</p>
            <p class="text-[9px] font-semibold">{{ lastUpdated }}</p>
          </div>
          <button
            @click="refreshData"
            class="bg-gray-700 hover:bg-gray-600 px-1 py-0.5 rounded transition flex items-center text-[8px]"
          >
            <svg class="w-2.5 h-2.5 mr-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
            </svg>
            Refresh
          </button>
        </div>
      </div>
    </div>

    <!-- Loading State -->
    <div v-if="loading" class="flex items-center justify-center h-32">
      <p class="text-gray-400 text-sm">Loading schedule...</p>
    </div>

    <!-- Schedule Content -->
    <div v-else class="p-0.5 space-y-0">
      <!-- Each Shift -->
      <div
        v-for="shift in shiftsWithAssignments"
        :key="shift.id"
        class="bg-gray-800 rounded border border-gray-700 p-0.5"
      >
        <h2 class="text-[9px] font-semibold mb-0 pb-0 border-b border-gray-700">
          {{ shift.name }}
        </h2>

        <!-- Employees Grid -->
        <div v-if="shift.employees && shift.employees.length > 0" class="divide-y divide-gray-700">
          <div
            v-for="employee in shift.employees"
            :key="employee.id"
            class="flex items-center gap-0.5 py-0"
          >
            <!-- Employee name -->
            <div class="w-28 text-white text-[8px] font-medium truncate flex-shrink-0">
              {{ employee.last_name }}, {{ employee.first_name }}
            </div>
            
            <!-- Inline assignment pills and break/lunch blocks -->
            <div class="flex flex-wrap gap-0.5">
              <div
                v-for="item in getEmployeeScheduleItems(employee)"
                :key="item.id"
                class="rounded px-0.5 py-0 text-[7px] border border-opacity-50 w-20 flex-shrink-0 flex items-center justify-center"
                :style="item.isBreak ? {
                  backgroundColor: '#4B5563', // Dark gray for breaks/lunch
                  borderColor: '#6B7280',
                  color: '#ffffff'
                } : {
                  backgroundColor: item.assignment.job_function.color_code,
                  borderColor: darkenColor(item.assignment.job_function.color_code),
                  color: getTextColor(item.assignment.job_function.color_code)
                }"
              >
                <div class="flex flex-col items-center justify-center min-h-[14px]">
                  <span class="font-semibold truncate leading-none">{{ item.isBreak ? item.label : item.assignment.job_function.name }}</span>
                  <span class="opacity-90 text-[6px] truncate leading-none">{{ item.timeRange }}</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- No employees message -->
        <div v-else class="text-center py-1 text-gray-500 text-[9px]">
          No staff scheduled for this shift
        </div>
      </div>

      <!-- No schedule message -->
      <div v-if="shiftsWithAssignments.length === 0" class="text-center py-8">
        <p class="text-gray-400 text-sm">No schedule available for today</p>
        <NuxtLink to="/" class="text-blue-400 hover:text-blue-300 mt-2 inline-block text-[9px]">
          Go to Home Page
        </NuxtLink>
      </div>
    </div>

    <!-- Auto-refresh indicator -->
    <div class="fixed bottom-0.5 right-0.5 bg-gray-800 px-0.5 py-0 rounded text-[7px] text-gray-400 border border-gray-700">
      Auto-refreshing every 2 minutes
    </div>
  </div>
</template>

<script setup lang="ts">
const { formatTime, formatDate } = useLaborCalculations()
const { 
  scheduleAssignments: assignments,
  shifts,
  loading,
  fetchShifts,
  fetchScheduleForDate
} = useSchedule()

// PTO
const { ptoByEmployeeId, fetchPTOForDate } = usePTO()

// Shift Swaps
const { swapByEmployeeId, fetchShiftSwapsForDate } = useShiftSwaps()

const {
  employees,
  loading: employeesLoading,
  fetchEmployees
} = useEmployees()

const lastUpdated = ref('')
const refreshInterval = ref<NodeJS.Timeout | null>(null)
const rolloverInterval = ref<NodeJS.Timeout | null>(null)
const realtimeSubscriptions = ref<any[]>([])

// Timezone-aware date helper (America/Chicago) to avoid UTC off-by-one
const getTZISODate = (tz: string): string => {
  // en-CA yields YYYY-MM-DD format
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: tz,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }).format(new Date())
}

// Today as a reactive ref in America/Chicago timezone
const TIMEZONE = 'America/Chicago'
const today = ref(getTZISODate(TIMEZONE))

const formattedDate = computed(() => {
  return formatDate(today.value)
})

const shiftsWithAssignments = computed(() => {
  console.log('Computing shiftsWithAssignments...')
  // Get all assignments and consolidate them first
  const allAssignments = consolidateAssignments(assignments.value)
  
  // Sort shifts by start time for consistent ordering
  const orderedShifts = [...(shifts.value || [])].sort((a: any, b: any) => String(a.start_time).localeCompare(String(b.start_time)))
  
  // Group assignments by employee for easy lookup
  const employeeAssignments = new Map()
  allAssignments.forEach(assignment => {
    const employeeId = assignment.employee_id
    if (!employeeAssignments.has(employeeId)) {
      employeeAssignments.set(employeeId, [])
    }
    employeeAssignments.get(employeeId).push(assignment)
  })
  
  // Group employees by their actual shift_id (like the schedule page does)
  const shiftMap = new Map()
  
  // Initialize all shifts (even empty ones)
  orderedShifts.forEach(shift => {
    shiftMap.set(shift.id, {
      ...shift,
      employees: []
    })
  })
  
  // Helper to check if an assignment overlaps PTO
  const overlapsPTO = (empId: string, startTime: string, endTime: string) => {
    const ptoRecs = (ptoByEmployeeId.value && ptoByEmployeeId.value[empId]) ? ptoByEmployeeId.value[empId] : []
    if (!ptoRecs || ptoRecs.length === 0) return false
    const aS = parseInt(startTime.substring(0,2)) * 60 + parseInt(startTime.substring(3,5))
    const aE = parseInt(endTime.substring(0,2)) * 60 + parseInt(endTime.substring(3,5))
    for (const r of ptoRecs) {
      if (!r.start_time && !r.end_time) return true // full day PTO
      const rStart = r.start_time ? String(r.start_time).substring(0,5) : '00:00'
      const rEnd = r.end_time ? String(r.end_time).substring(0,5) : '23:59'
      const rS = parseInt(rStart.substring(0,2)) * 60 + parseInt(rStart.substring(3,5))
      const rE = parseInt(rEnd.substring(0,2)) * 60 + parseInt(rEnd.substring(3,5))
      if (!(aE <= rS || aS >= rE)) return true
    }
    return false
  }
  
  // Group employees by their shift_id, accounting for shift swaps
  employees.value.forEach(employee => {
    // Check if employee has a shift swap
    const swap = swapByEmployeeId.value?.[employee.id]
    
    // Determine which shift this employee should appear in
    const targetShiftId = swap ? swap.swapped_shift_id : employee.shift_id
    
    if (shiftMap.has(targetShiftId)) {
      // If employee has any PTO record for today, skip entirely to save space
      const hasAnyPTO = !!(ptoByEmployeeId.value && ptoByEmployeeId.value[employee.id] && ptoByEmployeeId.value[employee.id].length > 0)
      if (hasAnyPTO) return

      // Get assignments for this employee and filter out those overlapping PTO
      const employeeAssignmentsList = (employeeAssignments.get(employee.id) || []).filter(a => !overlapsPTO(employee.id, String(a.start_time), String(a.end_time)))
      
      // Create employee object with assignments
      const employeeWithAssignments = {
        ...employee,
        assignments: employeeAssignmentsList
      }
      
      shiftMap.get(targetShiftId).employees.push(employeeWithAssignments)
    }
  })
  
  // Return all shifts in start-time order (including empty ones)
  return orderedShifts.map(s => shiftMap.get(s.id))
})

// Function to consolidate consecutive assignments for the same employee and job function
const consolidateAssignments = (assignments: any[]) => {
  if (!assignments || assignments.length === 0) return []
  
  // Sort assignments by employee, job function, and start time
  const sorted = [...assignments].sort((a, b) => {
    if (a.employee_id !== b.employee_id) return a.employee_id.localeCompare(b.employee_id)
    if (a.job_function_id !== b.job_function_id) return a.job_function_id.localeCompare(b.job_function_id)
    return a.start_time.localeCompare(b.start_time)
  })
  
  const consolidated: any[] = []
  let currentBlock: any = null
  
  for (const assignment of sorted) {
    if (!currentBlock) {
      // Start a new block
      currentBlock = { ...assignment }
    } else if (
      currentBlock.employee_id === assignment.employee_id &&
      currentBlock.job_function_id === assignment.job_function_id &&
      currentBlock.end_time === assignment.start_time
    ) {
      // Extend the current block
      currentBlock.end_time = assignment.end_time
    } else {
      // Save the current block and start a new one
      consolidated.push(currentBlock)
      currentBlock = { ...assignment }
    }
  }
  
  // Don't forget the last block
  if (currentBlock) {
    consolidated.push(currentBlock)
  }
  
  return consolidated
}

onMounted(() => {
  // Ensure client-side date in CST/CDT before first load
  today.value = getTZISODate(TIMEZONE)
  loadData()
  
  // Set up real-time subscriptions for immediate updates
  const { $supabase } = useNuxtApp()
  
  // Subscribe to schedule_assignments changes
  const assignmentsChannel = $supabase
    .channel('schedule-assignments-changes')
    .on(
      'postgres_changes',
      {
        event: '*', // INSERT, UPDATE, DELETE
        schema: 'public',
        table: 'schedule_assignments',
        filter: `schedule_date=eq.${today.value}`
      },
      (payload) => {
        console.log('Schedule assignment change detected:', payload)
        loadData()
      }
    )
    .subscribe()
  realtimeSubscriptions.value.push(assignmentsChannel)
  
  // Subscribe to PTO changes
  const ptoChannel = $supabase
    .channel('pto-changes')
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'pto_days',
        filter: `pto_date=eq.${today.value}`
      },
      (payload) => {
        console.log('PTO change detected:', payload)
        loadData()
      }
    )
    .subscribe()
  realtimeSubscriptions.value.push(ptoChannel)
  
  // Subscribe to shift swap changes
  const swapChannel = $supabase
    .channel('shift-swaps-changes')
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'shift_swaps',
        filter: `swap_date=eq.${today.value}`
      },
      (payload) => {
        console.log('Shift swap change detected:', payload)
        loadData()
      }
    )
    .subscribe()
  realtimeSubscriptions.value.push(swapChannel)

  // Set up auto-refresh every 2 minutes as fallback
  refreshInterval.value = setInterval(() => {
    loadData()
  }, 120000)

  // Update today's date every minute to catch midnight rollover, and reload when it changes
  const tick = () => {
    const current = getTZISODate(TIMEZONE)
    if (today.value !== current) {
      today.value = current
      loadData()
      // Resubscribe for new date - clean up old subscriptions first
      realtimeSubscriptions.value.forEach(sub => {
        $supabase.removeChannel(sub)
      })
      realtimeSubscriptions.value = []
      
      // Subscribe to schedule_assignments changes for new date
      const assignmentsChannel = $supabase
        .channel('schedule-assignments-changes')
        .on(
          'postgres_changes',
          {
            event: '*',
            schema: 'public',
            table: 'schedule_assignments',
            filter: `schedule_date=eq.${today.value}`
          },
          (payload) => {
            console.log('Schedule assignment change detected:', payload)
            loadData()
          }
        )
        .subscribe()
      realtimeSubscriptions.value.push(assignmentsChannel)
      
      // Subscribe to PTO changes for new date
      const ptoChannel = $supabase
        .channel('pto-changes')
        .on(
          'postgres_changes',
          {
            event: '*',
            schema: 'public',
            table: 'pto_days',
            filter: `pto_date=eq.${today.value}`
          },
          (payload) => {
            console.log('PTO change detected:', payload)
            loadData()
          }
        )
        .subscribe()
      realtimeSubscriptions.value.push(ptoChannel)
      
      // Subscribe to shift swap changes for new date
      const swapChannel = $supabase
        .channel('shift-swaps-changes')
        .on(
          'postgres_changes',
          {
            event: '*',
            schema: 'public',
            table: 'shift_swaps',
            filter: `swap_date=eq.${today.value}`
          },
          (payload) => {
            console.log('Shift swap change detected:', payload)
            loadData()
          }
        )
        .subscribe()
      realtimeSubscriptions.value.push(swapChannel)
    }
  }
  rolloverInterval.value = setInterval(tick, 60000)
})

onUnmounted(() => {
  if (refreshInterval.value) {
    clearInterval(refreshInterval.value)
  }
  if (rolloverInterval.value) {
    clearInterval(rolloverInterval.value)
  }
  // Clean up real-time subscriptions
  const { $supabase } = useNuxtApp()
  realtimeSubscriptions.value.forEach(sub => {
    $supabase.removeChannel(sub)
  })
  realtimeSubscriptions.value = []
})

const loadData = async () => {
  // Don't show loading state for background refreshes
  const wasLoading = loading.value
  if (!wasLoading) {
    loading.value = true
  }
  
  try {
    console.log('Refreshing display data...')
    await Promise.all([
      fetchShifts(),
      fetchEmployees(),
      fetchScheduleForDate(today.value),
      fetchPTOForDate(today.value),
      fetchShiftSwapsForDate(today.value)
    ])
    updateLastUpdated()
    console.log('Display data refreshed')
  } finally {
    if (!wasLoading) {
      loading.value = false
    }
  }
}

const refreshData = () => {
  loadData()
}

const updateLastUpdated = () => {
  const now = new Date()
  lastUpdated.value = now.toLocaleTimeString('en-US', {
    hour: 'numeric',
    minute: '2-digit',
    hour12: true
  })
}

const darkenColor = (hex: string): string => {
  // Remove # if present
  hex = hex.replace('#', '')
  
  // Convert to RGB
  const r = parseInt(hex.substring(0, 2), 16)
  const g = parseInt(hex.substring(2, 4), 16)
  const b = parseInt(hex.substring(4, 6), 16)
  
  // Darken by 20%
  const darken = (value: number) => Math.max(0, Math.floor(value * 0.8))
  
  // Convert back to hex
  const toHex = (value: number) => {
    const hex = value.toString(16)
    return hex.length === 1 ? '0' + hex : hex
  }
  
  return `#${toHex(darken(r))}${toHex(darken(g))}${toHex(darken(b))}`
}

const getTextColor = (hex: string): string => {
  // Remove # if present
  hex = hex.replace('#', '')
  
  // Convert to RGB
  const r = parseInt(hex.substring(0, 2), 16)
  const g = parseInt(hex.substring(2, 4), 16)
  const b = parseInt(hex.substring(4, 6), 16)
  
  // Calculate relative luminance
  const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
  
  // Return white text for dark backgrounds, black text for light backgrounds
  return luminance > 0.5 ? '#000000' : '#ffffff'
}

// Helper to convert time string to minutes
const timeToMinutes = (time: string): number => {
  const parts = time.split(':').map(Number)
  const hours = parts[0] || 0
  const minutes = parts[1] || 0
  return hours * 60 + minutes
}

// Helper to convert minutes to time string
const minutesToTime = (minutes: number): string => {
  const hours = Math.floor(minutes / 60)
  const mins = minutes % 60
  return `${hours.toString().padStart(2, '0')}:${mins.toString().padStart(2, '0')}`
}

// Get break periods for a shift
const getBreakPeriods = (shift: any): Array<{start: string, end: string, type: string, label: string}> => {
  const periods: Array<{start: string, end: string, type: string, label: string}> = []
  
  const convertTime = (timeStr: string | null | undefined): string | null => {
    if (!timeStr) return null
    const cleanTime = timeStr.toString().trim()
    if (cleanTime.includes(':')) {
      const parts = cleanTime.split(':')
      if (parts.length === 3) {
        return `${parts[0]}:${parts[1]}`
      }
    }
    return cleanTime
  }
  
  const break1Start = convertTime(shift.break_1_start)
  const break1End = convertTime(shift.break_1_end)
  const break2Start = convertTime(shift.break_2_start)
  const break2End = convertTime(shift.break_2_end)
  const lunchStart = convertTime(shift.lunch_start)
  const lunchEnd = convertTime(shift.lunch_end)
  
  if (break1Start && break1End) {
    periods.push({
      start: break1Start,
      end: break1End,
      type: 'break',
      label: 'BREAK'
    })
  }
  
  if (break2Start && break2End) {
    periods.push({
      start: break2Start,
      end: break2End,
      type: 'break',
      label: 'BREAK'
    })
  }
  
  if (lunchStart && lunchEnd) {
    periods.push({
      start: lunchStart,
      end: lunchEnd,
      type: 'lunch',
      label: 'LUNCH'
    })
  }
  
  return periods.sort((a, b) => timeToMinutes(a.start) - timeToMinutes(b.start))
}

// Get combined schedule items (assignments + breaks) for an employee, sorted by time
// This function splits assignments around breaks to show chronological order
const getEmployeeScheduleItems = (employee: any): Array<{id: string, isBreak: boolean, assignment?: any, label?: string, timeRange: string, sortTime: number}> => {
  const items: Array<{id: string, isBreak: boolean, assignment?: any, label?: string, timeRange: string, sortTime: number}> = []
  
  // Get employee's shift (accounting for shift swaps)
  const swap = swapByEmployeeId.value?.[employee.id]
  const targetShiftId = swap ? swap.swapped_shift_id : employee.shift_id
  const employeeShift = shifts.value.find(s => s.id === targetShiftId)
  if (!employeeShift) {
    // If no shift found, just return assignments
    return employee.assignments.map((a: any) => ({
      id: `assignment-${a.id}`,
      isBreak: false,
      assignment: a,
      timeRange: `${formatTime(a.start_time)}-${formatTime(a.end_time)}`,
      sortTime: timeToMinutes(a.start_time.substring(0, 5))
    }))
  }
  
  // Get break/lunch periods for this shift
  const breakPeriods = getBreakPeriods(employeeShift)
  
  // Process each assignment and split it around breaks
  employee.assignments.forEach((assignment: any) => {
    const assignmentStartMinutes = timeToMinutes(assignment.start_time.substring(0, 5))
    const assignmentEndMinutes = timeToMinutes(assignment.end_time.substring(0, 5))
    
    // Find breaks that fall within this assignment's time range
    const breaksInRange = breakPeriods.filter(period => {
      const breakStart = timeToMinutes(period.start)
      const breakEnd = timeToMinutes(period.end)
      // Check if break overlaps with assignment
      return !(breakEnd <= assignmentStartMinutes || breakStart >= assignmentEndMinutes)
    })
    
    // If no breaks within assignment, add assignment as-is
    if (breaksInRange.length === 0) {
      items.push({
        id: `assignment-${assignment.id}`,
        isBreak: false,
        assignment: assignment,
        timeRange: `${formatTime(assignment.start_time)}-${formatTime(assignment.end_time)}`,
        sortTime: assignmentStartMinutes
      })
    } else {
      // Split assignment around breaks
      let currentStart = assignmentStartMinutes
      
      // Sort breaks by start time
      const sortedBreaks = [...breaksInRange].sort((a, b) => timeToMinutes(a.start) - timeToMinutes(b.start))
      
      for (const breakPeriod of sortedBreaks) {
        const breakStart = timeToMinutes(breakPeriod.start)
        const breakEnd = timeToMinutes(breakPeriod.end)
        
        // Add assignment segment before this break (if there's time)
        if (currentStart < breakStart) {
          items.push({
            id: `assignment-${assignment.id}-before-${breakPeriod.type}-${breakStart}`,
            isBreak: false,
            assignment: {
              ...assignment,
              // Create a virtual segment with modified times
              start_time: minutesToTime(currentStart) + ':00',
              end_time: minutesToTime(breakStart) + ':00'
            },
            timeRange: `${formatTime(minutesToTime(currentStart))}-${formatTime(breakPeriod.start)}`,
            sortTime: currentStart
          })
        }
        
        // Add the break period
        items.push({
          id: `break-${employee.id}-${breakPeriod.type}-${breakStart}`,
          isBreak: true,
          label: breakPeriod.label,
          timeRange: `${formatTime(breakPeriod.start)}-${formatTime(breakPeriod.end)}`,
          sortTime: breakStart
        })
        
        // Update current start to after the break
        currentStart = breakEnd
      }
      
      // Add final assignment segment after all breaks (if there's time)
      if (currentStart < assignmentEndMinutes) {
        items.push({
          id: `assignment-${assignment.id}-after-breaks`,
          isBreak: false,
          assignment: {
            ...assignment,
            // Create a virtual segment with modified times
            start_time: minutesToTime(currentStart) + ':00',
            end_time: minutesToTime(assignmentEndMinutes) + ':00'
          },
          timeRange: `${formatTime(minutesToTime(currentStart))}-${formatTime(assignment.end_time)}`,
          sortTime: currentStart
        })
      }
    }
  })
  
  // Add any breaks that don't overlap with assignments (standalone breaks)
  breakPeriods.forEach((period, index) => {
    const breakStart = timeToMinutes(period.start)
    const breakEnd = timeToMinutes(period.end)
    
    // Check if this break overlaps with any assignment
    const overlapsAssignment = employee.assignments.some((assignment: any) => {
      const assignStart = timeToMinutes(assignment.start_time.substring(0, 5))
      const assignEnd = timeToMinutes(assignment.end_time.substring(0, 5))
      return !(breakEnd <= assignStart || breakStart >= assignEnd)
    })
    
    // If break doesn't overlap with any assignment, add it as standalone
    if (!overlapsAssignment) {
      items.push({
        id: `break-standalone-${employee.id}-${period.type}-${index}`,
        isBreak: true,
        label: period.label,
        timeRange: `${formatTime(period.start)}-${formatTime(period.end)}`,
        sortTime: breakStart
      })
    }
  })
  
  // Sort all items by start time
  return items.sort((a, b) => a.sortTime - b.sortTime)
}
</script>

