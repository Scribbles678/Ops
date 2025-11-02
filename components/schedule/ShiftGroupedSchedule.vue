<template>
  <div class="shift-grouped-schedule">
    <!-- Each Shift Group -->
    <div
      v-for="shift in shiftsWithEmployees"
      :key="shift.id"
      class="shift-group mb-8"
      :style="{ width: `${24 + 224 + (getShiftTimeBlocks(shift).length * 48)}px`, maxWidth: '100%' }"
    >
      <!-- Shift Header -->
      <div class="shift-header">
        <h2 class="text-2xl font-bold text-gray-800 mb-4 pb-3 border-b border-gray-300">
          {{ shift.name }}
        </h2>
      </div>

      <!-- Time Block Headers -->
      <div class="time-blocks-header-grid">
        <div class="employee-name-header">Staff</div>
        <div 
          class="time-header-grid relative"
          :style="{ gridTemplateColumns: getGridTemplateColumns(shift) }"
        >
          <!-- Render all time block cells for alignment (but empty) -->
          <div
            v-for="timeBlock in getShiftTimeBlocks(shift)"
            :key="`header-cell-${timeBlock.time}`"
            class="time-block-header-cell"
          ></div>
          
          <!-- Render hourly markers that span the full hour (4 columns) -->
          <div
            v-for="(marker, index) in getHourlyMarkers(shift)"
            :key="`hour-marker-${shift.id}-${marker.time}`"
            class="time-hour-marker"
            :style="{ gridColumn: `${marker.startIndex + 1} / span ${marker.span}` }"
          >
            {{ formatTimeForDisplay(marker.time) }}
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
          <div class="employee-name flex items-center gap-2">
            <span class="whitespace-nowrap truncate max-w-[200px]" :title="`${employee.last_name}, ${employee.first_name}`">{{ employee.last_name }}, {{ employee.first_name }}</span>
            <span v-if="hasPTO(employee.id)" class="px-1.5 py-0.5 text-[10px] font-semibold rounded bg-red-100 text-red-700 border border-red-200">PTO</span>
            <button @click="emit('addPTO', employee)" class="px-1.5 py-0.5 text-[10px] rounded-md border border-gray-300 text-gray-700 hover:bg-gray-100 transition-colors duration-150 shadow-sm">PTO</button>
            <button @click="emit('addShiftSwap', employee)" class="px-1.5 py-0.5 text-[10px] rounded-md border border-blue-300 text-blue-700 hover:bg-blue-100 transition-colors duration-150 shadow-sm">SS</button>
          </div>

          <!-- Grid row background cells for alignment and interaction -->
          <div class="relative flex-1 min-w-0">
            <div
              class="grid"
              :style="{ gridTemplateColumns: getGridTemplateColumns(shift) }"
            >
              <div 
                v-for="timeBlock in getShiftTimeBlocks(shift)" 
                :key="`cell-${employee.id}-${shift.id}-${timeBlock.time}`"
                class="time-block-content select-none"
                @mousedown.prevent="onSelectStart(employee, shift, timeBlock)"
                @mouseenter="onSelectMove(shift, timeBlock)"
                @mouseup="onSelectEnd()"
              >
                <div class="assignment-cell-full">
                  <div 
                    v-if="!isBreakTime(timeBlock.time, shift)"
                    @click="openAssignmentModal(employee, timeBlock, shift)"
                    class="assignment-clickable-full bg-white hover:bg-blue-50 transition-colors duration-150 rounded-sm"
                  >
                    <!-- Empty background cell; assignments are rendered as overlay spans -->
                  </div>
                  <div 
                    v-else
                    class="break-cell-full rounded-lg border text-white flex items-center justify-center"
                    style="background: linear-gradient(135deg, #374151 0%, #1f2937 100%); border-color: rgba(0, 0, 0, 0.2); box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.1);"
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
                class="rounded-lg border flex items-center justify-start px-2 text-[11px] font-medium overflow-hidden transition-all duration-200"
                :style="{
                  gridColumn: `${range.start} / ${range.end}`,
                  backgroundColor: getJobFunctionColor(range.label),
                  color: getTextColor(getJobFunctionColor(range.label)),
                  boxShadow: '0 1px 3px 0 rgba(0, 0, 0, 0.1), 0 1px 2px -1px rgba(0, 0, 0, 0.1)',
                  borderColor: 'rgba(0, 0, 0, 0.1)'
                }"
              >
                <span class="truncate">{{ range.label }}</span>
              </div>

              <!-- Selection overlay while dragging -->
              <div
                v-if="isSelecting && selectedEmployee?.id === employee.id && selectedShift?.id === shift.id && selectionRange"
                class="rounded-lg border-2 border-blue-500 bg-blue-100/60 backdrop-blur-sm"
                :style="{ 
                  gridColumn: `${selectionRange.start} / ${selectionRange.end}`,
                  boxShadow: '0 0 0 1px rgba(59, 130, 246, 0.2)'
                }"
              ></div>
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
      <div class="bg-white rounded-lg p-6 w-full mx-4 max-w-2xl max-h-[90vh] overflow-y-auto">
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
  ptoByEmployeeId?: Record<string, any[]>
  shiftSwapsByEmployeeId?: Record<string, any>
}>()

