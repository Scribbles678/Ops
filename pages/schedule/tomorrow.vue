<template>
  <div class="min-h-screen bg-gray-50">
    <div class="container mx-auto px-4 py-8">
      <!-- Header -->
      <div class="flex items-center justify-between mb-8">
        <div>
          <h1 class="text-4xl font-bold text-gray-800">Create Schedule</h1>
          <p class="text-gray-600 mt-2">Choose a date and create a schedule</p>
        </div>
        <div class="flex space-x-4">
          <button @click="handleLogout" class="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-lg text-sm font-medium transition-colors">
            Logout
          </button>
          <NuxtLink to="/" class="btn-secondary">
            ← Back to Home
          </NuxtLink>
        </div>
      </div>

      <!-- Date Selection -->
      <div class="card mb-8">
        <h2 class="text-xl font-bold text-gray-800 mb-4">Select Schedule Date</h2>
        <div class="flex items-center space-x-4">
          <div class="flex-1">
            <label for="schedule-date" class="block text-sm font-medium text-gray-700 mb-2">
              Schedule Date
            </label>
            <input
              id="schedule-date"
              v-model="selectedDate"
              type="date"
              :min="today"
              class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
          </div>
          <div class="flex flex-col space-y-2">
            <button 
              @click="setToTomorrow" 
              class="px-4 py-2 bg-blue-100 text-blue-700 rounded-lg hover:bg-blue-200 transition-colors text-sm"
            >
              Tomorrow
            </button>
            <button 
              @click="setToNextMonday" 
              class="px-4 py-2 bg-green-100 text-green-700 rounded-lg hover:bg-green-200 transition-colors text-sm"
            >
              Next Monday
            </button>
          </div>
        </div>
        <div class="mt-4 p-3 bg-blue-50 rounded-lg">
          <p class="text-sm text-blue-800">
            <strong>Selected:</strong> {{ formatDate(selectedDate || '') }}
            <span v-if="isWeekend" class="ml-2 text-orange-600 font-medium">(Weekend)</span>
          </p>
        </div>
      </div>

      <!-- Schedule Generation Options -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-8">
        <!-- Copy Today's Schedule -->
        <div class="card hover:shadow-lg transition-all cursor-pointer" @click="copyTodaySchedule">
          <div class="text-center py-8">
            <div class="bg-blue-100 rounded-full p-6 mb-4 mx-auto w-20 h-20 flex items-center justify-center">
              <svg class="w-10 h-10 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
              </svg>
            </div>
            <h3 class="text-xl font-bold text-gray-800 mb-2">Copy Today's Schedule</h3>
            <p class="text-gray-600">Copy the current schedule to {{ formatDate(selectedDate || '') }}</p>
            <p class="text-xs text-gray-500 mt-2 italic">Note: PTO and shift swaps are excluded</p>
          </div>
        </div>

        <!-- AI Generated Schedule -->
        <div class="card hover:shadow-lg transition-all cursor-pointer" @click="generateAISchedule" :class="{ 'opacity-50 cursor-not-allowed': generating }">
          <div class="text-center py-8">
            <div class="bg-purple-100 rounded-full p-6 mb-4 mx-auto w-20 h-20 flex items-center justify-center">
              <svg v-if="!generating" class="w-10 h-10 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
              </svg>
              <div v-else class="w-10 h-10 text-purple-600">
                <svg class="animate-spin" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
              </div>
            </div>
            <h3 class="text-xl font-bold text-gray-800 mb-2">
              {{ generating ? '⏳ Generating AI Schedule...' : '🤖 AI Generated Schedule' }}
            </h3>
            <p class="text-gray-600">
              {{ generating ? 'Please wait while the AI creates your optimized schedule...' : 'Generate an optimized schedule with exact staffing requirements for X4, EM9, and Locus' }}
            </p>
          </div>
        </div>

        <!-- Manual Schedule -->
        <div class="card hover:shadow-lg transition-all cursor-pointer" @click="goToManualSchedule">
          <div class="text-center py-8">
            <div class="bg-green-100 rounded-full p-6 mb-4 mx-auto w-20 h-20 flex items-center justify-center">
              <svg class="w-10 h-10 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
              </svg>
            </div>
            <h3 class="text-xl font-bold text-gray-800 mb-2">Manual Schedule</h3>
            <p class="text-gray-600">Create {{ formatDate(selectedDate || '') }} schedule manually from scratch</p>
          </div>
        </div>
      </div>

      <!-- Manage Business Rules Button -->
      <div class="text-center mt-6">
        <NuxtLink
          to="/admin/business-rules"
          class="inline-flex items-center px-6 py-3 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition"
        >
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
          </svg>
          Manage Business Rules
        </NuxtLink>
      </div>

      <!-- Loading Modal -->
      <div v-if="generating" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-white rounded-lg p-8 max-w-md w-full mx-4 shadow-xl">
          <div class="text-center">
            <div class="mb-4 flex justify-center">
              <svg class="animate-spin h-12 w-12 text-purple-600" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
            </div>
            <h3 class="text-2xl font-bold text-gray-800 mb-2">Generating AI Schedule</h3>
            <p class="text-gray-600 mb-4">
              Creating optimized schedule for {{ formatDate(selectedDate || '') }}
            </p>
            <p class="text-sm text-gray-500">
              This may take a few moments while we process business rules and create assignments...
            </p>
            <div class="mt-6 flex items-center justify-center space-x-2">
              <div class="w-2 h-2 bg-purple-600 rounded-full animate-pulse"></div>
              <div class="w-2 h-2 bg-purple-600 rounded-full animate-pulse" style="animation-delay: 0.2s"></div>
              <div class="w-2 h-2 bg-purple-600 rounded-full animate-pulse" style="animation-delay: 0.4s"></div>
            </div>
          </div>
        </div>
      </div>

      <!-- Notification Modal -->
      <div v-if="showNotificationModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4 shadow-xl">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-xl font-bold text-gray-800">{{ notificationType === 'success' ? '✅ Success' : '❌ Error' }}</h3>
            <button @click="closeNotificationModal" class="text-gray-400 hover:text-gray-600">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
          <div :class="notificationType === 'success' ? 'bg-green-50 border border-green-200 rounded-lg p-4 mb-4' : 'bg-red-50 border border-red-200 rounded-lg p-4 mb-4'">
            <p :class="notificationType === 'success' ? 'text-green-800' : 'text-red-800'" class="text-sm whitespace-pre-line">{{ notificationMessage }}</p>
          </div>
          <div class="flex justify-end">
            <button
              @click="closeNotificationModal"
              :class="notificationType === 'success' ? 'px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium' : 'px-6 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors font-medium'"
            >
              OK
            </button>
          </div>
        </div>
      </div>

      <!-- Warnings Modal -->
      <div v-if="showWarningsModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-white rounded-lg p-6 max-w-2xl w-full mx-4 shadow-xl max-h-[90vh] overflow-y-auto">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-2xl font-bold text-gray-800">Schedule Generation Complete</h3>
            <button @click="closeWarningsModal" class="text-gray-400 hover:text-gray-600">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
          
          <div v-if="scheduleWarnings.length > 0 && scheduleWarnings.some(w => w.includes('trained') || w.includes('Available') || w.includes('Required'))" class="mb-4 p-4 bg-green-50 border border-green-200 rounded-lg">
            <p class="text-green-800 font-medium">
              ✅ Schedule generated successfully, but some requirements could not be fulfilled.
            </p>
          </div>

          <div v-else-if="scheduleWarnings.length > 0" class="mb-4 p-4 bg-red-50 border border-red-200 rounded-lg">
            <p class="text-red-800 font-medium">
              ❌ Schedule could not be generated. Please review the issues below.
            </p>
          </div>

          <div class="mb-6">
            <h4 v-if="scheduleWarnings.some(w => w.includes('trained') || w.includes('Available') || w.includes('Required'))" class="text-lg font-semibold text-gray-700 mb-3">⚠️ Training Gaps Detected:</h4>
            <h4 v-else class="text-lg font-semibold text-red-700 mb-3">❌ Issues Found:</h4>
            <div class="space-y-2">
              <div
                v-for="(warning, index) in scheduleWarnings"
                :key="index"
                :class="warning.includes('No') || warning.includes('not') || warning.includes('Error') || warning.includes('No schedule') 
                  ? 'p-3 bg-red-50 border border-red-200 rounded-lg' 
                  : 'p-3 bg-yellow-50 border border-yellow-200 rounded-lg'"
              >
                <p :class="warning.includes('No') || warning.includes('not') || warning.includes('Error') || warning.includes('No schedule')
                  ? 'text-sm text-red-800'
                  : 'text-sm text-yellow-800'"
                >{{ warning }}</p>
              </div>
            </div>
          </div>

          <div class="p-4 bg-blue-50 border border-blue-200 rounded-lg mb-4">
            <p class="text-sm text-blue-800">
              <strong>Next Steps:</strong>
              <span v-if="scheduleWarnings.some(w => w.includes('trained') || w.includes('Available') || w.includes('Required'))">
                Review employee training assignments in the "Details & Settings" page and assign training for the missing job functions, then regenerate the schedule.
              </span>
              <span v-else>
                Please address the issues listed above and try generating the schedule again. Common fixes include: adding employees, configuring shifts, setting up job functions, and assigning employee training.
              </span>
            </p>
          </div>

          <div class="flex justify-end">
            <button
              @click="closeWarningsModal"
              class="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium"
            >
              View Schedule
            </button>
          </div>
        </div>
      </div>

    </div>
  </div>
