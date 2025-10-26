<template>
  <div class="min-h-screen bg-gray-50">
    <div class="container mx-auto px-4 py-8">
      <!-- Header -->
      <div class="flex items-center justify-between mb-8">
        <div>
          <h1 class="text-4xl font-bold text-gray-800">Edit Today's Schedule</h1>
          <p class="text-gray-600 mt-2">{{ formatDate(scheduleDate || '') }}</p>
        </div>
        <div class="flex space-x-4">
          <button @click="saveSchedule" class="btn-primary">
            Save Schedule
          </button>
          <NuxtLink to="/" class="btn-secondary">
            ← Back to Home
          </NuxtLink>
        </div>
      </div>

      <!-- Labor Hours Summary -->
      <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
        <div class="card">
          <div class="text-center">
            <div class="text-2xl font-bold text-blue-600">{{ totalEmployees }}</div>
            <div class="text-sm text-gray-600">Total Employees</div>
          </div>
        </div>
        <div class="card">
          <div class="text-center">
            <div class="text-2xl font-bold text-green-600">{{ totalLaborHours }}h</div>
            <div class="text-sm text-gray-600">Total Labor Hours</div>
          </div>
        </div>
        <div class="card">
          <div class="text-center">
            <div class="text-2xl font-bold text-purple-600">{{ totalShifts }}</div>
            <div class="text-sm text-gray-600">Active Shifts</div>
          </div>
        </div>
        <div class="card">
          <div class="text-center">
            <div class="text-2xl font-bold text-orange-600">{{ unassignedEmployees }}</div>
            <div class="text-sm text-gray-600">Unassigned</div>
          </div>
        </div>
      </div>

      <!-- Job Function Hours Breakdown -->
      <div class="card mb-8">
        <h3 class="text-xl font-bold text-gray-800 mb-4">Job Function Hours Breakdown</h3>
        <div class="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-7 gap-6">
          <div v-for="jobFunction in jobFunctionHours" :key="jobFunction.name" class="text-center bg-gray-50 rounded-lg p-4 border border-gray-200 hover:shadow-sm transition-shadow">
            <div class="flex items-center justify-center mb-3">
              <div 
                class="w-5 h-5 rounded border-2 border-gray-400 mr-3 shadow-sm" 
                :style="{ backgroundColor: jobFunction.color }"
              ></div>
              <span class="text-sm font-semibold text-gray-800">{{ jobFunction.name }}</span>
            </div>
            <div class="text-3xl font-bold text-gray-900 bg-white rounded-lg py-2 px-3 shadow-sm">
              {{ jobFunction.hours }}
            </div>
          </div>
        </div>
      </div>

      <!-- Shift-Based Schedule Layout -->
      <div v-if="loading" class="card text-center py-8">
        <p class="text-gray-600">Loading schedule data...</p>
      </div>
      
      <div v-else-if="error" class="card text-center py-8">
        <p class="text-red-600">Error loading schedule: {{ error }}</p>
      </div>
      
      <div v-else-if="!employees.length" class="card text-center py-8">
        <p class="text-gray-600">No employees found. Please add employees first.</p>
      </div>
      
      <!-- Full-width schedule container with horizontal scroll -->
      <div v-else class="w-full overflow-x-auto">
        <div class="min-w-max">
          <ShiftGroupedSchedule
            :employees="employees"
            :schedule-assignments="scheduleAssignments"
            :job-functions="jobFunctions"
            :shifts="scheduleData"
            :schedule-assignments-data="scheduleAssignmentsData"
            @add-assignment="handleAddAssignment"
            @edit-assignment="handleEditAssignment"
            @assign-break-coverage="handleBreakCoverage"
            @schedule-data-updated="handleScheduleDataUpdated"
          />
        </div>
      </div>

      <!-- Job Function Assignment Modal -->
      <div v-if="showEmployeeModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-white rounded-lg p-6 max-w-2xl w-full mx-4 max-h-96 overflow-y-auto">
          <h3 class="text-xl font-bold mb-4">
            Assign Job Function to {{ selectedEmployee?.last_name || '' }}, {{ selectedEmployee?.first_name || '' }}
            <span v-if="selectedShift"> - {{ selectedShift.name }}</span>
          </h3>
          
          <!-- Available Job Functions -->
          <div class="space-y-2 mb-4">
            <h4 class="font-medium text-gray-700">Available Job Functions:</h4>
            <div class="grid grid-cols-2 md:grid-cols-3 gap-2 max-h-48 overflow-y-auto">
              <div v-for="jobFunction in availableJobFunctions" :key="jobFunction" 
                   class="flex items-center justify-between p-2 border border-gray-200 rounded hover:bg-gray-50">
                <div class="flex items-center space-x-2">
                  <div class="w-4 h-4 rounded border border-gray-300" 
                       :style="{ backgroundColor: getJobFunctionColor(jobFunction) }"></div>
                  <span class="text-sm">{{ jobFunction }}</span>
                </div>
                <button @click="assignJobFunction(jobFunction)" 
                        class="px-3 py-1 bg-blue-100 text-blue-600 rounded hover:bg-blue-200 transition text-sm">
                  Assign
                </button>
              </div>
            </div>
          </div>

          <!-- Current Assignments -->
          <div v-if="selectedEmployee && selectedShift && getEmployeeAssignments(selectedEmployee.id, selectedShift.id).length > 0" class="space-y-2">
            <h4 class="font-medium text-gray-700">Current Assignments:</h4>
            <div class="space-y-1">
              <div v-for="assignment in getEmployeeAssignments(selectedEmployee.id, selectedShift.id)" :key="assignment.id" 
                   class="flex items-center justify-between p-2 bg-gray-50 rounded">
                <div class="flex items-center space-x-2">
                  <div class="w-4 h-4 rounded" 
                       :style="{ backgroundColor: getJobFunctionColor(assignment.job_function) }"></div>
                  <span class="text-sm">{{ assignment.job_function }}</span>
                </div>
                <button @click="removeAssignment(assignment.id)" 
                        class="px-3 py-1 bg-red-100 text-red-600 rounded hover:bg-red-200 transition text-sm">
                  Remove
                </button>
              </div>
            </div>
          </div>

          <div class="flex justify-end space-x-3 pt-4">
            <button @click="closeEmployeeModal" class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50">
              Close
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
// Import the component explicitly
import ShiftGroupedSchedule from '~/components/schedule/ShiftGroupedSchedule.vue'

