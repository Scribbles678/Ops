<template>
  <div class="business-rules-page min-h-screen bg-gray-50">
    <div class="container mx-auto px-3 md:px-4 py-4 md:py-6">
      <!-- Header -->
      <div class="flex items-center justify-between mb-4 md:mb-6">
        <div>
          <h1 class="text-2xl md:text-3xl font-semibold text-gray-800 leading-tight">Staffing Targets</h1>
          <p class="text-gray-600 mt-1 text-xs md:text-sm">Set target headcount per job function per hour for automated scheduling</p>
        </div>
        <div class="flex space-x-2 md:space-x-3">
          <button @click="handleLogout" class="bg-red-600 hover:bg-red-700 text-white px-3 py-1.5 rounded-lg text-xs md:text-sm font-medium transition-colors">
            Logout
          </button>
          <NuxtLink to="/" class="btn-secondary-sm md:btn-secondary">
            ← Back to Home
          </NuxtLink>
        </div>
      </div>

      <!-- Action Buttons -->
      <div class="mb-4 flex flex-wrap gap-2">
        <button
          @click="openPreferredAssignmentsModal"
          class="btn-secondary-sm md:btn-secondary flex items-center"
        >
          <svg class="w-4 h-4 md:w-5 md:h-5 mr-1.5 md:mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
          </svg>
          Required Assignments
        </button>
      </div>

      <!-- Success Toast -->
      <div
        v-if="showSuccessToast"
        class="fixed top-20 right-6 z-50 bg-green-100 border border-green-200 text-green-700 px-3 py-2 rounded-lg shadow-md flex items-center space-x-2 text-sm md:text-base"
      >
        <svg class="w-4 h-4 md:w-5 md:h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
        </svg>
        <span class="font-medium">{{ successToastMessage }}</span>
      </div>

      <!-- Staffing Targets Grid -->
      <div class="card p-3 md:p-4">
        <div v-if="loading" class="text-center py-5 text-sm text-gray-600">
          Loading staffing targets...
        </div>

        <div v-else-if="gridError" class="text-center py-5 text-sm text-red-600">
          Error: {{ gridError }}
        </div>

        <div v-else-if="gridJobFunctions.length === 0" class="text-center py-5 text-sm text-gray-600">
          No job functions found. Please create job functions first.
        </div>

        <div v-else>
          <div class="overflow-x-auto -mx-1 md:-mx-2">
            <table class="min-w-full text-xs md:text-sm">
              <thead class="bg-gray-50 text-xs uppercase tracking-wide text-gray-500">
                <tr>
                  <th class="px-3 md:px-4 py-2 text-left sticky left-0 bg-gray-50 z-10 min-w-[140px]">Job Function</th>
                  <th
                    v-for="hour in gridHours"
                    :key="hour.value"
                    class="px-2 py-2 text-center min-w-[60px]"
                  >
                    {{ hour.label }}
                  </th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <tr v-for="jf in gridJobFunctions" :key="jf.id">
                  <td class="px-3 md:px-4 py-2 whitespace-nowrap font-medium text-gray-900 sticky left-0 bg-white z-10">
                    {{ jf.name }}
                  </td>
                  <td
                    v-for="hour in gridHours"
                    :key="hour.value"
                    class="px-1 py-1 text-center"
                  >
                    <input
                      type="number"
                      min="0"
                      :value="getGridValue(jf.id, hour.value)"
                      @input="setGridValue(jf.id, hour.value, ($event.target as HTMLInputElement).value)"
                      class="w-14 px-1 py-1 text-center border border-gray-200 rounded focus:outline-none focus:ring-1 focus:ring-blue-500 text-sm"
                    />
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <div class="flex justify-end mt-4">
            <button
              @click="saveAllTargets"
              :disabled="saving || !hasChanges"
              class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed text-sm font-medium transition-colors"
            >
              {{ saving ? 'Saving...' : 'Save All' }}
            </button>
          </div>
        </div>
      </div>

      <!-- Required Assignments Modal -->
      <div v-if="showPreferredAssignmentsModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-white rounded-lg p-6 max-w-4xl w-full mx-4 max-h-[90vh] overflow-y-auto">
          <div class="flex items-center justify-between mb-6">
            <h3 class="text-2xl font-bold text-gray-800">Required Assignments</h3>
            <button @click="closePreferredAssignmentsModal" class="text-gray-400 hover:text-gray-600">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <div class="mb-6">
            <button @click="openAddPreferredAssignmentModal" class="btn-primary flex items-center">
              <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
              </svg>
              Add Required Assignment
            </button>
          </div>

          <div v-if="preferredAssignmentsLoading" class="text-center py-8">
            <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
            <p class="mt-2 text-gray-600">Loading required assignments...</p>
          </div>

          <div v-else-if="preferredAssignmentsError" class="bg-red-50 border border-red-200 rounded-lg p-4 mb-6">
            <p class="text-red-600">Error loading required assignments: {{ preferredAssignmentsError }}</p>
          </div>

          <div v-else class="space-y-4">
            <div
              v-for="pref in preferredAssignments"
              :key="pref.id"
              class="border border-gray-200 rounded-lg p-4 hover:shadow-md transition"
            >
              <div class="flex items-center justify-between">
                <div class="flex-1">
                  <div class="flex items-center space-x-4 mb-2">
                    <div class="flex-1">
                      <h4 class="text-lg font-semibold text-gray-800">
                        {{ pref.employee?.first_name }} {{ pref.employee?.last_name }}
                      </h4>
                      <p v-if="!pref.am_job_function_id && !pref.pm_job_function_id" class="text-sm text-gray-600">
                        AM &amp; PM: <span class="font-medium">{{ pref.job_function?.name }}</span>
                      </p>
                      <template v-else>
                        <p class="text-sm text-gray-600">
                          AM: <span class="font-medium">{{ getJfName(pref.am_job_function_id) ?? pref.job_function?.name }}</span>
                        </p>
                        <p class="text-sm text-gray-600">
                          PM: <span class="font-medium">{{ getJfName(pref.pm_job_function_id) ?? pref.job_function?.name }}</span>
                        </p>
                      </template>
                    </div>
                  </div>
                </div>
                <div class="flex space-x-2 ml-4">
                  <button
                    @click="openEditPreferredAssignmentModal(pref)"
                    class="px-4 py-2 bg-blue-100 text-blue-600 rounded hover:bg-blue-200 transition"
                  >
                    Edit
                  </button>
                  <button
                    @click="deletePreferredAssignmentHandler(pref.id)"
                    class="px-4 py-2 bg-red-100 text-red-600 rounded hover:bg-red-200 transition"
                  >
                    Delete
                  </button>
                </div>
              </div>
            </div>

            <div v-if="preferredAssignments.length === 0" class="text-center py-8 text-gray-500">
              <p>No required assignments configured yet.</p>
              <p class="text-sm mt-2">Click "+ Add Required Assignment" to create one.</p>
            </div>
          </div>

          <!-- Add/Edit Required Assignment Modal -->
          <div v-if="showPreferredAssignmentFormModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-[60]">
            <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4 relative">
              <div
                v-if="showSavedIcon"
                class="absolute inset-0 bg-white bg-opacity-95 flex items-center justify-center z-10 rounded-lg transition-opacity duration-300"
              >
                <div class="flex flex-col items-center">
                  <svg class="w-16 h-16 text-green-500 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                  </svg>
                  <span class="text-lg font-semibold text-green-600">Saved</span>
                </div>
              </div>

              <h4 class="text-xl font-bold mb-4">
                {{ editingPreferredAssignment ? 'Edit Required Assignment' : 'Add Required Assignment' }}
              </h4>
              <form @submit.prevent="handlePreferredAssignmentSubmit" class="space-y-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Employee</label>
                  <select
                    v-model="preferredAssignmentFormData.employee_id"
                    required
                    class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                  >
                    <option value="">Select employee...</option>
                    <option
                      v-for="employee in employees"
                      :key="employee.id"
                      :value="employee.id"
                    >
                      {{ employee.first_name }} {{ employee.last_name }}
                    </option>
                  </select>
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">AM Job Function</label>
                  <select
                    v-model="preferredAssignmentFormData.am_job_function_id"
                    required
                    class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                  >
                    <option value="">Select job function...</option>
                    <option
                      v-for="jf in sortedJobFunctions"
                      :key="jf.id"
                      :value="jf.id"
                    >
                      {{ jf.name }}
                    </option>
                  </select>
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    PM Job Function
                    <span class="text-gray-400 font-normal">(leave blank to use same as AM)</span>
                  </label>
                  <select
                    v-model="preferredAssignmentFormData.pm_job_function_id"
                    class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                  >
                    <option value="">Same as AM</option>
                    <option
                      v-for="jf in sortedJobFunctions"
                      :key="jf.id"
                      :value="jf.id"
                    >
                      {{ jf.name }}
                    </option>
                  </select>
                </div>
                <div class="flex justify-end space-x-3 pt-4">
                  <button
                    type="button"
                    @click="closePreferredAssignmentFormModal"
                    class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    class="btn-primary"
                  >
                    {{ editingPreferredAssignment ? 'Update' : 'Create' }}
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const { logout } = useAuth()
const { jobFunctions, fetchJobFunctions } = useJobFunctions()
const { employees, fetchEmployees } = useEmployees()
const { targets, loading: targetsLoading, error: targetsError, fetchTargets, saveTargets } = useStaffingTargets()
const {
  preferredAssignments,
  loading: preferredAssignmentsLoading,
  error: preferredAssignmentsError,
  fetchPreferredAssignments,
  createPreferredAssignment,
  updatePreferredAssignment,
  deletePreferredAssignment
} = usePreferredAssignments()