</template>

<script setup lang="ts">
// Import composables
const { copySchedule, createAssignment, fetchShifts } = useSchedule()
const { logout } = useAuth()
const { jobFunctions, fetchJobFunctions } = useJobFunctions()
const { fetchEmployees, getAllEmployeeTraining } = useEmployees()
const { fetchBusinessRules, rulesByJobFunction } = useBusinessRules()
const { fetchPreferredAssignments, getPreferredAssignmentsMap } = usePreferredAssignments()

// Tomorrow's date
const tomorrowDate = computed(() => {
  const tomorrow = new Date()
  tomorrow.setDate(tomorrow.getDate() + 1)
  return tomorrow.toISOString().split('T')[0]
})

// Today's date
const today = computed(() => {
  return new Date().toISOString().split('T')[0]
})

// Selected date for schedule creation
const selectedDate = ref(tomorrowDate.value)

// Check if selected date is weekend
const isWeekend = computed(() => {
  if (!selectedDate.value) return false
  
  let date: Date
  // For YYYY-MM-DD strings, parse as local date to avoid UTC shift
  if (typeof selectedDate.value === 'string' && selectedDate.value.match(/^\d{4}-\d{2}-\d{2}$/)) {
    const [year, month, day] = selectedDate.value.split('-').map(Number)
    date = new Date(year, month - 1, day)
  } else {
    date = new Date(selectedDate.value)
  }
  
  const day = date.getDay()
  return day === 0 || day === 6 // Sunday or Saturday
})

// AI Generation state
const generating = ref(false)
const showWarningsModal = ref(false)
const scheduleWarnings = ref<string[]>([])

// Notification modal state
const showNotificationModal = ref(false)
const notificationMessage = ref('')
const notificationType = ref<'success' | 'error'>('success')

const showNotification = (message: string, type: 'success' | 'error' = 'success') => {
  notificationMessage.value = message
  notificationType.value = type
  showNotificationModal.value = true
}

const closeNotificationModal = () => {
  showNotificationModal.value = false
  notificationMessage.value = ''
}

// Mock employee data (same as schedule page)
const employees = ref([
  { id: '1', first_name: 'John', last_name: 'Smith', trained_job_functions: ['RT Pick', 'Pick'] },
  { id: '2', first_name: 'Sarah', last_name: 'Johnson', trained_job_functions: ['Pick', 'Meter'] },
  { id: '3', first_name: 'Mike', last_name: 'Davis', trained_job_functions: ['RT Pick', 'Locus'] },
  { id: '4', first_name: 'Lisa', last_name: 'Wilson', trained_job_functions: ['Meter', 'Helpdesk'] },
  { id: '5', first_name: 'Tom', last_name: 'Brown', trained_job_functions: ['Locus', 'Coordinator'] },
  { id: '6', first_name: 'Emma', last_name: 'Garcia', trained_job_functions: ['Team Lead', 'Helpdesk'] },
  { id: '7', first_name: 'Chris', last_name: 'Martinez', trained_job_functions: ['RT Pick', 'Pick', 'Meter'] },
  { id: '8', first_name: 'Amy', last_name: 'Anderson', trained_job_functions: ['Pick', 'Locus'] },
  { id: '9', first_name: 'David', last_name: 'Taylor', trained_job_functions: ['Meter', 'Helpdesk'] },
  { id: '10', first_name: 'Jessica', last_name: 'Thomas', trained_job_functions: ['Locus', 'Coordinator'] },
  { id: '11', first_name: 'Kevin', last_name: 'Jackson', trained_job_functions: ['Team Lead', 'Helpdesk'] },
  { id: '12', first_name: 'Rachel', last_name: 'White', trained_job_functions: ['RT Pick', 'Pick'] },
  { id: '13', first_name: 'Mark', last_name: 'Harris', trained_job_functions: ['Pick', 'Meter'] },
  { id: '14', first_name: 'Nicole', last_name: 'Martin', trained_job_functions: ['RT Pick', 'Locus'] },
  { id: '15', first_name: 'Steve', last_name: 'Thompson', trained_job_functions: ['Meter', 'Helpdesk'] }
])

// Functions
const formatDate = (dateString: string) => {
  if (!dateString) return ''
  
  let date: Date
  // For YYYY-MM-DD strings, parse as local date to avoid UTC shift
  if (typeof dateString === 'string' && dateString.match(/^\d{4}-\d{2}-\d{2}$/)) {
    const [year, month, day] = dateString.split('-').map(Number)
    date = new Date(year, month - 1, day)
  } else {
    date = new Date(dateString)
  }
  
  return date.toLocaleDateString('en-US', { 
    weekday: 'long', 
    year: 'numeric', 
    month: 'long', 
    day: 'numeric' 
  })
}