// Use real composables instead of mock data
const { 
  employees, 
  loading: employeesLoading, 
  error: employeesError, 
  fetchEmployees 
} = useEmployees()

const { 
  jobFunctions, 
  loading: functionsLoading, 
  error: functionsError, 
  fetchJobFunctions 
} = useJobFunctions()

const { 
  shifts, 
  loading: shiftsLoading, 
  error: shiftsError, 
  fetchShifts 
} = useSchedule()

const { 
  scheduleAssignments: scheduleAssignmentsRef, 
  loading: assignmentsLoading, 
  error: assignmentsError, 
  fetchScheduleForDate,
  createAssignment,
  deleteAssignment
} = useSchedule()

// Ensure scheduleAssignments is always an array
const scheduleAssignments = computed(() => (scheduleAssignmentsRef.value || []) as any[])

// Create schedule data from shifts
const scheduleData = computed(() => {
  if (!shifts.value || shifts.value.length === 0) return []
  return shifts.value.map((shift: any) => ({
    id: shift.id,
    name: shift.name,
    start_time: shift.start_time,
    end_time: shift.end_time,
    break_1_start: shift.break_1_start,
    break_1_end: shift.break_1_end,
    break_2_start: shift.break_2_start,
    break_2_end: shift.break_2_end,
    lunch_start: shift.lunch_start,
    lunch_end: shift.lunch_end,
    employee_count: 0 // Will be calculated
  }))
})

// Data loading
const loading = computed(() => 
  employeesLoading.value || functionsLoading.value || shiftsLoading.value || assignmentsLoading.value
)

const error = computed(() => 
  employeesError.value || functionsError.value || shiftsError.value || assignmentsError.value
)

// Modal state
const showEmployeeModal = ref(false)
const selectedEmployee = ref<any>(null)
const selectedShift = ref<any>(null)
const selectedJobFunction = ref('')
const scheduleAssignmentsData = ref<Record<string, any>>({})

// Get route params
const route = useRoute()
const scheduleDate = ref((route.params.date as string) || new Date().toISOString().split('T')[0])

