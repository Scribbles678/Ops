<template>
  <div class="display-page min-h-screen text-white" style="background: linear-gradient(135deg, #1a1f4e 0%, #182078 50%, #1a1f4e 100%)">
    <!-- Header bar -->
    <div class="sticky top-0 z-30 px-4 py-2 flex items-center justify-between" style="background: rgba(15, 18, 60, 0.9); backdrop-filter: blur(8px); border-bottom: 1px solid rgba(255,255,255,0.08)">
      <div class="flex items-center gap-3">
        <h1 class="text-sm font-bold tracking-wide text-white/90">Today's Schedule</h1>
        <span class="text-xs text-white/40">{{ formattedDate }}</span>
      </div>
      <div class="flex items-center gap-3">
        <span class="text-[10px] text-white/30 uppercase tracking-widest">{{ lastUpdated ? `Updated ${lastUpdated}` : '' }}</span>
        <button
          @click="showRequestModal = true"
          class="px-3 py-1.5 rounded-md text-[11px] text-white font-medium tracking-wide transition-colors"
          style="background: rgba(255,255,255,0.12); border: 1px solid rgba(255,255,255,0.15)"
          onmouseover="this.style.background='rgba(255,255,255,0.2)'"
          onmouseout="this.style.background='rgba(255,255,255,0.12)'"
        >
          Time Off / Schedule Change
        </button>
      </div>
    </div>

    <div class="max-w-[1500px] mx-auto px-4 py-3 space-y-3">
      <!-- Loading (initial load only) -->
      <div v-if="!initialLoadDone" class="flex items-center justify-center h-[60vh]">
        <div class="flex flex-col items-center gap-3 text-white/60">
          <svg class="animate-spin h-6 w-6 text-blue-300" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="3"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          <p class="text-sm">Loading schedule...</p>
        </div>
      </div>

      <!-- Schedule -->
      <div v-else class="space-y-3">
        <section
          v-for="shift in shiftsWithAssignments"
          :key="shift.id"
          class="rounded-lg overflow-hidden"
          style="background: rgba(255,255,255,0.06); border: 1px solid rgba(255,255,255,0.08)"
        >
          <!-- Shift header -->
          <div class="flex items-center justify-between px-4 py-2" style="background: rgba(255,255,255,0.05); border-bottom: 1px solid rgba(255,255,255,0.06)">
            <div class="flex items-center gap-2">
              <div class="w-1 h-5 rounded-full bg-blue-400"></div>
              <h2 class="text-xs font-bold tracking-wide text-white/90 uppercase">{{ shift.name }}</h2>
            </div>
            <div class="flex items-center gap-3">
              <span class="text-[10px] text-white/40 uppercase tracking-widest">
                {{ getAssignedCount(shift) }} assigned
              </span>
              <span class="text-[10px] text-white/25 uppercase tracking-widest">
                {{ shift.employees?.length || 0 }} total
              </span>
            </div>
          </div>

          <!-- Assigned employees -->
          <div v-if="getAssignedEmployees(shift).length > 0" class="divide-y divide-white/5">
            <article
              v-for="employee in getAssignedEmployees(shift)"
              :key="employee.id"
              class="flex items-center gap-4 px-4 py-1.5"
            >
              <div class="w-36 flex-shrink-0 text-[11px] font-semibold uppercase tracking-wider text-white/70">
                {{ employee.last_name }}, {{ employee.first_name }}
              </div>
              <div class="flex flex-wrap gap-1.5 flex-1">
                <div
                  v-for="item in getEmployeeScheduleItems(employee)"
                  :key="item.id"
                  class="flex items-center gap-1.5 px-2.5 py-1 rounded-md min-w-[8rem]"
                  :style="{
                    backgroundColor: addAlpha(item.assignment.job_function.color_code, 0.9),
                    color: getTextColor(item.assignment.job_function.color_code),
                  }"
                >
                  <div class="w-0.5 h-5 rounded-full" :style="{ backgroundColor: darkenColor(item.assignment.job_function.color_code) }"></div>
                  <div class="flex flex-col leading-tight">
                    <span class="font-bold text-[10px] uppercase tracking-wide">{{ item.assignment.job_function.name }}</span>
                    <span class="text-[9px] font-medium opacity-75">{{ item.timeRange }}</span>
                  </div>
                </div>
              </div>
            </article>
          </div>

          <!-- Unassigned employees (collapsed) -->
          <div v-if="getUnassignedEmployees(shift).length > 0" class="px-4 py-1.5" style="background: rgba(255,255,255,0.02); border-top: 1px solid rgba(255,255,255,0.04)">
            <div class="flex flex-wrap gap-x-4 gap-y-0.5">
              <span class="text-[10px] text-white/25 uppercase tracking-wider font-medium mr-1">Unassigned:</span>
              <span
                v-for="emp in getUnassignedEmployees(shift)"
                :key="emp.id"
                class="text-[10px] text-white/30"
              >
                {{ emp.last_name }}, {{ emp.first_name }}
              </span>
            </div>
          </div>

          <div v-if="!shift.employees || shift.employees.length === 0" class="px-4 py-3 text-xs text-white/25 text-center">
            No team members assigned to this shift
          </div>
        </section>

        <div v-if="shiftsWithAssignments.length === 0" class="text-center py-16 text-white/40">
          <p class="text-sm">No schedule available for today</p>
          <NuxtLink to="/" class="inline-flex items-center text-blue-300 hover:text-blue-200 text-xs mt-2 underline decoration-dotted">
            Open Operations Console
          </NuxtLink>
        </div>
      </div>
    </div>

    <!-- Request Modal -->
    <ScheduleRequestsRequestFormModal
      v-if="showRequestModal"
      @close="showRequestModal = false"
      @submitted="onRequestSubmitted"
    />
  </div>
