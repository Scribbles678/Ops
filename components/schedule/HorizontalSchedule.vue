<template>
  <div class="horizontal-schedule">
    <!-- Header with time blocks -->
    <div class="schedule-header">
      <div class="employee-name-header">Employee</div>
      
      <!-- 6:00 AM Block -->
      <div class="time-block">
        <div class="time-header">6:00 AM</div>
      </div>

      <!-- 8:00 AM Block -->
      <div class="time-block">
        <div class="time-header">8:00 AM</div>
      </div>

      <!-- 10:00 AM Block -->
      <div class="time-block">
        <div class="time-header">10:00 AM</div>
      </div>

      <!-- 12:00 PM Block -->
      <div class="time-block">
        <div class="time-header">12:00 PM</div>
      </div>

      <!-- 4:30 PM Block -->
      <div class="time-block">
        <div class="time-header">4:30 PM</div>
      </div>
    </div>

    <!-- Employee rows -->
    <div class="schedule-body">
      <div 
        v-for="employee in employees" 
        :key="employee.id" 
        class="employee-row"
      >
        <!-- Employee name -->
        <div class="employee-name">
          {{ employee.last_name }}, {{ employee.first_name }}
        </div>

        <!-- 6:00 AM Block -->
        <div class="time-block-content">
          <div class="assignment-cell">
            <input 
              type="text" 
              :value="getAssignment(employee.id, '06:00')"
              @input="updateAssignment(employee.id, '06:00', $event.target.value)"
              class="assignment-input"
            />
          </div>
          <div class="until-cell">
            <input 
              type="text" 
              :value="getUntil(employee.id, '06:00')"
              @input="updateUntil(employee.id, '06:00', $event.target.value)"
              class="until-input"
            />
          </div>
          <div class="break-cell">
            <input 
              type="text" 
              :value="getBreakAssignment(employee.id, '06:00', 1)"
              @input="updateBreakAssignment(employee.id, '06:00', 1, $event.target.value)"
              class="break-input"
            />
          </div>
          <div class="break-until-cell">
            <input 
              type="text" 
              :value="getBreakUntil(employee.id, '06:00', 1)"
              @input="updateBreakUntil(employee.id, '06:00', 1, $event.target.value)"
              class="break-until-input"
            />
          </div>
          <div class="assignment-cell">
            <input 
              type="text" 
              :value="getAssignment(employee.id, '06:00', 2)"
              @input="updateAssignment(employee.id, '06:00', $event.target.value, 2)"
              class="assignment-input"
            />
          </div>
          <div class="until-cell">
            <input 
              type="text" 
              :value="getUntil(employee.id, '06:00', 2)"
              @input="updateUntil(employee.id, '06:00', $event.target.value, 2)"
              class="until-input"
            />
          </div>
        </div>

        <!-- 8:00 AM Block -->
        <div class="time-block-content">
          <div class="assignment-cell">
            <input 
              type="text" 
              :value="getAssignment(employee.id, '08:00')"
              @input="updateAssignment(employee.id, '08:00', $event.target.value)"
              class="assignment-input"
            />
          </div>
          <div class="until-cell">
            <input 
              type="text" 
              :value="getUntil(employee.id, '08:00')"
              @input="updateUntil(employee.id, '08:00', $event.target.value)"
              class="until-input"
            />
          </div>
          <div class="break-cell">
            <input 
              type="text" 
              :value="getBreakAssignment(employee.id, '08:00', 1)"
              @input="updateBreakAssignment(employee.id, '08:00', 1, $event.target.value)"
              class="break-input"
            />
          </div>
          <div class="break-until-cell">
            <input 
              type="text" 
              :value="getBreakUntil(employee.id, '08:00', 1)"
              @input="updateBreakUntil(employee.id, '08:00', 1, $event.target.value)"
              class="break-until-input"
            />
          </div>
          <div class="assignment-cell">
            <input 
              type="text" 
              :value="getAssignment(employee.id, '08:00', 2)"
              @input="updateAssignment(employee.id, '08:00', $event.target.value, 2)"
              class="assignment-input"
            />
          </div>
          <div class="until-cell">
            <input 
              type="text" 
              :value="getUntil(employee.id, '08:00', 2)"
              @input="updateUntil(employee.id, '08:00', $event.target.value, 2)"
              class="until-input"
            />
          </div>
        </div>

        <!-- 10:00 AM Block -->
        <div class="time-block-content">
          <div class="assignment-cell">
            <input 
              type="text" 
              :value="getAssignment(employee.id, '10:00')"
              @input="updateAssignment(employee.id, '10:00', $event.target.value)"
              class="assignment-input"
            />
          </div>
          <div class="until-cell">
            <input 
              type="text" 
              :value="getUntil(employee.id, '10:00')"
              @input="updateUntil(employee.id, '10:00', $event.target.value)"
              class="until-input"
            />
          </div>
          <div class="break-cell">
            <input 
              type="text" 
              :value="getBreakAssignment(employee.id, '10:00', 1)"
              @input="updateBreakAssignment(employee.id, '10:00', 1, $event.target.value)"
              class="break-input"
            />
          </div>
          <div class="break-until-cell">
            <input 
              type="text" 
              :value="getBreakUntil(employee.id, '10:00', 1)"
              @input="updateBreakUntil(employee.id, '10:00', 1, $event.target.value)"
              class="break-until-input"
            />
          </div>
          <div class="assignment-cell">
            <input 
              type="text" 
              :value="getAssignment(employee.id, '10:00', 2)"
              @input="updateAssignment(employee.id, '10:00', $event.target.value, 2)"
              class="assignment-input"
            />
          </div>
          <div class="until-cell">
            <input 
              type="text" 
              :value="getUntil(employee.id, '10:00', 2)"
              @input="updateUntil(employee.id, '10:00', $event.target.value, 2)"
              class="until-input"
            />
          </div>
        </div>

        <!-- 12:00 PM Block -->
        <div class="time-block-content">
          <div class="assignment-cell">
            <input 
              type="text" 
              :value="getAssignment(employee.id, '12:00')"
              @input="updateAssignment(employee.id, '12:00', $event.target.value)"
              class="assignment-input"
            />
          </div>
          <div class="until-cell">
            <input 
              type="text" 
              :value="getUntil(employee.id, '12:00')"
              @input="updateUntil(employee.id, '12:00', $event.target.value)"
              class="until-input"
            />
          </div>
          <div class="break-cell">
            <input 
              type="text" 
              :value="getBreakAssignment(employee.id, '12:00', 2)"
              @input="updateBreakAssignment(employee.id, '12:00', 2, $event.target.value)"
              class="break-input"
            />
          </div>
          <div class="break-until-cell">
            <input 
              type="text" 
              :value="getBreakUntil(employee.id, '12:00', 2)"
              @input="updateBreakUntil(employee.id, '12:00', 2, $event.target.value)"
              class="break-until-input"
            />
          </div>
          <div class="assignment-cell">
            <input 
              type="text" 
              :value="getAssignment(employee.id, '12:00', 2)"
              @input="updateAssignment(employee.id, '12:00', $event.target.value, 2)"
              class="assignment-input"
            />
          </div>
          <div class="until-cell">
            <input 
              type="text" 
              :value="getUntil(employee.id, '12:00', 2)"
              @input="updateUntil(employee.id, '12:00', $event.target.value, 2)"
              class="until-input"
            />
          </div>
        </div>

        <!-- 4:30 PM Block -->
        <div class="time-block-content">
          <div class="assignment-cell">
            <input 
              type="text" 
              :value="getAssignment(employee.id, '16:30')"
              @input="updateAssignment(employee.id, '16:30', $event.target.value)"
              class="assignment-input"
            />
          </div>
          <div class="until-cell">
            <input 
              type="text" 
              :value="getUntil(employee.id, '16:30')"
              @input="updateUntil(employee.id, '16:30', $event.target.value)"
              class="until-input"
            />
          </div>
          <div class="break-cell">
            <input 
              type="text" 
              :value="getBreakAssignment(employee.id, '16:30', 2)"
              @input="updateBreakAssignment(employee.id, '16:30', 2, $event.target.value)"
              class="break-input"
            />
          </div>
          <div class="break-until-cell">
            <input 
              type="text" 
              :value="getBreakUntil(employee.id, '16:30', 2)"
              @input="updateBreakUntil(employee.id, '16:30', 2, $event.target.value)"
              class="break-until-input"
            />
          </div>
          <div class="assignment-cell">
            <input 
              type="text" 
              :value="getAssignment(employee.id, '16:30', 2)"
              @input="updateAssignment(employee.id, '16:30', $event.target.value, 2)"
              class="assignment-input"
            />
          </div>
          <div class="until-cell">
            <input 
              type="text" 
              :value="getUntil(employee.id, '16:30', 2)"
              @input="updateUntil(employee.id, '16:30', $event.target.value, 2)"
              class="until-input"
            />
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'