const loading = ref(true)
const saving = ref(false)
const gridError = ref<string | null>(null)
const showSuccessToast = ref(false)
const successToastMessage = ref('')
let successTimeout: ReturnType<typeof setTimeout> | null = null

// Required Assignments Modal State
const showPreferredAssignmentsModal = ref(false)
const showPreferredAssignmentFormModal = ref(false)
const editingPreferredAssignment = ref<any>(null)
const preferredAssignmentFormData = ref({ employee_id: '', am_job_function_id: '', pm_job_function_id: '' })
const showSavedIcon = ref(false)

// Grid data: { "jfId|hour": headcount }
const gridData = ref<Record<string, number>>({})
const originalGridData = ref<Record<string, number>>({})

// Hours columns: 6AM through 8PM (covers up to 8:30PM end-of-shift)
const gridHours = computed(() => {
  const hours = []
  for (let h = 6; h <= 20; h++) {
    const value = `${h.toString().padStart(2, '0')}:00`
    const period = h >= 12 ? 'PM' : 'AM'
    const display = h > 12 ? h - 12 : h === 0 ? 12 : h
    hours.push({ value, label: `${display}${period}` })
  }
  return hours
})

// Job functions for the grid (active, exclude individual Meter N — use parent Meter,
// and exclude any functions marked as exclude_from_targets)
const gridJobFunctions = computed(() => {
  return [...(jobFunctions.value || [])]
    .filter(jf =>
      jf.is_active !== false &&
      !jf.exclude_from_targets &&
      !/^Meter [0-9]+$/.test(jf.name || '')
    )
    .sort((a, b) => (a.name || '').localeCompare(b.name || ''))
})

