<template>
  <div>
    <div class="flex justify-between items-center mb-6">
      <h2 class="text-2xl font-bold text-gray-800">Shifts</h2>
      <p class="text-sm text-gray-500">(View Only for MVP)</p>
    </div>

    <!-- Loading State -->
    <div v-if="loading" class="text-center py-8">
      <p class="text-gray-600">Loading shifts...</p>
    </div>

    <!-- Shifts List -->
    <div v-else class="space-y-4">
      <div
        v-for="shift in shifts"
        :key="shift.id"
        class="border border-gray-200 rounded-lg p-4"
      >
        <h3 class="text-lg font-semibold text-gray-800 mb-3">{{ shift.name }}</h3>
        
        <div class="grid grid-cols-2 gap-4 text-sm">
          <div>
            <span class="font-medium text-gray-700">Start Time:</span>
            <span class="text-gray-600 ml-2">{{ formatTime(shift.start_time) }}</span>
          </div>
          <div>
            <span class="font-medium text-gray-700">End Time:</span>
            <span class="text-gray-600 ml-2">{{ formatTime(shift.end_time) }}</span>
          </div>
          
          <div v-if="shift.break_1_start">
            <span class="font-medium text-gray-700">Break 1:</span>
            <span class="text-gray-600 ml-2">
              {{ formatTime(shift.break_1_start) }} - {{ formatTime(shift.break_1_end) }}
            </span>
          </div>
          
          <div v-if="shift.break_2_start">
            <span class="font-medium text-gray-700">Break 2:</span>
            <span class="text-gray-600 ml-2">
              {{ formatTime(shift.break_2_start) }} - {{ formatTime(shift.break_2_end) }}
            </span>
          </div>
          
          <div v-if="shift.lunch_start">
            <span class="font-medium text-gray-700">Lunch:</span>
            <span class="text-gray-600 ml-2">
              {{ formatTime(shift.lunch_start) }} - {{ formatTime(shift.lunch_end) }}
            </span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const { shifts, loading, fetchShifts } = useSchedule()
const { formatTime } = useLaborCalculations()

onMounted(() => {
  fetchShifts()
})
</script>

