<template>
  <div class="card">
    <div class="mb-4 flex justify-between items-center">
      <h3 class="text-xl font-bold text-gray-800">Schedule Grid (15-Minute Increments)</h3>
      <div class="flex space-x-2">
        <button
          @click="toggleBreakView"
          class="px-3 py-1 text-sm rounded border"
          :class="showBreaks ? 'bg-blue-100 text-blue-700 border-blue-300' : 'bg-gray-100 text-gray-700 border-gray-300'"
        >
          {{ showBreaks ? 'Hide Breaks' : 'Show Breaks' }}
        </button>
        <button
          @click="addAssignment"
          class="px-3 py-1 bg-green-600 text-white rounded hover:bg-green-700 transition text-sm"
        >
          + Add Assignment
        </button>
      </div>
    </div>

    <!-- Time Slot Headers -->
    <div class="overflow-x-auto">
      <div class="min-w-max">
        <!-- Main time header -->
        <div class="flex border-b-2 border-gray-300">
          <div class="w-32 px-3 py-2 text-xs font-medium text-gray-700 bg-gray-50 border-r border-gray-300 sticky left-0 z-10">
            Employee
          </div>
          <div
            v-for="slot in timeSlots"
            :key="slot.id"
            class="px-1 py-2 text-center text-xs font-medium border-r border-gray-200"
            :class="getTimeSlotClasses(slot)"
            :style="{ minWidth: '60px' }"
          >
            {{ formatTimeForHeader(slot.time) }}
          </div>
        </div>

        <!-- Break indicators row -->
        <div v-if="showBreaks" class="flex border-b border-gray-200 bg-yellow-50">
          <div class="w-32 px-3 py-1 text-xs font-medium text-gray-600 bg-yellow-100 border-r border-gray-300 sticky left-0 z-10">
            Break Coverage
          </div>
          <div
            v-for="slot in timeSlots"
            :key="`break-${slot.id}`"
            class="px-1 py-1 text-center text-xs border-r border-gray-200"
            :class="getBreakSlotClasses(slot)"
            :style="{ minWidth: '60px' }"
          >
            <span v-if="slot.isBreakTime" class="text-xs">
              {{ getBreakLabel(slot.breakType) }}
            </span>
          </div>
        </div>

        <!-- Employee rows -->
        <div
          v-for="employee in employees"
          :key="employee.id"
          class="flex border-b border-gray-200 hover:bg-gray-50"
        >
          <!-- Employee name -->
          <div class="w-32 px-3 py-2 text-xs font-medium text-gray-800 bg-white border-r border-gray-300 sticky left-0 z-10">
            {{ employee.last_name }}, {{ employee.first_name }}
          </div>

          <!-- Time slots for this employee -->
          <div
            v-for="slot in timeSlots"
            :key="`${employee.id}-${slot.id}`"
            class="px-1 py-2 text-center text-xs border-r border-gray-200 relative"
            :class="getEmployeeSlotClasses(employee.id, slot)"
            :style="{ minWidth: '60px' }"
            @click="handleSlotClick(employee.id, slot)"
          >
            <!-- Assignment content -->
            <div
              v-if="getEmployeeAssignment(employee.id, slot.time)"
              class="w-full h-full flex items-center justify-center rounded cursor-pointer hover:opacity-80 transition text-xs font-medium"
              :style="getAssignmentStyle(employee.id, slot.time)"
              @click.stop="editAssignment(employee.id, slot.time)"
            >
              {{ getAssignmentText(employee.id, slot.time) }}
            </div>

            <!-- Break coverage indicator -->
            <div
              v-else-if="slot.isBreakTime && showBreaks"
              class="w-full h-full flex items-center justify-center rounded cursor-pointer hover:bg-yellow-200 transition text-xs"
              :class="getBreakCoverageClasses(employee.id, slot)"
              @click.stop="assignBreakCoverage(employee.id, slot)"
            >
              <span v-if="hasBreakCoverage(employee.id, slot)" class="text-green-600">✓</span>
              <span v-else class="text-gray-400">-</span>
            </div>

            <!-- Empty slot -->
            <div
              v-else
              class="w-full h-full flex items-center justify-center cursor-pointer hover:bg-blue-50 transition text-xs text-gray-400"
              @click.stop="addAssignment(employee.id, slot)"
            >
              +
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Legend -->
    <div class="mt-4 pt-4 border-t border-gray-200">
      <div class="flex flex-wrap gap-4 text-xs">
        <div class="flex items-center space-x-2">
          <div class="w-3 h-3 bg-yellow-200 border border-yellow-400 rounded"></div>
          <span>Break Periods</span>
        </div>
        <div class="flex items-center space-x-2">
          <div class="w-3 h-3 bg-green-200 border border-green-400 rounded"></div>
          <span>Break Coverage</span>
        </div>
        <div class="flex items-center space-x-2">
          <div class="w-3 h-3 bg-blue-200 border border-blue-400 rounded"></div>
          <span>Available Slots</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { generateTimeSlots, formatTimeForHeader, type TimeSlot } from '~/utils/timeSlots'