const copyTodaySchedule = async () => {
  try {
    const today = new Date().toISOString().split('T')[0]
    
    // Copy today's schedule to selected date
    const success = await copySchedule(today, selectedDate.value || '')
    
    if (success) {
      showNotification(`Today's schedule copied to ${formatDate(selectedDate.value || '')} successfully!`, 'success')
      // Navigate to the selected date's schedule page to see/edit the copied schedule
      navigateTo(`/schedule/${selectedDate.value || ''}`)
    } else {
      showNotification('Error copying schedule. Please try again.', 'error')
    }
  } catch (error) {
    console.error('Error copying schedule:', error)
    showNotification('Error copying schedule. Please try again.', 'error')
  }
}

const generateAISchedule = async () => {
  if (confirm('Generate AI schedule for ' + formatDate(selectedDate.value || '') + '? This will create assignments based on exact business rules.')) {
    try {
      generating.value = true
      scheduleWarnings.value = [] // Reset warnings
      
      // Generate AI schedule
      const { schedule, warnings, errors } = await generateAIScheduleLogic()
      
      if (schedule.length > 0) {
        // Apply the schedule directly
        await applyAISchedule(schedule)
        
        // Store warnings for modal display
        scheduleWarnings.value = warnings
        
        // If there are warnings, show the modal instead of alert
        if (warnings.length > 0) {
          showWarningsModal.value = true
        } else {
          // No warnings - show success and navigate
          showNotification(`✅ AI schedule generated successfully!\n\nCreated ${schedule.length} assignments for ${formatDate(selectedDate.value || '')}.\n\nRedirecting to schedule view...`, 'success')
          // Wait a moment for modal to show, then navigate
          setTimeout(() => {
            navigateTo(`/schedule/${selectedDate.value || ''}`)
          }, 500)
        }
      } else {
        // Show detailed error modal with specific issues
        scheduleWarnings.value = errors
        showWarningsModal.value = true
      }
    } catch (error) {
      console.error('Error generating AI schedule:', error)
      showNotification('❌ Error generating AI schedule.\n\nPlease try again or check the console for details.', 'error')
    } finally {
      generating.value = false
    }
  }
}

const closeWarningsModal = () => {
  showWarningsModal.value = false
  // Navigate to schedule view after closing modal
  navigateTo(`/schedule/${selectedDate.value || ''}`)
}

const goToManualSchedule = () => {
  // Navigate to the selected date's schedule page for manual editing
  navigateTo(`/schedule/${selectedDate.value || ''}`)
}

const handleLogout = async () => {
  if (confirm('Are you sure you want to logout?')) {
    await logout()
  }
}

// Date helper functions
const setToTomorrow = () => {
  selectedDate.value = tomorrowDate.value
}

const setToNextMonday = () => {
  const today = new Date()
  const daysUntilMonday = (1 - today.getDay() + 7) % 7
  const nextMonday = new Date(today)
  nextMonday.setDate(today.getDate() + (daysUntilMonday === 0 ? 7 : daysUntilMonday))
  selectedDate.value = nextMonday.toISOString().split('T')[0]
}


// AI Schedule Generation Logic

const generateAIScheduleLogic = async (): Promise<{ schedule: any[], warnings: string[], errors: string[] }> => {
  const warnings: string[] = []
  const errors: string[] = []
  
  try {
    // Load real data including business rules and preferred assignments
    const [employeesData, jobFunctionsData, shiftsData, businessRulesData] = await Promise.all([
      fetchEmployees(),
      fetchJobFunctions(),
      fetchShifts(),
      fetchBusinessRules()
    ])
    
    // Fetch preferred assignments separately
    await fetchPreferredAssignments()
    
    const employees = Array.isArray(employeesData) ? employeesData : []
    const jobFunctions = Array.isArray(jobFunctionsData) ? jobFunctionsData : []
    const shifts = Array.isArray(shiftsData) ? shiftsData : []
    const businessRules = Array.isArray(businessRulesData) ? businessRulesData : []
    
    console.log('Loaded data:', { 
      employees: employees.length, 
      jobFunctions: jobFunctions.length, 
      shifts: shifts.length,
      businessRules: businessRules.length
    })
    
    // Validate data before proceeding
    if (!Array.isArray(employees) || employees.length === 0) {
      errors.push('No employees found in the system. Please add employees before generating a schedule.')
    }
    
    const activeEmployees = Array.isArray(employees) ? employees.filter((emp: any) => emp && emp.is_active !== false) : []
    if (!Array.isArray(activeEmployees) || activeEmployees.length === 0) {
      errors.push('No active employees found. Please activate employees or add new ones.')
    }
    
    if (!Array.isArray(shifts) || shifts.length === 0) {
      errors.push('No shifts configured. Please set up shifts before generating a schedule.')
    }
    
    const activeShifts = Array.isArray(shifts) ? shifts.filter((shift: any) => shift && shift.is_active !== false) : []
    if (!Array.isArray(activeShifts) || activeShifts.length === 0) {
      errors.push('No active shifts found. Please activate shifts or create new ones.')
    }
    
    if (!Array.isArray(jobFunctions) || jobFunctions.length === 0) {
      errors.push('No job functions configured. Please add job functions before generating a schedule.')
    }
    
    if (!Array.isArray(businessRules) || businessRules.length === 0) {
      errors.push('No business rules configured. Please set up business rules in the "Manage Business Rules" page.')
    }
    
    // If we have critical errors, return early
    if (errors.length > 0) {
      return { schedule: [], warnings: [], errors }
    }
    
    // Get training data for all employees - safely handle undefined/null
    const employeeIds = Array.isArray(employees) ? employees
      .filter((emp: any) => emp && emp.id)
      .map((emp: any) => emp.id) : []
    
    if (employeeIds.length === 0) {
      errors.push('No valid employee IDs found. Please check employee data.')
      return { schedule: [], warnings: [], errors }
    }
    
    let trainingData: any = {}
    try {
      trainingData = await getAllEmployeeTraining(employeeIds) || {}
    } catch (trainError: any) {
      console.error('Error fetching training data:', trainError)
      errors.push(`Error loading employee training: ${trainError.message || 'Unknown error'}`)
      return { schedule: [], warnings: [], errors }
    }
    
    console.log('Training data:', trainingData)
    
    // Check if any employees have training - safely handle undefined/null
    const trainingDataKeys = trainingData && typeof trainingData === 'object' ? Object.keys(trainingData) : []
    const employeesWithTraining = trainingDataKeys.filter(empId => {
      const training = trainingData[empId]
      return training && Array.isArray(training) && training.length > 0
    })
    
    if (employeesWithTraining.length === 0) {
      errors.push('No employees have any job function training assigned. Please assign training to employees in the "Details & Settings" page.')
    } else if (employeesWithTraining.length < activeEmployees.length) {
      warnings.push(`${activeEmployees.length - employeesWithTraining.length} employees have no training assigned. They will not be scheduled.`)
    }
    
    // Check if employees are assigned to shifts
    const employeesWithShifts = Array.isArray(activeEmployees) 
      ? activeEmployees.filter((emp: any) => emp && emp.shift_id) 
      : []
    if (!Array.isArray(employeesWithShifts) || employeesWithShifts.length === 0) {
      errors.push('No employees are assigned to shifts. Please assign employees to shifts before generating a schedule.')
    } else if (Array.isArray(activeEmployees) && employeesWithShifts.length < activeEmployees.length) {
      warnings.push(`${activeEmployees.length - employeesWithShifts.length} employees are not assigned to any shift. They will not be scheduled.`)
    }
    
    // If we have critical errors after training check, return early
    if (errors.length > 0) {
      return { schedule: [], warnings: [...warnings, ...errors], errors }
    }
    
    // Get preferred assignments map for prioritizing employees
    const preferredAssignmentsMap = getPreferredAssignmentsMap()
    
    // Build the schedule using database rules (pass warnings array to collect warnings)
    const { schedule, warnings: scheduleWarnings } = await buildOptimalSchedule(employees, jobFunctions, shifts, trainingData, businessRules, warnings, preferredAssignmentsMap)
    
    console.log('✅ Generated schedule:', schedule.length, 'assignments')
    console.log('📊 Schedule Summary:')
    console.log('  - X4 assignments:', schedule.filter(a => a.job_function === 'X4').length)
    console.log('  - EM9 assignments:', schedule.filter(a => a.job_function === 'EM9').length)
    console.log('  - Locus assignments:', schedule.filter(a => a.job_function === 'Locus').length)
    console.log('  - Flex assignments:', schedule.filter(a => a.job_function === 'Flex').length)
    
    // If no assignments were created, add explanation
    if (schedule.length === 0) {
      errors.push('No schedule assignments could be created. This may be due to:')
      errors.push('• No employees available during the required time slots')
      errors.push('• Employees not trained in the job functions specified in business rules')
      errors.push('• Employee shift times not overlapping with business rule time slots')
      errors.push('• All employees already have conflicting assignments')
    }
    
    return { schedule, warnings: [...warnings, ...scheduleWarnings], errors }
  } catch (error: any) {
    console.error('Error generating AI schedule:', error)
    errors.push(`Error occurred: ${error.message || 'Unknown error'}`)
    return { schedule: [], warnings: [], errors }
  }
}

