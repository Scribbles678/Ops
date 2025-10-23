<template>
  <div class="min-h-screen bg-gray-50">
    <div class="container mx-auto px-4 py-8">
      <!-- Header -->
      <div class="flex items-center justify-between mb-8">
        <div>
          <h1 class="text-4xl font-bold text-gray-800">Make Tomorrow's Schedule</h1>
          <p class="text-gray-600 mt-2">{{ formatDate(tomorrowDate) }}</p>
        </div>
        <div class="flex space-x-4">
          <NuxtLink to="/" class="btn-secondary">
            ← Back to Home
          </NuxtLink>
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
            <p class="text-gray-600">Copy the current schedule to tomorrow</p>
          </div>
        </div>

        <!-- AI Generated Schedule -->
        <div class="card hover:shadow-lg transition-all cursor-pointer" @click="generateAISchedule">
          <div class="text-center py-8">
            <div class="bg-purple-100 rounded-full p-6 mb-4 mx-auto w-20 h-20 flex items-center justify-center">
              <svg class="w-10 h-10 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
              </svg>
            </div>
            <h3 class="text-xl font-bold text-gray-800 mb-2">🤖 AI Generated Schedule</h3>
            <p class="text-gray-600">Let AI create an optimized schedule based on employee training, productivity rates, and business rules</p>
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
            <p class="text-gray-600">Create tomorrow's schedule manually from scratch</p>
          </div>
        </div>
      </div>

      <!-- AI Schedule Generation Modal -->
      <div v-if="showAIModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-white rounded-lg p-6 max-w-4xl w-full mx-4 max-h-[90vh] overflow-y-auto">
          <h3 class="text-2xl font-bold mb-6">🤖 AI Schedule Generator</h3>
          
          <!-- AI Configuration Options -->
          <div class="space-y-6">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <!-- Business Rules -->
              <div class="space-y-4">
                <h4 class="text-lg font-semibold text-gray-800">Business Rules</h4>
                
                <div class="space-y-3">
                  <label class="flex items-center space-x-3">
                    <input v-model="aiConfig.minimumCoverage" type="checkbox" class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500">
                    <span class="text-sm text-gray-700">Ensure minimum coverage for critical functions</span>
                  </label>
                  
                  <label class="flex items-center space-x-3">
                    <input v-model="aiConfig.balanceWorkload" type="checkbox" class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500">
                    <span class="text-sm text-gray-700">Balance workload across time blocks</span>
                  </label>
                  
                  <label class="flex items-center space-x-3">
                    <input v-model="aiConfig.optimizeProductivity" type="checkbox" class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500">
                    <span class="text-sm text-gray-700">Optimize for maximum productivity</span>
                  </label>
                  
                  <label class="flex items-center space-x-3">
                    <input v-model="aiConfig.respectBreaks" type="checkbox" class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500">
                    <span class="text-sm text-gray-700">Respect break and lunch schedules</span>
                  </label>
                </div>
              </div>

              <!-- Coverage Requirements -->
              <div class="space-y-4">
                <h4 class="text-lg font-semibold text-gray-800">Coverage Requirements</h4>
                
                <div class="space-y-3">
                  <div class="flex items-center justify-between">
                    <label class="text-sm text-gray-700">RT Pick Minimum:</label>
                    <input v-model="aiConfig.rtPickMin" type="number" min="0" class="w-20 px-2 py-1 border border-gray-300 rounded text-sm">
                  </div>
                  
                  <div class="flex items-center justify-between">
                    <label class="text-sm text-gray-700">Pick Minimum:</label>
                    <input v-model="aiConfig.pickMin" type="number" min="0" class="w-20 px-2 py-1 border border-gray-300 rounded text-sm">
                  </div>
                  
                  <div class="flex items-center justify-between">
                    <label class="text-sm text-gray-700">Meter Minimum:</label>
                    <input v-model="aiConfig.meterMin" type="number" min="0" class="w-20 px-2 py-1 border border-gray-300 rounded text-sm">
                  </div>
                  
                  <div class="flex items-center justify-between">
                    <label class="text-sm text-gray-700">Locus Minimum:</label>
                    <input v-model="aiConfig.locusMin" type="number" min="0" class="w-20 px-2 py-1 border border-gray-300 rounded text-sm">
                  </div>
                </div>
              </div>
            </div>

            <!-- AI Preview -->
            <div v-if="aiGeneratedSchedule.length > 0" class="space-y-4">
              <h4 class="text-lg font-semibold text-gray-800">AI Generated Schedule Preview</h4>
              
              <div class="bg-gray-50 rounded-lg p-4 max-h-64 overflow-y-auto">
                <div class="grid grid-cols-8 gap-2 text-xs">
                  <div class="font-semibold">Employee</div>
                  <div class="font-semibold text-center">6AM</div>
                  <div class="font-semibold text-center">8AM</div>
                  <div class="font-semibold text-center">10AM</div>
                  <div class="font-semibold text-center">12PM</div>
                  <div class="font-semibold text-center">2PM</div>
                  <div class="font-semibold text-center">4PM</div>
                  <div class="font-semibold text-center">6PM</div>
                  
                  <template v-for="assignment in aiGeneratedSchedule" :key="assignment.id">
                    <div class="text-xs">{{ getEmployeeName(assignment.employee_id) }}</div>
                    <div v-for="timeBlock in ['6am', '8am', '10am', '12pm', '2pm', '4pm', '6pm']" :key="timeBlock" 
                         class="text-center">
                      <span v-if="assignment.shift_id === timeBlock" 
                            class="inline-block px-2 py-1 rounded text-xs font-medium"
                            :style="{ 
                              backgroundColor: getJobFunctionColor([assignment.job_function]), 
                              color: assignment.job_function === 'Locus' ? '#000' : '#fff' 
                            }">
                        {{ assignment.job_function }}
                      </span>
                    </div>
                  </template>
                </div>
              </div>
            </div>
          </div>

          <!-- Action Buttons -->
          <div class="flex justify-between items-center pt-6 border-t border-gray-200 mt-6">
            <button @click="closeAIModal" class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50">
              Cancel
            </button>
            <div class="flex space-x-3">
              <button @click="previewAISchedule" 
                      :disabled="generating"
                      class="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50">
                {{ generating ? 'Generating...' : 'Preview AI Schedule' }}
              </button>
              <button v-if="aiGeneratedSchedule.length > 0" @click="applyAISchedule" 
                      class="px-6 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700">
                Apply AI Schedule
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
// Tomorrow's date
const tomorrowDate = computed(() => {
  const tomorrow = new Date()
  tomorrow.setDate(tomorrow.getDate() + 1)
  return tomorrow.toISOString().split('T')[0]
})

