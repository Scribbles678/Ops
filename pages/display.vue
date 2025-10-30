<template>
  <div class="min-h-screen bg-gray-900 text-white">
    <!-- Header -->
    <div class="bg-gray-800 border-b border-gray-700 px-3 py-2">
      <div class="flex justify-between items-center">
        <div>
          <h1 class="text-lg font-bold">OPERATIONS SCHEDULE</h1>
          <p class="text-gray-400 text-sm">{{ formattedDate }}</p>
        </div>
        <div class="flex items-center space-x-3">
          <div class="text-right">
            <p class="text-xs text-gray-400">Last Updated</p>
            <p class="text-sm font-semibold">{{ lastUpdated }}</p>
          </div>
          <button
            @click="refreshData"
            class="bg-gray-700 hover:bg-gray-600 px-2 py-1 rounded-md transition flex items-center text-xs"
          >
            <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
            </svg>
            Refresh
          </button>
        </div>
      </div>
    </div>

    <!-- Loading State -->
    <div v-if="loading" class="flex items-center justify-center h-64">
      <p class="text-gray-400 text-xl">Loading schedule...</p>
    </div>

    <!-- Schedule Content -->
    <div v-else class="p-2 space-y-2">
      <!-- Each Shift -->
      <div
        v-for="shift in shiftsWithAssignments"
        :key="shift.id"
        class="bg-gray-800 rounded-md border border-gray-700 p-2"
      >
        <h2 class="text-sm font-semibold mb-1 pb-1 border-b border-gray-700">
          {{ shift.name }}
        </h2>

        <!-- Employees Grid -->
        <div v-if="shift.employees && shift.employees.length > 0" class="divide-y divide-gray-700">
          <div
            v-for="employee in shift.employees"
            :key="employee.id"
            class="flex items-center gap-2 py-1"
          >
            <!-- Employee name -->
            <div class="w-40 text-white text-xs font-medium truncate">
              {{ employee.last_name }}, {{ employee.first_name }}
            </div>
            
            <!-- Inline assignment pills -->
            <div class="flex flex-wrap gap-1">
              <div
                v-for="assignment in employee.assignments"
                :key="assignment.id"
                class="rounded-sm px-1 py-0.5 text-[9px] border border-opacity-50"
                :style="{
                  backgroundColor: assignment.job_function.color_code,
                  borderColor: darkenColor(assignment.job_function.color_code),
                  color: getTextColor(assignment.job_function.color_code)
                }"
              >
                <span class="font-semibold mr-1">{{ assignment.job_function.name }}</span>
                <span class="opacity-90">{{ formatTime(assignment.start_time) }}-{{ formatTime(assignment.end_time) }}</span>
              </div>
            </div>
          </div>
        </div>

        <!-- No employees message -->
        <div v-else class="text-center py-4 text-gray-500 text-sm">
          No staff scheduled for this shift
        </div>
      </div>

      <!-- No schedule message -->
      <div v-if="shiftsWithAssignments.length === 0" class="text-center py-16">
        <p class="text-gray-400 text-xl">No schedule available for today</p>
        <NuxtLink to="/" class="text-blue-400 hover:text-blue-300 mt-4 inline-block">
          Go to Home Page
        </NuxtLink>
      </div>
    </div>

    <!-- Auto-refresh indicator -->
    <div class="fixed bottom-2 right-2 bg-gray-800 px-2 py-1 rounded text-xs text-gray-400 border border-gray-700">
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

const {
  employees,
  loading: employeesLoading,
  fetchEmployees
} = useEmployees()

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
  
  // Group employees by their shift_id
  employees.value.forEach(employee => {
    const shiftId = employee.shift_id
    if (shiftMap.has(shiftId)) {
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
      
      shiftMap.get(shiftId).employees.push(employeeWithAssignments)
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
  
  // Set up auto-refresh every 2 minutes
  refreshInterval.value = setInterval(() => {
    loadData()
  }, 120000)

  // Update today's date every minute to catch midnight rollover, and reload when it changes
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
  if (refreshInterval.value) {
    clearInterval(refreshInterval.value)
  }
  if (rolloverInterval.value) {
    clearInterval(rolloverInterval.value)
  }
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
      fetchPTOForDate(today.value)
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
</script>

