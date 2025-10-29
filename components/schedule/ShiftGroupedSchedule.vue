<template>
  <div class="shift-grouped-schedule">
    <!-- Each Shift Group -->
    <div
      v-for="shift in shiftsWithEmployees"
      :key="shift.id"
      class="shift-group mb-8 w-full"
    >
      <!-- Shift Header -->
      <div class="shift-header">
        <h2 class="text-2xl font-bold text-gray-800 mb-4 pb-3 border-b border-gray-300">
          {{ shift.name }}
        </h2>
      </div>

      <!-- Time Block Headers -->
      <div class="time-blocks-header">
        <div class="employee-name-header">Staff</div>
        <div 
          v-for="timeBlock in getShiftTimeBlocks(shift)" 
          :key="timeBlock.time"
          class="time-block"
          :class="{ 'hourly-marker': isHourlyMarker(timeBlock.time) }"
        >
          <div class="time-header" :class="{ 'hourly-header': isHourlyMarker(timeBlock.time) }">
            {{ timeBlock.display }}
          </div>
        </div>
      </div>

      <!-- Break Overlay Row (aligns once per shift) -->
      <div class="relative mb-2 min-w-max">
        <div 
          class="grid w-full"
          :style="{ gridTemplateColumns: getGridTemplateColumns(shift) }"
        >
          <div
            v-for="timeBlock in getShiftTimeBlocks(shift)"
            :key="`break-${shift.id}-${timeBlock.time}`"
            class="min-h-[14px] border-r border-gray-200"
            :class="{
              'bg-gray-100': !timeBlock.isBreakTime,
              'bg-black text-white': timeBlock.isBreakTime
            }"
          >
            <span v-if="timeBlock.isBreakTime" class="sr-only">{{ getBreakType(timeBlock.time, shift) }}</span>
          </div>
        </div>
      </div>

      <!-- Employee Rows for this Shift -->
      <div class="shift-employees">
        <div 
          v-for="employee in shift.employees" 
          :key="employee.id" 
          class="employee-row odd:bg-white even:bg-gray-50/40"
        >
          <!-- Employee name -->
          <div class="employee-name">
            {{ employee.last_name }}, {{ employee.first_name }}
          </div>

          <!-- Grid row background cells for alignment and interaction -->
          <div class="relative w-full">
            <div
              class="grid"
              :style="{ gridTemplateColumns: getGridTemplateColumns(shift) }"
            >
              <div 
                v-for="timeBlock in getShiftTimeBlocks(shift)" 
                :key="`cell-${employee.id}-${shift.id}-${timeBlock.time}`"
                class="time-block-content"
                :class="{ 'hourly-marker-content': isHourlyMarker(timeBlock.time) }"
              >
                <div class="assignment-cell-full">
                  <div 
                    v-if="!isBreakTime(timeBlock.time, shift)"
                    @click="openAssignmentModal(employee, timeBlock, shift)"
                    class="assignment-clickable-full bg-white hover:bg-blue-50"
                  >
                    <!-- Empty background cell; assignments are rendered as overlay spans -->
                  </div>
                  <div 
                    v-else
                    class="break-cell-full"
                    :style="{ backgroundColor: '#000000' }"
                  >
                    {{ getBreakType(timeBlock.time, shift) }}
                  </div>
                </div>
              </div>
            </div>

            <!-- Assignment overlay spans (single element per contiguous range) -->
            <div 
              class="pointer-events-none absolute inset-0 grid"
              :style="{ gridTemplateColumns: getGridTemplateColumns(shift) }"
            >
              <div
                v-for="range in getEmployeeAssignmentRanges(employee.id, shift)"
                :key="`range-${employee.id}-${shift.id}-${range.start}-${range.end}-${range.label}`"
                class="rounded-lg border border-gray-300 flex items-center justify-start px-2 text-xs font-medium shadow-sm overflow-hidden"
                :style="{
                  gridColumn: `${range.start} / ${range.end}`,
                  backgroundColor: getJobFunctionColor(range.label),
                  color: '#000'
                }"
              >
                <span class="truncate">{{ range.label }}</span>
              </div>
            </div>
          </div>
        </div>
        
        <!-- Show break times even if no employees are assigned to this shift -->
        <div v-if="shift.employees.length === 0" class="no-employees-message min-w-max">
          <div class="employee-name text-gray-500 italic">
            No employees assigned to this shift
          </div>
          <div 
            v-for="timeBlock in getShiftTimeBlocks(shift)" 
            :key="timeBlock.time"
            class="time-block-content"
            :class="{ 'hourly-marker-content': isHourlyMarker(timeBlock.time) }"
          >
            <div class="assignment-cell-full">
              <div 
                v-if="isBreakTime(timeBlock.time, shift)"
                class="break-cell-full"
                style="background-color: #000000"
              >
                {{ getBreakType(timeBlock.time, shift) }}
              </div>
              <div 
                v-else
                class="empty-cell-full"
                style="background-color: #ffffff"
              >
                <!-- Empty cell for non-break times -->
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Assignment Modal -->
    <div v-if="showAssignmentModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4">
        <h3 class="text-xl font-bold mb-4">
          Assign Task to {{ selectedEmployee?.last_name }}, {{ selectedEmployee?.first_name }}
        </h3>
        <p class="text-gray-600 mb-4">
          Time: {{ selectedTimeBlock?.display }} ({{ selectedTimeBlock?.time }})
        </p>
        
        <!-- Job Function Selection -->
        <div class="space-y-3 mb-6">
          <label class="block text-sm font-medium text-gray-700">Select Job Function:</label>
          <div class="grid grid-cols-2 gap-2">
            <button
              v-for="jobFunction in availableJobFunctions"
              :key="jobFunction.id"
              @click="selectJobFunction(jobFunction)"
              class="p-3 border border-gray-300 rounded-lg hover:bg-gray-50 transition text-left"
              :class="{ 'bg-blue-100 border-blue-500': selectedJobFunction?.id === jobFunction.id }"
            >
              <div class="flex items-center space-x-2">
                <div 
                  class="w-4 h-4 rounded border border-gray-300" 
                  :style="{ backgroundColor: jobFunction.color_code }"
                ></div>
                <span class="text-sm font-medium">{{ jobFunction.name }}</span>
              </div>
            </button>
          </div>
        </div>

        <!-- Meter Number Selection (only show when Meter is selected) -->
        <div v-if="selectedJobFunction?.id === 'meter-group' || selectedJobFunction?.name === 'Meter'" class="space-y-3 mb-6">
          <label class="block text-sm font-medium text-gray-700">Select Meter Number:</label>
          <div v-if="allIndividualMeters.length > 0" class="grid grid-cols-4 gap-2">
            <button
              v-for="meter in allIndividualMeters"
              :key="meter.id"
              @click="selectMeterNumber(meter)"
              class="p-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition text-center"
              :class="{ 'bg-blue-100 border-blue-500': selectedMeterNumber === meter.id }"
            >
              <span class="text-sm font-medium">{{ meter.name }}</span>
            </button>
          </div>
          <div v-else class="text-center py-4 text-gray-500">
            <p class="text-sm">No individual meter entries found in database.</p>
            <p class="text-xs mt-1">Please run the database migration to create Meter 1-20 entries.</p>
            <div class="mt-3 grid grid-cols-4 gap-2">
              <button
                v-for="meter in placeholderMeters"
                :key="meter.id"
                @click="selectMeterNumber(meter)"
                class="p-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition text-center"
                :class="{ 'bg-blue-100 border-blue-500': selectedMeterNumber === meter.id }"
              >
                <span class="text-sm font-medium">{{ meter.name }}</span>
              </button>
            </div>
          </div>
        </div>
        

        <!-- Time Range Selection -->
        <div class="space-y-3 mb-6">
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Start Time:</label>
              <input 
                v-model="assignmentStartTime" 
                type="time" 
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">End Time:</label>
              <input 
                v-model="assignmentEndTime" 
                type="time" 
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
          </div>
        </div>

        <!-- Action Buttons -->
        <div class="flex justify-end space-x-3">
          <button
            @click="closeAssignmentModal"
            class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50"
          >
            Cancel
          </button>
          <button
            v-if="getAssignment(selectedEmployee?.id, selectedTimeBlock?.time)"
            @click="removeAssignment"
            class="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700"
          >
            Remove Assignment
          </button>
          <button
            v-if="selectedJobFunction && assignmentStartTime && assignmentEndTime && (selectedJobFunction.id !== 'meter-group' || selectedMeterNumber || selectedJobFunction.name === 'Meter')"
            @click="saveAssignment"
            class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
          >
            {{ getAssignment(selectedEmployee?.id, selectedTimeBlock?.time) ? 'Update Assignment' : 'Assign Task' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'

const { getEmployeeTraining } = useEmployees()
const { getGroupedJobFunctions, isMeterJobFunction } = useJobFunctions()

// Optimize meter job functions with computed property to avoid repeated filtering
const allIndividualMeters = computed(() => {
  return props.jobFunctions.filter(jf => jf.name && jf.name.startsWith('Meter '))
})

// Create placeholder meters for when database doesn't have individual meters
const placeholderMeters = computed(() => {
  return Array.from({ length: 20 }, (_, i) => ({
    id: `meter-${i + 1}`,
    name: `Meter ${i + 1}`,
    color_code: '#87CEEB'
  }))
})

// Props
const props = defineProps<{
  employees: any[]
  scheduleAssignments: any[]
  jobFunctions: any[]
  shifts: any[]
  scheduleAssignmentsData?: Record<string, any>
}>()

// Emits
const emit = defineEmits<{
  addAssignment: [employeeId: string, timeSlot: string]
  editAssignment: [employeeId: string, timeSlot: string]
  assignBreakCoverage: [employeeId: string, timeSlot: string]
  scheduleDataUpdated: [scheduleData: Record<string, any>]
}>()

// Use the passed scheduleAssignmentsData directly instead of local state
const scheduleData = computed(() => {
  console.log('Using scheduleAssignmentsData:', props.scheduleAssignmentsData)
  return props.scheduleAssignmentsData || {}
})

// Assignment modal state
const showAssignmentModal = ref(false)
const selectedEmployee = ref<any>(null)
const selectedTimeBlock = ref<any>(null)
const selectedShift = ref<any>(null)
const selectedJobFunction = ref<any>(null)
const assignmentStartTime = ref('')
const assignmentEndTime = ref('')
const selectedMeterNumber = ref('')

// Group employees by their assigned shifts
const shiftsWithEmployees = computed(() => {
  return props.shifts.map(shift => {
    const employeesForShift = props.employees.filter(employee => employee.shift_id === shift.id)
    
    return {
      ...shift,
      employees: employeesForShift
    }
  })
})

// Available job functions for the selected employee - optimized for performance
const availableJobFunctions = computed(() => {
  if (!selectedEmployee.value) return []
  
  // Simple approach: just filter out individual meters and add a grouped meter entry
  const nonMeterFunctions = props.jobFunctions.filter(jf => 
    jf.is_active && !jf.name.startsWith('Meter ') && jf.name !== 'Meter'
  )
  
  // Add grouped meter entry
  const meterEntry = {
    id: 'meter-group',
    name: 'Meter',
    color_code: '#87CEEB',
    productivity_rate: 150,
    unit_of_measure: 'boxes/hour',
    is_active: true,
    sort_order: 3,
    isGroup: true
  }
  
  return [...nonMeterFunctions, meterEntry].sort((a, b) => a.sort_order - b.sort_order)
})

// Initialize schedule data for each employee
const initializeScheduleData = () => {
  props.employees.forEach(employee => {
    if (!scheduleData.value[employee.id]) {
      scheduleData.value[employee.id] = {
        '06:00': { assignment: '', until: '', break1: { assignment: '', until: '' }, assignment2: '', until2: '' },
        '08:00': { assignment: '', until: '', break1: { assignment: '', until: '' }, assignment2: '', until2: '' },
        '10:00': { assignment: '', until: '', break1: { assignment: '', until: '' }, assignment2: '', until2: '' },
        '12:00': { assignment: '', until: '', break2: { assignment: '', until: '' }, assignment2: '', until2: '' },
        '16:30': { assignment: '', until: '', break2: { assignment: '', until: '' }, assignment2: '', until2: '' }
      }
    }
  })
}

// Get assignment for employee at specific time
const getAssignment = (employeeId: string, timeSlot: string, segment: number = 1) => {
  const employeeData = scheduleData.value[employeeId]
  if (!employeeData) {
    console.log(`No employee data for ${employeeId}`)
    return ''
  }
  
  if (!employeeData[timeSlot]) {
    console.log(`No assignment for ${employeeId} at ${timeSlot}. Available slots:`, Object.keys(employeeData))
    return ''
  }
  
  const assignment = segment === 1 ? 
    (employeeData[timeSlot].assignment || '') : 
    (employeeData[timeSlot].assignment2 || '')
  
  if (assignment) {
    console.log(`Found assignment for ${employeeId} at ${timeSlot}:`, assignment)
  }
  
  return assignment
}

// Get until time for employee at specific time
const getUntil = (employeeId: string, timeSlot: string, segment: number = 1) => {
  const employeeData = scheduleData.value[employeeId]
  if (!employeeData || !employeeData[timeSlot]) return ''
  
  if (segment === 1) {
    return employeeData[timeSlot].until || ''
  } else {
    return employeeData[timeSlot].until2 || ''
  }
}

// Get break assignment
const getBreakAssignment = (employeeId: string, timeSlot: string, breakNumber: number) => {
  const employeeData = scheduleData.value[employeeId]
  if (!employeeData || !employeeData[timeSlot]) return ''
  
  const breakKey = `break${breakNumber}`
  return employeeData[timeSlot][breakKey]?.assignment || ''
}

// Get break until time
const getBreakUntil = (employeeId: string, timeSlot: string, breakNumber: number) => {
  const employeeData = scheduleData.value[employeeId]
  if (!employeeData || !employeeData[timeSlot]) return ''
  
  const breakKey = `break${breakNumber}`
  return employeeData[timeSlot][breakKey]?.until || ''
}

// Update assignment
const updateAssignment = (employeeId: string, timeSlot: string, value: string, segment: number = 1) => {
  if (!scheduleData.value[employeeId]) {
    scheduleData.value[employeeId] = {}
  }
  if (!scheduleData.value[employeeId][timeSlot]) {
    scheduleData.value[employeeId][timeSlot] = {}
  }
  
  if (segment === 1) {
    scheduleData.value[employeeId][timeSlot].assignment = value
  } else {
    scheduleData.value[employeeId][timeSlot].assignment2 = value
  }
}

// Update until time
const updateUntil = (employeeId: string, timeSlot: string, value: string, segment: number = 1) => {
  if (!scheduleData.value[employeeId]) {
    scheduleData.value[employeeId] = {}
  }
  if (!scheduleData.value[employeeId][timeSlot]) {
    scheduleData.value[employeeId][timeSlot] = {}
  }
  
  if (segment === 1) {
    scheduleData.value[employeeId][timeSlot].until = value
  } else {
    scheduleData.value[employeeId][timeSlot].until2 = value
  }
}

// Update break assignment
const updateBreakAssignment = (employeeId: string, timeSlot: string, breakNumber: number, value: string) => {
  if (!scheduleData.value[employeeId]) {
    scheduleData.value[employeeId] = {}
  }
  if (!scheduleData.value[employeeId][timeSlot]) {
    scheduleData.value[employeeId][timeSlot] = {}
  }
  
  const breakKey = `break${breakNumber}`
  if (!scheduleData.value[employeeId][timeSlot][breakKey]) {
    scheduleData.value[employeeId][timeSlot][breakKey] = {}
  }
  
  scheduleData.value[employeeId][timeSlot][breakKey].assignment = value
}

// Update break until time
const updateBreakUntil = (employeeId: string, timeSlot: string, breakNumber: number, value: string) => {
  if (!scheduleData.value[employeeId]) {
    scheduleData.value[employeeId] = {}
  }
  if (!scheduleData.value[employeeId][timeSlot]) {
    scheduleData.value[employeeId][timeSlot] = {}
  }
  
  const breakKey = `break${breakNumber}`
  if (!scheduleData.value[employeeId][timeSlot][breakKey]) {
    scheduleData.value[employeeId][timeSlot][breakKey] = {}
  }
  
  scheduleData.value[employeeId][timeSlot][breakKey].until = value
}

// Get job function color
const getJobFunctionColor = (jobFunctionName: string) => {
  if (!jobFunctionName) return '#ffffff'
  
  const jobFunction = props.jobFunctions.find(jf => jf.name === jobFunctionName)
  return jobFunction?.color_code || '#ffffff'
}

// Grid helpers
const getGridTemplateColumns = (shift: any) => {
  const cols = getShiftTimeBlocks(shift).length
  // Fixed column width for crisp alignment and predictable wrapping
  return `repeat(${cols}, 60px)`
}

const timeToColumnIndex = (time: string, shift: any) => {
  const blocks = getShiftTimeBlocks(shift)
  const index = blocks.findIndex(b => b.time === time)
  return index >= 0 ? index + 1 : 1 // CSS grid columns are 1-based
}

// Build contiguous assignment ranges to render a single span per block
const getEmployeeAssignmentRanges = (employeeId: string, shift: any) => {
  const blocks = getShiftTimeBlocks(shift)
  const ranges: Array<{ start: number; end: number; label: string }> = []

  let currentLabel = ''
  let currentStart = -1

  for (let i = 0; i < blocks.length; i++) {
    const b = blocks[i]
    const label = getAssignment(employeeId, b.time) || ''

    if (!b.isBreakTime && label) {
      if (currentLabel === '') {
        currentLabel = label
        currentStart = i + 1 // 1-based start
      } else if (label !== currentLabel) {
        // close previous and start new
        ranges.push({ start: currentStart, end: i + 1, label: currentLabel })
        currentLabel = label
        currentStart = i + 1
      }
    } else {
      if (currentLabel !== '') {
        ranges.push({ start: currentStart, end: i + 1, label: currentLabel })
        currentLabel = ''
        currentStart = -1
      }
    }
  }

  if (currentLabel !== '') {
    ranges.push({ start: currentStart, end: blocks.length + 1, label: currentLabel })
  }

  return ranges
}

// Generate time blocks for a specific shift
const getShiftTimeBlocks = (shift: any) => {
  const startTime = shift.start_time || '06:00'
  const endTime = shift.end_time || '14:30'
  
  // console.log(`\n=== Generating time blocks for shift: ${shift.name} ===`)
  // console.log(`Start time: ${startTime}, End time: ${endTime}`)
  // console.log(`Break times: Break1(${shift.break_1_start}-${shift.break_1_end}), Break2(${shift.break_2_start}-${shift.break_2_end}), Lunch(${shift.lunch_start}-${shift.lunch_end})`)
  
  // Convert start time to minutes
  const startMinutes = timeToMinutes(startTime)
  const endMinutes = timeToMinutes(endTime)
  
  const timeBlocks = []
  let currentMinutes = startMinutes
  
  // Generate time blocks every 15 minutes from start to end
  while (currentMinutes < endMinutes) {
    const timeString = minutesToTime(currentMinutes)
    const displayTime = formatTimeForDisplay(timeString)
    
    // Check if this time slot should be a break
    const isBreak = isBreakTime(timeString, shift)
    
    timeBlocks.push({
      time: timeString,
      display: displayTime,
      isBreakTime: isBreak
    })
    
    currentMinutes += 15 // Add 15 minutes for more granular scheduling
  }
  
  // console.log(`Generated ${timeBlocks.length} time blocks`)
  return timeBlocks
}

// Convert time to minutes
const timeToMinutes = (time: string): number => {
  const [hours, minutes] = time.split(':').map(Number)
  return hours * 60 + minutes
}

// Convert minutes to time string
const minutesToTime = (minutes: number): string => {
  const hours = Math.floor(minutes / 60)
  const mins = minutes % 60
  return `${hours.toString().padStart(2, '0')}:${mins.toString().padStart(2, '0')}`
}

// Format time for display - only show hourly labels with enhanced visual distinction
const formatTimeForDisplay = (time: string): string => {
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

// Check if a time block is an hourly marker for enhanced styling
const isHourlyMarker = (time: string): boolean => {
  const [hours, minutes] = time.split(':').map(Number)
  return minutes === 0
}

// Check if a time slot should be blocked out as break time
const isBreakTime = (timeSlot: string, shift: any) => {
  // Convert time slot to minutes for comparison
  const timeMinutes = timeToMinutes(timeSlot)
  
  // Helper function to safely convert database time strings to minutes
  const convertTimeToMinutes = (timeStr: string | null | undefined): number | null => {
    if (!timeStr) return null
    
    // Handle different time formats from database
    let cleanTime = timeStr.toString().trim()
    
    // Remove seconds if present (HH:MM:SS -> HH:MM)
    if (cleanTime.includes(':')) {
      const parts = cleanTime.split(':')
      if (parts.length === 3) {
        cleanTime = `${parts[0]}:${parts[1]}`
      }
    }
    
    return timeToMinutes(cleanTime)
  }
  
  // Get break times from shift data
  const break1Start = convertTimeToMinutes(shift.break_1_start)
  const break1End = convertTimeToMinutes(shift.break_1_end)
  const break2Start = convertTimeToMinutes(shift.break_2_start)
  const break2End = convertTimeToMinutes(shift.break_2_end)
  const lunchStart = convertTimeToMinutes(shift.lunch_start)
  const lunchEnd = convertTimeToMinutes(shift.lunch_end)
  
  // Check Break 1
  if (break1Start !== null && break1End !== null) {
    if (timeMinutes >= break1Start && timeMinutes < break1End) {
      return true
    }
  }
  
  // Check Break 2
  if (break2Start !== null && break2End !== null) {
    if (timeMinutes >= break2Start && timeMinutes < break2End) {
      return true
    }
  }
  
  // Check Lunch
  if (lunchStart !== null && lunchEnd !== null) {
    if (timeMinutes >= lunchStart && timeMinutes < lunchEnd) {
      return true
    }
  }
  
  return false
}

// Get the type of break for a time slot
const getBreakType = (timeSlot: string, shift: any) => {
  const timeMinutes = timeToMinutes(timeSlot)
  
  // Helper function to convert time string to minutes (handles both HH:MM and HH:MM:SS formats)
  const convertTimeToMinutes = (timeStr: string | null | undefined): number | null => {
    if (!timeStr) return null
    // Remove seconds if present (HH:MM:SS -> HH:MM)
    const cleanTime = timeStr.toString().trim()
    if (cleanTime.includes(':')) {
      const parts = cleanTime.split(':')
      if (parts.length === 3) {
        return timeToMinutes(`${parts[0]}:${parts[1]}`)
      }
    }
    return timeToMinutes(cleanTime)
  }
  
  // Check if time slot falls within any configured break periods
  const break1Start = convertTimeToMinutes(shift.break_1_start)
  const break1End = convertTimeToMinutes(shift.break_1_end)
  const break2Start = convertTimeToMinutes(shift.break_2_start)
  const break2End = convertTimeToMinutes(shift.break_2_end)
  const lunchStart = convertTimeToMinutes(shift.lunch_start)
  const lunchEnd = convertTimeToMinutes(shift.lunch_end)
  
  // Check if time slot is within break 1 period
  if (break1Start !== null && break1End !== null && timeMinutes >= break1Start && timeMinutes < break1End) {
    return 'BREAK 1'
  }
  
  // Check if time slot is within break 2 period
  if (break2Start !== null && break2End !== null && timeMinutes >= break2Start && timeMinutes < break2End) {
    return 'BREAK 2'
  }
  
  // Check if time slot is within lunch period
  if (lunchStart !== null && lunchEnd !== null && timeMinutes >= lunchStart && timeMinutes < lunchEnd) {
    return 'LUNCH'
  }
  
  return 'BREAK'
}


// Modal functions
const openAssignmentModal = (employee: any, timeBlock: any, shift: any) => {
  selectedEmployee.value = employee
  selectedTimeBlock.value = timeBlock
  selectedShift.value = shift
  selectedJobFunction.value = null
  
  // Set default times based on the clicked time block
  assignmentStartTime.value = timeBlock.time
  assignmentEndTime.value = minutesToTime(timeToMinutes(timeBlock.time) + 60) // Default to 1 hour
  
  // If there's an existing assignment, populate the form
  const existingAssignment = getAssignment(employee.id, timeBlock.time)
  if (existingAssignment) {
    // Find the job function by name
    const jobFunction = props.jobFunctions.find(jf => jf.name === existingAssignment)
    if (jobFunction) {
      selectedJobFunction.value = jobFunction
    }
    
    // Get the existing end time
    const existingUntil = getUntil(employee.id, timeBlock.time)
    if (existingUntil) {
      assignmentEndTime.value = existingUntil
    }
  }
  
  showAssignmentModal.value = true
}

const closeAssignmentModal = () => {
  showAssignmentModal.value = false
  selectedEmployee.value = null
  selectedTimeBlock.value = null
  selectedShift.value = null
  selectedJobFunction.value = null
  assignmentStartTime.value = ''
  assignmentEndTime.value = ''
  selectedMeterNumber.value = ''
}

const selectJobFunction = (jobFunction: any) => {
  selectedJobFunction.value = jobFunction
  // Clear meter number when selecting a non-meter job function
  if (jobFunction.id !== 'meter-group') {
    selectedMeterNumber.value = ''
  }
}

const selectMeterNumber = (meter: any) => {
  selectedMeterNumber.value = meter.id
}

const saveAssignment = () => {
  if (!selectedEmployee.value || !selectedTimeBlock.value || !selectedJobFunction.value || !assignmentStartTime.value || !assignmentEndTime.value) return
  
  // For meter assignments, require meter number selection
  if ((selectedJobFunction.value.id === 'meter-group' || selectedJobFunction.value.name === 'Meter') && !selectedMeterNumber.value) {
    alert('Please select a meter number')
    return
  }
  
  // Snap to 15-minute increments to ensure perfect alignment
  const roundToQuarter = (mins: number) => Math.round(mins / 15) * 15
  const startMinutes = roundToQuarter(timeToMinutes(assignmentStartTime.value))
  const endMinutes = roundToQuarter(timeToMinutes(assignmentEndTime.value))
  
  // Clear any existing assignments for this employee in this time range
  clearAssignmentsInRange(selectedEmployee.value.id, startMinutes, endMinutes)
  
  // Determine the job function name to use
  let jobFunctionName = selectedJobFunction.value.name
  if (selectedJobFunction.value.id === 'meter-group' || selectedJobFunction.value.name === 'Meter') {
    // Find the specific meter job function
    const meterJobFunction = props.jobFunctions.find(m => m.id === selectedMeterNumber.value)
    if (meterJobFunction) {
      jobFunctionName = meterJobFunction.name
    } else if (selectedMeterNumber.value && selectedMeterNumber.value.startsWith('meter-')) {
      // Handle placeholder meter IDs (meter-1, meter-2, etc.)
      const meterNumber = selectedMeterNumber.value.replace('meter-', '')
      jobFunctionName = `Meter ${meterNumber}`
    } else {
      jobFunctionName = 'Meter'
    }
  }
  
  // Create assignments for each 15-minute block in the time range
  let currentMinutes = startMinutes
  while (currentMinutes < endMinutes) {
    const timeSlot = minutesToTime(currentMinutes)
    updateAssignment(selectedEmployee.value.id, timeSlot, jobFunctionName)
    updateUntil(selectedEmployee.value.id, timeSlot, assignmentEndTime.value)
    currentMinutes += 15
  }
  
  // Emit event to parent component
  emit('addAssignment', selectedEmployee.value.id, selectedTimeBlock.value.time)
  
  closeAssignmentModal()
}

const removeAssignment = () => {
  if (!selectedEmployee.value || !selectedTimeBlock.value) return
  
  // Get the current assignment to determine the time range
  const currentAssignment = getAssignment(selectedEmployee.value.id, selectedTimeBlock.value.time)
  const currentUntil = getUntil(selectedEmployee.value.id, selectedTimeBlock.value.time)
  
  if (currentAssignment && currentUntil) {
    // Clear all assignments in the time range
    const startMinutes = timeToMinutes(selectedTimeBlock.value.time)
    const endMinutes = timeToMinutes(currentUntil)
    clearAssignmentsInRange(selectedEmployee.value.id, startMinutes, endMinutes)
  } else {
    // Just clear the single time slot
    updateAssignment(selectedEmployee.value.id, selectedTimeBlock.value.time, '')
    updateUntil(selectedEmployee.value.id, selectedTimeBlock.value.time, '')
  }
  
  closeAssignmentModal()
}

// Helper function to clear assignments in a time range
const clearAssignmentsInRange = (employeeId: string, startMinutes: number, endMinutes: number) => {
  let currentMinutes = startMinutes
  while (currentMinutes < endMinutes) {
    const timeSlot = minutesToTime(currentMinutes)
    updateAssignment(employeeId, timeSlot, '')
    updateUntil(employeeId, timeSlot, '')
    currentMinutes += 15
  }
}

// Helper functions to determine assignment position for visual merging
const isAssignmentStart = (employeeId: string, timeSlot: string): boolean => {
  const assignment = getAssignment(employeeId, timeSlot)
  if (!assignment) return false
  
  const currentMinutes = timeToMinutes(timeSlot)
  const prevMinutes = currentMinutes - 15
  const prevTimeSlot = minutesToTime(prevMinutes)
  const prevAssignment = getAssignment(employeeId, prevTimeSlot)
  
  return assignment !== prevAssignment
}

const isAssignmentEnd = (employeeId: string, timeSlot: string): boolean => {
  const assignment = getAssignment(employeeId, timeSlot)
  if (!assignment) return false
  
  const currentMinutes = timeToMinutes(timeSlot)
  const nextMinutes = currentMinutes + 15
  const nextTimeSlot = minutesToTime(nextMinutes)
  const nextAssignment = getAssignment(employeeId, nextTimeSlot)
  
  return assignment !== nextAssignment
}

const isAssignmentMiddle = (employeeId: string, timeSlot: string): boolean => {
  const assignment = getAssignment(employeeId, timeSlot)
  if (!assignment) return false
  
  return !isAssignmentStart(employeeId, timeSlot) && !isAssignmentEnd(employeeId, timeSlot)
}

const isAssignmentSingle = (employeeId: string, timeSlot: string): boolean => {
  const assignment = getAssignment(employeeId, timeSlot)
  if (!assignment) return false
  
  return isAssignmentStart(employeeId, timeSlot) && isAssignmentEnd(employeeId, timeSlot)
}

// Initialize on mount
initializeScheduleData()
</script>

<style scoped>
.shift-grouped-schedule {
  @apply w-full;
}

.shift-group {
  @apply bg-white rounded-lg border border-gray-200 p-6 w-full;
}

.shift-header {
  @apply mb-6;
}

.time-blocks-header {
  @apply flex bg-gray-100 border-b-2 border-gray-300 sticky top-0 z-10 min-w-max;
}

.employee-name-header {
  @apply w-48 px-4 py-3 font-semibold text-gray-700 border-r border-gray-300 flex-shrink-0;
}

.time-block {
  @apply border-r border-gray-300 min-w-[60px];
}

.time-header {
  @apply bg-gray-200 px-0 py-1 text-sm font-semibold text-center border-b border-gray-300;
}

/* Enhanced styling for hourly markers */
.hourly-marker {
  @apply border-l-4 border-blue-500 bg-blue-50;
}

.hourly-header {
  @apply bg-blue-100 text-blue-800 font-bold text-base border-b-2 border-blue-400;
}

.shift-employees {
  @apply divide-y divide-gray-200 min-w-max;
}

.employee-row {
  @apply flex hover:bg-gray-50 min-w-max;
}

.employee-name {
  @apply w-48 px-4 py-3 font-medium text-gray-900 border-r border-gray-300 flex-shrink-0;
}

.time-block-content {
  @apply border-r border-gray-300 min-w-[60px];
}

.hourly-marker-content {
  @apply border-l-4 border-blue-500 bg-blue-50;
}

.assignment-cell-full {
  @apply w-full h-full;
}

.assignment-input,
.until-input {
  @apply w-full px-2 py-1 text-sm border-0 bg-transparent focus:bg-white focus:ring-1 focus:ring-blue-500 focus:outline-none;
}

.assignment-clickable {
  @apply w-full px-2 py-1 text-sm border border-gray-300 cursor-pointer hover:bg-opacity-80 transition-all min-h-[32px] flex items-center justify-center;
}

.assignment-clickable-full {
  @apply w-full h-full px-0 py-1 text-sm border border-gray-300 cursor-pointer hover:bg-opacity-80 transition-all min-h-[40px] flex items-center justify-center;
}

.assignment-start {
  @apply rounded-l-lg border-r-0;
}

.assignment-middle {
  @apply border-r-0 border-l-0;
}

.assignment-end {
  @apply rounded-r-lg border-l-0;
}

.assignment-single {
  @apply rounded-lg;
}

.until-display {
  @apply w-full px-2 py-1 text-sm border border-gray-200 min-h-[32px] flex items-center justify-center text-gray-500;
}

.break-cell-full {
  @apply w-full h-full px-0 py-1 text-xs font-bold text-center border-0 cursor-not-allowed min-h-[40px] flex items-center justify-center text-white;
}

.empty-cell-full {
  @apply w-full h-full px-0 py-1 text-xs text-center border border-gray-200 min-h-[40px] flex items-center justify-center;
}

.break-blocked {
  @apply text-white font-bold;
}

.break-blocked::placeholder {
  @apply text-gray-400;
}

.break-cell {
  @apply w-full px-2 py-1 text-xs font-bold text-center border-0 cursor-not-allowed;
  min-height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.empty-cell {
  @apply w-full px-2 py-1 text-xs text-center border border-gray-200;
  min-height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.no-employees-message {
  @apply border-t border-gray-200 pt-4;
}

/* Color coding for different job functions */
.assignment-input[value*="Pick"] {
  @apply bg-yellow-100;
}

.assignment-input[value*="X4"] {
  @apply bg-green-100;
}

.assignment-input[value*="EM9"] {
  @apply bg-green-100;
}

.assignment-input[value*="RT-Pick"] {
  @apply bg-orange-100;
}

.assignment-input[value*="Meter"] {
  @apply bg-blue-100;
}

.assignment-input[value*="Training"] {
  @apply bg-red-100;
}

.assignment-input[value*="Lunch"] {
  @apply bg-red-100;
}

/* Responsive design - optimized for full-width layout */
@media (max-width: 1400px) {
  .shift-grouped-schedule {
    @apply text-xs;
  }
  
  .employee-name {
    @apply w-28 px-2;
  }
  
  .assignment-input,
  .until-input,
  .break-input,
  .break-until-input {
    @apply px-1 py-0.5 text-xs;
  }
}

@media (max-width: 1200px) {
  .shift-grouped-schedule {
    @apply text-xs;
  }
  
  .employee-name {
    @apply w-24 px-1;
  }
  
  .assignment-input,
  .until-input,
  .break-input,
  .break-until-input {
    @apply px-1 py-0.5 text-xs;
  }
}
</style>
