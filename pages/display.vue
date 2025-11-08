<template>
  <div class="display-page min-h-screen bg-gradient-to-b from-gray-950 via-black to-gray-950 text-white text-[10px] md:text-[11px]">
    <div class="max-w-[1400px] mx-auto px-2.5 py-2 space-y-1.5">
      <!-- Loading -->
      <div v-if="loading" class="flex items-center justify-center h-[60vh]">
        <div class="flex flex-col items-center gap-2 text-white/60">
          <svg class="animate-spin h-5 w-5 text-blue-400" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="3"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          <p>Syncing schedule data...</p>
        </div>
      </div>

      <!-- Schedule -->
      <div v-else class="space-y-1.5">
        <section
          v-for="shift in shiftsWithAssignments"
          :key="shift.id"
          class="rounded-md border border-white/10 bg-white/5 backdrop-blur-sm shadow-[0_4px_12px_rgba(0,0,0,0.25)] overflow-hidden"
        >
          <div class="flex items-center justify-between px-2.5 py-1 border-b border-white/10 bg-gradient-to-r from-white/6 to-transparent">
            <h2 class="text-[10px] font-semibold tracking-wide text-white">{{ shift.name }}</h2>
            <span v-if="shift.employees && shift.employees.length" class="text-[8px] text-white/50 uppercase tracking-[0.2em]">
              {{ shift.employees.length }} staff
            </span>
          </div>

          <div v-if="shift.employees && shift.employees.length > 0" class="divide-y divide-white/10">
            <article
              v-for="employee in shift.employees"
              :key="employee.id"
              class="flex items-start gap-2 px-2.5 py-1.25 hover:bg-white/8 transition-colors"
            >
              <div class="w-28 flex-shrink-0 text-[9px] font-semibold uppercase tracking-[0.2em] text-white/70">
                {{ employee.last_name }}, {{ employee.first_name }}
              </div>
              <div class="flex flex-wrap gap-0.75">
                <div
                  v-for="item in getEmployeeScheduleItems(employee)"
                  :key="item.id"
                  class="relative flex items-center gap-0.5 px-1.25 py-0.5 rounded border border-white/15 shadow-md shadow-black/25 min-w-[4.75rem] max-w-[5.5rem]"
                  :style="{
                    backgroundColor: addAlpha(item.assignment.job_function.color_code, 0.85),
                    borderColor: addAlpha(darkenColor(item.assignment.job_function.color_code), 0.8),
                    color: getTextColor(item.assignment.job_function.color_code),
                    boxShadow: '0 5px 9px -8px rgba(0,0,0,0.6)'
                  }"
                >
                  <div class="w-0.5 h-5 rounded" :style="{ backgroundColor: darkenColor(item.assignment.job_function.color_code) }"></div>
                  <div class="flex flex-col leading-tight">
                    <span class="font-semibold text-[9px] uppercase tracking-wide truncate">{{ item.assignment.job_function.name }}</span>
                    <span class="text-[8px] font-medium opacity-70">{{ item.timeRange }}</span>
                  </div>
                </div>
              </div>
            </article>
          </div>

          <div v-else class="px-2.5 py-1.5 text-[9px] text-white/50 text-center bg-white/4">
            No team members assigned to this shift
          </div>
        </section>

        <div v-if="shiftsWithAssignments.length === 0" class="text-center py-10 text-white/50 text-sm">
          <p>No schedule available for today</p>
          <NuxtLink to="/" class="inline-flex items-center text-blue-300 hover:text-blue-200 text-[10px] mt-1 underline decoration-dotted">
            Open Operations Console
          </NuxtLink>
        </div>
      </div>
    </div>

    <footer class="fixed bottom-2 right-2 px-1.5 py-0.75 rounded-full bg-white/10 border border-white/20 text-[8px] text-white/60 uppercase tracking-[0.25em] backdrop-blur">
      Auto Refresh · 2m
    </footer>
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
      const employeeAssignmentsList = (employeeAssignments.get(employee.id) || [])
        .filter((a: any) => a.shift_id === targetShiftId)
        .filter((a: any) => !overlapsPTO(employee.id, String(a.start_time), String(a.end_time)))
      
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
      currentBlock.shift_id === assignment.shift_id &&
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

const addAlpha = (hex: string, alpha: number): string => {
  hex = hex.replace('#', '')
  const r = parseInt(hex.substring(0, 2), 16)
  const g = parseInt(hex.substring(2, 4), 16)
  const b = parseInt(hex.substring(4, 6), 16)
  return `rgba(${r}, ${g}, ${b}, ${alpha})`
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