// Core algorithm with 15-minute increments and 2-4 hour blocks
const buildOptimalSchedule = async (employees: any[], jobFunctions: any[], shifts: any[], trainingData: any, dbRules: any[], warnings: string[] = [], preferredAssignmentsMap: Record<string, Record<string, any>> = {}) => {
  const assignments = []
  const employeeAssignments = new Map() // Track what each employee is doing
  const employeeHours = new Map() // Track hours per employee
  
  // STEP 1: Assign Startup to all 6am employees (6am-8am)
  await assignStartupTo6amEmployees(employees, shifts, jobFunctions, trainingData, assignments, employeeAssignments, employeeHours)
  
  // Convert database rules to processing format
  // Group by job function and process max staff limits separately
  const globalMaxLimits = new Map<string, number>() // jobFunction -> maxStaff
  const timeSlotRules: Record<string, any[]> = {} // jobFunction -> array of time slot rules
  
  for (const dbRule of dbRules) {
    const jfName = dbRule.job_function_name
    
    // Handle global max limits (where min_staff is null)
    if (!dbRule.min_staff && dbRule.max_staff) {
      globalMaxLimits.set(jfName, dbRule.max_staff)
      continue
    }
    
    // Regular time slot rules
    if (!timeSlotRules[jfName]) {
      timeSlotRules[jfName] = []
    }
    
    timeSlotRules[jfName].push({
      start: dbRule.time_slot_start,
      end: dbRule.time_slot_end,
      minStaff: dbRule.min_staff,
      maxStaff: dbRule.max_staff,
      blockSize: dbRule.block_size_minutes,
      priority: dbRule.priority || 0
    })
  }
  
  // Sort time slots by priority, then by start time
  Object.keys(timeSlotRules).forEach(jfName => {
    timeSlotRules[jfName].sort((a, b) => {
      if (a.priority !== b.priority) return a.priority - b.priority
      return a.start.localeCompare(b.start)
    })
  })
  
  // Process each job function's rules
  console.log('🔄 Building optimal schedule from database rules...')
  for (const [jobFunction, timeSlots] of Object.entries(timeSlotRules)) {
    console.log(`📋 Processing ${jobFunction} assignments...`)
    
    // Check global max limit for this function
    const globalMax = globalMaxLimits.get(jobFunction)
    let currentStaffCount = 0
    
    for (const timeSlot of timeSlots) {
      const requiredStaff = timeSlot.minStaff
      const maxStaff = timeSlot.maxStaff || requiredStaff
      
      // Apply global max limit if exists
      if (globalMax !== undefined && currentStaffCount >= globalMax) {
        console.log(`Reached global max of ${globalMax} for ${jobFunction}`)
        continue
      }
      
      // Calculate how many staff we can assign (respecting global and slot max limits)
      let effectiveMaxStaff = maxStaff || 0
      if (globalMax !== undefined) {
        const remainingGlobal = globalMax - currentStaffCount
        effectiveMaxStaff = Math.min(effectiveMaxStaff || 999, remainingGlobal)
      }
      
      // Find available employees for this time slot
      const availableEmployees = findAvailableEmployees(
        employees, 
        shifts, 
        trainingData, 
        jobFunctions,
        jobFunction, 
        timeSlot.start, 
        timeSlot.end,
        assignments, // Pass existing assignments to check for conflicts
        preferredAssignmentsMap // Pass preferred assignments for prioritization
      )
      
      // Assign staff (respecting max limits)
      const staffToAssign = Math.min(requiredStaff || 0, availableEmployees.length, effectiveMaxStaff)
      
      if (availableEmployees.length === 0) {
        const warning = `No trained employees available for ${jobFunction} at ${timeSlot.start}-${timeSlot.end} (Required: ${requiredStaff || 0})`
        console.warn(`⚠️ ${warning}`)
        warnings.push(warning)
      } else if (availableEmployees.length < (requiredStaff || 0)) {
        const warning = `Insufficient trained employees for ${jobFunction} at ${timeSlot.start}-${timeSlot.end} (Available: ${availableEmployees.length}, Required: ${requiredStaff || 0})`
        console.warn(`⚠️ ${warning}`)
        warnings.push(warning)
      } else {
        console.log(`✅ Assigning ${staffToAssign} staff for ${jobFunction} at ${timeSlot.start}-${timeSlot.end} (available: ${availableEmployees.length}, required: ${requiredStaff}, max: ${effectiveMaxStaff})`)
      }
      
      for (let i = 0; i < staffToAssign; i++) {
        const employee = availableEmployees[i]
        if (employee) {
          // Create 15-minute assignments for this block
          const blockAssignments = createBlockAssignments(
            employee, 
            jobFunction, 
            timeSlot.start, 
            timeSlot.end, 
            timeSlot.blockSize || 0
          )
          
          assignments.push(...blockAssignments)
          
          // Track assignment for this employee
          if (!employeeAssignments.has(employee.id)) {
            employeeAssignments.set(employee.id, [])
          }
          employeeAssignments.get(employee.id).push(jobFunction)
          
          // Track hours
          const hours = (timeSlot.blockSize || 0) / 60
          employeeHours.set(employee.id, (employeeHours.get(employee.id) || 0) + hours)
          
          // Increment current staff count for global max tracking
          currentStaffCount++
        }
      }
      
      // If we couldn't meet the minimum requirement, try to find any available employee
      if (staffToAssign < (requiredStaff || 0) && globalMax === undefined) {
        console.log(`Warning: Only found ${staffToAssign} employees for ${jobFunction}, need ${requiredStaff}`)
        
        // Try to find employees trained in any function and assign them
        const anyTrainedEmployees = employees.filter((emp: any) => {
          const shift = shifts.find((s: any) => s.id === emp.shift_id)
          if (!shift) return false
          
          const shiftStart = shift.start_time
          const shiftEnd = shift.end_time
          return timeSlot.start >= shiftStart && timeSlot.end <= shiftEnd
        })
        
        for (let i = staffToAssign; i < (requiredStaff || 0) && i < anyTrainedEmployees.length && currentStaffCount < (globalMax || 999); i++) {
          const employee = anyTrainedEmployees[i]
          const blockAssignments = createBlockAssignments(
            employee, 
            jobFunction, 
            timeSlot.start, 
            timeSlot.end, 
            timeSlot.blockSize || 0
          )
          
          assignments.push(...blockAssignments)
          
          if (!employeeAssignments.has(employee.id)) {
            employeeAssignments.set(employee.id, [])
          }
          employeeAssignments.get(employee.id).push(jobFunction)
          currentStaffCount++
        }
      }
    }
  }
  
  // Add break coverage for Locus and X4
  await addBreakCoverage(employees, shifts, trainingData, jobFunctions, assignments, employeeAssignments)
  
  // STEP 3: Consolidate assignments into simple 2-4 hour blocks following strategy
  const consolidatedAssignments = await consolidateAssignmentsStrategy(
    employees,
    shifts,
    trainingData,
    assignments,
    employeeAssignments,
    employeeHours
  )
  
  // Fill remaining hours with "Flex" assignments (2-4 hour blocks)
  await fillRemainingHoursWithFlex(employees, shifts, trainingData, consolidatedAssignments, employeeAssignments, employeeHours)
  
  // If no assignments were created, create a basic fallback schedule
  if (consolidatedAssignments.length === 0) {
    console.log('No assignments created, creating fallback schedule')
    const fallbackSchedule = await createFallbackSchedule(employees, jobFunctions, shifts, trainingData)
    return { schedule: Array.isArray(fallbackSchedule) ? fallbackSchedule : [], warnings }
  }
  
  return { schedule: consolidatedAssignments, warnings }
}