// Emits
const emit = defineEmits<{
  addAssignment: [employeeId: string, timeSlot: string]
  editAssignment: [employeeId: string, timeSlot: string]
  assignBreakCoverage: [employeeId: string, timeSlot: string]
  scheduleDataUpdated: [scheduleData: Record<string, any>]
  addPTO: [employee: any]
  addShiftSwap: [employee: any]
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

// Drag-to-select state
const isSelecting = ref(false)
const selectionStartTime = ref('')
const selectionEndTime = ref('')
const selectionRange = computed(() => {
  if (!isSelecting.value || !selectionStartTime.value || !selectionEndTime.value || !selectedShift.value) return null
  const blocks = getShiftTimeBlocks(selectedShift.value)
  const startIdx = Math.min(
    Math.max(blocks.findIndex(b => b.time === selectionStartTime.value), 0),
    blocks.length - 1
  )
  const endIdx = Math.min(
    Math.max(blocks.findIndex(b => b.time === selectionEndTime.value), 0),
    blocks.length - 1
  )
  const start = Math.min(startIdx, endIdx) + 1
  const end = Math.max(startIdx, endIdx) + 2 // end is exclusive
  return { start, end }
})

// Group employees by their assigned shifts
const shiftsWithEmployees = computed(() => {
  return props.shifts.map(shift => {
    // Get employees for this shift:
    // 1. Employees who are swapped TO this shift for today
    // 2. Employees whose shift_id matches this shift AND they don't have a swap
    const employeesForShift = props.employees.filter(employee => {
      // Check if employee has a shift swap
      const swap = props.shiftSwapsByEmployeeId?.[employee.id]
      
      if (swap) {
        // If employee has a swap, only show them in the swapped shift
        return swap.swapped_shift_id === shift.id
      } else {
        // If no swap, show them in their normal shift
        return employee.shift_id === shift.id
      }
    })
    
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
  
  // Handle normalized names (e.g., "LUNCH" should match "Lunch")
  const normalizedName = jobFunctionName === 'LUNCH' ? 'Lunch' :
                         jobFunctionName === 'BREAK' ? 'Break' :
                         jobFunctionName === 'BREAK 1' ? 'Break 1' :
                         jobFunctionName === 'BREAK 2' ? 'Break 2' :
                         jobFunctionName
  
  const jobFunction = props.jobFunctions.find(jf => 
    jf.name === normalizedName || 
    jf.name.toLowerCase() === normalizedName.toLowerCase()
  )
  
  // Special handling for LUNCH/BREAK if not found
  if (!jobFunction) {
    if (jobFunctionName === 'LUNCH') return '#000000' // Black for lunch
    if (jobFunctionName === 'BREAK' || jobFunctionName.startsWith('BREAK')) return '#000000' // Black for breaks
  }
  
  return jobFunction?.color_code || '#ffffff'
}

// Get appropriate text color based on background luminance
const getTextColor = (hex: string): string => {
  if (!hex || hex === '#ffffff' || hex === '#FFFFFF') return '#000000'
  if (hex === '#000000' || hex === '#000') return '#ffffff'
  
  // Convert hex to RGB
  const r = parseInt(hex.slice(1, 3), 16)
  const g = parseInt(hex.slice(3, 5), 16)
  const b = parseInt(hex.slice(5, 7), 16)
  
  // Calculate relative luminance (per WCAG)
  // L = 0.299*R + 0.587*G + 0.114*B
  const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
  
  // Use white text on dark backgrounds (luminance < 0.5), black on light
  return luminance > 0.5 ? '#000000' : '#ffffff'
}

// Grid helpers
const getGridTemplateColumns = (shift: any) => {
  const cols = getShiftTimeBlocks(shift).length
  // Fixed column width for crisp alignment and predictable wrapping
  return `repeat(${cols}, 48px)`
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
    if (!b) continue
    
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

// PTO helpers
const hasPTO = (employeeId: string) => {
  return !!props.ptoByEmployeeId && Array.isArray(props.ptoByEmployeeId[employeeId]) && props.ptoByEmployeeId[employeeId].length > 0
}

const isOverlappingPTO = (employeeId: string, startMinutes: number, endMinutes: number) => {
  if (!props.ptoByEmployeeId) return false
  const records = props.ptoByEmployeeId[employeeId] || []
  for (const r of records) {
    // Full day
    if (!r.start_time && !r.end_time) return true
    const s = r.start_time ? timeToMinutes(String(r.start_time).substring(0,5)) : 0
    const e = r.end_time ? timeToMinutes(String(r.end_time).substring(0,5)) : 24 * 60
    if (!(endMinutes <= s || startMinutes >= e)) return true
  }
  return false
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
  const parts = time.split(':').map(Number)
  const hours = parts[0] || 0
  const minutes = parts[1] || 0
  return hours * 60 + minutes
}

// Convert minutes to time string
const minutesToTime = (minutes: number): string => {
  const hours = Math.floor(minutes / 60)
  const mins = minutes % 60
  return `${hours.toString().padStart(2, '0')}:${mins.toString().padStart(2, '0')}`
}

// Format time for display - only show hourly labels
const formatTimeForDisplay = (time: string): string => {
  const parts = time.split(':').map(Number)
  const hours = parts[0] ?? 0
  const minutes = parts[1] ?? 0
  
  // Only show time labels for hourly slots (when minutes === 0)
  if (minutes === 0 && hours !== undefined) {
    const period = hours >= 12 ? 'PM' : 'AM'
    const displayHours = hours > 12 ? hours - 12 : (hours === 0 ? 12 : hours)
    return `${displayHours} ${period}`
  }
  
  // Return empty string for non-hourly slots (handled by v-if in template)
  return ''
}

// Get hourly markers for a shift to create spanning headers
const getHourlyMarkers = (shift: any) => {
  const blocks = getShiftTimeBlocks(shift)
  const hourlyMarkers: Array<{ time: string; startIndex: number; span: number }> = []
  
  blocks.forEach((block, index) => {
    if (isHourlyMarker(block.time)) {
      // Calculate span: typically 4 blocks (1 hour = 4 x 15 minutes)
      // But check if this is the last hour - may be less than 4
      let span = 4
      if (index + 4 > blocks.length) {
        span = blocks.length - index
      }
      
      hourlyMarkers.push({
        time: block.time,
        startIndex: index, // 0-based for CSS grid-column
        span: span
      })
    }
  })
  
  return hourlyMarkers
}

// Check if a time block is an hourly marker for enhanced styling
const isHourlyMarker = (time: string): boolean => {
  const parts = time.split(':').map(Number)
  const minutes = parts[1] ?? 0
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
    return 'BREAK'
  }
  
  // Check if time slot is within break 2 period
  if (break2Start !== null && break2End !== null && timeMinutes >= break2Start && timeMinutes < break2End) {
    return 'BREAK'
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

// Drag-to-select handlers
const onSelectStart = (employee: any, shift: any, timeBlock: any) => {
  if (isBreakTime(timeBlock.time, shift)) return
  isSelecting.value = true
  selectedEmployee.value = employee
  selectedShift.value = shift
  selectionStartTime.value = timeBlock.time
  selectionEndTime.value = timeBlock.time
}

const onSelectMove = (shift: any, timeBlock: any) => {
  if (!isSelecting.value) return
  if (!selectedShift.value || selectedShift.value.id !== shift.id) return
  if (isBreakTime(timeBlock.time, shift)) return
  selectionEndTime.value = timeBlock.time
}

const onSelectEnd = () => {
  if (!isSelecting.value) return
  isSelecting.value = false
  // Open modal with prefilled start/end based on selection
  if (!selectedEmployee.value || !selectedShift.value || !selectionRange.value) return
  const blocks = getShiftTimeBlocks(selectedShift.value)
  const startIdx = selectionRange.value.start - 1
  const endIdxExclusive = selectionRange.value.end - 1
  const startBlock = blocks[startIdx]
  const endBlock = blocks[Math.min(endIdxExclusive - 1, blocks.length - 1)]
  const startTime = startBlock?.time || ''
  const endTime = endBlock
    ? minutesToTime(timeToMinutes(endBlock.time) + 15)
    : ''
  
  selectedTimeBlock.value = { time: startTime }
  assignmentStartTime.value = startTime
  assignmentEndTime.value = endTime
  showAssignmentModal.value = true
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
  // PTO overlap check
  if (props.ptoByEmployeeId && isOverlappingPTO(selectedEmployee.value.id, startMinutes, endMinutes)) {
    alert('This employee has PTO during the selected time. Adjust the range or remove PTO.')
    return
  }
  
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
  if (!selectedEmployee.value || !selectedTimeBlock.value || !selectedShift.value) return
  
  // Get the current assignment at the clicked time
  const currentAssignment = getAssignment(selectedEmployee.value.id, selectedTimeBlock.value.time)
  
  if (!currentAssignment) {
    // No assignment to remove
    closeAssignmentModal()
    return
  }
  
  // Find the entire contiguous assignment range that contains the clicked time
  const blocks = getShiftTimeBlocks(selectedShift.value)
  const clickedTime = selectedTimeBlock.value.time
  const clickedMinutes = timeToMinutes(clickedTime)
  
  // Find the start of the contiguous assignment
  let rangeStartMinutes = clickedMinutes
  let rangeEndMinutes = clickedMinutes + 15 // Default to just the clicked block
  
  // Walk backwards to find the start of the contiguous range
  let checkMinutes = clickedMinutes
  while (checkMinutes >= timeToMinutes(blocks[0]?.time || '00:00')) {
    const checkTime = minutesToTime(checkMinutes)
    const assignment = getAssignment(selectedEmployee.value.id, checkTime)
    if (assignment === currentAssignment && !isBreakTime(checkTime, selectedShift.value)) {
      rangeStartMinutes = checkMinutes
      checkMinutes -= 15
    } else {
      break
    }
  }
  
  // Walk forwards to find the end of the contiguous range
  checkMinutes = clickedMinutes + 15
  const shiftEndMinutes = timeToMinutes(selectedShift.value.end_time || '23:59')
  while (checkMinutes < shiftEndMinutes) {
    const checkTime = minutesToTime(checkMinutes)
    const assignment = getAssignment(selectedEmployee.value.id, checkTime)
    if (assignment === currentAssignment && !isBreakTime(checkTime, selectedShift.value)) {
      rangeEndMinutes = checkMinutes + 15
      checkMinutes += 15
    } else {
      break
    }
  }
  
  // Remove all assignments in the entire range
  clearAssignmentsInRange(selectedEmployee.value.id, rangeStartMinutes, rangeEndMinutes)
  
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
  @apply bg-white rounded-xl border border-gray-200;
  padding: 24px 0 24px 24px; /* top right bottom left - only left/top/bottom padding, no right padding */
  box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1), 0 1px 2px -1px rgba(0, 0, 0, 0.1);
  /* Width is set dynamically based on shift end_time via inline style */
  /* Content extends to the right edge of container (no right padding) */
}

.shift-header {
  @apply mb-6;
}

.shift-header h2 {
  @apply text-gray-800;
  letter-spacing: -0.025em;
}

.time-blocks-header-grid {
  @apply flex bg-gradient-to-b from-gray-50 to-gray-100 border-b border-gray-300 sticky top-0 z-10;
  box-shadow: 0 2px 4px -1px rgba(0, 0, 0, 0.06);
  /* Ensure header structure matches employee rows exactly */
  align-items: stretch;
}

.employee-name-header {
  @apply px-3 py-2 font-semibold text-gray-700 border-r border-gray-300 flex-shrink-0;
  background: linear-gradient(135deg, #f9fafb 0%, #f3f4f6 100%);
  box-shadow: inset 0 -1px 0 0 rgba(0, 0, 0, 0.06);
  /* Exact width: 224px (14rem) to match employee-name */
  width: 224px;
  min-width: 224px;
  max-width: 224px;
  box-sizing: border-box;
}

.time-header-grid {
  @apply grid flex-1;
  background: transparent;
  /* Ensure grid starts immediately after employee name header */
  min-width: 0;
  /* No gaps - borders handle separation */
  column-gap: 0;
  row-gap: 0;
  /* Ensure perfect alignment */
  margin: 0;
  padding: 0;
}

.time-block-header-cell {
  @apply relative;
  background: transparent;
  /* Grid will handle width via gridTemplateColumns */
  /* Add border to match content cells for alignment */
  border-right: 1px solid rgba(229, 231, 235, 0.5);
}

.time-hour-marker {
  @apply px-3 py-2 text-xs font-semibold text-gray-700 text-center flex items-center justify-center;
  /* Modern styling with gradient and subtle shadow */
  background: linear-gradient(135deg, #f3f4f6 0%, #e5e7eb 100%);
  border-right: 2px solid #d1d5db;
  border-bottom: 1px solid #e5e7eb;
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
  letter-spacing: 0.025em;
  /* Spanning is handled via grid-column in the inline style */
}

.shift-employees {
  @apply divide-y divide-gray-200;
  /* Remove min-w-max to allow proper flex alignment */
}

.employee-row {
  @apply flex transition-colors duration-150;
  border-bottom: 1px solid rgba(229, 231, 235, 0.6);
  /* Match header structure exactly */
  align-items: stretch;
}

.employee-row:hover {
  background: linear-gradient(to right, #f9fafb 0%, #ffffff 100%);
}

.employee-name {
  @apply px-3 py-2 font-medium text-gray-900 border-r border-gray-300 flex-shrink-0;
  background: rgba(249, 250, 251, 0.5);
  /* Exact width: 224px (14rem) to match employee-name-header */
  width: 224px;
  min-width: 224px;
  max-width: 224px;
  box-sizing: border-box;
}

.time-block-content {
  @apply relative;
  /* Grid will handle width via gridTemplateColumns */
  /* Border must match header cells exactly for alignment */
  border-right: 1px solid rgba(229, 231, 235, 0.5);
}

/* Removed hourly-marker-content - was causing unnecessary blue vertical bars */

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
  @apply w-full h-full px-0 py-0.5 text-xs border border-gray-300 cursor-pointer hover:bg-opacity-80 transition-all min-h-[28px] flex items-center justify-center;
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
  @apply w-full h-full px-2 text-[11px] font-medium text-center cursor-not-allowed flex items-center justify-center;
  /* Match assignment block styling for consistent height */
}

.empty-cell-full {
  @apply w-full h-full px-0 py-0.5 text-[10px] text-center border border-gray-200 min-h-[28px] flex items-center justify-center;
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
    @apply w-40 px-2;
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
    @apply w-36 px-1;
  }
  
  .assignment-input,
  .until-input,
  .break-input,
  .break-until-input {
    @apply px-1 py-0.5 text-xs;
  }
}
</style>
