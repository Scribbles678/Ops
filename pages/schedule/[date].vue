<template>
  <div class="min-h-screen bg-gray-50">
    <div class="px-4 py-6">
      <!-- Header -->
      <div class="flex items-center justify-between mb-6">
        <div>
          <h1 class="text-4xl font-bold text-gray-800">View/Edit Schedule</h1>
          <p class="text-gray-600 mt-2">
            <ClientOnly>
              {{ formatDate(scheduleDate || '') }}
            </ClientOnly>
          </p>
        </div>
        <div class="flex space-x-4">
          <button 
            @click="saveSchedule" 
            :disabled="isSaving"
            class="btn-primary disabled:opacity-50 disabled:cursor-not-allowed flex items-center"
          >
            <svg v-if="isSaving" class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            {{ isSaving ? 'Saving...' : 'Save Schedule' }}
          </button>
          <button @click="handleLogout" class="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-lg text-sm font-medium transition-colors">
            Logout
          </button>
          <NuxtLink to="/" class="btn-secondary">
            ← Back to Home
          </NuxtLink>
        </div>
      </div>

      <!-- Date Selector and Stats Row -->
      <div class="flex gap-4 mb-4">
        <!-- Date Selector (Left Side) -->
        <div class="card flex-shrink-0" style="width: 400px;">
          <div class="p-4">
            <h2 class="text-lg font-bold text-gray-800 mb-3">Select Schedule Date</h2>
            <div class="flex items-center space-x-4">
              <div class="flex-1">
                <label for="schedule-date" class="block text-sm font-medium text-gray-700 mb-2">
                  Schedule Date
                </label>
                <input
                  id="schedule-date"
                  v-model="scheduleDate"
                  type="date"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                />
              </div>
              <div class="flex flex-col space-y-2">
                <button 
                  @click="goToToday" 
                  class="px-4 py-2 bg-blue-100 text-blue-700 rounded-lg hover:bg-blue-200 transition-colors text-sm"
                >
                  Today
                </button>
                <button 
                  @click="goToYesterday" 
                  class="px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors text-sm"
                >
                  Yesterday
                </button>
                <button 
                  @click="goToTomorrow" 
                  class="px-4 py-2 bg-green-100 text-green-700 rounded-lg hover:bg-green-200 transition-colors text-sm"
                >
                  Tomorrow
                </button>
              </div>
            </div>
            <div class="mt-4 p-3 bg-blue-50 rounded-lg">
              <p class="text-sm text-blue-800">
                <strong>Selected:</strong> 
                <ClientOnly>
                  {{ formatDate(scheduleDate) }}
                  <span v-if="isWeekend" class="ml-2 text-orange-600 font-medium">(Weekend)</span>
                  <span v-if="isFuture" class="ml-2 text-green-600 font-medium">(Future)</span>
                  <span v-if="isPast" class="ml-2 text-gray-600 font-medium">(Past)</span>
                </ClientOnly>
              </p>
            </div>
          </div>
        </div>

        <!-- Labor Hours Summary (Right Side) -->
        <div class="flex-1 grid grid-cols-2 md:grid-cols-4 gap-1">
          <div class="card p-1">
            <div class="text-center">
              <div class="text-base font-bold text-blue-600">{{ totalEmployees }}</div>
              <div class="text-xs text-gray-600">Total Employees</div>
            </div>
          </div>
          <div class="card p-1">
            <div class="text-center">
              <div class="text-base font-bold text-green-600">{{ totalLaborHours }}h</div>
              <div class="text-xs text-gray-600">Total Labor Hours</div>
            </div>
          </div>
          <div class="card p-1">
            <div class="text-center">
              <div class="text-base font-bold text-purple-600">{{ totalShifts }}</div>
              <div class="text-xs text-gray-600">Active Shifts</div>
            </div>
          </div>
          <div class="card p-1">
            <div class="text-center">
              <div class="text-base font-bold text-orange-600">{{ unassignedEmployees }}</div>
              <div class="text-xs text-gray-600">Unassigned</div>
            </div>
          </div>
        </div>
      </div>

      <!-- Save Progress Indicator -->
      <div v-if="isSaving" class="card mb-6 bg-blue-50 border-blue-200">
        <div class="flex items-center space-x-4">
          <svg class="animate-spin h-6 w-6 text-blue-600" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          <div class="flex-1">
            <h3 class="text-lg font-semibold text-blue-800">Saving Schedule...</h3>
            <p class="text-sm text-blue-700">{{ saveProgress }}</p>
            <p class="text-xs text-blue-600 mt-1">
              💡 You can navigate away from this page - the save will continue in the background
            </p>
          </div>
        </div>
      </div>

      <!-- Job Function Hours Breakdown / Meter Dashboard -->
      <div class="card mb-6">
        <div class="flex items-center justify-between mb-3">
          <h3 class="text-lg font-bold text-gray-800">
            {{ showMeterDashboard ? 'Meter Staffing Dashboard' : 'Job Function Hours Breakdown' }}
          </h3>
          <div class="flex space-x-2">
            <button 
              @click="showMeterDashboard = false"
              class="px-3 py-1 text-sm rounded border transition-colors"
              :class="!showMeterDashboard ? 'bg-blue-100 text-blue-700 border-blue-300' : 'bg-gray-100 text-gray-700 border-gray-300'"
            >
              Job Functions
            </button>
            <button 
              @click="showMeterDashboard = true"
              class="px-3 py-1 text-sm rounded border transition-colors"
              :class="showMeterDashboard ? 'bg-blue-100 text-blue-700 border-blue-300' : 'bg-gray-100 text-gray-700 border-gray-300'"
            >
              Meter Dashboard
            </button>
          </div>
        </div>
        <!-- Job Function Hours Breakdown -->
        <div v-if="!showMeterDashboard" class="grid grid-cols-3 md:grid-cols-6 lg:grid-cols-8 xl:grid-cols-10 gap-3">
          <div v-for="jobFunction in jobFunctionHours" :key="jobFunction.name" class="text-center bg-gray-50 rounded-lg p-3 border border-gray-200 hover:shadow-sm transition-shadow">
            <div class="flex items-center justify-center mb-2">
              <div 
                class="w-4 h-4 rounded border-2 border-gray-400 mr-2 shadow-sm" 
                :style="{ backgroundColor: jobFunction.color }"
              ></div>
              <span class="text-xs font-semibold text-gray-800">{{ jobFunction.name }}</span>
            </div>
            <div class="text-xs text-gray-600 mb-1">Actual Hours</div>
            <div class="text-xl font-bold text-gray-900 bg-white rounded-lg py-1 px-2 shadow-sm mb-1">
              {{ jobFunction.hours }}
            </div>
            <div class="text-xs text-gray-600 mb-1">Target Hours</div>
            <div class="text-lg font-semibold text-blue-600 bg-blue-50 rounded-lg py-1 px-2">
              {{ getTargetHours(jobFunction.id) }}
            </div>
          </div>
        </div>

        <!-- Meter Staffing Dashboard -->
        <div v-else class="overflow-x-auto">
          <div class="min-w-max">
            <!-- Time Header -->
            <div class="flex border-b-2 border-gray-300 mb-2">
              <div class="w-20 px-2 py-1 text-xs font-medium text-gray-700 bg-gray-50 border-r border-gray-300 sticky left-0 z-10">
                Meter
              </div>
              <div
                v-for="timeSlot in meterTimeSlots"
                :key="timeSlot.time"
                class="px-1 py-1 text-center text-xs font-medium border-r border-gray-200"
                :class="{ 'hourly-marker': isHourlyMarker(timeSlot.time) }"
                :style="{ minWidth: '40px' }"
              >
                {{ formatTimeForMeterDashboard(timeSlot.time) }}
              </div>
            </div>

            <!-- Meter Rows -->
            <div
              v-for="meterNumber in 20"
              :key="meterNumber"
              class="flex border-b border-gray-200 hover:bg-gray-50"
            >
              <!-- Meter Label -->
              <div class="w-20 px-2 py-1 text-xs font-medium text-gray-800 bg-white border-r border-gray-300 sticky left-0 z-10">
                Meter {{ meterNumber }}
              </div>

              <!-- Time Slots for this Meter -->
              <div
                v-for="timeSlot in meterTimeSlots"
                :key="`meter-${meterNumber}-${timeSlot.time}`"
                class="px-1 py-1 text-center text-xs border-r border-gray-200 relative"
                :class="{ 'hourly-marker-content': isHourlyMarker(timeSlot.time) }"
                :style="{ minWidth: '40px' }"
              >
                <div
                  class="w-full h-full flex items-center justify-center rounded cursor-pointer transition"
                  :class="getMeterSlotClasses(meterNumber, timeSlot.time)"
                  :style="getMeterSlotStyle(meterNumber, timeSlot.time)"
                  @click="toggleMeterSlot(meterNumber, timeSlot.time)"
                >
                  <span v-if="isMeterBooked(meterNumber, timeSlot.time)" class="text-white text-xs">●</span>
                  <span v-else class="text-gray-300 text-xs">○</span>
                </div>
              </div>
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