// Initialize schedule data from existing assignments
const initializeScheduleData = () => {
  console.log('Initializing schedule data...')
  console.log('Schedule assignments:', scheduleAssignments.value)
  console.log('Employees:', employees.value.length)
  console.log('Job functions:', jobFunctions.value.length)
  
  const initialData: Record<string, any> = {}
  
  // Initialize data for each employee
  employees.value.forEach((employee: any) => {
    initialData[employee.id] = {}
  })
  
  // Add existing assignments
  scheduleAssignments.value.forEach((assignment: any) => {
    if (!initialData[assignment.employee_id]) {
      initialData[assignment.employee_id] = {}
    }
    
    const jobFunction = jobFunctions.value.find((jf: any) => jf.id === assignment.job_function_id)
    if (jobFunction) {
      // Convert time format from "HH:MM:SS" to "HH:MM" for consistency
      const timeKey = assignment.start_time.substring(0, 5) // "07:00:00" -> "07:00"
      
      initialData[assignment.employee_id][timeKey] = {
        assignment: jobFunction.name,
        until: assignment.end_time ? assignment.end_time.substring(0, 5) : ''
      }
    }
  })
  
  console.log('Initialized schedule data:', initialData)
  scheduleAssignmentsData.value = initialData
  console.log('scheduleAssignmentsData after initialization:', scheduleAssignmentsData.value)
}

// Load data on mount
onMounted(async () => {
  try {
    await Promise.all([
      fetchEmployees(),
      fetchJobFunctions(),
      fetchShifts(),
      fetchScheduleForDate(scheduleDate.value)
    ])
    
    // Initialize schedule data from existing assignments
    // Use nextTick to ensure all reactive data is updated
    await nextTick()
    initializeScheduleData()
    
  } catch (error) {
    console.error('Error loading schedule data:', error)
  }
})

// Computed properties
const totalEmployees = computed(() => {
  return employees.value.length
})

const totalLaborHours = computed(() => {
  // Calculate as total employees × 8 hours (standard work day)
  return totalEmployees.value * 8
})

const totalShifts = computed(() => {
  return shifts.value.length
})

const unassignedEmployees = computed(() => {
  if (!scheduleAssignments.value || !employees.value) return 0
  const assignedEmployeeIds = new Set(scheduleAssignments.value.map((a: any) => a.employee_id))
  return employees.value.filter((e: any) => !assignedEmployeeIds.has(e.id)).length
})

const jobFunctionHours = computed(() => {
  if (!jobFunctions.value || !scheduleAssignmentsData.value) return []
  
  // Calculate hours based on actual schedule data from the component
  const jobFunctionTotals: Record<string, number> = {}
  
  // Initialize all job functions with 0 hours
  jobFunctions.value.forEach((job: any) => {
    jobFunctionTotals[job.name] = 0
  })
  
  // Calculate hours for each employee's schedule
  Object.entries(scheduleAssignmentsData.value).forEach(([employeeId, employeeSchedule]: [string, any]) => {
    Object.entries(employeeSchedule).forEach(([timeSlot, data]: [string, any]) => {
      if (data.assignment && data.assignment.trim() !== '') {
        // Each 15-minute slot = 0.25 hours
        const jobName = data.assignment
        if (jobFunctionTotals.hasOwnProperty(jobName)) {
          jobFunctionTotals[jobName] += 0.25
        }
      }
    })
  })
  
  return jobFunctions.value.map((job: any) => {
    const totalHours = jobFunctionTotals[job.name] || 0
    
    return {
      name: job.name,
      color: job.color_code,
      hours: Math.round(totalHours * 10) / 10, // Round to 1 decimal place
      employees: 0 // We'll calculate this separately if needed
    }
  })
})

// Functions
const formatDate = (dateString: string) => {
  const date = new Date(dateString)
  return date.toLocaleDateString('en-US', { 
    weekday: 'long', 
    year: 'numeric', 
    month: 'long', 
    day: 'numeric' 
  })
}

const getEmployeeAssignment = (employeeId: string, timeBlock: string) => {
  if (!scheduleAssignments.value) return null
  return scheduleAssignments.value.find((a: any) => 
    a.employee_id === employeeId && a.shift_id === timeBlock
  )
}

