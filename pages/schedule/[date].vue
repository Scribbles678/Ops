<template>
  <div class="min-h-screen bg-gray-50">
    <div class="container mx-auto px-4 py-8">
      <!-- Header -->
      <div class="flex items-center justify-between mb-8">
        <div>
          <h1 class="text-4xl font-bold text-gray-800">Edit Today's Schedule</h1>
          <p class="text-gray-600 mt-2">{{ formatDate(scheduleDate) }}</p>
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
        <div class="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-7 gap-4">
          <div v-for="jobFunction in jobFunctionHours" :key="jobFunction.name" class="text-center">
            <div class="flex items-center justify-center mb-2">
              <div 
                class="w-4 h-4 rounded border border-gray-300 mr-2" 
                :style="{ backgroundColor: jobFunction.color }"
              ></div>
              <span class="text-sm font-medium text-gray-700">{{ jobFunction.name }}</span>
            </div>
            <div class="text-2xl font-bold" :style="{ color: jobFunction.color }">
              {{ jobFunction.hours }}h
            </div>
            <div class="text-xs text-gray-500">{{ jobFunction.employees }} people</div>
          </div>
        </div>
      </div>

      <!-- Employee-Centric Schedule Grid -->
      <div class="card">
        <div class="overflow-x-auto">
          <table class="w-full border-collapse text-sm">
            <thead>
              <tr class="bg-gray-50">
                <th class="border border-gray-200 px-3 py-2 text-left text-xs font-medium text-gray-700 sticky left-0 bg-gray-50 z-10 min-w-[120px]">Employee</th>
                <th class="border border-gray-200 px-1 py-2 text-center text-xs font-medium text-gray-700 min-w-[80px]">6:00 AM</th>
                <th class="border border-gray-200 px-1 py-2 text-center text-xs font-medium text-gray-700 min-w-[80px]">8:00 AM</th>
                <th class="border border-gray-200 px-1 py-2 text-center text-xs font-medium text-gray-700 min-w-[80px]">10:00 AM</th>
                <th class="border border-gray-200 px-1 py-2 text-center text-xs font-medium text-gray-700 min-w-[80px]">12:00 PM</th>
                <th class="border border-gray-200 px-1 py-2 text-center text-xs font-medium text-gray-700 min-w-[80px]">2:00 PM</th>
                <th class="border border-gray-200 px-1 py-2 text-center text-xs font-medium text-gray-700 min-w-[80px]">4:00 PM</th>
                <th class="border border-gray-200 px-1 py-2 text-center text-xs font-medium text-gray-700 min-w-[80px]">6:00 PM</th>
                <th class="border border-gray-200 px-1 py-2 text-center text-xs font-medium text-gray-700 min-w-[80px]">8:00 PM</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="employee in employees" :key="employee.id" class="hover:bg-gray-50">
                <td class="border border-gray-200 px-3 py-2 font-medium text-gray-800 sticky left-0 bg-white z-10 text-xs">
                  {{ employee.last_name }}, {{ employee.first_name }}
                </td>
                <td class="border border-gray-200 px-1 py-2">
                  <div class="h-8 flex items-center justify-center">
                    <div v-if="getEmployeeAssignment(employee.id, '6am')" 
                         @click="removeAssignment(getEmployeeAssignment(employee.id, '6am').id)"
                         class="w-full h-full flex items-center justify-center rounded cursor-pointer hover:opacity-80 transition text-xs font-medium"
                         :style="{ 
                           backgroundColor: getJobFunctionColor(getEmployeeAssignment(employee.id, '6am').job_function), 
                           color: getEmployeeAssignment(employee.id, '6am').job_function === 'Locus' ? '#000' : '#fff' 
                         }">
                      {{ getEmployeeAssignment(employee.id, '6am').job_function }}
                    </div>
                    <button v-else @click="addAssignmentToEmployee(employee.id, '6am')" 
                            class="w-full h-full text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded transition text-xs border border-dashed border-gray-300">
                      +
                    </button>
                  </div>
                </td>
                <td class="border border-gray-200 px-1 py-2">
                  <div class="h-8 flex items-center justify-center">
                    <div v-if="getEmployeeAssignment(employee.id, '8am')" 
                         @click="removeAssignment(getEmployeeAssignment(employee.id, '8am').id)"
                         class="w-full h-full flex items-center justify-center rounded cursor-pointer hover:opacity-80 transition text-xs font-medium"
                         :style="{ 
                           backgroundColor: getJobFunctionColor(getEmployeeAssignment(employee.id, '8am').job_function), 
                           color: getEmployeeAssignment(employee.id, '8am').job_function === 'Locus' ? '#000' : '#fff' 
                         }">
                      {{ getEmployeeAssignment(employee.id, '8am').job_function }}
                    </div>
                    <button v-else @click="addAssignmentToEmployee(employee.id, '8am')" 
                            class="w-full h-full text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded transition text-xs border border-dashed border-gray-300">
                      +
                    </button>
                  </div>
                </td>
                <td class="border border-gray-200 px-1 py-2">
                  <div class="h-8 flex items-center justify-center">
                    <div v-if="getEmployeeAssignment(employee.id, '10am')" 
                         @click="removeAssignment(getEmployeeAssignment(employee.id, '10am').id)"
                         class="w-full h-full flex items-center justify-center rounded cursor-pointer hover:opacity-80 transition text-xs font-medium"
                         :style="{ 
                           backgroundColor: getJobFunctionColor(getEmployeeAssignment(employee.id, '10am').job_function), 
                           color: getEmployeeAssignment(employee.id, '10am').job_function === 'Locus' ? '#000' : '#fff' 
                         }">
                      {{ getEmployeeAssignment(employee.id, '10am').job_function }}
                    </div>
                    <button v-else @click="addAssignmentToEmployee(employee.id, '10am')" 
                            class="w-full h-full text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded transition text-xs border border-dashed border-gray-300">
                      +
                    </button>
                  </div>
                </td>
                <td class="border border-gray-200 px-1 py-2">
                  <div class="h-8 flex items-center justify-center">
                    <div v-if="getEmployeeAssignment(employee.id, '12pm')" 
                         @click="removeAssignment(getEmployeeAssignment(employee.id, '12pm').id)"
                         class="w-full h-full flex items-center justify-center rounded cursor-pointer hover:opacity-80 transition text-xs font-medium"
                         :style="{ 
                           backgroundColor: getJobFunctionColor(getEmployeeAssignment(employee.id, '12pm').job_function), 
                           color: getEmployeeAssignment(employee.id, '12pm').job_function === 'Locus' ? '#000' : '#fff' 
                         }">
                      {{ getEmployeeAssignment(employee.id, '12pm').job_function }}
                    </div>
                    <button v-else @click="addAssignmentToEmployee(employee.id, '12pm')" 
                            class="w-full h-full text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded transition text-xs border border-dashed border-gray-300">
                      +
                    </button>
                  </div>
                </td>
                <td class="border border-gray-200 px-1 py-2">
                  <div class="h-8 flex items-center justify-center">
                    <div v-if="getEmployeeAssignment(employee.id, '2pm')" 
                         @click="removeAssignment(getEmployeeAssignment(employee.id, '2pm').id)"
                         class="w-full h-full flex items-center justify-center rounded cursor-pointer hover:opacity-80 transition text-xs font-medium"
                         :style="{ 
                           backgroundColor: getJobFunctionColor(getEmployeeAssignment(employee.id, '2pm').job_function), 
                           color: getEmployeeAssignment(employee.id, '2pm').job_function === 'Locus' ? '#000' : '#fff' 
                         }">
                      {{ getEmployeeAssignment(employee.id, '2pm').job_function }}
                    </div>
                    <button v-else @click="addAssignmentToEmployee(employee.id, '2pm')" 
                            class="w-full h-full text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded transition text-xs border border-dashed border-gray-300">
                      +
                    </button>
                  </div>
                </td>
                <td class="border border-gray-200 px-1 py-2">
                  <div class="h-8 flex items-center justify-center">
                    <div v-if="getEmployeeAssignment(employee.id, '4pm')" 
                         @click="removeAssignment(getEmployeeAssignment(employee.id, '4pm').id)"
                         class="w-full h-full flex items-center justify-center rounded cursor-pointer hover:opacity-80 transition text-xs font-medium"
                         :style="{ 
                           backgroundColor: getJobFunctionColor(getEmployeeAssignment(employee.id, '4pm').job_function), 
                           color: getEmployeeAssignment(employee.id, '4pm').job_function === 'Locus' ? '#000' : '#fff' 
                         }">
                      {{ getEmployeeAssignment(employee.id, '4pm').job_function }}
                    </div>
                    <button v-else @click="addAssignmentToEmployee(employee.id, '4pm')" 
                            class="w-full h-full text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded transition text-xs border border-dashed border-gray-300">
                      +
                    </button>
                  </div>
                </td>
                <td class="border border-gray-200 px-1 py-2">
                  <div class="h-8 flex items-center justify-center">
                    <div v-if="getEmployeeAssignment(employee.id, '6pm')" 
                         @click="removeAssignment(getEmployeeAssignment(employee.id, '6pm').id)"
                         class="w-full h-full flex items-center justify-center rounded cursor-pointer hover:opacity-80 transition text-xs font-medium"
                         :style="{ 
                           backgroundColor: getJobFunctionColor(getEmployeeAssignment(employee.id, '6pm').job_function), 
                           color: getEmployeeAssignment(employee.id, '6pm').job_function === 'Locus' ? '#000' : '#fff' 
                         }">
                      {{ getEmployeeAssignment(employee.id, '6pm').job_function }}
                    </div>
                    <button v-else @click="addAssignmentToEmployee(employee.id, '6pm')" 
                            class="w-full h-full text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded transition text-xs border border-dashed border-gray-300">
                      +
                    </button>
                  </div>
                </td>
                <td class="border border-gray-200 px-1 py-2">
                  <div class="h-8 flex items-center justify-center">
                    <div v-if="getEmployeeAssignment(employee.id, '8pm')" 
                         @click="removeAssignment(getEmployeeAssignment(employee.id, '8pm').id)"
                         class="w-full h-full flex items-center justify-center rounded cursor-pointer hover:opacity-80 transition text-xs font-medium"
                         :style="{ 
                           backgroundColor: getJobFunctionColor(getEmployeeAssignment(employee.id, '8pm').job_function), 
                           color: getEmployeeAssignment(employee.id, '8pm').job_function === 'Locus' ? '#000' : '#fff' 
                         }">
                      {{ getEmployeeAssignment(employee.id, '8pm').job_function }}
                    </div>
                    <button v-else @click="addAssignmentToEmployee(employee.id, '8pm')" 
                            class="w-full h-full text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded transition text-xs border border-dashed border-gray-300">
                      +
                    </button>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- Job Function Assignment Modal -->
      <div v-if="showEmployeeModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-white rounded-lg p-6 max-w-2xl w-full mx-4 max-h-96 overflow-y-auto">
          <h3 class="text-xl font-bold mb-4">
            Assign Job Function to {{ selectedEmployee?.last_name }}, {{ selectedEmployee?.first_name }}
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
                       :style="{ backgroundColor: getJobFunctionColor([jobFunction]) }"></div>
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
                       :style="{ backgroundColor: getJobFunctionColor([assignment.job_function]) }"></div>
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
// Mock data for shifts
const scheduleData = ref([
  {
    id: '6am',
    name: '6:00 AM Shift',
    start_time: '6:00 AM',
    end_time: '2:30 PM',
    employee_count: 4
  },
  {
    id: '7am',
    name: '7:00 AM Shift',
    start_time: '7:00 AM',
    end_time: '3:30 PM',
    employee_count: 1
  },
  {
    id: '8am',
    name: '8:00 AM Shift',
    start_time: '8:00 AM',
    end_time: '4:30 PM',
    employee_count: 12
  },
  {
    id: '10am',
    name: '10:00 AM Shift',
    start_time: '10:00 AM',
    end_time: '6:30 PM',
    employee_count: 15
  },
  {
    id: '12pm',
    name: '12:00 PM Shift',
    start_time: '12:00 PM',
    end_time: '8:30 PM',
    employee_count: 10
  },
  {
    id: '4pm',
    name: '4:00 PM Shift',
    start_time: '4:00 PM',
    end_time: '8:30 PM',
    employee_count: 5
  }
])