// Supabase client
const { $supabase } = useNuxtApp()

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

// Save state
const isSaving = ref(false)
const saveProgress = ref('')

// Target hours state
const targetHours = ref({})

// Meter dashboard state
const showMeterDashboard = ref(false)
const meterBookings = ref<Record<string, boolean>>({})

// Get route params - use client-only for date to avoid hydration mismatch
const route = useRoute()
const scheduleDate = ref('')

// Initialize date on client side to avoid hydration mismatch
onMounted(() => {
  if (!scheduleDate.value) {
    scheduleDate.value = (route.params.date as string) || new Date().toISOString().split('T')[0]
  }
})

// Date navigation functions
const goToToday = () => {
  scheduleDate.value = new Date().toISOString().split('T')[0]
  navigateTo(`/schedule/${scheduleDate.value}`)
}

const goToYesterday = () => {
  const yesterday = new Date()
  yesterday.setDate(yesterday.getDate() - 1)
  scheduleDate.value = yesterday.toISOString().split('T')[0]
  navigateTo(`/schedule/${scheduleDate.value}`)
}

const goToTomorrow = () => {
  const tomorrow = new Date()
  tomorrow.setDate(tomorrow.getDate() + 1)
  scheduleDate.value = tomorrow.toISOString().split('T')[0]
  navigateTo(`/schedule/${scheduleDate.value}`)
}