</template>

<script setup lang="ts">
const { formatTime, formatDate } = useLaborCalculations()
const {
  scheduleAssignments: assignments,
  shifts,
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

const showRequestModal = ref(false)

const onRequestSubmitted = () => {
  // Refresh data after a request is submitted (approved PTO/swap may affect display)
  loadData()
}

const initialLoadDone = ref(false)
const lastUpdated = ref('')
const refreshInterval = ref<NodeJS.Timeout | null>(null)
const rolloverInterval = ref<NodeJS.Timeout | null>(null)

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
  today.value = getTZISODate(TIMEZONE)
  loadData()

  // Auto-refresh every 2 minutes
  refreshInterval.value = setInterval(() => {
    loadData()
  }, 120000)

  // Update date every minute to catch midnight rollover
  const tick = () => {
    const current = getTZISODate(TIMEZONE)
    if (today.value !== current) {
      today.value = current
      loadData()
    }
  }
  rolloverInterval.value = setInterval(tick, 60000)
})

onUnmounted(() => {
  if (refreshInterval.value) clearInterval(refreshInterval.value)
  if (rolloverInterval.value) clearInterval(rolloverInterval.value)
})

const loadData = async () => {
  try {
    await Promise.all([
      fetchShifts(),
      fetchEmployees(),
      fetchScheduleForDate(today.value),
      fetchPTOForDate(today.value),
      fetchShiftSwapsForDate(today.value)
    ])
    updateLastUpdated()
    initialLoadDone.value = true
  } catch (e) {
    console.error('Failed to load display data:', e)
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

// Helpers for assigned vs unassigned employees within a shift
const getAssignedEmployees = (shift: any) => {
  return (shift.employees || []).filter((emp: any) => emp.assignments && emp.assignments.length > 0)
}

const getUnassignedEmployees = (shift: any) => {
  return (shift.employees || []).filter((emp: any) => !emp.assignments || emp.assignments.length === 0)
}

const getAssignedCount = (shift: any) => {
  return getAssignedEmployees(shift).length
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