// Props
const props = defineProps<{
  employees: any[]
  scheduleAssignments: any[]
  jobFunctions: any[]
  shifts: any[]
}>()

// Emits
const emit = defineEmits<{
  addAssignment: [employeeId: string, timeSlot: string]
  editAssignment: [employeeId: string, timeSlot: string]
  assignBreakCoverage: [employeeId: string, timeSlot: string]
}>()

// Local state for schedule data
const scheduleData = ref<Record<string, any>>({})

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
  if (!employeeData || !employeeData[timeSlot]) return ''
  
  if (segment === 1) {
    return employeeData[timeSlot].assignment || ''
  } else {
    return employeeData[timeSlot].assignment2 || ''
  }
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

// Initialize on mount
initializeScheduleData()
</script>

<style scoped>
.horizontal-schedule {
  @apply w-full overflow-x-auto;
}

.schedule-header {
  @apply flex bg-gray-100 border-b-2 border-gray-300 sticky top-0 z-10;
}

.employee-name-header {
  @apply w-48 px-4 py-3 font-semibold text-gray-700 border-r border-gray-300 flex-shrink-0;
}

.time-block {
  @apply flex-1 border-r border-gray-300;
}

.time-header {
  @apply bg-gray-200 px-2 py-1 text-sm font-semibold text-center border-b border-gray-300;
}



.schedule-body {
  @apply divide-y divide-gray-200;
}

.employee-row {
  @apply flex hover:bg-gray-50;
}

.employee-name {
  @apply w-48 px-4 py-3 font-medium text-gray-900 border-r border-gray-300 flex-shrink-0;
}

.time-block-content {
  @apply flex-1 flex border-r border-gray-300;
}

.assignment-cell,
.until-cell {
  @apply flex-1 border-r border-gray-200;
}

.break-cell,
.break-until-cell {
  @apply flex-1 border-r border-gray-200 bg-blue-50;
}

.assignment-input,
.until-input,
.break-input,
.break-until-input {
  @apply w-full px-2 py-1 text-sm border-0 bg-transparent focus:bg-white focus:ring-1 focus:ring-blue-500 focus:outline-none;
}

.break-input,
.break-until-input {
  @apply bg-blue-50 focus:bg-white;
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

/* Responsive design */
@media (max-width: 1200px) {
  .horizontal-schedule {
    @apply text-xs;
  }
  
  .employee-name {
    @apply w-32 px-2;
  }
  
  .assignment-input,
  .until-input,
  .break-input,
  .break-until-input {
    @apply px-1 py-0.5 text-xs;
  }
}
</style>