// Assign Startup to all 6am employees (6am-8am)
const assignStartupTo6amEmployees = async (
  employees: any[],
  shifts: any[],
  jobFunctions: any[],
  trainingData: any,
  assignments: any[],
  employeeAssignments: Map<string, any[]>,
  employeeHours: Map<string, number>
) => {
  console.log('🌅 Assigning Startup to 6am employees...')
  
  // Find the 6am shift (usually shift starting at 06:00)
  const sixAMShift = shifts.find((s: any) => {
    const shiftStart = timeToMinutes(s.start_time)
    return shiftStart === timeToMinutes('06:00') // 6am = 360 minutes
  })
  
  if (!sixAMShift) {
    console.log('No 6am shift found, skipping Startup assignments')
    return
  }
  
  // Find all employees on the 6am shift
  const sixAMEmployees = employees.filter((emp: any) => emp.shift_id === sixAMShift.id)
  
  console.log(`Found ${sixAMEmployees.length} employees on 6am shift`)
  
  // Check if "Startup" job function exists
  const startupJobFunction = jobFunctions.find((jf: any) => jf.name === 'Startup')
  if (!startupJobFunction) {
    console.log('Startup job function not found, skipping')
    return
  }
  
  // Assign Startup (06:00-08:00) to all 6am employees
  for (const employee of sixAMEmployees) {
    // Check if employee is trained in Startup (or if Startup doesn't require training)
    const isTrained = !startupJobFunction.requires_training || trainingData[employee.id]?.includes(startupJobFunction.id)
    
    if (isTrained) {
      const startupAssignments = createBlockAssignments(
        employee,
        'Startup',
        '06:00',
        '08:00',
        120 // 2 hours
      )
      
      assignments.push(...startupAssignments)
      
      // Track assignment
      if (!employeeAssignments.has(employee.id)) {
        employeeAssignments.set(employee.id, [])
      }
      employeeAssignments.get(employee.id).push('Startup')
      
      // Track hours
      employeeHours.set(employee.id, (employeeHours.get(employee.id) || 0) + 2)
    }
  }
  
  console.log(`✅ Assigned Startup to ${sixAMEmployees.length} employees`)
}