const getEmployeeAssignments = (employeeId: string, shiftId: string) => {
  if (!scheduleAssignments.value) return []
  return scheduleAssignments.value.filter((a: any) => 
    a.employee_id === employeeId && a.shift_id === shiftId
  )
}

const getEmployeesForShiftAndJob = (shiftId: string, jobFunction: string) => {
  if (!scheduleAssignments.value || !employees.value) return []
  const assignments = scheduleAssignments.value.filter((a: any) => 
    a.shift_id === shiftId && a.job_function === jobFunction
  )
  return assignments.map((assignment: any) => 
    employees.value.find((e: any) => e.id === assignment.employee_id)
  ).filter(Boolean)
}

const getTotalEmployeesForShift = (shiftId: string) => {
  if (!scheduleAssignments.value) return 0
  return scheduleAssignments.value.filter((a: any) => a.shift_id === shiftId).length
}

const getJobFunctionColor = (jobFunctions: string) => {
  const colors: Record<string, string> = {
    'RT Pick': '#FFA500',
    'Pick': '#FFFF00',
    'Meter': '#87CEEB',
    'Locus': '#FFFFFF',
    'Helpdesk': '#FFD700',
    'Coordinator': '#C0C0C0',
    'Team Lead': '#000080'
  }
  return colors[jobFunctions] || '#3B82F6'
}

const addAssignmentToEmployee = (employeeId: string, shiftId: string) => {
  selectedEmployee.value = employees.value.find((e: any) => e.id === employeeId) || null
  selectedShift.value = scheduleData.value.find((s: any) => s.id === shiftId) || null
  showEmployeeModal.value = true
}

const addEmployeeToShift = (shiftId: string, jobFunction: string) => {
  selectedShift.value = scheduleData.value.find((s: any) => s.id === shiftId) || null
  selectedJobFunction.value = jobFunction
  showEmployeeModal.value = true
}

const availableJobFunctions = computed(() => {
  if (!selectedEmployee.value) return []
  
  // Get job functions the employee is trained for
  return (selectedEmployee.value as any).trained_job_functions || []
})

const availableEmployees = computed(() => {
  if (!selectedShift.value || !selectedJobFunction.value || !scheduleAssignments.value || !employees.value) return []
  
  const assignedEmployeeIds = scheduleAssignments.value
    .filter((a: any) => a.shift_id === (selectedShift.value as any).id)
    .map((a: any) => a.employee_id)
  
  return employees.value.filter((employee: any) => 
    !assignedEmployeeIds.includes(employee.id) && 
    employee.trained_job_functions.includes(selectedJobFunction.value)
  )
})

const assignJobFunction = (jobFunction: string) => {
  if (!scheduleAssignments.value || !selectedEmployee.value || !selectedShift.value) return
  
  scheduleAssignments.value.push({
    id: Date.now().toString(), // Simple ID generation
    employee_id: (selectedEmployee.value as any).id,
    shift_id: (selectedShift.value as any).id,
    job_function: jobFunction
  })
}

const removeAssignment = (assignmentId: string) => {
  if (!scheduleAssignments.value) return
  const index = scheduleAssignments.value.findIndex((a: any) => a.id === assignmentId)
  if (index > -1) {
    scheduleAssignments.value.splice(index, 1)
  }
}

const assignEmployee = (employeeId: string) => {
  if (!scheduleAssignments.value || !selectedShift.value) return
  
  scheduleAssignments.value.push({
    id: Date.now().toString(),
    employee_id: employeeId,
    shift_id: (selectedShift.value as any).id,
    job_function: selectedJobFunction.value
  })
}

const removeEmployee = (employeeId: string) => {
  if (!scheduleAssignments.value || !selectedShift.value) return
  
  const index = scheduleAssignments.value.findIndex((a: any) => 
    a.employee_id === employeeId && 
    a.shift_id === (selectedShift.value as any).id &&
    a.job_function === selectedJobFunction.value
  )
  if (index > -1) {
    scheduleAssignments.value.splice(index, 1)
  }
}

const closeEmployeeModal = () => {
  showEmployeeModal.value = false
  selectedEmployee.value = null
  selectedShift.value = null
  selectedJobFunction.value = ''
}

