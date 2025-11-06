<template>
  <div class="min-h-screen bg-gray-900 text-white">
    <!-- Header -->
    <div class="bg-gray-800 border-b border-gray-700 px-1.5 py-0.5">
      <div class="flex justify-between items-center">
        <div class="flex items-center gap-2">
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
            
            <!-- Inline assignment pills -->
            <div class="flex flex-wrap gap-0.5">
              <div
                v-for="item in getEmployeeScheduleItems(employee)"
                :key="item.id"
                class="rounded px-0.5 py-0.5 text-[7px] border border-opacity-50 flex-shrink-0 flex items-center justify-center shadow-sm w-22 min-w-[5.5rem] max-w-[5.5rem] box-border overflow-hidden whitespace-nowrap"
                :style="{
                  backgroundColor: item.assignment.job_function.color_code,
                  borderColor: darkenColor(item.assignment.job_function.color_code),
                  color: getTextColor(item.assignment.job_function.color_code),
                  textShadow: getTextColor(item.assignment.job_function.color_code) === '#ffffff' 
                    ? '0 1px 2px rgba(0,0,0,0.3)' 
                    : '0 1px 2px rgba(255,255,255,0.5)'
                }"
              >
                <div class="flex items-center gap-0.5 min-h-[14px] w-full justify-center">
                  <span class="font-semibold truncate leading-tight text-[7px]">{{ item.assignment.job_function.name }}</span>
                  <span class="opacity-90 text-[6px] truncate leading-tight">{{ item.timeRange }}</span>
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
  const shiftMap = new Map<string, any>()
  
  // Initialize all shifts (even empty ones)
  orderedShifts.forEach((shift: any) => {
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
  employees.value.forEach((employee: any) => {
    // Check if employee has a shift swap
    const swap = swapByEmployeeId.value?.[employee.id]
    
    // Determine which shift this employee should appear in
    const targetShiftId = swap ? swap.swapped_shift_id : employee.shift_id
    
    if (shiftMap.has(targetShiftId)) {
      // If employee has any PTO record for today, skip entirely to save space
      const ptoRecords = ptoByEmployeeId.value?.[employee.id]
      const hasAnyPTO = !!(ptoRecords && ptoRecords.length > 0)
      if (hasAnyPTO) return

      // Get assignments for this employee and filter out those overlapping PTO
      const employeeAssignmentsList = (employeeAssignments.get(employee.id) || []).filter((a: any) => !overlapsPTO(employee.id, String(a.start_time), String(a.end_time)))
      
      // Create employee object with assignments
      const employeeWithAssignments = {
        ...employee,
        assignments: employeeAssignmentsList
      }
      
      shiftMap.get(targetShiftId).employees.push(employeeWithAssignments)
    }
  })
  
  // Return all shifts in start-time order (including empty ones)
  return orderedShifts.map((s: any) => shiftMap.get(s.id))
})

// Function to consolidate consecutive assignments for the same employee and job function
// Also deduplicates identical assignments
const consolidateAssignments = (assignments: any[]) => {
  if (!assignments || assignments.length === 0) return []
  
  // First, deduplicate identical assignments (same employee, job function, time range)
  const seen = new Set<string>()
  const deduplicated: any[] = []
  
  for (const assignment of assignments) {
    const key = `${assignment.employee_id}-${assignment.job_function_id}-${assignment.start_time}-${assignment.end_time}`
    if (!seen.has(key)) {
      seen.add(key)
      deduplicated.push(assignment)
    }
  }
  
  // Sort assignments by employee, job function, and start time
  const sorted = [...deduplicated].sort((a, b) => {
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


// Get schedule items (assignments only) for an employee, sorted by time
const getEmployeeScheduleItems = (employee: any): Array<{id: string, assignment: any, timeRange: string, sortTime: number}> => {
  if (!employee.assignments || employee.assignments.length === 0) {
    return []
  }
  
  // Return assignments sorted by start time
  return employee.assignments.map((a: any) => ({
    id: `assignment-${a.id}`,
    assignment: a,
    timeRange: `${formatTime(a.start_time)}-${formatTime(a.end_time)}`,
    sortTime: timeToMinutes(a.start_time.substring(0, 5))
  })).sort((a: any, b: any) => a.sortTime - b.sortTime)
}
</script>

