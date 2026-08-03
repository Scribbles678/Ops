<template>
  <div class="details-page min-h-screen bg-gray-50">
    <div class="container mx-auto px-4 py-6 md:py-8">
      <!-- Header -->
      <div class="flex items-center justify-between mb-5">
        <h1 class="text-2xl md:text-3xl font-semibold text-gray-800">Details & Settings</h1>
        <NuxtLink to="/" class="btn-secondary">
          ← Back to Home
        </NuxtLink>
      </div>

      <!-- Tabs -->
      <div class="mb-5">
        <div class="border-b border-gray-200">
          <nav class="-mb-px flex flex-wrap gap-2 md:gap-4">
            <button
              @click="activeTab = 'job-functions'"
              :class="[
                'py-2 md:py-3 px-1 border-b-2 font-medium text-sm transition',
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
                'py-2 md:py-3 px-1 border-b-2 font-medium text-sm transition',
                activeTab === 'shifts'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              ]"
            >
              Shift Management
            </button>
            <button
              @click="activeTab = 'target-hours'"
              :class="[
                'py-2 md:py-3 px-1 border-b-2 font-medium text-sm transition',
                activeTab === 'target-hours'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              ]"
            >
              Target Hours
            </button>
          </nav>
        </div>
      </div>

      <!-- Tab Content -->
      <div class="card">
        <!-- Job Functions Tab -->
        <div v-if="activeTab === 'job-functions'">
          <div class="p-4 md:p-5">
            <div class="flex justify-between items-center mb-4">
              <h2 class="text-xl md:text-2xl font-semibold text-gray-800">Job Functions</h2>
              <button @click="openAddJobFunctionModal" class="btn-primary">
                + Add New Job Function
              </button>
            </div>

            <!-- Loading State -->
            <div v-if="loading" class="text-center py-6">
              <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
              <p class="mt-2 text-gray-600">Loading job functions...</p>
            </div>

            <!-- Error State -->
            <div v-else-if="error" class="bg-red-50 border border-red-200 rounded-lg p-3 mb-4 text-sm">
              <p class="text-red-600">Error loading job functions: {{ error }}</p>
            </div>

            <!-- Job Functions List -->
            <div v-else class="space-y-3">
              <div 
                v-for="jobFunction in jobFunctions" 
                :key="jobFunction.id"
                class="border border-gray-200 rounded-lg p-3 md:p-4 hover:shadow-md transition"
              >
                <div class="flex items-center justify-between">
                  <div class="flex items-center space-x-3 md:space-x-4">
                    <div 
                      class="w-10 h-10 md:w-12 md:h-12 rounded border border-gray-300" 
                      :style="{ backgroundColor: jobFunction.color_code }"
                    ></div>
                    <div>
                      <h3 class="text-base md:text-lg font-semibold text-gray-800 flex items-center gap-2">
                        {{ jobFunction.name }}
                        <span
                          v-if="(jobFunction.staffing_priority ?? 3) !== 3"
                          :class="priorityBadgeClass(jobFunction.staffing_priority)"
                          class="px-1.5 py-0.5 rounded text-[11px] font-medium"
                        >{{ priorityLabel(jobFunction.staffing_priority) }}</span>
                      </h3>
                      <p class="text-xs md:text-sm text-gray-600">
                        <span class="font-medium text-gray-700">Rate:</span>
                        <span v-if="jobFunction.productivity_rate !== null && jobFunction.productivity_rate !== undefined">
                          {{ jobFunction.productivity_rate }}
                        </span>
                        <span v-else>N/A</span>
                        <span v-if="getJobFunctionUnitLabel(jobFunction)" class="ml-1">
                          {{ getJobFunctionUnitLabel(jobFunction) }}
                        </span>
                      </p>
                    </div>
                  </div>
                  <div class="flex space-x-2">
                    <button 
                      @click="openEditJobFunctionModal(jobFunction)"
                      class="px-3 py-1.5 text-sm bg-blue-100 text-blue-600 rounded hover:bg-blue-200 transition"
                    >
                      Edit
                    </button>
                    <button 
                      @click="deleteJobFunctionHandler(jobFunction.id)"
                      class="px-3 py-1.5 text-sm bg-red-100 text-red-600 rounded hover:bg-red-200 transition"
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
          <div class="p-4 md:p-5">
            <div class="flex justify-between items-center mb-4">
              <h2 class="text-xl md:text-2xl font-semibold text-gray-800">Shift Management</h2>
              <button @click="openAddShiftModal" class="btn-primary">
                + Add New Shift
              </button>
            </div>

            <!-- Loading State -->
            <div v-if="loading" class="text-center py-6">
              <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
              <p class="mt-2 text-gray-600">Loading shifts...</p>
            </div>

            <!-- Error State -->
            <div v-else-if="error" class="bg-red-50 border border-red-200 rounded-lg p-3 mb-4 text-sm">
              <p class="text-red-600">Error loading shifts: {{ error }}</p>
            </div>

            <!-- Shifts List -->
            <div v-else class="space-y-3">
              <div 
                v-for="shift in shifts" 
                :key="shift.id"
                class="border border-gray-200 rounded-lg p-3 md:p-4 hover:shadow-md transition"
              >
                <div class="flex justify-between items-start">
                  <div class="flex-1">
                    <h3 class="text-base md:text-lg font-semibold text-gray-800 mb-2">{{ shift.name }}</h3>
                    <div class="grid grid-cols-2 md:grid-cols-3 gap-3 text-xs md:text-sm">
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
                      class="px-3 py-1.5 text-sm bg-blue-100 text-blue-600 rounded hover:bg-blue-200 transition"
                    >
                      Edit
                    </button>
                    <button 
                      @click="deleteShiftHandler(shift.id)"
                      class="px-3 py-1.5 text-sm bg-red-100 text-red-600 rounded hover:bg-red-200 transition"
                    >
                      Delete
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Target Hours Tab -->
        <div v-else-if="activeTab === 'target-hours'">
          <div class="p-4 md:p-5">
            <div class="flex justify-between items-center mb-6">
              <h2 class="text-2xl font-bold text-gray-800">Target Hours</h2>
              <button 
                @click="saveTargetHours" 
                :disabled="targetHoursLoading"
                class="btn-primary disabled:opacity-50 disabled:cursor-not-allowed flex items-center"
              >
                <svg v-if="targetHoursLoading" class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                {{ targetHoursLoading ? 'Saving...' : 'Save Changes' }}
              </button>
            </div>

            <!-- Loading State -->
            <div v-if="loading" class="text-center py-8">
              <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
              <p class="mt-2 text-gray-600">Loading target hours...</p>
            </div>

            <!-- Error State -->
            <div v-else-if="error" class="bg-red-50 border border-red-200 rounded-lg p-4 mb-6">
              <p class="text-red-600">Error loading target hours: {{ error }}</p>
            </div>

            <!-- Target Hours Table -->
            <div v-else class="overflow-x-auto">
              <table class="w-full border-collapse">
                <thead>
                  <tr class="bg-gray-50">
                    <th class="border border-gray-200 px-4 py-3 text-left text-sm font-medium text-gray-700">Job Function</th>
                    <th class="border border-gray-200 px-4 py-3 text-left text-sm font-medium text-gray-700">Target Hours</th>
                    <th class="border border-gray-200 px-4 py-3 text-left text-sm font-medium text-gray-700">Description</th>
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
                        :value="getTargetHours(jobFunction.id)" 
                        @change="updateTargetHours(jobFunction.id, $event.target.value)"
                        min="0"
                        step="0.25"
                        class="w-20 px-2 py-1 border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500"
                      />
                    </td>
                    <td class="border border-gray-200 px-4 py-3">
                      <span class="text-sm text-gray-600">
                        Daily target hours for {{ jobFunction.name.toLowerCase() }} operations
                      </span>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>

            <!-- Help Text -->
            <div class="mt-6 p-4 bg-blue-50 border border-blue-200 rounded-lg">
              <h4 class="font-semibold text-blue-800 mb-2">About Target Hours</h4>
              <p class="text-sm text-blue-700">
                Target hours represent the ideal number of hours each job function should be staffed per day. 
                These values are used to compare against actual scheduled hours in the schedule view.
              </p>
            </div>

          </div>
        </div>

      </div>
    </div>

    <!-- Notification Modal -->
    <div v-if="showNotificationModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div class="bg-white rounded-lg p-4 md:p-5 max-w-md w-full mx-4 shadow-xl">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-xl font-bold text-gray-800">{{ notificationType === 'success' ? '✅ Success' : '❌ Error' }}</h3>
          <button @click="closeNotificationModal" class="text-gray-400 hover:text-gray-600">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
        <div :class="notificationType === 'success' ? 'bg-green-50 border border-green-200 rounded-lg p-4 mb-4' : 'bg-red-50 border border-red-200 rounded-lg p-4 mb-4'">
          <p :class="notificationType === 'success' ? 'text-green-800' : 'text-red-800'" class="text-sm">{{ notificationMessage }}</p>
        </div>
        <div class="flex justify-end">
          <button
            @click="closeNotificationModal"
            :class="notificationType === 'success' ? 'px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium' : 'px-6 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors font-medium'"
          >
            OK
          </button>
        </div>
      </div>
    </div>

    <!-- Job Function Modal -->
    <div v-if="showJobFunctionModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div class="bg-white rounded-lg p-4 md:p-5 max-w-md w-full mx-4">
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
              v-model.number="jobFunctionFormData.productivity_rate"
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
          <div class="flex items-center space-x-2.5">
            <input
              id="jobFunction_exclude_from_targets"
              v-model="jobFunctionFormData.exclude_from_targets"
              type="checkbox"
              class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
            />
            <label for="jobFunction_exclude_from_targets" class="block text-sm font-medium text-gray-700">
              Exclude from staffing targets grid
              <span class="block text-xs font-normal text-gray-500">Use for roles handled by Required Assignments (e.g. Coordinator, TL)</span>
            </label>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Max people at once (per hour)</label>
            <input
              v-model.number="jobFunctionFormData.max_headcount"
              type="number"
              min="0"
              placeholder="No limit"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
            <span class="block text-xs text-gray-500 mt-1">Builder never assigns more than this many people to this function in any hour. Leave blank for no limit.</span>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Staffing priority</label>
            <select
              v-model.number="jobFunctionFormData.staffing_priority"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option :value="1">1 — Critical (fill first)</option>
              <option :value="2">2 — High</option>
              <option :value="3">3 — Normal</option>
              <option :value="4">4 — Low</option>
              <option :value="5">5 — Optional (drop first)</option>
            </select>
            <span class="block text-xs text-gray-500 mt-1">When there aren't enough people to cover everything, the V2 builder fills higher-priority functions first and lets the lowest ones go short.</span>
          </div>
          <div class="flex items-center space-x-2.5">
            <input
              id="jobFunction_surplus_overflow"
              v-model="jobFunctionFormData.surplus_overflow"
              type="checkbox"
              class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
            />
            <label for="jobFunction_surplus_overflow" class="block text-sm font-medium text-gray-700">
              Surplus overflow function
              <span class="block text-xs font-normal text-gray-500">After targets are met, extra workers flow into this function first (e.g. Pick, Projects)</span>
            </label>
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
      <div class="bg-white rounded-lg p-4 md:p-5 max-w-lg w-full mx-4">
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