const sortedJobFunctions = computed(() => {
  return [...(jobFunctions.value || [])]
    .filter(jf => jf.is_active !== false)
    .sort((a, b) => {
      const aIsMeter = a.name?.startsWith('Meter ')
      const bIsMeter = b.name?.startsWith('Meter ')
      if (aIsMeter && !bIsMeter) return 1
      if (!aIsMeter && bIsMeter) return -1
      return (a.name || '').localeCompare(b.name || '')
    })
})

const hasChanges = computed(() => {
  return JSON.stringify(gridData.value) !== JSON.stringify(originalGridData.value)
})

// Look up a job function name by ID (used for AM/PM display in the list)
const getJfName = (id: string | null | undefined): string | null => {
  if (!id) return null
  return jobFunctions.value?.find((jf: any) => jf.id === id)?.name ?? null
}

const gridKey = (jfId: string, hour: string) => `${jfId}|${hour}`

const getGridValue = (jfId: string, hour: string): number => {
  return gridData.value[gridKey(jfId, hour)] ?? 0
}

const setGridValue = (jfId: string, hour: string, rawValue: string) => {
  const val = parseInt(rawValue, 10)
  gridData.value[gridKey(jfId, hour)] = isNaN(val) || val < 0 ? 0 : val
}

const loadGridFromTargets = () => {
  const data: Record<string, number> = {}
  for (const t of targets.value) {
    data[gridKey(t.job_function_id, t.hour_start)] = t.headcount
  }
  gridData.value = { ...data }
  originalGridData.value = { ...data }
}