// Mock employee data
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
  { id: '15', first_name: 'Steve', last_name: 'Thompson', trained_job_functions: ['Meter', 'Helpdesk'] },
  { id: '16', first_name: 'Michelle', last_name: 'Garcia', trained_job_functions: ['Locus', 'Coordinator'] },
  { id: '17', first_name: 'Ryan', last_name: 'Martinez', trained_job_functions: ['Team Lead', 'Helpdesk'] },
  { id: '18', first_name: 'Stephanie', last_name: 'Robinson', trained_job_functions: ['RT Pick', 'Pick', 'Meter'] },
  { id: '19', first_name: 'Brian', last_name: 'Clark', trained_job_functions: ['Pick', 'Locus'] },
  { id: '20', first_name: 'Jennifer', last_name: 'Rodriguez', trained_job_functions: ['Meter', 'Helpdesk'] },
  { id: '21', first_name: 'Jason', last_name: 'Lewis', trained_job_functions: ['Locus', 'Coordinator'] },
  { id: '22', first_name: 'Amanda', last_name: 'Lee', trained_job_functions: ['Team Lead', 'Helpdesk'] },
  { id: '23', first_name: 'Daniel', last_name: 'Walker', trained_job_functions: ['RT Pick', 'Pick'] },
  { id: '24', first_name: 'Laura', last_name: 'Hall', trained_job_functions: ['Pick', 'Meter'] },
  { id: '25', first_name: 'Robert', last_name: 'Allen', trained_job_functions: ['RT Pick', 'Locus'] },
  { id: '26', first_name: 'Heather', last_name: 'Young', trained_job_functions: ['Meter', 'Helpdesk'] },
  { id: '27', first_name: 'Michael', last_name: 'King', trained_job_functions: ['Locus', 'Coordinator'] },
  { id: '28', first_name: 'Melissa', last_name: 'Wright', trained_job_functions: ['Team Lead', 'Helpdesk'] },
  { id: '29', first_name: 'Andrew', last_name: 'Lopez', trained_job_functions: ['RT Pick', 'Pick', 'Meter'] },
  { id: '30', first_name: 'Kimberly', last_name: 'Hill', trained_job_functions: ['Pick', 'Locus'] }
])

