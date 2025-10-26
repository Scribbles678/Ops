<template>
  <div class="space-y-4">
    <!-- Each Shift Section -->
    <div
      v-for="shift in shiftSections"
      :key="shift.id"
      class="bg-white rounded-lg border border-gray-200 p-4"
    >
      <!-- Shift Header -->
      <div class="flex items-center justify-between mb-4 pb-3 border-b border-gray-200">
        <div>
          <h3 class="text-lg font-bold text-gray-800">{{ shift.name }}</h3>
          <p class="text-sm text-gray-600">{{ shift.startTime }} - {{ shift.endTime }}</p>
        </div>
        <div class="flex items-center space-x-2">
          <span class="text-sm text-gray-500">{{ shift.employeeCount }} assigned</span>
          <button
            @click="toggleShiftView(shift.id)"
            class="px-3 py-1 text-xs rounded border"
            :class="shift.expanded ? 'bg-blue-100 text-blue-700 border-blue-300' : 'bg-gray-100 text-gray-700 border-gray-300'"
          >
            {{ shift.expanded ? 'Collapse' : 'Expand' }}
          </button>
        </div>
      </div>

      <!-- Shift Content -->
      <div v-if="shift.expanded" class="space-y-3">
        <!-- Time Slots Grid -->
        <div class="grid gap-2" :class="getTimeSlotGridClass(shift.timeSlots.length)">
          <div
            v-for="timeSlot in shift.timeSlots"
            :key="timeSlot.id"
            class="relative"
          >
            <!-- Time Slot Header -->
            <div class="text-xs font-medium text-gray-600 mb-1 text-center">
              {{ formatTimeForSlot(timeSlot.time) }}
            </div>

            <!-- Break Indicator -->
            <div
              v-if="timeSlot.isBreakTime"
              class="h-8 bg-yellow-100 border border-yellow-300 rounded flex items-center justify-center text-xs font-medium text-yellow-800"
            >
              {{ getBreakLabel(timeSlot.breakType) }}
            </div>

            <!-- Assignment Slots -->
            <div
              v-else
              class="h-8 border border-gray-200 rounded flex items-center justify-center text-xs cursor-pointer hover:bg-blue-50 transition"
              @click="addAssignment(shift.id, timeSlot.time)"
            >
              <div
                v-if="getAssignmentForSlot(shift.id, timeSlot.time)"
                class="w-full h-full flex items-center justify-center rounded text-white font-medium"
                :style="getAssignmentStyle(shift.id, timeSlot.time)"
                @click.stop="editAssignment(shift.id, timeSlot.time)"
              >
                {{ getAssignmentText(shift.id, timeSlot.time) }}
              </div>
              <span v-else class="text-gray-400">+</span>
            </div>
          </div>
        </div>

        <!-- Break Coverage Summary -->
        <div v-if="hasBreakPeriods(shift)" class="mt-4 pt-3 border-t border-gray-200">
          <h4 class="text-sm font-medium text-gray-700 mb-2">Break Coverage</h4>
          <div class="grid grid-cols-2 gap-2">
            <div
              v-for="breakPeriod in getBreakPeriods(shift)"
              :key="breakPeriod.id"
              class="flex items-center justify-between p-2 bg-yellow-50 rounded text-xs"
            >
              <span class="font-medium">{{ breakPeriod.time }}</span>
              <span
                class="px-2 py-1 rounded text-xs"
                :class="breakPeriod.covered ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'"
              >
                {{ breakPeriod.covered ? 'Covered' : 'Uncovered' }}
              </span>
            </div>
          </div>
        </div>
      </div>

      <!-- Collapsed View -->
      <div v-else class="grid grid-cols-4 gap-2">
        <div
          v-for="assignment in getShiftAssignments(shift.id)"
          :key="assignment.id"
          class="p-2 rounded text-white text-xs font-medium text-center"
          :style="{ backgroundColor: getJobFunctionColor(assignment.job_function) }"
        >
          {{ assignment.employee_name }}
          <div class="text-xs opacity-75">{{ assignment.job_function }}</div>
        </div>
        <div
          v-if="getShiftAssignments(shift.id).length === 0"
          class="col-span-4 text-center text-gray-500 text-sm py-4"
        >
          No assignments
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { nextTick } from 'vue'
import { generateTimeSlots, formatTimeForHeader, type TimeSlot } from '~/utils/timeSlots'

const props = defineProps<{
  employees: any[]
  scheduleAssignments: any[]
  jobFunctions: any[]
  shifts: any[]
}>()

const emit = defineEmits<{
  addAssignment: [shiftId: string, timeSlot: string]
  editAssignment: [shiftId: string, timeSlot: string]
  assignBreakCoverage: [shiftId: string, timeSlot: string]
}>()

// Generate time slots for the day
const allTimeSlots = generateTimeSlots(6, 20)

// Convert time to minutes
const timeToMinutes = (time: string): number => {
  const [hours, minutes] = time.split(':').map(Number)
  return hours * 60 + minutes
}

// Check if time is in range
const isTimeInRange = (time: string, start: string, end: string): boolean => {
  const timeMinutes = timeToMinutes(time)
  const startMinutes = timeToMinutes(start)
  const endMinutes = timeToMinutes(end)
  return timeMinutes >= startMinutes && timeMinutes < endMinutes
}