// Consolidate assignments into simple 2-4 hour blocks following strategic pattern
const consolidateAssignmentsStrategy = async (
  employees: any[],
  shifts: any[],
  trainingData: any,
  rawAssignments: any[],
  employeeAssignments: Map<string, any[]>,
  employeeHours: Map<string, number>
) => {
  console.log('🔄 Consolidating assignments into strategic 2-4 hour blocks...')
  
  const consolidated: any[] = []
  const employeeTimeBlocks = new Map<string, Array<{start: number, end: number, function: string}>>()
  
  // Group assignments by employee and time
  for (const employee of employees) {
    const shift = shifts.find((s: any) => s.id === employee.shift_id)
    if (!shift) continue
    
    const shiftStart = timeToMinutes(shift.start_time)
    const shiftEnd = timeToMinutes(shift.end_time)
    
    // Get all assignments for this employee
    const empAssignments = rawAssignments
      .filter(a => a.employee_id === employee.id)
      .map(a => ({
        start: timeToMinutes(a.start_time),
        end: timeToMinutes(a.end_time),
        function: a.job_function
      }))
    
    // Sort by start time
    empAssignments.sort((a, b) => a.start - b.start)
    
    // Merge contiguous same-function assignments
    const merged: Array<{start: number, end: number, function: string}> = []
    for (const assign of empAssignments) {
      const last = merged[merged.length - 1]
      if (last && last.function === assign.function && last.end === assign.start) {
        // Extend contiguous block
        last.end = assign.end
      } else {
        // New block
        merged.push({ ...assign })
      }
    }
    
    // Strategy: Organize into 2-4 hour blocks
    // Goal: Function 1 before lunch, Function 2 after lunch
    // Lunch is typically 12:30-13:00, use 12:00-13:00 as split point
    const lunchSplit = timeToMinutes('12:00')
    const lunchEnd = timeToMinutes('13:00')
    
    const beforeLunch: Array<{start: number, end: number, function: string}> = []
    const afterLunch: Array<{start: number, end: number, function: string}> = []
    
    for (const block of merged) {
      // Skip Startup (already assigned correctly, keep as-is)
      if (block.function === 'Startup') {
        beforeLunch.push(block)
        continue
      }
      
      if (block.end <= lunchSplit) {
        // Completely before lunch
        beforeLunch.push(block)
      } else if (block.start >= lunchEnd) {
        // Completely after lunch
        afterLunch.push(block)
      } else {
        // Spans lunch period - split it
        if (block.start < lunchSplit) {
          beforeLunch.push({ start: block.start, end: lunchSplit, function: block.function })
        }
        if (block.end > lunchEnd) {
          afterLunch.push({ start: lunchEnd, end: block.end, function: block.function })
        }
      }
    }
    
    // Consolidate blocks in each period into 2-4 hour chunks
    const consolidatePeriod = (blocks: Array<{start: number, end: number, function: string}>): Array<{start: number, end: number, function: string}> => {
      if (blocks.length === 0) return []
      
      const result: Array<{start: number, end: number, function: string}> = []
      const blocksByFunction: Record<string, Array<{start: number, end: number}>> = {}
      
      // Group by function
      for (const block of blocks) {
        if (!blocksByFunction[block.function]) {
          blocksByFunction[block.function] = []
        }
        blocksByFunction[block.function].push({ start: block.start, end: block.end })
      }
      
      // For each function, merge contiguous blocks
      for (const [func, funcBlocks] of Object.entries(blocksByFunction)) {
        funcBlocks.sort((a, b) => a.start - b.start)
        
        let currentBlock: {start: number, end: number} | null = null
        for (const block of funcBlocks) {
          if (!currentBlock) {
            currentBlock = { ...block }
          } else if (block.start <= currentBlock.end + 60) { // Within 1 hour, merge
            currentBlock.end = Math.max(currentBlock.end, block.end)
          } else {
            // Save current and start new
            result.push({ ...currentBlock, function: func })
            currentBlock = { ...block }
          }
        }
        if (currentBlock) {
          result.push({ ...currentBlock, function: func })
        }
      }
      
      // Sort by start time
      result.sort((a, b) => a.start - b.start)
      
      // Limit to 4 functions per day
      const uniqueFunctions = new Set(result.map(b => b.function))
      if (uniqueFunctions.size > 4) {
        // Keep only first 4 unique functions
        const seen = new Set<string>()
        return result.filter(b => {
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
    
    // Combine blocks (prefer 2-4 hour blocks, but keep all assignments)
    const allBlocks = [...beforeConsolidated, ...afterConsolidated]
      .sort((a, b) => a.start - b.start)
    
    // Merge very small blocks (< 2 hours) with adjacent same-function blocks if possible
    const finalBlocks: Array<{start: number, end: number, function: string}> = []
    for (const block of allBlocks) {
      const blockDuration = block.end - block.start
      
      if (blockDuration < 120 && finalBlocks.length > 0) {
        // Try to merge with previous block if same function and close
        const last = finalBlocks[finalBlocks.length - 1]
        if (last.function === block.function && (block.start - last.end) <= 60) {
          // Merge with previous block
          last.end = block.end
          continue
        }
      }
      
      finalBlocks.push(block)
    }
    
    employeeTimeBlocks.set(employee.id, finalBlocks)
  }
  
  // Convert back to assignment format
  for (const [employeeId, blocks] of employeeTimeBlocks.entries()) {
    for (const block of blocks) {
      const blockAssignments = createBlockAssignments(
        employees.find(e => e.id === employeeId)!,
        block.function,
        minutesToTime(block.start),
        minutesToTime(block.end),
        block.end - block.start
      )
      consolidated.push(...blockAssignments)
    }
  }
  
  console.log(`✅ Consolidated ${rawAssignments.length} raw assignments into ${consolidated.length} strategic blocks`)
  return consolidated
}

// Fill remaining hours with Flex in 2-4 hour blocks (instead of 1-hour blocks)
const fillRemainingHoursWithFlex = async (
  employees: any[],
  shifts: any[],
  trainingData: any,
  assignments: any[],
  employeeAssignments: Map<string, any[]>,
  employeeHours: Map<string, number>
) => {
  console.log('📦 Filling remaining hours with Flex (2-4 hour blocks)...')
  
  for (const employee of employees) {
    const shift = shifts.find((s: any) => s.id === employee.shift_id)
    if (!shift) continue
    
    const shiftStart = timeToMinutes(shift.start_time)
    const shiftEnd = timeToMinutes(shift.end_time)
    
    // Find assigned time slots
    const assignedTimes = new Set<number>()
    assignments
      .filter((a: any) => a.employee_id === employee.id)
      .forEach((a: any) => {
        const start = timeToMinutes(a.start_time)
        const end = timeToMinutes(a.end_time)
        for (let t = start; t < end; t += 15) {
          assignedTimes.add(t)
        }
      })
    
    // Find gaps and fill with Flex in 2-4 hour blocks
    let currentTime = shiftStart
    while (currentTime < shiftEnd) {
      if (!assignedTimes.has(currentTime)) {
        // Find the end of this gap
        let gapEnd = currentTime
        while (gapEnd < shiftEnd && !assignedTimes.has(gapEnd)) {
          gapEnd += 15
        }
        
        const gapDuration = gapEnd - currentTime
        
        // Create Flex blocks: 2-4 hours each
        let flexTime = currentTime
        while (flexTime < gapEnd) {
          // Target 3 hours (180 minutes), but adjust for remaining gap
          const remaining = gapEnd - flexTime
          let blockDuration = Math.min(180, remaining) // Default 3 hours
          
          // If remaining is 2-4 hours, use it all
          if (remaining >= 120 && remaining <= 240) {
            blockDuration = remaining
          } else if (remaining > 240) {
            // Split into multiple 2-4 hour blocks
            blockDuration = 180 // 3 hours
          } else if (remaining < 120) {
            // Less than 2 hours, merge with previous or make minimum 2 hours
            blockDuration = Math.max(120, remaining)
          }
          
          const flexEnd = Math.min(flexTime + blockDuration, gapEnd)
          
          const flexAssignments = createBlockAssignments(
            employee,
            'Flex',
            minutesToTime(flexTime),
            minutesToTime(flexEnd),
            flexEnd - flexTime
          )
          
          assignments.push(...flexAssignments)
          flexTime = flexEnd
        }
        
        currentTime = gapEnd
      } else {
        currentTime += 15
      }
    }
  }
  
  console.log('✅ Filled remaining hours with Flex blocks')
}

// Helper function to find available employees (updated to check existing assignments and prioritize preferred assignments)
const findAvailableEmployees = (employees: any[], shifts: any[], trainingData: any, jobFunctions: any[], jobFunction: string, startTime: string, endTime: string, existingAssignments: any[] = [], preferredAssignmentsMap: Record<string, Record<string, any>> = {}) => {
  const startMinutes = timeToMinutes(startTime)
  const endMinutes = timeToMinutes(endTime)
  
  const available = employees.filter((employee: any) => {
    // Check if employee is trained in this job function
    const jobFunctionObj = jobFunctions.find((jf: any) => jf.name === jobFunction)
    if (!jobFunctionObj) {
      console.log(`Job function ${jobFunction} not found`)
      return false
    }
    
    const isTrained = trainingData[employee.id]?.includes(jobFunctionObj.id)
    if (!isTrained) {
      console.log(`Employee ${employee.first_name} not trained in ${jobFunction}`)
      return false
    }
    
    // Check if employee's shift covers this time
    const shift = shifts.find((s: any) => s.id === employee.shift_id)
    if (!shift) {
      console.log(`Employee ${employee.first_name} has no shift`)
      return false
    }
    
    const shiftStart = shift.start_time
    const shiftEnd = shift.end_time
    
    // More flexible time coverage - allow partial overlap
    const timeCovered = startTime < shiftEnd && endTime > shiftStart
    if (!timeCovered) {
      console.log(`Employee ${employee.first_name} shift ${shiftStart}-${shiftEnd} doesn't cover ${startTime}-${endTime}`)
    }
    
    // Check if employee already has an assignment during this time
    const hasConflict = existingAssignments.some((a: any) => {
      if (a.employee_id !== employee.id) return false
      const aStart = timeToMinutes(a.start_time)
      const aEnd = timeToMinutes(a.end_time)
      // Check for overlap
      return !(endMinutes <= aStart || startMinutes >= aEnd)
    })
    
    if (hasConflict) {
      console.log(`Employee ${employee.first_name} already has an assignment during ${startTime}-${endTime}`)
      return false
    }
    
    return timeCovered
  })
  
  // Sort by preferred assignment priority (higher priority first)
  // Employees with preferred assignments come first, sorted by priority (descending)
  // Then employees with required assignments (is_required = true)
  // Then regular employees
  const jobFunctionObj = jobFunctions.find((jf: any) => jf.name === jobFunction)
  if (jobFunctionObj) {
    available.sort((a: any, b: any) => {
      const aPref = preferredAssignmentsMap[a.id]?.[jobFunctionObj.id]
      const bPref = preferredAssignmentsMap[b.id]?.[jobFunctionObj.id]
      
      // Required assignments come first
      if (aPref?.is_required && !bPref?.is_required) return -1
      if (!aPref?.is_required && bPref?.is_required) return 1
      
      // Then sort by priority (higher priority first)
      if (aPref && bPref) {
        return (bPref.priority || 0) - (aPref.priority || 0)
      }
      if (aPref && !bPref) return -1
      if (!aPref && bPref) return 1
      
      return 0 // Equal priority
    })
  }
  
  console.log(`Found ${available.length} available employees for ${jobFunction} at ${startTime}-${endTime}`)
  if (jobFunctionObj) {
    const preferredCount = available.filter((emp: any) => preferredAssignmentsMap[emp.id]?.[jobFunctionObj.id]).length
    if (preferredCount > 0) {
      console.log(`  → ${preferredCount} employees have preferred assignments for ${jobFunction}`)
    }
  }
  return available
}

// Create 15-minute assignments for a time block
const createBlockAssignments = (employee: any, jobFunction: string, startTime: string, endTime: string, blockSizeMinutes: number) => {
  const assignments = []
  const startMinutes = timeToMinutes(startTime)
  const endMinutes = timeToMinutes(endTime)
  const blockSize = blockSizeMinutes || (endMinutes - startMinutes)
  
  // Create assignments in 15-minute increments
  let currentMinutes = startMinutes
  while (currentMinutes < endMinutes) {
    const nextMinutes = Math.min(currentMinutes + 15, endMinutes)
    
    assignments.push({
      id: `${employee.id}-${jobFunction}-${currentMinutes}`,
      employee_id: employee.id,
      job_function: jobFunction,
      start_time: minutesToTime(currentMinutes),
      end_time: minutesToTime(nextMinutes)
    })
    
    currentMinutes = nextMinutes
  }
  
  return assignments
}

// Add lunch coverage for Locus and X4 only
const addBreakCoverage = async (employees: any[], shifts: any[], trainingData: any, jobFunctions: any[], assignments: any[], employeeAssignments: any) => {
  // Only cover lunch time (12:30-13:00)
  const lunchTime = { start: '12:30', end: '13:00' }
  
  // Priority functions for lunch coverage
  const priorityFunctions = ['Locus', 'X4']
  
  for (const priorityFunction of priorityFunctions) {
    // Find employees currently assigned to this function during lunch time
    const employeesOnFunction = assignments
      .filter((a: any) => a.job_function === priorityFunction && 
                  a.start_time <= lunchTime.start && 
                  a.end_time > lunchTime.start)
      .map((a: any) => a.employee_id)
    
    // Find available employees to cover lunch
    const availableCoverage = findAvailableEmployees(
      employees, 
      shifts, 
      trainingData, 
      jobFunctions,
      priorityFunction, 
      lunchTime.start, 
      lunchTime.end,
      assignments // Pass existing assignments to check for conflicts
    ).filter((emp: any) => !employeesOnFunction.includes(emp.id))
    
    // Assign lunch coverage (1 person per function)
    if (availableCoverage.length > 0) {
      const coverageEmployee = availableCoverage[0]
      const lunchAssignments = createBlockAssignments(
        coverageEmployee,
        priorityFunction,
        lunchTime.start,
        lunchTime.end,
        30 // 30-minute lunch
      )
      
      assignments.push(...lunchAssignments)
      
      // Track assignment
      if (!employeeAssignments.has(coverageEmployee.id)) {
        employeeAssignments.set(coverageEmployee.id, [])
      }
      employeeAssignments.get(coverageEmployee.id).push(priorityFunction)
    }
  }
}

// Ensure employees get at least 2 different functions
const ensureDiverseAssignments = async (employees: any[], shifts: any[], trainingData: any, jobFunctions: any[], assignments: any[], employeeAssignments: any) => {
  for (const employee of employees) {
    const currentFunctions = new Set(employeeAssignments.get(employee.id) || [])
    
    // If employee has less than 2 functions, try to add another
    if (currentFunctions.size < 2) {
      const shift = shifts.find((s: any) => s.id === employee.shift_id)
      if (!shift) continue
      
      // Find available time slots for this employee
      const assignedTimes = new Set()
      assignments
        .filter((a: any) => a.employee_id === employee.id)
        .forEach((a: any) => {
          const start = timeToMinutes(a.start_time)
          const end = timeToMinutes(a.end_time)
          for (let t = start; t < end; t += 15) {
            assignedTimes.add(t)
          }
        })
      
      // Find a 2-hour gap to assign a different function
      const shiftStart = timeToMinutes(shift.start_time)
      const shiftEnd = timeToMinutes(shift.end_time)
      
      for (let time = shiftStart; time < shiftEnd - 120; time += 15) {
        if (!assignedTimes.has(time) && !assignedTimes.has(time + 15) && 
            !assignedTimes.has(time + 30) && !assignedTimes.has(time + 45) &&
            !assignedTimes.has(time + 60) && !assignedTimes.has(time + 75) &&
            !assignedTimes.has(time + 90) && !assignedTimes.has(time + 105)) {
          
          // Find a different function this employee is trained for
          const availableFunctions = jobFunctions.filter((jf: any) => 
            trainingData[employee.id]?.includes(jf.id) && 
            !currentFunctions.has(jf.name) &&
            jf.name !== 'Flex'
          )
          
          if (availableFunctions.length > 0) {
            const newFunction = availableFunctions[0]
            const newAssignments = createBlockAssignments(
              employee,
              newFunction.name,
              minutesToTime(time),
              minutesToTime(time + 120),
              120 // 2 hours
            )
            
            assignments.push(...newAssignments)
            
            // Ensure the array exists before pushing
            if (!employeeAssignments.has(employee.id)) {
              employeeAssignments.set(employee.id, [])
            }
            employeeAssignments.get(employee.id).push(newFunction.name)
            break
          }
        }
      }
    }
  }
}

// Fill remaining hours with "Flex" assignments
const fillRemainingHours = async (employees: any[], shifts: any[], trainingData: any, assignments: any[], employeeAssignments: any, employeeHours: any) => {
  // Find employees with remaining capacity
  for (const employee of employees) {
    const shift = shifts.find((s: any) => s.id === employee.shift_id)
    if (!shift) continue
    
    const shiftStart = timeToMinutes(shift.start_time)
    const shiftEnd = timeToMinutes(shift.end_time)
    const shiftDuration = shiftEnd - shiftStart
    const currentHours = employeeHours.get(employee.id) || 0
    const remainingHours = (shiftDuration / 60) - currentHours
    
    if (remainingHours > 0) {
      // Find time slots not yet assigned
      const assignedTimes = new Set()
      assignments
        .filter((a: any) => a.employee_id === employee.id)
        .forEach((a: any) => {
          const start = timeToMinutes(a.start_time)
          const end = timeToMinutes(a.end_time)
          for (let t = start; t < end; t += 15) {
            assignedTimes.add(t)
          }
        })
      
      // Find gaps to fill with Flex
      let currentTime = shiftStart
      while (currentTime < shiftEnd) {
        if (!assignedTimes.has(currentTime)) {
          const gapEnd = Math.min(currentTime + 60, shiftEnd) // 1-hour Flex blocks
          
          const flexAssignments = createBlockAssignments(
            employee,
            'Flex',
            minutesToTime(currentTime),
            minutesToTime(gapEnd),
            60
          )
          
          assignments.push(...flexAssignments)
          currentTime = gapEnd
        } else {
          currentTime += 15
        }
      }
    }
  }
}

// Fallback schedule creation
const createFallbackSchedule = async (employees: any[], jobFunctions: any[], shifts: any[], trainingData: any) => {
  const assignments = []
  
  console.log('Creating fallback schedule with available data')
  
  // Create basic assignments for each employee during their shift
  for (const employee of employees) {
    const shift = shifts.find((s: any) => s.id === employee.shift_id)
    if (!shift) continue
    
    // Get the first job function this employee is trained for
    const trainedFunctions = trainingData[employee.id] || []
    if (trainedFunctions.length === 0) continue
    
    const jobFunction = jobFunctions.find((jf: any) => trainedFunctions.includes(jf.id))
    if (!jobFunction) continue
    
    // Create a simple 8-hour assignment during their shift
    const shiftStart = timeToMinutes(shift.start_time)
    const shiftEnd = timeToMinutes(shift.end_time)
    const workDuration = Math.min(480, shiftEnd - shiftStart) // 8 hours max
    
    const blockAssignments = createBlockAssignments(
      employee,
      jobFunction.name,
      minutesToTime(shiftStart),
      minutesToTime(shiftStart + workDuration),
      workDuration
    )
    
    assignments.push(...blockAssignments)
  }
  
  console.log(`Created ${assignments.length} fallback assignments`)
  return assignments
}

// Time utility functions
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

const applyAISchedule = async (schedule: any[]) => {
  try {
    // Get shifts data
    const shiftsData = await fetchShifts()
    
    // Merge contiguous per-slot assignments into ranges by employee/job/shift
    const timeAsc = (a: string, b: string) => timeToMinutes(a) - timeToMinutes(b)
    const keyFor = (empId: string, jobId: string, shiftId: string) => `${empId}|${jobId}|${shiftId}`

    // Pre-resolve job function ids and shift ids for each slot
    const enriched = schedule
      .map(a => {
        const jf = jobFunctions.value.find((jf: any) => jf.name === a.job_function) as any
        if (!jf) return null
        const shift = (shiftsData || []).find((s: any) => {
          const t = timeToMinutes(a.start_time)
          return t >= timeToMinutes(s.start_time) && t < timeToMinutes(s.end_time)
        }) as any
        if (!shift) return null
        return { ...a, job_function_id: jf.id, shift_id: shift.id }
      })
      .filter(Boolean) as any[]

    const grouped: Record<string, any[]> = {}
    for (const a of enriched) {
      const k = keyFor(a.employee_id, a.job_function_id, a.shift_id)
      if (!grouped[k]) grouped[k] = []
      grouped[k].push(a)
    }

    const ranges: any[] = []
    Object.entries(grouped).forEach(([k, items]) => {
      items.sort((a, b) => timeAsc(a.start_time, b.start_time))
      let curStart = ''
      let curEnd = ''
      for (const it of items) {
        if (!curStart) {
          curStart = it.start_time
          curEnd = it.end_time
        } else if (it.start_time === curEnd) {
          // extend contiguous
          curEnd = it.end_time
        } else {
          const [empId, jobId, shiftId] = k.split('|')
          ranges.push({ employee_id: empId, job_function_id: jobId, shift_id: shiftId, start_time: curStart, end_time: curEnd, schedule_date: selectedDate.value })
          curStart = it.start_time
          curEnd = it.end_time
        }
      }
      if (curStart) {
        const [empId, jobId, shiftId] = k.split('|')
        ranges.push({ employee_id: empId, job_function_id: jobId, shift_id: shiftId, start_time: curStart, end_time: curEnd, schedule_date: selectedDate.value })
      }
    })

    // Bulk insert ranges in batches for performance
    const batchSize = 200
    for (let i = 0; i < ranges.length; i += batchSize) {
      const batch = ranges.slice(i, i + batchSize)
      const { error } = await useNuxtApp().$supabase.from('schedule_assignments').insert(batch)
      if (error) throw error
    }
  } catch (error) {
    console.error('Error applying AI schedule:', error)
    throw error
  }
}

// Load job functions on mount
onMounted(async () => {
  await fetchJobFunctions()
})
</script>