// Schedule assignments - this would come from database
const scheduleAssignments = ref([
  // Sample assignments for 2-hour blocks
  { id: '1', employee_id: '1', shift_id: '6am', job_function: 'RT Pick' },
  { id: '2', employee_id: '2', shift_id: '6am', job_function: 'Pick' },
  { id: '3', employee_id: '3', shift_id: '8am', job_function: 'Meter' },
  { id: '4', employee_id: '4', shift_id: '8am', job_function: 'Locus' },
  { id: '5', employee_id: '5', shift_id: '10am', job_function: 'Helpdesk' },
  { id: '6', employee_id: '6', shift_id: '10am', job_function: 'Team Lead' },
  { id: '7', employee_id: '7', shift_id: '12pm', job_function: 'RT Pick' },
  { id: '8', employee_id: '8', shift_id: '12pm', job_function: 'Pick' },
  { id: '9', employee_id: '9', shift_id: '2pm', job_function: 'Meter' },
  { id: '10', employee_id: '10', shift_id: '2pm', job_function: 'Locus' },
  { id: '11', employee_id: '11', shift_id: '4pm', job_function: 'Helpdesk' },
  { id: '12', employee_id: '12', shift_id: '4pm', job_function: 'Coordinator' },
  { id: '13', employee_id: '13', shift_id: '6pm', job_function: 'RT Pick' },
  { id: '14', employee_id: '14', shift_id: '6pm', job_function: 'Pick' },
  { id: '15', employee_id: '15', shift_id: '8pm', job_function: 'Meter' }
])

