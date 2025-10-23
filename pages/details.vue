<template>
  <div class="min-h-screen bg-gray-50">
    <div class="container mx-auto px-4 py-8">
      <!-- Header -->
      <div class="flex items-center justify-between mb-8">
        <h1 class="text-4xl font-bold text-gray-800">Details & Settings</h1>
        <NuxtLink to="/" class="btn-secondary">
          ← Back to Home
        </NuxtLink>
      </div>

      <!-- Tabs -->
      <div class="mb-6">
        <div class="border-b border-gray-200">
          <nav class="-mb-px flex space-x-8">
            <button
              @click="activeTab = 'job-functions'"
              :class="[
                'py-4 px-1 border-b-2 font-medium text-sm transition',
                activeTab === 'job-functions'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              ]"
            >
              Job Functions
            </button>
            <button
              @click="activeTab = 'shifts'"
              :class="[
                'py-4 px-1 border-b-2 font-medium text-sm transition',
                activeTab === 'shifts'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              ]"
            >
              Shift Management
            </button>
            <button
              @click="activeTab = 'productivity'"
              :class="[
                'py-4 px-1 border-b-2 font-medium text-sm transition',
                activeTab === 'productivity'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              ]"
            >
              Productivity Rates
            </button>
          </nav>
        </div>
      </div>

      <!-- Tab Content -->
      <div class="card">
        <!-- Job Functions Tab -->
        <div v-if="activeTab === 'job-functions'">
          <div class="p-6">
            <div class="flex justify-between items-center mb-6">
              <h2 class="text-2xl font-bold text-gray-800">Job Functions</h2>
              <button @click="openAddJobFunctionModal" class="btn-primary">
                + Add New Job Function
              </button>
            </div>

            <!-- Loading State -->
            <div v-if="loading" class="text-center py-8">
              <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
              <p class="mt-2 text-gray-600">Loading job functions...</p>
            </div>

            <!-- Error State -->
            <div v-else-if="error" class="bg-red-50 border border-red-200 rounded-lg p-4 mb-6">
              <p class="text-red-600">Error loading job functions: {{ error }}</p>
            </div>

            <!-- Job Functions List -->
            <div v-else class="space-y-4">
              <div 
                v-for="jobFunction in jobFunctions" 
                :key="jobFunction.id"
                class="border border-gray-200 rounded-lg p-4 hover:shadow-md transition"
              >
                <div class="flex items-center justify-between">
                  <div class="flex items-center space-x-4">
                    <div 
                      class="w-12 h-12 rounded border border-gray-300" 
                      :style="{ backgroundColor: jobFunction.color_code }"
                    ></div>
                    <div>
                      <h3 class="text-lg font-semibold text-gray-800">{{ jobFunction.name }}</h3>
                      <p class="text-sm text-gray-600">
                        Rate: {{ jobFunction.productivity_rate || 'N/A' }} 
                        {{ jobFunction.unit_of_measure ? jobFunction.unit_of_measure : '' }}
                      </p>
                    </div>
                  </div>
                  <div class="flex space-x-2">
                    <button 
                      @click="openEditJobFunctionModal(jobFunction)"
                      class="px-4 py-2 bg-blue-100 text-blue-600 rounded hover:bg-blue-200 transition"
                    >
                      Edit
                    </button>
                    <button 
                      @click="deleteJobFunctionHandler(jobFunction.id)"
                      class="px-4 py-2 bg-red-100 text-red-600 rounded hover:bg-red-200 transition"
                    >
                      Delete
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Shift Management Tab -->
        <div v-else-if="activeTab === 'shifts'">
          <div class="p-6">
            <div class="flex justify-between items-center mb-6">
              <h2 class="text-2xl font-bold text-gray-800">Shift Management</h2>
              <button @click="openAddShiftModal" class="btn-primary">
                + Add New Shift
              </button>
            </div>

            <!-- Loading State -->
            <div v-if="loading" class="text-center py-8">
              <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
              <p class="mt-2 text-gray-600">Loading shifts...</p>
            </div>

            <!-- Error State -->
            <div v-else-if="error" class="bg-red-50 border border-red-200 rounded-lg p-4 mb-6">
              <p class="text-red-600">Error loading shifts: {{ error }}</p>
            </div>

            <!-- Shifts List -->
            <div v-else class="space-y-4">
              <div 
                v-for="shift in shifts" 
                :key="shift.id"
                class="border border-gray-200 rounded-lg p-4 hover:shadow-md transition"
              >
                <div class="flex justify-between items-start">
                  <div class="flex-1">
                    <h3 class="text-lg font-semibold text-gray-800 mb-3">{{ shift.name }}</h3>
                    <div class="grid grid-cols-2 md:grid-cols-3 gap-4 text-sm">
                      <div>
                        <span class="font-medium text-gray-700">Start Time:</span>
                        <span class="text-gray-600 ml-2">{{ shift.start_time }}</span>
                      </div>
                      <div>
                        <span class="font-medium text-gray-700">End Time:</span>
                        <span class="text-gray-600 ml-2">{{ shift.end_time }}</span>
                      </div>
                      <div v-if="shift.break_1_start">
                        <span class="font-medium text-gray-700">Break 1:</span>
                        <span class="text-gray-600 ml-2">{{ shift.break_1_start }} - {{ shift.break_1_end }}</span>
                      </div>
                      <div v-if="shift.break_2_start">
                        <span class="font-medium text-gray-700">Break 2:</span>
                        <span class="text-gray-600 ml-2">{{ shift.break_2_start }} - {{ shift.break_2_end }}</span>
                      </div>
                      <div v-if="shift.lunch_start">
                        <span class="font-medium text-gray-700">Lunch:</span>
                        <span class="text-gray-600 ml-2">{{ shift.lunch_start }} - {{ shift.lunch_end }}</span>
                      </div>
                    </div>
                  </div>
                  <div class="flex space-x-2 ml-4">
                    <button 
                      @click="openEditShiftModal(shift)"
                      class="px-4 py-2 bg-blue-100 text-blue-600 rounded hover:bg-blue-200 transition"
                    >
                      Edit
                    </button>
                    <button 
                      @click="deleteShiftHandler(shift.id)"
                      class="px-4 py-2 bg-red-100 text-red-600 rounded hover:bg-red-200 transition"
                    >
                      Delete
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Productivity Rates Tab -->
        <div v-else-if="activeTab === 'productivity'">
          <div class="p-6">
            <div class="flex justify-between items-center mb-6">
              <h2 class="text-2xl font-bold text-gray-800">Productivity Rates</h2>
              <button class="btn-primary">
                Save Changes
              </button>
            </div>

            <!-- Loading State -->
            <div v-if="loading" class="text-center py-8">
              <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
              <p class="mt-2 text-gray-600">Loading productivity rates...</p>
            </div>

            <!-- Error State -->
            <div v-else-if="error" class="bg-red-50 border border-red-200 rounded-lg p-4 mb-6">
              <p class="text-red-600">Error loading productivity rates: {{ error }}</p>
            </div>

            <!-- Productivity Rates Table -->
            <div v-else class="overflow-x-auto">
              <table class="w-full border-collapse">
                <thead>
                  <tr class="bg-gray-50">
                    <th class="border border-gray-200 px-4 py-3 text-left text-sm font-medium text-gray-700">Job Function</th>
                    <th class="border border-gray-200 px-4 py-3 text-left text-sm font-medium text-gray-700">Productivity Rate</th>
                    <th class="border border-gray-200 px-4 py-3 text-left text-sm font-medium text-gray-700">Unit of Measure</th>
                    <th class="border border-gray-200 px-4 py-3 text-left text-sm font-medium text-gray-700">Custom Unit</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="jobFunction in jobFunctions" :key="jobFunction.id">
                    <td class="border border-gray-200 px-4 py-3">
                      <div class="flex items-center space-x-3">
                        <div 
                          class="w-4 h-4 rounded border border-gray-300" 
                          :style="{ backgroundColor: jobFunction.color_code }"
                        ></div>
                        <span class="font-medium text-gray-800">{{ jobFunction.name }}</span>
                      </div>
                    </td>
                    <td class="border border-gray-200 px-4 py-3">
                      <input 
                        type="number" 
                        :value="jobFunction.productivity_rate" 
                        @change="updateProductivityRate(jobFunction.id, $event.target.value)"
                        class="w-20 px-2 py-1 border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500"
                      />
                    </td>
                    <td class="border border-gray-200 px-4 py-3">
                      <select 
                        :value="jobFunction.unit_of_measure" 
                        @change="updateUnitOfMeasure(jobFunction.id, $event.target.value)"
                        class="px-2 py-1 border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500"
                      >
                        <option value="">Select unit</option>
                        <option value="cartons/hour">Cartons/Hour</option>
                        <option value="boxes/hour">Boxes/Hour</option>
                        <option value="units/hour">Units/Hour</option>
                        <option value="pieces/hour">Pieces/Hour</option>
                        <option value="orders/hour">Orders/Hour</option>
                        <option value="pallets/hour">Pallets/Hour</option>
                        <option value="cases/hour">Cases/Hour</option>
                        <option value="items/hour">Items/Hour</option>
                        <option value="custom">Custom</option>
                      </select>
                    </td>
                    <td class="border border-gray-200 px-4 py-3">
                      <input 
                        type="text" 
                        :value="jobFunction.custom_unit" 
                        @change="updateCustomUnit(jobFunction.id, $event.target.value)"
                        placeholder="Custom unit" 
                        class="w-32 px-2 py-1 border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500"
                      />
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Job Function Modal -->
    <div v-if="showJobFunctionModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4">
        <h3 class="text-xl font-bold mb-4">
          {{ editingJobFunction ? 'Edit Job Function' : 'Add New Job Function' }}
        </h3>
        <form @submit.prevent="handleJobFunctionSubmit" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Name</label>
            <input
              v-model="jobFunctionFormData.name"
              type="text"
              required
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Color</label>
            <input
              v-model="jobFunctionFormData.color_code"
              type="color"
              class="w-full h-10 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Productivity Rate</label>
            <input
              v-model="jobFunctionFormData.productivity_rate"
              type="number"
              min="0"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Unit of Measure</label>
            <select
              v-model="jobFunctionFormData.unit_of_measure"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="">Select unit</option>
              <option value="cartons/hour">Cartons/Hour</option>
              <option value="boxes/hour">Boxes/Hour</option>
              <option value="units/hour">Units/Hour</option>
              <option value="pieces/hour">Pieces/Hour</option>
              <option value="orders/hour">Orders/Hour</option>
              <option value="pallets/hour">Pallets/Hour</option>
              <option value="cases/hour">Cases/Hour</option>
              <option value="items/hour">Items/Hour</option>
              <option value="custom">Custom</option>
            </select>
          </div>
          <div v-if="jobFunctionFormData.unit_of_measure === 'custom'">
            <label class="block text-sm font-medium text-gray-700 mb-1">Custom Unit</label>
            <input
              v-model="jobFunctionFormData.custom_unit"
              type="text"
              placeholder="Enter custom unit"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <div class="flex items-center">
            <input
              v-model="jobFunctionFormData.is_active"
              type="checkbox"
              id="jobFunction_active"
              class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
            />
            <label for="jobFunction_active" class="ml-2 block text-sm text-gray-700">
              Active
            </label>
          </div>
          <div class="flex justify-end space-x-3 pt-4">
            <button
              type="button"
              @click="closeJobFunctionModal"
              class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50"
            >
              Cancel
            </button>
            <button
              type="submit"
              class="btn-primary"
            >
              {{ editingJobFunction ? 'Update' : 'Create' }}
            </button>
          </div>
        </form>
      </div>
    </div>

    <!-- Shift Modal -->
    <div v-if="showShiftModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div class="bg-white rounded-lg p-6 max-w-lg w-full mx-4">
        <h3 class="text-xl font-bold mb-4">
          {{ editingShift ? 'Edit Shift' : 'Add New Shift' }}
        </h3>
        <form @submit.prevent="handleShiftSubmit" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Shift Name</label>
            <input
              v-model="shiftFormData.name"
              type="text"
              required
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Start Time</label>
              <input
                v-model="shiftFormData.start_time"
                type="time"
                required
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">End Time</label>
              <input
                v-model="shiftFormData.end_time"
                type="time"
                required
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
          </div>
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Break 1 Start</label>
              <input
                v-model="shiftFormData.break_1_start"
                type="time"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Break 1 End</label>
              <input
                v-model="shiftFormData.break_1_end"
                type="time"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
          </div>
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Break 2 Start</label>
              <input
                v-model="shiftFormData.break_2_start"
                type="time"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Break 2 End</label>
              <input
                v-model="shiftFormData.break_2_end"
                type="time"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
          </div>
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Lunch Start</label>
              <input
                v-model="shiftFormData.lunch_start"
                type="time"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Lunch End</label>
              <input
                v-model="shiftFormData.lunch_end"
                type="time"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
          </div>
          <div class="flex items-center">
            <input
              v-model="shiftFormData.is_active"
              type="checkbox"
              id="shift_active"
              class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
            />
            <label for="shift_active" class="ml-2 block text-sm text-gray-700">
              Active
            </label>
          </div>
          <div class="flex justify-end space-x-3 pt-4">
            <button
              type="button"
              @click="closeShiftModal"
              class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50"
            >
              Cancel
            </button>
            <button
              type="submit"
              class="btn-primary"
            >
              {{ editingShift ? 'Update' : 'Create' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const activeTab = ref('job-functions')

// Composables
const { 
  jobFunctions, 
  loading: jobFunctionsLoading, 
  error: jobFunctionsError, 
  fetchJobFunctions, 
  createJobFunction, 
  updateJobFunction, 
  deleteJobFunction 
} = useJobFunctions()

const { 
  shifts, 
  loading: shiftsLoading, 
  error: shiftsError, 
  fetchShifts, 
  createShift, 
  updateShift, 
  deleteShift 
} = useSchedule()

// Modal states
const showJobFunctionModal = ref(false)
const showShiftModal = ref(false)
const editingJobFunction = ref(null)
const editingShift = ref(null)

// Form data
const jobFunctionFormData = ref({
  name: '',
  color_code: '#3B82F6',
  productivity_rate: null,
  unit_of_measure: '',
  custom_unit: '',
  is_active: true,
  sort_order: 0
})

const shiftFormData = ref({
  name: '',
  start_time: '',
  end_time: '',
  break_1_start: null,
  break_1_end: null,
  break_2_start: null,
  break_2_end: null,
  lunch_start: null,
  lunch_end: null,
  is_active: true
})

// Loading and error states
const loading = computed(() => jobFunctionsLoading.value || shiftsLoading.value)
const error = computed(() => jobFunctionsError.value || shiftsError.value)

// Job Functions functions
const openAddJobFunctionModal = () => {
  editingJobFunction.value = null
  jobFunctionFormData.value = {
    name: '',
    color_code: '#3B82F6',
    productivity_rate: null,
    unit_of_measure: '',
    custom_unit: '',
    is_active: true,
    sort_order: jobFunctions.value.length
  }
  showJobFunctionModal.value = true
}

const openEditJobFunctionModal = (jobFunction) => {
  editingJobFunction.value = jobFunction
  jobFunctionFormData.value = {
    name: jobFunction.name,
    color_code: jobFunction.color_code,
    productivity_rate: jobFunction.productivity_rate,
    unit_of_measure: jobFunction.unit_of_measure || '',
    custom_unit: jobFunction.custom_unit || '',
    is_active: jobFunction.is_active,
    sort_order: jobFunction.sort_order
  }
  showJobFunctionModal.value = true
}

const closeJobFunctionModal = () => {
  showJobFunctionModal.value = false
  editingJobFunction.value = null
}

const handleJobFunctionSubmit = async () => {
  try {
    if (editingJobFunction.value) {
      await updateJobFunction(editingJobFunction.value.id, jobFunctionFormData.value)
    } else {
      await createJobFunction(jobFunctionFormData.value)
    }
    closeJobFunctionModal()
  } catch (e) {
    console.error('Error saving job function:', e)
  }
}

const deleteJobFunctionHandler = async (jobFunctionId) => {
  if (confirm('Are you sure you want to delete this job function?')) {
    await deleteJobFunction(jobFunctionId)
  }
}

// Shifts functions
const openAddShiftModal = () => {
  editingShift.value = null
  shiftFormData.value = {
    name: '',
    start_time: '',
    end_time: '',
    break_1_start: null,
    break_1_end: null,
    break_2_start: null,
    break_2_end: null,
    lunch_start: null,
    lunch_end: null,
    is_active: true
  }
  showShiftModal.value = true
}

const openEditShiftModal = (shift) => {
  editingShift.value = shift
  shiftFormData.value = {
    name: shift.name,
    start_time: shift.start_time,
    end_time: shift.end_time,
    break_1_start: shift.break_1_start,
    break_1_end: shift.break_1_end,
    break_2_start: shift.break_2_start,
    break_2_end: shift.break_2_end,
    lunch_start: shift.lunch_start,
    lunch_end: shift.lunch_end,
    is_active: shift.is_active
  }
  showShiftModal.value = true
}

const closeShiftModal = () => {
  showShiftModal.value = false
  editingShift.value = null
}

const handleShiftSubmit = async () => {
  try {
    if (editingShift.value) {
      await updateShift(editingShift.value.id, shiftFormData.value)
    } else {
      await createShift(shiftFormData.value)
    }
    closeShiftModal()
  } catch (e) {
    console.error('Error saving shift:', e)
  }
}

const deleteShiftHandler = async (shiftId) => {
  if (confirm('Are you sure you want to delete this shift?')) {
    await deleteShift(shiftId)
  }
}

// Productivity rates functions
const updateProductivityRate = async (jobFunctionId, rate) => {
  await updateJobFunction(jobFunctionId, { productivity_rate: rate })
}

const updateUnitOfMeasure = async (jobFunctionId, unit) => {
  await updateJobFunction(jobFunctionId, { unit_of_measure: unit })
}

const updateCustomUnit = async (jobFunctionId, customUnit) => {
  await updateJobFunction(jobFunctionId, { custom_unit: customUnit })
}

// Initialize data
onMounted(async () => {
  await Promise.all([
    fetchJobFunctions(false), // Get all job functions including inactive
    fetchShifts()
  ])
})
</script>