// Create shift sections with time slots
const shiftSections = ref([
  {
    id: '6am',
    name: '6:00 AM Shift',
    startTime: '6:00 AM',
    endTime: '2:30 PM',
    timeSlots: allTimeSlots.filter(slot => isTimeInRange(slot.time, '06:00', '14:30')),
    employeeCount: 0,
    expanded: true
  },
  {
    id: '7am',
    name: '7:00 AM Shift',
    startTime: '7:00 AM',
    endTime: '3:30 PM',
    timeSlots: allTimeSlots.filter(slot => isTimeInRange(slot.time, '07:00', '15:30')),
    employeeCount: 0,
    expanded: true
  },
  {
    id: '8am',
    name: '8:00 AM Shift',
    startTime: '8:00 AM',
    endTime: '4:30 PM',
    timeSlots: allTimeSlots.filter(slot => isTimeInRange(slot.time, '08:00', '16:30')),
    employeeCount: 0,
    expanded: true
  },
  {
    id: '10am',
    name: '10:00 AM Shift',
    startTime: '10:00 AM',
    endTime: '6:30 PM',
    timeSlots: allTimeSlots.filter(slot => isTimeInRange(slot.time, '10:00', '18:30')),
    employeeCount: 0,
    expanded: true
  },
  {
    id: '12pm',
    name: '12:00 PM Shift',
    startTime: '12:00 PM',
    endTime: '8:30 PM',
    timeSlots: allTimeSlots.filter(slot => isTimeInRange(slot.time, '12:00', '20:30')),
    employeeCount: 0,
    expanded: true
  },
  {
    id: '4pm',
    name: '4:00 PM Shift',
    startTime: '4:00 PM',
    endTime: '8:30 PM',
    timeSlots: allTimeSlots.filter(slot => isTimeInRange(slot.time, '16:00', '20:30')),
    employeeCount: 0,
    expanded: true
  }
])


// Get grid class based on number of time slots
const getTimeSlotGridClass = (slotCount: number) => {
  if (slotCount <= 8) return 'grid-cols-4'
  if (slotCount <= 16) return 'grid-cols-6'
  if (slotCount <= 24) return 'grid-cols-8'
  return 'grid-cols-10'
}

// Format time for display
const formatTimeForSlot = (time: string): string => {
  const [hours, minutes] = time.split(':').map(Number)
  const displayHour = hours === 0 ? 12 : hours > 12 ? hours - 12 : hours
  const ampm = hours >= 12 ? 'PM' : 'AM'
  
  if (minutes === 0) {
    return `${displayHour} ${ampm}`
  } else {
    return `${displayHour}:${minutes.toString().padStart(2, '0')} ${ampm}`
  }
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

// Get assignment for a specific slot
const getAssignmentForSlot = (shiftId: string, timeSlot: string) => {
  if (!props.scheduleAssignments) return null
  
  return props.scheduleAssignments.find(assignment => 
    assignment && 
    assignment.shift_id === shiftId && 
    assignment.start_time <= timeSlot && 
    assignment.end_time > timeSlot
  )
}

// Get assignment style
const getAssignmentStyle = (shiftId: string, timeSlot: string) => {
  const assignment = getAssignmentForSlot(shiftId, timeSlot)
  if (!assignment) return {}
  
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
const getAssignmentText = (shiftId: string, timeSlot: string) => {
  const assignment = getAssignmentForSlot(shiftId, timeSlot)
  if (!assignment) return ''
  
  return assignment.job_function || ''
}

// Get job function color
const getJobFunctionColor = (jobFunction: string) => {
  const colors = {
    'RT Pick': '#FFA500',
    'Pick': '#4CAF50',
    'Meter': '#2196F3',
    'Locus': '#FFC107',
    'Helpdesk': '#9C27B0',
    'Coordinator': '#F44336',
    'Team Lead': '#607D8B'
  }
  
  return colors[jobFunction] || '#6B7280'
}

// Get shift assignments
const getShiftAssignments = (shiftId: string) => {
  if (!props.scheduleAssignments || !props.employees) return []
  
  return props.scheduleAssignments
    .filter(assignment => assignment && assignment.shift_id === shiftId)
    .map(assignment => {
      const employee = props.employees.find(emp => emp && emp.id === assignment.employee_id)
      return {
        ...assignment,
        employee_name: employee ? `${employee.last_name}, ${employee.first_name}` : 'Unknown Employee'
      }
    })
}

// Check if shift has break periods
const hasBreakPeriods = (shift: any) => {
  return shift.timeSlots.some((slot: TimeSlot) => slot.isBreakTime)
}

// Get break periods for a shift
const getBreakPeriods = (shift: any) => {
  return shift.timeSlots
    .filter((slot: TimeSlot) => slot.isBreakTime)
    .map((slot: TimeSlot) => ({
      id: slot.id,
      time: formatTimeForSlot(slot.time),
      covered: hasBreakCoverage(shift.id, slot)
    }))
}

// Check if break has coverage
const hasBreakCoverage = (shiftId: string, slot: TimeSlot) => {
  // This would check if the break is covered
  // For now, return false
  return false
}

// Toggle shift view
const toggleShiftView = (shiftId: string) => {
  const shift = shiftSections.value.find(s => s.id === shiftId)
  if (shift) {
    shift.expanded = !shift.expanded
  }
}

// Event handlers
const addAssignment = (shiftId: string, timeSlot: string) => {
  emit('addAssignment', shiftId, timeSlot)
}

const editAssignment = (shiftId: string, timeSlot: string) => {
  emit('editAssignment', shiftId, timeSlot)
}

// Update employee counts
watch(() => props.scheduleAssignments, () => {
  nextTick(() => {
    if (shiftSections.value && shiftSections.value.length > 0) {
      shiftSections.value.forEach(shift => {
        if (shift) {
          shift.employeeCount = getShiftAssignments(shift.id).length
        }
      })
    }
  })
}, { deep: true })
</script>