// Modal state
const showEmployeeModal = ref(false)
const selectedEmployee = ref(null)
const selectedShift = ref(null)
const selectedJobFunction = ref('')

// Get route params
const route = useRoute()
const scheduleDate = ref(route.params.date || new Date().toISOString().split('T')[0])

// Computed properties
const totalEmployees = computed(() => {
  return scheduleAssignments.value.length
})

const totalLaborHours = computed(() => {
  // Calculate based on shift durations (simplified)
  const hoursPerShift = {
    '6am': 8.5,
    '7am': 8.5,
    '8am': 8.5,
    '10am': 8.5,
    '12pm': 8.5,
    '4pm': 4.5
  }
  
  return scheduleAssignments.value.reduce((total, assignment) => {
    return total + (hoursPerShift[assignment.shift_id] || 0)
  }, 0)
})

const totalShifts = computed(() => {
  return scheduleData.value.length
})

const unassignedEmployees = computed(() => {
  const assignedEmployeeIds = new Set(scheduleAssignments.value.map(a => a.employee_id))
  return employees.value.filter(e => !assignedEmployeeIds.has(e.id)).length
})

const jobFunctionHours = computed(() => {
  const jobFunctions = [
    { name: 'RT Pick', color: '#FFA500' },
    { name: 'Pick', color: '#FFFF00' },
    { name: 'Meter', color: '#87CEEB' },
    { name: 'Locus', color: '#FFFFFF' },
    { name: 'Helpdesk', color: '#FFD700' },
    { name: 'Coordinator', color: '#C0C0C0' },
    { name: 'Team Lead', color: '#000080' }
  ]
  
  const hoursPerShift = {
    '6am': 8.5,
    '7am': 8.5,
    '8am': 8.5,
    '10am': 8.5,
    '12pm': 8.5,
    '4pm': 4.5
  }
  
  return jobFunctions.map(job => {
    const assignments = scheduleAssignments.value.filter(a => a.job_function === job.name)
    const totalHours = assignments.reduce((total, assignment) => {
      return total + (hoursPerShift[assignment.shift_id] || 0)
    }, 0)
    
    return {
      ...job,
      hours: totalHours,
      employees: assignments.length
    }
  })
})

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

