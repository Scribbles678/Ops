<template>
  <div class="min-h-screen bg-gray-900 text-white">
    <!-- Header -->
    <div class="bg-gray-800 border-b border-gray-700 px-6 py-4">
      <div class="flex justify-between items-center">
        <div>
          <h1 class="text-3xl font-bold">OPERATIONS SCHEDULE</h1>
          <p class="text-gray-400 text-lg">{{ formattedDate }}</p>
        </div>
        <div class="flex items-center space-x-4">
          <div class="text-right">
            <p class="text-sm text-gray-400">Last Updated</p>
            <p class="text-lg font-semibold">{{ lastUpdated }}</p>
          </div>
          <button
            @click="refreshData"
            class="bg-gray-700 hover:bg-gray-600 px-4 py-2 rounded-lg transition flex items-center"
          >
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
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
    <div v-else class="p-6 space-y-6">
      <!-- Each Shift -->
      <div
        v-for="shift in shiftsWithAssignments"
        :key="shift.id"
        class="bg-gray-800 rounded-lg border border-gray-700 p-6"
      >
        <h2 class="text-2xl font-bold mb-4 pb-3 border-b border-gray-700">
          {{ shift.name }}
        </h2>

        <!-- Employees Grid -->
        <div v-if="shift.employees && shift.employees.length > 0" class="space-y-4">
          <div
            v-for="employee in shift.employees"
            :key="employee.id"
            class="bg-gray-700 rounded-lg p-4"
          >
            <!-- Employee Header -->
            <div class="text-lg font-semibold mb-3 text-white">
              {{ employee.last_name }}, {{ employee.first_name }}
            </div>
            
            <!-- Employee Assignments -->
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-3">
              <div
                v-for="assignment in employee.assignments"
                :key="assignment.id"
                class="rounded-lg p-3 text-white font-medium border-2 border-opacity-50"
                :style="{
                  backgroundColor: assignment.job_function.color_code,
                  borderColor: darkenColor(assignment.job_function.color_code)
                }"
              >
                <div class="flex flex-col">
                  <div class="text-sm font-semibold mb-1">
                    {{ assignment.job_function.name }}
                  </div>
                  <div class="text-xs opacity-90 flex items-center">
                    <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    {{ formatTime(assignment.start_time) }} - {{ formatTime(assignment.end_time) }}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- No employees message -->
        <div v-else class="text-center py-8 text-gray-500">
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
    <div class="fixed bottom-4 right-4 bg-gray-800 px-4 py-2 rounded-lg text-sm text-gray-400 border border-gray-700">
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

const lastUpdated = ref('')
const refreshInterval = ref<NodeJS.Timeout | null>(null)

const today = computed(() => {
  return new Date().toISOString().split('T')[0]
})

const formattedDate = computed(() => {
  return formatDate(today.value)
})

const shiftsWithAssignments = computed(() => {
  console.log('Computing shiftsWithAssignments...')
  // Get all assignments and consolidate them first
  const allAssignments = consolidateAssignments(assignments.value)
  
  // Group assignments by employee to find their starting shift
  const employeeStartingShifts = new Map()
  
  allAssignments.forEach(assignment => {
    const employeeId = assignment.employee_id
    if (!employeeStartingShifts.has(employeeId)) {
      // Find the shift this assignment belongs to
      const shift = shifts.value.find(s => s.id === assignment.shift_id)
      if (shift) {
        employeeStartingShifts.set(employeeId, {
          shift,
          assignments: []
        })
      }
    }
    
    // Add this assignment to the employee's list
    const employeeData = employeeStartingShifts.get(employeeId)
    if (employeeData) {
      employeeData.assignments.push(assignment)
    }
  })
  
  // Convert back to shift-based structure
  const shiftMap = new Map()
  
  employeeStartingShifts.forEach((employeeData, employeeId) => {
    const shiftId = employeeData.shift.id
    if (!shiftMap.has(shiftId)) {
      shiftMap.set(shiftId, {
        ...employeeData.shift,
        employees: []
      })
    }
    
    // Group assignments by job function for this employee
    const assignmentsByJobFunction = new Map()
    employeeData.assignments.forEach(assignment => {
      const jobFunctionId = assignment.job_function_id
      if (!assignmentsByJobFunction.has(jobFunctionId)) {
        assignmentsByJobFunction.set(jobFunctionId, [])
      }
      assignmentsByJobFunction.get(jobFunctionId).push(assignment)
    })
    
    // Create employee object with consolidated assignments
    const employee = {
      id: employeeId,
      first_name: employeeData.assignments[0].employee.first_name,
      last_name: employeeData.assignments[0].employee.last_name,
      assignments: Array.from(assignmentsByJobFunction.values()).flat()
    }
    
    shiftMap.get(shiftId).employees.push(employee)
  })
  
  return Array.from(shiftMap.values())
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
  loadData()
  
  // Set up auto-refresh every 2 minutes
  refreshInterval.value = setInterval(() => {
    loadData()
  }, 120000)
})

onUnmounted(() => {
  if (refreshInterval.value) {
    clearInterval(refreshInterval.value)
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
    await fetchShifts()
    await fetchScheduleForDate(today.value)
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
</script>