// AI Modal state
const showAIModal = ref(false)
const generating = ref(false)
const aiGeneratedSchedule = ref([])

// AI Configuration
const aiConfig = ref({
  minimumCoverage: true,
  balanceWorkload: true,
  optimizeProductivity: true,
  respectBreaks: true,
  rtPickMin: 2,
  pickMin: 2,
  meterMin: 1,
  locusMin: 1
})

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
const formatDate = (dateString) => {
  const date = new Date(dateString)
  return date.toLocaleDateString('en-US', { 
    weekday: 'long', 
    year: 'numeric', 
    month: 'long', 
    day: 'numeric' 
  })
}

const copyTodaySchedule = () => {
  // Navigate to tomorrow's schedule page
  navigateTo(`/schedule/${tomorrowDate.value}`)
}

const generateAISchedule = () => {
  showAIModal.value = true
}

const goToManualSchedule = () => {
  // Navigate to tomorrow's schedule page
  navigateTo(`/schedule/${tomorrowDate.value}`)
}

const closeAIModal = () => {
  showAIModal.value = false
  aiGeneratedSchedule.value = []
}

const getEmployeeName = (employeeId) => {
  const employee = employees.value.find(e => e.id === employeeId)
  return employee ? `${employee.last_name}, ${employee.first_name}` : 'Unknown'
}

const getJobFunctionColor = (jobFunctions) => {
  const colors = {
    'RT Pick': '#FFA500',
    'Pick': '#FFFF00',
    'Meter': '#87CEEB',
    'Locus': '#FFFFFF',
    'Helpdesk': '#FFD700',
    'Coordinator': '#C0C0C0',
    'Team Lead': '#000080'
  }
  return colors[jobFunctions[0]] || '#3B82F6'
}

// AI Schedule Generation Logic
const previewAISchedule = async () => {
  generating.value = true
  
  // Simulate AI processing time
  await new Promise(resolve => setTimeout(resolve, 2000))
  
  // Generate AI schedule based on configuration
  aiGeneratedSchedule.value = generateAIScheduleLogic()
  
  generating.value = false
}

const generateAIScheduleLogic = () => {
  const schedule = []
  const timeBlocks = ['6am', '8am', '10am', '12pm', '2pm', '4pm', '6pm']
  const jobFunctions = ['RT Pick', 'Pick', 'Meter', 'Locus', 'Helpdesk', 'Coordinator', 'Team Lead']
  
  // Simple AI logic - assign employees optimally
  employees.value.forEach((employee, index) => {
    // Assign each employee to 2-3 time blocks
    const assignedBlocks = timeBlocks.slice(index % 3, (index % 3) + 2)
    
    assignedBlocks.forEach(block => {
      // Find a job function the employee is trained for
      const availableJobs = employee.trained_job_functions.filter(job => 
        jobFunctions.includes(job)
      )
      
      if (availableJobs.length > 0) {
        schedule.push({
          id: `${employee.id}-${block}`,
          employee_id: employee.id,
          shift_id: block,
          job_function: availableJobs[0]
        })
      }
    })
  })
  
  return schedule
}

const applyAISchedule = () => {
  // This would save the AI-generated schedule to the database
  console.log('Applying AI schedule:', aiGeneratedSchedule.value)
  alert('AI schedule applied successfully!')
  closeAIModal()
  
  // Navigate to tomorrow's schedule page to see the results
  navigateTo(`/schedule/${tomorrowDate.value}`)
}
</script>