const { 
  employees, 
  fetchEmployees: fetchEmployeesForDetails, 
  loading: employeesLoading 
} = useEmployees()


// Target hours composables
const {
  fetchTargetHours: fetchTargetHoursFromApi,
  saveTargetHours: saveTargetHoursToApi
} = useSchedule()

// Target hours state
const targetHours = ref({})
const targetHoursLoading = ref(false)

// Notification modal state
const showNotificationModal = ref(false)
const notificationMessage = ref('')
const notificationType = ref<'success' | 'error'>('success')

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
  sort_order: 0,
  exclude_from_targets: false,
  max_headcount: null,
  surplus_overflow: false,
  staffing_priority: 3
})

const PRIORITY_LABELS = {
  1: 'Priority 1 · Critical',
  2: 'Priority 2 · High',
  4: 'Priority 4 · Low',
  5: 'Priority 5 · Optional'
}

const priorityLabel = (p) => PRIORITY_LABELS[p ?? 3] ?? ''

const priorityBadgeClass = (p) =>
  (p ?? 3) <= 2 ? 'bg-amber-100 text-amber-700' : 'bg-gray-100 text-gray-600'

const getJobFunctionUnitLabel = (jobFunction) => {
  if (!jobFunction) return ''
  if (jobFunction.unit_of_measure === 'custom') {
    return jobFunction.custom_unit || ''
  }
  return jobFunction.unit_of_measure || ''
}

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
    sort_order: jobFunctions.value.length,
    exclude_from_targets: false,
    max_headcount: null,
    surplus_overflow: false,
    staffing_priority: 3
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
    sort_order: jobFunction.sort_order,
    exclude_from_targets: jobFunction.exclude_from_targets ?? false,
    max_headcount: jobFunction.max_headcount ?? null,
    surplus_overflow: jobFunction.surplus_overflow ?? false,
    staffing_priority: jobFunction.staffing_priority ?? 3
  }
  showJobFunctionModal.value = true
}

