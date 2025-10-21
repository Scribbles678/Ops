<template>
  <div class="card">
    <h2 class="text-xl font-bold text-gray-800 mb-4">Labor Hours by Function</h2>

    <div v-if="jobFunctions.length === 0" class="text-gray-500 text-center py-8">
      No job functions configured
    </div>

    <div v-else class="space-y-4">
      <div
        v-for="jobFunction in jobFunctions"
        :key="jobFunction.id"
        class="border border-gray-200 rounded-lg p-4"
      >
        <div class="flex items-center mb-2">
          <div
            class="w-6 h-6 rounded mr-2"
            :style="{ backgroundColor: jobFunction.color_code }"
          ></div>
          <h3 class="font-semibold text-gray-800">{{ jobFunction.name }}</h3>
        </div>

        <!-- Scheduled vs Required Hours -->
        <div class="mb-2">
          <div class="flex justify-between text-sm mb-1">
            <span class="text-gray-600">
              {{ scheduledHours[jobFunction.id] || 0 }}h scheduled
            </span>
            <span class="text-gray-600">
              {{ requiredHours[jobFunction.id] || 0 }}h required
            </span>
          </div>
          
          <!-- Progress Bar -->
          <div class="w-full bg-gray-200 rounded-full h-3 overflow-hidden">
            <div
              :class="getStatusColor(jobFunction.id)"
              class="h-full transition-all"
              :style="{ width: getProgressPercentage(jobFunction.id) + '%' }"
            ></div>
          </div>
        </div>

        <!-- Target Info -->
        <div class="text-sm text-gray-600">
          <div v-if="targets[jobFunction.id]">
            Target: {{ targets[jobFunction.id].target_units }} units
            <span v-if="jobFunction.productivity_rate">
              | Rate: {{ jobFunction.productivity_rate }}/hr
            </span>
          </div>
          <div v-else class="text-gray-400">
            No target set
          </div>
        </div>

        <!-- Status -->
        <div class="mt-2">
          <span
            :class="{
              'text-red-600': getStatus(jobFunction.id) === 'understaffed-critical',
              'text-yellow-600': getStatus(jobFunction.id) === 'understaffed',
              'text-green-600': getStatus(jobFunction.id) === 'adequate',
              'text-blue-600': getStatus(jobFunction.id) === 'overstaffed'
            }"
            class="text-sm font-medium"
          >
            {{ getStatusText(getStatus(jobFunction.id)) }}
            <span v-if="getDifference(jobFunction.id) !== 0">
              ({{ getDifference(jobFunction.id) > 0 ? '+' : '' }}{{ getDifference(jobFunction.id) }}h)
            </span>
          </span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{
  jobFunctions: any[]
  assignments: any[]
  targets: Record<string, any>
}>()

const {
  calculateScheduledHours,
  calculateRequiredHours,
  calculateStaffingStatus,
  getStatusColor: getColorClass,
  getStatusText: getStatusLabel
} = useLaborCalculations()

const scheduledHours = computed(() => {
  const hours: Record<string, number> = {}
  props.jobFunctions.forEach(jf => {
    hours[jf.id] = Math.round(calculateScheduledHours(props.assignments, jf.id) * 10) / 10
  })
  return hours
})

const requiredHours = computed(() => {
  const hours: Record<string, number> = {}
  props.jobFunctions.forEach(jf => {
    const target = props.targets[jf.id]
    if (target && jf.productivity_rate) {
      hours[jf.id] = Math.round(calculateRequiredHours(target.target_units, jf.productivity_rate) * 10) / 10
    } else {
      hours[jf.id] = 0
    }
  })
  return hours
})

const getStatus = (jobFunctionId: string) => {
  const scheduled = scheduledHours.value[jobFunctionId] || 0
  const required = requiredHours.value[jobFunctionId] || 0
  return calculateStaffingStatus(scheduled, required).status
}

const getStatusText = (status: string) => {
  return getStatusLabel(status)
}

const getStatusColor = (jobFunctionId: string) => {
  const status = getStatus(jobFunctionId)
  return getColorClass(status)
}

const getProgressPercentage = (jobFunctionId: string) => {
  const scheduled = scheduledHours.value[jobFunctionId] || 0
  const required = requiredHours.value[jobFunctionId] || 0
  if (required === 0) return 100
  return Math.min(Math.round((scheduled / required) * 100), 100)
}

const getDifference = (jobFunctionId: string) => {
  const scheduled = scheduledHours.value[jobFunctionId] || 0
  const required = requiredHours.value[jobFunctionId] || 0
  return Math.round((scheduled - required) * 10) / 10
}
</script>