const getEmployeeAssignment = (employeeId, timeBlock) => {
  return scheduleAssignments.value.find(a => 
    a.employee_id === employeeId && a.shift_id === timeBlock
  )
}

const getEmployeeAssignments = (employeeId, shiftId) => {
  return scheduleAssignments.value.filter(a => 
    a.employee_id === employeeId && a.shift_id === shiftId
  )
}

const getEmployeesForShiftAndJob = (shiftId, jobFunction) => {
  const assignments = scheduleAssignments.value.filter(a => 
    a.shift_id === shiftId && a.job_function === jobFunction
  )
  return assignments.map(assignment => 
    employees.value.find(e => e.id === assignment.employee_id)
  ).filter(Boolean)
}

const getTotalEmployeesForShift = (shiftId) => {
  return scheduleAssignments.value.filter(a => a.shift_id === shiftId).length
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

const addAssignmentToEmployee = (employeeId, shiftId) => {
  selectedEmployee.value = employees.value.find(e => e.id === employeeId)
  selectedShift.value = scheduleData.value.find(s => s.id === shiftId)
  showEmployeeModal.value = true
}

const addEmployeeToShift = (shiftId, jobFunction) => {
  selectedShift.value = scheduleData.value.find(s => s.id === shiftId)
  selectedJobFunction.value = jobFunction
  showEmployeeModal.value = true
}

const availableJobFunctions = computed(() => {
  if (!selectedEmployee.value) return []
  
  // Get job functions the employee is trained for
  return selectedEmployee.value.trained_job_functions || []
})

const availableEmployees = computed(() => {
  if (!selectedShift.value || !selectedJobFunction.value) return []
  
  const assignedEmployeeIds = scheduleAssignments.value
    .filter(a => a.shift_id === selectedShift.value.id)
    .map(a => a.employee_id)
  
  return employees.value.filter(employee => 
    !assignedEmployeeIds.includes(employee.id) && 
    employee.trained_job_functions.includes(selectedJobFunction.value)
  )
})

const assignJobFunction = (jobFunction) => {
  scheduleAssignments.value.push({
    id: Date.now().toString(), // Simple ID generation
    employee_id: selectedEmployee.value.id,
    shift_id: selectedShift.value.id,
    job_function: jobFunction
  })
}

const removeAssignment = (assignmentId) => {
  const index = scheduleAssignments.value.findIndex(a => a.id === assignmentId)
  if (index > -1) {
    scheduleAssignments.value.splice(index, 1)
  }
}

const assignEmployee = (employeeId) => {
  scheduleAssignments.value.push({
    id: Date.now().toString(),
    employee_id: employeeId,
    shift_id: selectedShift.value.id,
    job_function: selectedJobFunction.value
  })
}

const removeEmployee = (employeeId) => {
  const index = scheduleAssignments.value.findIndex(a => 
    a.employee_id === employeeId && 
    a.shift_id === selectedShift.value.id &&
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

const saveSchedule = () => {
  // This would save to database
  console.log('Saving schedule:', scheduleAssignments.value)
  alert('Schedule saved successfully!')
}
</script>