// Date status computed properties - make them hydration-safe
const isWeekend = computed(() => {
  if (!scheduleDate.value) return false
  const date = new Date(scheduleDate.value)
  const day = date.getDay()
  return day === 0 || day === 6 // Sunday or Saturday
})

const isFuture = computed(() => {
  if (!scheduleDate.value) return false
  const selectedDate = new Date(scheduleDate.value)
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  return selectedDate > today
})

const isPast = computed(() => {
  if (!scheduleDate.value) return false
  const selectedDate = new Date(scheduleDate.value)
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  return selectedDate < today
})

// Watch for date changes to reload schedule data
watch(scheduleDate, async (newDate) => {
  if (newDate) {
    await fetchScheduleForDate(newDate)
    await nextTick()
    initializeScheduleData()
  }
})

// Reload target hours when page becomes active (for SPA navigation)
onActivated(() => {
  loadTargetHours()
})

// Listen for localStorage changes (when target hours are updated in another tab/page)
onMounted(() => {
  // Also listen for focus events to refresh when returning to the page
  const handleFocus = () => {
    loadTargetHours()
  }
  
  window.addEventListener('focus', handleFocus)
  
  // Cleanup on unmount
  onUnmounted(() => {
    window.removeEventListener('focus', handleFocus)
  })
})