const closeJobFunctionModal = () => {
  showJobFunctionModal.value = false
  editingJobFunction.value = null
}

const handleJobFunctionSubmit = async () => {
  try {
    if (jobFunctionFormData.value.unit_of_measure !== 'custom') {
      jobFunctionFormData.value.custom_unit = ''
    }
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

// Target hours functions
const getTargetHours = (jobFunctionId) => {
  return targetHours.value[jobFunctionId] || 8.00
}

const updateTargetHours = async (jobFunctionId, hours) => {
  try {
    // Only update local state, don't save yet
    targetHours.value[jobFunctionId] = parseFloat(hours) || 0
    console.log(`Updated local target hours for job function ${jobFunctionId} to ${hours}`)
  } catch (error) {
    console.error('Error updating target hours:', error)
  }
}

const fetchTargetHours = async () => {
  try {
    targetHoursLoading.value = true
    const data = await fetchTargetHoursFromApi()
    const targetHoursData = { ...data }
    jobFunctions.value.forEach((jf: any) => {
      if (!(jf.id in targetHoursData)) targetHoursData[jf.id] = 8.00
    })
    targetHours.value = targetHoursData
  } catch {
    const defaultTargetHours: Record<string, number> = {}
    jobFunctions.value.forEach((jf: any) => { defaultTargetHours[jf.id] = 8.00 })
    targetHours.value = defaultTargetHours
  } finally {
    targetHoursLoading.value = false
  }
}

const saveTargetHours = async () => {
  try {
    targetHoursLoading.value = true
    const allTargetHours = { ...targetHours.value }
    jobFunctions.value.forEach((jf: any) => {
      if (!(jf.id in allTargetHours)) allTargetHours[jf.id] = 8.00
    })
    const items = Object.entries(allTargetHours).map(([job_function_id, target_hours]) => ({
      job_function_id,
      target_hours: parseFloat(String(target_hours)) || 0
    }))
    const ok = await saveTargetHoursToApi(items)
    if (!ok) throw new Error('Save failed')
    targetHours.value = allTargetHours
    showNotification('Target hours saved successfully!', 'success')
  } catch {
    showNotification('Error saving target hours. Please try again.', 'error')
  } finally {
    targetHoursLoading.value = false
  }
}

// Notification modal functions
const showNotification = (message: string, type: 'success' | 'error' = 'success') => {
  notificationMessage.value = message
  notificationType.value = type
  showNotificationModal.value = true
}

const closeNotificationModal = () => {
  showNotificationModal.value = false
}


// Initialize data
onMounted(async () => {
  await Promise.all([
    fetchJobFunctions(false), // Get all job functions including inactive
    fetchShifts(),
    fetchEmployeesForDetails(false) // Get all employees including inactive
  ])
})

// Load per-tab data on demand
watch(activeTab, async (newTab) => {
  if (newTab === 'target-hours') {
    await fetchTargetHours()
  }
})
</script>

