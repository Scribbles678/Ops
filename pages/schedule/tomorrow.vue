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

    </div>
  </div>
</template>

<script setup lang="ts">
// Import composables
const { copySchedule, createAssignment, fetchShifts } = useSchedule()
const { logout } = useAuth()
const { jobFunctions, fetchJobFunctions } = useJobFunctions()
const { fetchEmployees, getAllEmployeeTraining } = useEmployees()

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
  const date = new Date(selectedDate.value || '')
  const day = date.getDay()
  return day === 0 || day === 6 // Sunday or Saturday
})

// AI Generation state
const generating = ref(false)

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
  const date = new Date(dateString)
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
      alert(`Today's schedule copied to ${formatDate(selectedDate.value || '')} successfully!`)
      // Navigate to the selected date's schedule page to see/edit the copied schedule
      navigateTo(`/schedule/${selectedDate.value || ''}`)
    } else {
      alert('Error copying schedule. Please try again.')
    }
  } catch (error) {
    console.error('Error copying schedule:', error)
    alert('Error copying schedule. Please try again.')
  }
}

const generateAISchedule = async () => {
  if (confirm('Generate AI schedule for ' + formatDate(selectedDate.value || '') + '? This will create assignments based on exact business rules.')) {
    try {
      generating.value = true
      
      // Generate AI schedule
      const schedule = await generateAIScheduleLogic()
      
      if (schedule.length > 0) {
        // Apply the schedule directly
        await applyAISchedule(schedule)
        
        // Show success message
        alert(`✅ AI schedule generated successfully!\n\nCreated ${schedule.length} assignments for ${formatDate(selectedDate.value || '')}.\n\nRedirecting to schedule view...`)
        
        // Navigate to the schedule page to see the results
        navigateTo(`/schedule/${selectedDate.value || ''}`)
      } else {
        alert('❌ No schedule could be generated.\n\nPlease check:\n• Employee training assignments\n• Shift configurations\n• Job function availability')
      }
    } catch (error) {
      console.error('Error generating AI schedule:', error)
      alert('❌ Error generating AI schedule.\n\nPlease try again or check the console for details.')
    } finally {
      generating.value = false
    }
  }
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

const generateAIScheduleLogic = async () => {
  try {
    // Load real data
    const [employeesData, jobFunctionsData, shiftsData] = await Promise.all([
      fetchEmployees(),
      fetchJobFunctions(),
      fetchShifts()
    ])
    
    const employees = employeesData || []
    const jobFunctions = jobFunctionsData || []
    const shifts = shiftsData || []
    
    console.log('Loaded data:', { 
      employees: employees.length, 
      jobFunctions: jobFunctions.length, 
      shifts: shifts.length 
    })
    
    // Get training data for all employees
    const employeeIds = employees.map(emp => emp.id)
    const trainingData = await getAllEmployeeTraining(employeeIds)
    
    console.log('Training data:', trainingData)
    
    // Build the schedule
    const schedule = await buildOptimalSchedule(employees, jobFunctions, shifts, trainingData)
    
    console.log('✅ Generated schedule:', schedule.length, 'assignments')
    console.log('📊 Schedule Summary:')
    console.log('  - X4 assignments:', schedule.filter(a => a.job_function === 'X4').length)
    console.log('  - EM9 assignments:', schedule.filter(a => a.job_function === 'EM9').length)
    console.log('  - Locus assignments:', schedule.filter(a => a.job_function === 'Locus').length)
    console.log('  - Flex assignments:', schedule.filter(a => a.job_function === 'Flex').length)
    
    return schedule
  } catch (error) {
    console.error('Error generating AI schedule:', error)
    return []
  }
}

// Core algorithm with 15-minute increments and 2-4 hour blocks
const buildOptimalSchedule = async (employees: any[], jobFunctions: any[], shifts: any[], trainingData: any) => {
  const assignments = []
  const employeeAssignments = new Map() // Track what each employee is doing
  const employeeHours = new Map() // Track hours per employee
  
  // Business rules with 15-minute precision - using actual job functions from database
  // Based on your shifts: 06:00-14:30, 07:00-15:30, 08:00-16:30, 10:00-18:30, 12:00-20:30, 16:00-20:30
  const businessRules = [
    { 
      jobFunction: 'X4', 
      timeSlots: [
        { start: '08:00', end: '14:30', minStaff: 2, blockSize: 390 }, // 6.5 hours
        { start: '10:00', end: '18:30', minStaff: 2, blockSize: 510 }, // 8.5 hours
        { start: '12:00', end: '20:30', minStaff: 2, blockSize: 510 }, // 8.5 hours
        { start: '16:00', end: '20:30', minStaff: 1, blockSize: 270 }  // 4.5 hours
      ] 
    },
    { 
      jobFunction: 'EM9', 
      timeSlots: [
        { start: '08:00', end: '14:30', minStaff: 1, blockSize: 390 }, // 6.5 hours
        { start: '10:00', end: '18:30', minStaff: 2, blockSize: 510 }, // 8.5 hours
        { start: '12:00', end: '20:30', minStaff: 2, blockSize: 510 }, // 8.5 hours
        { start: '16:00', end: '20:30', minStaff: 1, blockSize: 270 }  // 4.5 hours
      ] 
    },
    { 
      jobFunction: 'Locus', 
      timeSlots: [
        { start: '08:00', end: '14:30', minStaff: 2, blockSize: 390 }, // 6.5 hours
        { start: '10:00', end: '18:30', minStaff: 3, blockSize: 510 }, // 8.5 hours
        { start: '12:00', end: '20:30', minStaff: 3, blockSize: 510 }, // 8.5 hours
        { start: '16:00', end: '20:30', minStaff: 2, blockSize: 270 }, // 4.5 hours
        { start: '08:00', end: '20:30', maxStaff: 6 } // Global max
      ] 
    }
  ]
  
  // Process each business rule
  console.log('🔄 Building optimal schedule...')
  for (const rule of businessRules) {
    console.log(`📋 Processing ${rule.jobFunction} assignments...`)
    for (const timeSlot of rule.timeSlots) {
      const requiredStaff = timeSlot.minStaff
      const maxStaff = timeSlot.maxStaff || requiredStaff
      
      // Find available employees for this time slot
      const availableEmployees = findAvailableEmployees(
        employees, 
        shifts, 
        trainingData, 
        jobFunctions,
        rule.jobFunction, 
        timeSlot.start, 
        timeSlot.end
      )
      
      // Assign staff (respecting max limits)
      const staffToAssign = Math.min(requiredStaff || 0, availableEmployees.length, maxStaff || 0)
      
      console.log(`Assigning ${staffToAssign} staff for ${rule.jobFunction} at ${timeSlot.start}-${timeSlot.end}`)
      
      for (let i = 0; i < staffToAssign; i++) {
        const employee = availableEmployees[i]
        if (employee) {
          // Create 15-minute assignments for this block
          const blockAssignments = createBlockAssignments(
            employee, 
            rule.jobFunction, 
            timeSlot.start, 
            timeSlot.end, 
            timeSlot.blockSize || 0
          )
          
          assignments.push(...blockAssignments)
          
          // Track assignment for this employee
          if (!employeeAssignments.has(employee.id)) {
            employeeAssignments.set(employee.id, [])
          }
          employeeAssignments.get(employee.id).push(rule.jobFunction)
          
          // Track hours
          const hours = (timeSlot.blockSize || 0) / 60
          employeeHours.set(employee.id, (employeeHours.get(employee.id) || 0) + hours)
        }
      }
      
      // If we couldn't meet the minimum requirement, try to find any available employee
      if (staffToAssign < (requiredStaff || 0)) {
        console.log(`Warning: Only found ${staffToAssign} employees for ${rule.jobFunction}, need ${requiredStaff}`)
        
        // Try to find employees trained in any function and assign them
        const anyTrainedEmployees = employees.filter((emp: any) => {
          const shift = shifts.find((s: any) => s.id === emp.shift_id)
          if (!shift) return false
          
          const shiftStart = shift.start_time
          const shiftEnd = shift.end_time
          return timeSlot.start >= shiftStart && timeSlot.end <= shiftEnd
        })
        
        for (let i = staffToAssign; i < (requiredStaff || 0) && i < anyTrainedEmployees.length; i++) {
          const employee = anyTrainedEmployees[i]
          const blockAssignments = createBlockAssignments(
            employee, 
            rule.jobFunction, 
            timeSlot.start, 
            timeSlot.end, 
            timeSlot.blockSize || 0
          )
          
          assignments.push(...blockAssignments)
          
          if (!employeeAssignments.has(employee.id)) {
            employeeAssignments.set(employee.id, [])
          }
          employeeAssignments.get(employee.id).push(rule.jobFunction)
        }
      }
    }
  }
  
  // Add break coverage for Locus and X4
  await addBreakCoverage(employees, shifts, trainingData, jobFunctions, assignments, employeeAssignments)
  
  // Ensure employees get at least 2 different functions
  await ensureDiverseAssignments(employees, shifts, trainingData, jobFunctions, assignments, employeeAssignments)
  
  // Fill remaining hours with "Flex" assignments
  await fillRemainingHours(employees, shifts, trainingData, assignments, employeeAssignments, employeeHours)
  
  // If no assignments were created, create a basic fallback schedule
  if (assignments.length === 0) {
    console.log('No assignments created, creating fallback schedule')
    return await createFallbackSchedule(employees, jobFunctions, shifts, trainingData)
  }
  
  return assignments
}

// Helper function to find available employees
const findAvailableEmployees = (employees: any[], shifts: any[], trainingData: any, jobFunctions: any[], jobFunction: string, startTime: string, endTime: string) => {
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
    
    return timeCovered
  })
  
  console.log(`Found ${available.length} available employees for ${jobFunction} at ${startTime}-${endTime}`)
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
      lunchTime.end
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