// Target hours functions
const loadTargetHours = async () => {
  try {
    console.log('Loading target hours from database...')
    console.log('Job functions available:', jobFunctions.value.length)
    
    // First, let's check if the table exists and has any data
    const { data: allData, error: allError } = await $supabase
      .from('target_hours')
      .select('*')
    
    console.log('All target_hours table data:', allData)
    console.log('Any errors:', allError)
    
    // Load from database
    const { data, error } = await $supabase
      .from('target_hours')
      .select('job_function_id, target_hours')
    
    if (error) {
      console.error('Database error:', error)
      throw error
    }
    
    console.log('Raw target hours data from database:', data)
    
    // Convert array to object format
    const targetHoursData = {}
    if (data && data.length > 0) {
      data.forEach(item => {
        targetHoursData[item.job_function_id] = item.target_hours
        console.log(`Mapped ${item.job_function_id} -> ${item.target_hours}`)
      })
    } else {
      console.log('No target hours data found in database')
    }
    
    console.log('Converted target hours data:', targetHoursData)
    
    // Don't add default values - only use what's in the database
    console.log('Using only database values, no defaults added')
    
    targetHours.value = targetHoursData
    console.log('Final target hours loaded:', targetHours.value)
    
  } catch (error) {
    console.error('Error loading target hours:', error)
    // Don't use fallback - keep targetHours empty so we can see the issue
    targetHours.value = {}
    console.log('Error occurred, targetHours.value set to empty object')
  }
}

const getTargetHours = (jobFunctionId: string) => {
  console.log(`Getting target hours for job function ${jobFunctionId}`)
  console.log('Current targetHours.value:', targetHours.value)
  
  if (!targetHours.value || Object.keys(targetHours.value).length === 0) {
    console.log('targetHours.value is empty, returning 0')
    return 0
  }
  
  // Special handling for meter group
  if (jobFunctionId === 'meter-group') {
    // Sum up target hours for all meters
    let totalMeterHours = 0
    jobFunctions.value.forEach((job: any) => {
      if (job.name.startsWith('Meter ')) {
        const hours = targetHours.value[job.id]
        if (hours !== undefined && hours !== null) {
          totalMeterHours += hours
        }
      }
    })
    console.log(`Found total meter target hours: ${totalMeterHours}`)
    return totalMeterHours
  }
  
  const hours = targetHours.value[jobFunctionId]
  if (hours === undefined || hours === null) {
    console.log(`No target hours found for ${jobFunctionId}, returning 0`)
    return 0
  }
  
  console.log(`Found target hours for ${jobFunctionId}: ${hours}`)
  return hours
}

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
    
    // Load target hours from database
    await loadTargetHours()
    
    // Initialize schedule data from existing assignments
    // Use nextTick to ensure all reactive data is updated
    await nextTick()
    initializeScheduleData()
    
    // Sync meter bookings after schedule data is initialized
    syncMeterBookings()
    
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
  
  // Always initialize Meter entry for grouping
  jobFunctionTotals['Meter'] = 0
  
  // Calculate hours for each employee's schedule
  Object.entries(scheduleAssignmentsData.value).forEach(([employeeId, employeeSchedule]: [string, any]) => {
    Object.entries(employeeSchedule).forEach(([timeSlot, data]: [string, any]) => {
      if (data.assignment && data.assignment.trim() !== '') {
        // Each 15-minute slot = 0.25 hours
        const jobName = data.assignment
        
        // If it's a meter assignment, count it under 'Meter'
        if (jobName.startsWith('Meter ')) {
          jobFunctionTotals['Meter'] = (jobFunctionTotals['Meter'] || 0) + 0.25
        } else if (jobFunctionTotals.hasOwnProperty(jobName)) {
          jobFunctionTotals[jobName] += 0.25
        }
      }
    })
  })
  
  // Group meter hours together
  const groupedJobFunctions: Record<string, any> = {}
  let meterColor = '#87CEEB' // Default meter color
  
  // Find the actual meter color from any existing meter job function
  const firstMeterJobFunction = jobFunctions.value.find((job: any) => job.name && job.name.startsWith('Meter '))
  if (firstMeterJobFunction) {
    meterColor = firstMeterJobFunction.color_code
  }
  
  jobFunctions.value.forEach((job: any) => {
    if (!job.name.startsWith('Meter ')) { // Exclude individual meters from direct display
      groupedJobFunctions[job.name] = {
        id: job.id,
        name: job.name,
        color: job.color_code,
        hours: Math.round((jobFunctionTotals[job.name] || 0) * 10) / 10,
        employees: 0
      }
    }
  })
  
  // Add grouped meter entry if there are any meter assignments
  if (jobFunctionTotals['Meter'] > 0) {
    groupedJobFunctions['Meter'] = {
      id: 'meter-group',
      name: 'Meter',
      color: meterColor, // This will now use the reliably found meter color
      hours: Math.round(jobFunctionTotals['Meter'] * 10) / 10,
      employees: 0
    }
  }
  
  return Object.values(groupedJobFunctions)
})