const props = defineProps<{
  employees: any[]
  scheduleAssignments: any[]
  jobFunctions: any[]
  shifts: any[]
}>()

const emit = defineEmits<{
  addAssignment: [employeeId: string, timeSlot: string]
  editAssignment: [employeeId: string, timeSlot: string]
  assignBreakCoverage: [employeeId: string, timeSlot: TimeSlot]
}>()

// Generate 15-minute time slots (6 AM to 8 PM) using shift data
const timeSlots = computed(() => generateTimeSlots(6, 20, props.shifts))
const showBreaks = ref(true)

// Get CSS classes for time slot headers
const getTimeSlotClasses = (slot: TimeSlot) => {
  const classes = ['text-gray-700']
  
  if (slot.isBreakTime) {
    classes.push('bg-yellow-100', 'text-yellow-800')
  } else {
    classes.push('bg-gray-50')
  }
  
  return classes
}

// Get CSS classes for break slots
const getBreakSlotClasses = (slot: TimeSlot) => {
  if (!slot.isBreakTime) return ['bg-white']
  
  const classes = ['bg-yellow-100', 'text-yellow-800']
  
  switch (slot.breakType) {
    case 'break1':
      classes.push('bg-orange-100', 'text-orange-800')
      break
    case 'break2':
      classes.push('bg-blue-100', 'text-blue-800')
      break
    case 'lunch':
      classes.push('bg-red-100', 'text-red-800')
      break
  }
  
  return classes
}

// Get break label
const getBreakLabel = (breakType?: string) => {
  switch (breakType) {
    case 'break1': return 'B1'
    case 'break2': return 'B2'
    case 'lunch': return 'L'
    default: return 'B'
  }
}

// Get CSS classes for employee time slots
const getEmployeeSlotClasses = (employeeId: string, slot: TimeSlot) => {
  const classes = []
  
  if (slot.isBreakTime) {
    classes.push('bg-yellow-50')
  } else {
    classes.push('bg-white')
  }
  
  return classes
}

// Get assignment for employee at specific time
const getEmployeeAssignment = (employeeId: string, timeSlot: string) => {
  return props.scheduleAssignments.find(assignment => 
    assignment.employee_id === employeeId && 
    assignment.start_time <= timeSlot && 
    assignment.end_time > timeSlot
  )
}

// Get assignment style
const getAssignmentStyle = (employeeId: string, timeSlot: string) => {
  const assignment = getEmployeeAssignment(employeeId, timeSlot)
  if (!assignment) return {}
  
  // Use mock colors for now since we don't have job functions loaded
  const colors = {
    'RT Pick': '#FFA500',
    'Pick': '#4CAF50',
    'Meter': '#2196F3',
    'Locus': '#FFC107',
    'Helpdesk': '#9C27B0',
    'Coordinator': '#F44336',
    'Team Lead': '#607D8B'
  }
  
  const color = colors[assignment.job_function] || '#6B7280'
  
  return {
    backgroundColor: color,
    color: assignment.job_function === 'Locus' ? '#000' : '#fff'
  }
}

// Get assignment text
const getAssignmentText = (employeeId: string, timeSlot: string) => {
  const assignment = getEmployeeAssignment(employeeId, timeSlot)
  if (!assignment) return ''
  
  return assignment.job_function || ''
}

// Check if employee has break coverage
const hasBreakCoverage = (employeeId: string, slot: TimeSlot) => {
  // This would check if the employee is assigned to cover this break
  // Implementation depends on your break coverage logic
  return false
}

// Get break coverage classes
const getBreakCoverageClasses = (employeeId: string, slot: TimeSlot) => {
  const hasCoverage = hasBreakCoverage(employeeId, slot)
  return hasCoverage 
    ? ['bg-green-100', 'text-green-600'] 
    : ['bg-yellow-100', 'text-yellow-600']
}

// Handle slot clicks
const handleSlotClick = (employeeId: string, slot: TimeSlot) => {
  if (slot.isBreakTime && showBreaks.value) {
    emit('assignBreakCoverage', employeeId, slot)
  } else {
    emit('addAssignment', employeeId, slot.time)
  }
}

// Event handlers
const addAssignment = () => {
  // Open assignment modal
}

const editAssignment = (employeeId: string, timeSlot: string) => {
  emit('editAssignment', employeeId, timeSlot)
}

const assignBreakCoverage = (employeeId: string, slot: TimeSlot) => {
  emit('assignBreakCoverage', employeeId, slot)
}

const toggleBreakView = () => {
  showBreaks.value = !showBreaks.value
}
</script>