// Time utility functions
const timeToMinutes = (timeStr: string): number => {
  const [hours, minutes] = timeStr.split(':').map(Number)
  return hours * 60 + minutes
}

const minutesToTime = (minutes: number): string => {
  const hours = Math.floor(minutes / 60)
  const mins = minutes % 60
  return `${hours.toString().padStart(2, '0')}:${mins.toString().padStart(2, '0')}`
}

const clearAssignmentsForDate = async (date: string) => {
  try {
    // Get all assignments for this date
    const assignmentsToDelete = scheduleAssignments.value.filter(assignment => 
      assignment.schedule_date === date
    )
    
    // Delete each assignment
    for (const assignment of assignmentsToDelete) {
      await deleteAssignment(assignment.id)
    }
  } catch (error) {
    console.error('Error clearing assignments:', error)
    throw error
  }
}

const saveSchedule = async () => {
  try {
    // Clear existing assignments for this date first
    await clearAssignmentsForDate(scheduleDate.value)
    
    // Convert scheduleAssignmentsData to database format and save
    const assignmentsToSave = []
    
    Object.entries(scheduleAssignmentsData.value).forEach(([employeeId, employeeSchedule]) => {
      Object.entries(employeeSchedule).forEach(([timeSlot, data]) => {
        if (data.assignment && data.assignment.trim() !== '') {
          // Find the job function ID
          const jobFunction = jobFunctions.value.find(jf => jf.name === data.assignment)
          if (jobFunction) {
            // Find the shift ID for this time slot
            const shift = shifts.value.find(s => {
              // Check if this time slot falls within the shift hours
              const timeSlotMinutes = timeToMinutes(timeSlot)
              const shiftStartMinutes = timeToMinutes(s.start_time)
              const shiftEndMinutes = timeToMinutes(s.end_time)
              return timeSlotMinutes >= shiftStartMinutes && timeSlotMinutes < shiftEndMinutes
            })
            
            if (shift) {
              // Calculate end time (15 minutes later)
              const startTimeMinutes = timeToMinutes(timeSlot)
              const endTimeMinutes = startTimeMinutes + 15
              const endTime = minutesToTime(endTimeMinutes)
              
              assignmentsToSave.push({
                employee_id: employeeId,
                job_function_id: jobFunction.id,
                shift_id: shift.id,
                start_time: timeSlot,
                end_time: endTime,
                schedule_date: scheduleDate.value
              })
            }
          }
        }
      })
    })
    
    // Save all assignments
    if (assignmentsToSave.length > 0) {
      for (const assignment of assignmentsToSave) {
        await createAssignment(assignment)
      }
    }
    
    // Refresh the schedule data
    await fetchScheduleForDate(scheduleDate.value)
    
    alert(`Schedule saved successfully! ${assignmentsToSave.length} assignments created.`)
  } catch (error) {
    console.error('Error saving schedule:', error)
    alert(`Error saving schedule: ${error.message || 'Unknown error'}. Please try again.`)
  }
}

// Event handlers for 15-minute grid
const handleAddAssignment = (employeeId: string, timeSlot: string) => {
  selectedEmployee.value = employees.value.find((e: any) => e.id === employeeId) || null
  selectedShift.value = { id: timeSlot, name: `${timeSlot} Slot` }
  showEmployeeModal.value = true
}

const handleEditAssignment = (employeeId: string, timeSlot: string) => {
  const assignment = getEmployeeAssignment(employeeId, timeSlot)
  if (assignment) {
    selectedEmployee.value = employees.value.find((e: any) => e.id === employeeId) || null
    selectedShift.value = { id: timeSlot, name: `${timeSlot} Slot` }
    selectedJobFunction.value = (assignment as any).job_function
    showEmployeeModal.value = true
  }
}

const handleBreakCoverage = (employeeId: string, timeSlot: any) => {
  // Handle break coverage assignment
  console.log('Assigning break coverage:', employeeId, timeSlot)
  // You can implement break coverage logic here
}

const handleScheduleDataUpdated = (newScheduleData: Record<string, any>) => {
  scheduleAssignmentsData.value = newScheduleData
}

// Watch for changes in schedule assignments and update schedule data
watch(scheduleAssignments, () => {
  initializeScheduleData()
}, { deep: true })

</script>

<style scoped>
</style>