// Functions
const formatDate = (dateString: string) => {
  if (!dateString) return ''
  try {
    const date = new Date(dateString)
    return date.toLocaleDateString('en-US', {
      weekday: 'long', 
      year: 'numeric', 
      month: 'long', 
      day: 'numeric'
    })
  } catch (error) {
    return dateString
  }
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
    isSaving.value = true
    saveProgress.value = 'Preparing to save schedule...'
    
    // Clear existing assignments for this date first
    saveProgress.value = 'Clearing existing assignments...'
    await clearAssignmentsForDate(scheduleDate.value)
    
    // Convert scheduleAssignmentsData to database format and save
    saveProgress.value = 'Processing schedule data...'
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
      saveProgress.value = `Saving ${assignmentsToSave.length} assignments to database...`
      
      for (let i = 0; i < assignmentsToSave.length; i++) {
        const assignment = assignmentsToSave[i]
        saveProgress.value = `Saving assignment ${i + 1} of ${assignmentsToSave.length}...`
        await createAssignment(assignment)
      }
    }
    
    // Refresh the schedule data
    saveProgress.value = 'Refreshing schedule data...'
    await fetchScheduleForDate(scheduleDate.value)
    
    // Success!
    isSaving.value = false
    saveProgress.value = ''
    alert(`Schedule saved successfully! ${assignmentsToSave.length} assignments created.`)
    
  } catch (error) {
    console.error('Error saving schedule:', error)
    isSaving.value = false
    saveProgress.value = ''
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
  // Sync meter bookings when schedule data is updated
  syncMeterBookings()
}

// Meter dashboard functions
const meterTimeSlots = computed(() => {
  const slots = []
  // Generate time slots from 6 AM to 8:30 PM (6:00 to 20:30)
  for (let hour = 6; hour <= 20; hour++) {
    for (let quarter = 0; quarter < 4; quarter++) {
      const minutes = quarter * 15
      const timeString = `${hour.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}`
      
      // Stop at 8:30 PM (20:30)
      if (hour === 20 && minutes > 30) break
      
      slots.push({
        time: timeString,
        hour,
        minutes
      })
    }
  }
  return slots
})

const formatTimeForMeterDashboard = (time: string): string => {
  const [hours, minutes] = time.split(':').map(Number)
  
  // Only show time labels for hourly slots (when minutes === 0)
  if (minutes === 0) {
    const period = hours >= 12 ? 'PM' : 'AM'
    const displayHours = hours > 12 ? hours - 12 : (hours === 0 ? 12 : hours)
    return `${displayHours} ${period}`
  }
  
  // Return empty string for non-hourly slots
  return ''
}

