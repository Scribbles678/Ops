<template>
  <div class="min-h-screen bg-gray-50">
    <div class="container mx-auto px-4 py-8">
      <!-- Header -->
      <div class="flex items-center justify-between mb-6">
        <div>
          <h1 class="text-3xl font-bold text-gray-800">
            {{ isToday ? 'Edit Today\'s Schedule' : 'Edit Schedule' }}
          </h1>
          <p class="text-gray-600 mt-1">{{ formattedDate }}</p>
        </div>
        <div class="flex space-x-3">
          <button
            @click="refreshData"
            class="btn-secondary"
          >
            🔄 Refresh
          </button>
          <NuxtLink to="/" class="btn-secondary">
            ← Back to Home
          </NuxtLink>
        </div>
      </div>

      <!-- Loading State -->
      <div v-if="loading" class="card text-center py-8">
        <p class="text-gray-600">Loading schedule...</p>
      </div>

      <!-- Main Content -->
      <div v-else class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <!-- Schedule Grid (2/3 width) -->
        <div class="lg:col-span-2 space-y-4">
          <!-- Add Assignment Button -->
          <div class="flex justify-end">
            <button
              @click="openAddModal"
              class="btn-primary"
            >
              + Add Assignment
            </button>
          </div>

          <!-- Assignments by Shift -->
          <div v-for="shift in shifts" :key="shift.id" class="card">
            <h3 class="text-lg font-bold text-gray-800 mb-4">{{ shift.name }}</h3>

            <!-- Assignments for this shift -->
            <div class="space-y-2">
              <div
                v-for="assignment in getShiftAssignments(shift.id)"
                :key="assignment.id"
                @click="openEditModal(assignment)"
                class="schedule-cell-filled cursor-pointer p-3 rounded-lg transition hover:shadow-md"
                :style="{ backgroundColor: assignment.job_function.color_code }"
              >
                <div class="flex justify-between items-start">
                  <div>
                    <p class="font-semibold">
                      {{ assignment.employee.last_name }}, {{ assignment.employee.first_name }}
                    </p>
                    <p class="text-sm opacity-90">{{ assignment.job_function.name }}</p>
                  </div>
                  <div class="text-right text-sm opacity-90">
                    <p>{{ formatTime(assignment.start_time) }}</p>
                    <p>{{ formatTime(assignment.end_time) }}</p>
                  </div>
                </div>
              </div>

              <p v-if="getShiftAssignments(shift.id).length === 0" class="text-gray-400 text-center py-4">
                No assignments for this shift
              </p>
            </div>
          </div>
        </div>

        <!-- Labor Hours Panel (1/3 width) -->
        <div class="lg:col-span-1">
          <LaborHoursPanel
            :job-functions="jobFunctions"
            :assignments="assignments"
            :targets="targetsMap"
          />

          <!-- Daily Targets Section -->
          <div class="card mt-6">
            <h3 class="text-lg font-bold text-gray-800 mb-4">Daily Targets</h3>
            <div class="space-y-3">
              <div v-for="jf in jobFunctions" :key="jf.id" class="text-sm">
                <label class="block text-gray-700 mb-1">{{ jf.name }}</label>
                <input
                  type="number"
                  :value="targetsMap[jf.id]?.target_units || 0"
                  @change="updateTarget(jf.id, $event)"
                  min="0"
                  class="w-full px-3 py-1 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
                  placeholder="Target units"
                />
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Assignment Modal -->
    <AssignmentModal
      :show="showModal"
      :assignment="selectedAssignment"
      :schedule-date="scheduleDate"
      :employees="employees"
      :job-functions="jobFunctions"
      :shifts="shifts"
      :existing-assignments="assignments"
      @close="closeModal"
      @save="saveAssignment"
      @delete="deleteAssignment"
    />
  </div>
</template>

<script setup lang="ts">
const route = useRoute()
const { formatTime, formatDate } = useLaborCalculations()
const { employees, fetchEmployees } = useEmployees()
const { jobFunctions, fetchJobFunctions } = useJobFunctions()
const { 
  scheduleAssignments: assignments,
  shifts,
  dailyTargets,
  loading,
  fetchShifts,
  fetchScheduleForDate,
  createAssignment,
  updateAssignment,
  deleteAssignment: deleteAssignmentApi,
  fetchDailyTargets,
  upsertDailyTarget
} = useSchedule()

const showModal = ref(false)
const selectedAssignment = ref(null)

const scheduleDate = computed(() => {
  return typeof route.params.date === 'string' ? route.params.date : route.params.date[0]
})

const isToday = computed(() => {
  const today = new Date().toISOString().split('T')[0]
  return scheduleDate.value === today
})

const formattedDate = computed(() => {
  return formatDate(scheduleDate.value)
})

const targetsMap = computed(() => {
  const map: Record<string, any> = {}
  dailyTargets.value.forEach((target: any) => {
    map[target.job_function_id] = target
  })
  return map
})

onMounted(async () => {
  await loadData()
})

const loadData = async () => {
  await Promise.all([
    fetchEmployees(),
    fetchJobFunctions(),
    fetchShifts(),
    fetchScheduleForDate(scheduleDate.value),
    fetchDailyTargets(scheduleDate.value)
  ])
}

const refreshData = () => {
  loadData()
}

const getShiftAssignments = (shiftId: string) => {
  return assignments.value.filter((a: any) => a.shift_id === shiftId)
}

const openAddModal = () => {
  selectedAssignment.value = null
  showModal.value = true
}

const openEditModal = (assignment: any) => {
  selectedAssignment.value = assignment
  showModal.value = true
}

const closeModal = () => {
  showModal.value = false
  selectedAssignment.value = null
}

const saveAssignment = async (assignmentData: any) => {
  if (selectedAssignment.value) {
    await updateAssignment(selectedAssignment.value.id, assignmentData)
  } else {
    await createAssignment(assignmentData)
  }
  await fetchScheduleForDate(scheduleDate.value)
  closeModal()
}

const deleteAssignment = async (assignmentId: string) => {
  await deleteAssignmentApi(assignmentId)
  await fetchScheduleForDate(scheduleDate.value)
  closeModal()
}

const updateTarget = async (jobFunctionId: string, event: Event) => {
  const target = (event.target as HTMLInputElement).value
  const targetUnits = parseInt(target) || 0

  await upsertDailyTarget({
    schedule_date: scheduleDate.value,
    job_function_id: jobFunctionId,
    target_units: targetUnits
  })

  await fetchDailyTargets(scheduleDate.value)
}
</script>