const saveAllTargets = async () => {
  saving.value = true
  try {
    // Only send cells that actually changed — never zero-out untouched hours
    const items: { job_function_id: string; hour_start: string; headcount: number }[] = []
    for (const jf of gridJobFunctions.value) {
      for (const hour of gridHours.value) {
        const key = gridKey(jf.id, hour.value)
        const current = gridData.value[key] ?? 0
        const original = originalGridData.value[key] ?? 0
        if (current !== original) {
          items.push({ job_function_id: jf.id, hour_start: hour.value, headcount: current })
        }
      }
    }
    if (items.length > 0) {
      await saveTargets(items)
    }
    loadGridFromTargets()
    showSuccessIndicator('Staffing targets saved')
  } catch (e: any) {
    gridError.value = e.message || 'Error saving targets'
  } finally {
    saving.value = false
  }
}

const showSuccessIndicator = (message: string) => {
  successToastMessage.value = message
  showSuccessToast.value = true
  if (successTimeout) clearTimeout(successTimeout)
  successTimeout = setTimeout(() => { showSuccessToast.value = false }, 2000)
}

const handleLogout = async () => {
  await logout()
}

// Required Assignments Functions
const openPreferredAssignmentsModal = async () => {
  showPreferredAssignmentsModal.value = true
  await fetchPreferredAssignments()
  if (employees.value.length === 0) {
    await fetchEmployees(false)
  }
}

const closePreferredAssignmentsModal = () => {
  showPreferredAssignmentsModal.value = false
  showPreferredAssignmentFormModal.value = false
  editingPreferredAssignment.value = null
}

const openAddPreferredAssignmentModal = () => {
  editingPreferredAssignment.value = null
  preferredAssignmentFormData.value = { employee_id: '', am_job_function_id: '', pm_job_function_id: '' }
  showPreferredAssignmentFormModal.value = true
}

const openEditPreferredAssignmentModal = (pref: any) => {
  editingPreferredAssignment.value = pref
  preferredAssignmentFormData.value = {
    employee_id: pref.employee_id,
    am_job_function_id: pref.am_job_function_id ?? pref.job_function_id ?? '',
    pm_job_function_id: pref.pm_job_function_id ?? ''
  }
  showPreferredAssignmentFormModal.value = true
}

const closePreferredAssignmentFormModal = () => {
  showPreferredAssignmentFormModal.value = false
  editingPreferredAssignment.value = null
}

const handlePreferredAssignmentSubmit = async () => {
  try {
    const { employee_id, am_job_function_id, pm_job_function_id } = preferredAssignmentFormData.value
    const payload = {
      employee_id,
      // job_function_id is the AM function (required for the unique constraint)
      job_function_id: am_job_function_id,
      am_job_function_id,
      pm_job_function_id: pm_job_function_id || null,
      is_required: true,
      priority: 0,
      notes: ''
    }
    if (editingPreferredAssignment.value) {
      await updatePreferredAssignment(editingPreferredAssignment.value.id, payload)
    } else {
      await createPreferredAssignment(payload)
    }
    await fetchPreferredAssignments()
    showSavedIcon.value = true
    setTimeout(() => {
      showSavedIcon.value = false
      closePreferredAssignmentFormModal()
    }, 1500)
  } catch (e: any) {
    alert(`Error saving required assignment: ${e.message || 'Unknown error'}`)
  }
}

const deletePreferredAssignmentHandler = async (id: string) => {
  try {
    await deletePreferredAssignment(id)
    await fetchPreferredAssignments()
  } catch (e: any) {
    alert(`Error deleting preferred assignment: ${e.message || 'Unknown error'}`)
  }
}

onMounted(async () => {
  try {
    await Promise.all([
      fetchTargets(),
      fetchJobFunctions(),
      fetchEmployees(false)
    ])
    loadGridFromTargets()
  } catch (e: any) {
    gridError.value = e.message || 'Error loading data'
  } finally {
    loading.value = false
  }
})

onBeforeUnmount(() => {
  if (successTimeout) clearTimeout(successTimeout)
})
</script>