const isHourlyMarker = (time: string): boolean => {
  const [hours, minutes] = time.split(':').map(Number)
  return minutes === 0
}

const isMeterBooked = (meterNumber: number, timeSlot: string): boolean => {
  const key = `meter-${meterNumber}-${timeSlot}`
  return meterBookings.value[key] || false
}

const getMeterSlotClasses = (meterNumber: number, timeSlot: string): string => {
  const isBooked = isMeterBooked(meterNumber, timeSlot)
  return isBooked 
    ? 'hover:opacity-80' 
    : 'bg-gray-100 hover:bg-gray-200'
}

const getMeterSlotStyle = (meterNumber: number, timeSlot: string): Record<string, string> => {
  const isBooked = isMeterBooked(meterNumber, timeSlot)
  if (!isBooked) return {}
  
  // Get the meter color from job functions
  const meterJobFunction = jobFunctions.value?.find(jf => jf.name === `Meter ${meterNumber}`)
  const meterColor = meterJobFunction?.color_code || '#87CEEB' // Default meter color
  
  return {
    backgroundColor: meterColor,
    color: '#ffffff'
  }
}

const toggleMeterSlot = (meterNumber: number, timeSlot: string) => {
  const key = `meter-${meterNumber}-${timeSlot}`
  meterBookings.value[key] = !meterBookings.value[key]
}

// Sync meter bookings with actual schedule assignments
const syncMeterBookings = () => {
  console.log('🔄 Syncing meter bookings...')
  console.log('Schedule assignments data:', scheduleAssignmentsData.value)
  
  // Clear existing bookings
  meterBookings.value = {}
  
  // Get all meter assignments from schedule data
  if (scheduleAssignmentsData.value) {
    Object.entries(scheduleAssignmentsData.value).forEach(([employeeId, employeeSchedule]: [string, any]) => {
      Object.entries(employeeSchedule).forEach(([timeSlot, data]: [string, any]) => {
        if (data && data.assignment && data.assignment.startsWith('Meter ')) {
          const meterNumber = parseInt(data.assignment.split(' ')[1])
          console.log(`📊 Found meter assignment: Meter ${meterNumber} at ${timeSlot} until ${data.until}`)
          
          if (meterNumber >= 1 && meterNumber <= 20) {
            // Mark all time slots for this assignment as booked
            const startTime = timeSlot
            const endTime = data.until
            
            // Generate all 15-minute slots between start and end time
            const startMinutes = timeToMinutes(startTime)
            const endMinutes = timeToMinutes(endTime)
            
            let currentMinutes = startMinutes
            while (currentMinutes < endMinutes) {
              const timeString = minutesToTime(currentMinutes)
              const key = `meter-${meterNumber}-${timeString}`
              meterBookings.value[key] = true
              currentMinutes += 15
            }
          }
        }
      })
    })
  }
  
  console.log('📋 Final meter bookings:', meterBookings.value)
}


const { logout } = useAuth()

const handleLogout = async () => {
  if (confirm('Are you sure you want to logout?')) {
    await logout()
  }
}

// Watch for changes in schedule assignments and update schedule data
watch(scheduleAssignments, () => {
  initializeScheduleData()
}, { deep: true })

// Watch for changes in schedule data and sync meter bookings
watch(scheduleAssignmentsData, () => {
  syncMeterBookings()
}, { deep: true })

// Prevent accidental navigation during save
onMounted(() => {
  window.addEventListener('beforeunload', (e) => {
    if (isSaving.value) {
      e.preventDefault()
      e.returnValue = 'Schedule is currently saving. Are you sure you want to leave?'
    }
  })
})

onUnmounted(() => {
  window.removeEventListener('beforeunload', (e) => {
    if (isSaving.value) {
      e.preventDefault()
      e.returnValue = 'Schedule is currently saving. Are you sure you want to leave?'
    }
  })
})

</script>

<style scoped>
</style>