<template>
  <div class="business-rules-page min-h-screen bg-gray-50">
    <div class="container mx-auto px-3 md:px-4 py-4 md:py-6">
      <!-- Header -->
      <div class="flex items-center justify-between mb-4 md:mb-6">
        <div>
          <h1 class="text-2xl md:text-3xl font-semibold text-gray-800 leading-tight">Business Rules</h1>
          <p class="text-gray-600 mt-1 text-xs md:text-sm">Configure AI schedule generation rules</p>
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

      <!-- Add New Rule Button and Preferred Assignments Button -->
      <div class="mb-4 flex flex-wrap gap-2">
        <button
          @click="openAddModal"
          class="btn-primary-sm md:btn-primary flex items-center"
        >
          <svg class="w-4 h-4 md:w-5 md:h-5 mr-1.5 md:mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
          </svg>
          Add Business Rule
        </button>
        <button
          @click="openPreferredAssignmentsModal"
          class="btn-secondary-sm md:btn-secondary flex items-center"
        >
          <svg class="w-4 h-4 md:w-5 md:h-5 mr-1.5 md:mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
          </svg>
          Preferred Assignments
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

      <!-- Rules Table -->
      <div class="card p-3 md:p-4">
        <div v-if="loading" class="text-center py-5 text-sm text-gray-600">
          Loading rules...
        </div>
        
        <div v-else-if="error" class="text-center py-5 text-sm text-red-600">
          Error: {{ error }}
        </div>

        <div v-else-if="businessRules.length === 0" class="text-center py-5 text-sm text-gray-600">
          No business rules found. Click "Add Business Rule" to create one.
        </div>

        <div v-else class="overflow-x-auto -mx-1 md:-mx-2">
          <table class="min-w-full divide-y divide-gray-200 text-xs md:text-sm">
            <thead class="bg-gray-50 text-xs uppercase tracking-wide text-gray-500">
              <tr>
                <th class="px-3 md:px-4 py-2 text-left">Job Function</th>
                <th class="px-3 md:px-4 py-2 text-left">Time Slot</th>
                <th class="px-3 md:px-4 py-2 text-left">Min Staff</th>
                <th class="px-3 md:px-4 py-2 text-left">Max Staff</th>
                <th class="px-3 md:px-4 py-2 text-left">Block Size</th>
                <th class="px-3 md:px-4 py-2 text-left">Status</th>
                <th class="px-3 md:px-4 py-2 text-left">Notes</th>
                <th class="px-3 md:px-4 py-2 text-right">Actions</th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <tr v-for="rule in sortedRules" :key="rule.id" :class="{ 'bg-gray-50': !rule.is_active }">
                <td class="px-3 md:px-4 py-2 whitespace-nowrap font-medium text-gray-900">
                  <div class="flex items-center space-x-2">
                    <span>{{ rule.job_function_name }}</span>
                    <span
                      v-if="rule.fan_out_enabled"
                      class="px-1.5 py-0.5 text-[10px] uppercase tracking-wide bg-blue-100 text-blue-700 rounded-full"
                    >
                      Fan-out
                    </span>
                  </div>
                </td>
                <td class="px-3 md:px-4 py-2 whitespace-nowrap text-gray-600">
                  {{ formatTime(rule.time_slot_start) }} - {{ formatTime(rule.time_slot_end) }}
                </td>
                <td class="px-3 md:px-4 py-2 whitespace-nowrap text-gray-600">
                  <span v-if="rule.min_staff !== null">{{ rule.min_staff }}</span>
                  <span v-else class="text-gray-400 italic">Global Max</span>
                </td>
                <td class="px-3 md:px-4 py-2 whitespace-nowrap text-gray-600">{{ rule.max_staff || '-' }}</td>
                <td class="px-3 md:px-4 py-2 whitespace-nowrap text-gray-600">{{ rule.block_size_minutes }} min</td>
                <td class="px-3 md:px-4 py-2 whitespace-nowrap">
                  <span 
                    class="px-1.5 py-0.5 inline-flex text-[10px] leading-4 font-semibold rounded-full"
                    :class="rule.is_active ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-600'"
                  >
                    {{ rule.is_active ? 'Active' : 'Inactive' }}
                  </span>
                </td>
                <td class="px-3 md:px-4 py-2 text-gray-600">{{ rule.notes || '-' }}</td>
                <td class="px-3 md:px-4 py-2 whitespace-nowrap text-right font-medium space-x-2">
                  <button
                    @click="editRule(rule)"
                    class="text-blue-600 hover:text-blue-800 text-xs"
                  >
                    Edit
                  </button>
                  <button
                    @click="deleteRule(rule.id)"
                    class="text-red-600 hover:text-red-800 text-xs"
                  >
                    Delete
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- Add/Edit Modal -->
      <div v-if="showModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-white rounded-lg p-4 md:p-5 max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto">
          <h3 class="text-lg md:text-xl font-semibold mb-3">
            {{ editingRule ? 'Edit Business Rule' : 'Add Business Rule' }}
          </h3>

          <div class="space-y-3">
            <!-- Job Function -->
            <div>
              <label class="block text-xs md:text-sm font-medium text-gray-700 mb-1">Job Function Name</label>
              <select
                v-model="ruleForm.job_function_name"
                class="w-full px-3 py-1.5 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"
                :disabled="editingRule !== null"
              >
                <option value="">Select a job function...</option>
                <option v-for="jf in sortedJobFunctions" :key="jf.id" :value="jf.name">
                  {{ jf.name }}
                </option>
              </select>
              <p class="mt-1 text-xs text-gray-500">
                {{ editingRule ? 'Job function cannot be changed when editing' : 'Must match exactly with job function names in your system' }}
              </p>
            </div>

            <!-- Time Slot -->
            <div class="grid grid-cols-2 gap-3">
              <div>
                <label class="block text-xs md:text-sm font-medium text-gray-700 mb-1">Start Time</label>
                <input
                  v-model="ruleForm.time_slot_start"
                  type="time"
                  class="w-full px-3 py-1.5 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"
                />
              </div>
              <div>
                <label class="block text-xs md:text-sm font-medium text-gray-700 mb-1">End Time</label>
                <input
                  v-model="ruleForm.time_slot_end"
                  type="time"
                  class="w-full px-3 py-1.5 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"
                />
              </div>
            </div>

            <!-- Rule Type Toggle -->
            <div class="flex items-center gap-4">
              <label class="flex items-center">
                <input
                  v-model="isGlobalMax"
                  type="checkbox"
                  class="h-4 w-4 text-blue-600 border-gray-300 rounded"
                />
                <span class="ml-2 text-xs md:text-sm text-gray-700">Global Max Limit (no minimum staff)</span>
              </label>
            </div>

            <!-- Min/Max Staff -->
            <div class="grid grid-cols-2 gap-3" v-if="!isGlobalMax">
              <div>
              <label class="block text-xs md:text-sm font-medium text-gray-700 mb-1">Min Staff</label>
                <input
                  v-model.number="ruleForm.min_staff"
                  type="number"
                  min="0"
                  class="w-full px-3 py-1.5 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"
                />
              </div>
              <div>
              <label class="block text-xs md:text-sm font-medium text-gray-700 mb-1">Max Staff (optional)</label>
                <input
                  v-model.number="ruleForm.max_staff"
                  type="number"
                  min="0"
                  class="w-full px-3 py-1.5 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"
                  placeholder="Leave empty for no limit"
                />
              </div>
            </div>

            <!-- Max Staff Only (for Global Max) -->
            <div v-if="isGlobalMax">
              <label class="block text-xs md:text-sm font-medium text-gray-700 mb-1">Max Staff</label>
              <input
                v-model.number="ruleForm.max_staff"
                type="number"
                min="1"
                class="w-full px-3 py-1.5 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"
              />
              <p class="mt-1 text-xs text-gray-500">Global maximum staff for this job function across all time slots</p>
            </div>

            <!-- Block Size -->
            <div v-if="!isGlobalMax">
              <label class="block text-xs md:text-sm font-medium text-gray-700 mb-1">Block Size (minutes)</label>
              <input
                v-model.number="ruleForm.block_size_minutes"
                type="number"
                min="0"
                class="w-full px-3 py-1.5 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"
                placeholder="e.g., 390 for 6.5 hours"
              />
            </div>

            <!-- Priority -->
            <div>
              <label class="block text-xs md:text-sm font-medium text-gray-700 mb-1">Priority</label>
              <input
                v-model.number="ruleForm.priority"
                type="number"
                min="0"
                class="w-full px-3 py-1.5 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"
              />
              <p class="mt-1 text-xs text-gray-500">Lower numbers are processed first. 0 = highest priority.</p>
            </div>

            <!-- Fan-out Rules -->
            <div class="border border-blue-200 rounded-md bg-blue-50/70 px-3 py-2 space-y-2">
              <label class="flex items-center text-xs md:text-sm font-medium text-blue-800">
                <input
                  type="checkbox"
                  v-model="ruleForm.fan_out_enabled"
                  class="h-4 w-4 text-blue-600 border-blue-300 rounded focus:ring-blue-500"
                />
                <span class="ml-2">Apply this rule to matching job functions</span>
              </label>
              <p class="text-[11px] md:text-xs text-blue-700">
                When enabled, the AI will duplicate this rule for every active job function whose name begins with the prefix below.
                Min/Max values apply to each station individually.
              </p>
              <input
                v-model="ruleForm.fan_out_prefix"
                :disabled="!ruleForm.fan_out_enabled"
                type="text"
                placeholder="e.g., Meter "
                class="w-full px-3 py-1.5 border border-blue-200 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm disabled:bg-blue-50 disabled:text-blue-300"
              />
            </div>

            <!-- Active Status -->
            <div class="flex items-center">
              <input
                v-model="ruleForm.is_active"
                type="checkbox"
                class="h-4 w-4 text-blue-600 border-gray-300 rounded"
                id="is_active"
              />
              <label for="is_active" class="ml-2 text-sm text-gray-700">Active (inactive rules are ignored)</label>
            </div>

            <!-- Notes -->
            <div>
              <label class="block text-xs md:text-sm font-medium text-gray-700 mb-1">Notes (optional)</label>
              <textarea
                v-model="ruleForm.notes"
                rows="2"
                class="w-full px-3 py-1.5 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"
                placeholder="e.g., Morning pick coverage"
              ></textarea>
            </div>
          </div>

          <!-- Modal Actions -->
          <div class="flex justify-end space-x-2 mt-4">
            <button
              @click="closeModal"
              class="px-3 py-1.5 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 text-sm"
            >
              Cancel
            </button>
            <button
              @click="saveRule"
              :disabled="!ruleForm.job_function_name || (!isGlobalMax && (!ruleForm.min_staff || ruleForm.min_staff < 0)) || (isGlobalMax && !ruleForm.max_staff)"
              class="px-3 py-1.5 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed text-sm"
            >
              {{ editingRule ? 'Update Rule' : 'Create Rule' }}
            </button>
          </div>
        </div>
      </div>

      <!-- Preferred Assignments Modal -->
      <div v-if="showPreferredAssignmentsModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-white rounded-lg p-6 max-w-4xl w-full mx-4 max-h-[90vh] overflow-y-auto">
          <div class="flex items-center justify-between mb-6">
            <h3 class="text-2xl font-bold text-gray-800">Preferred Assignments</h3>
            <button @click="closePreferredAssignmentsModal" class="text-gray-400 hover:text-gray-600">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <!-- Add Button -->
          <div class="mb-6">
            <button @click="openAddPreferredAssignmentModal" class="btn-primary flex items-center">
              <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
              </svg>
              Add Preferred Assignment
            </button>
          </div>

          <!-- Loading State -->
          <div v-if="preferredAssignmentsLoading" class="text-center py-8">
            <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
            <p class="mt-2 text-gray-600">Loading preferred assignments...</p>
          </div>

          <!-- Error State -->
          <div v-else-if="preferredAssignmentsError" class="bg-red-50 border border-red-200 rounded-lg p-4 mb-6">
            <p class="text-red-600">Error loading preferred assignments: {{ preferredAssignmentsError }}</p>
          </div>

          <!-- Preferred Assignments List -->
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
                      <p class="text-sm text-gray-600">
                        Job Function: <span class="font-medium">{{ pref.job_function?.name }}</span>
                      </p>
                    </div>
                    <div class="flex items-center space-x-3">
                      <span 
                        v-if="pref.is_required"
                        class="px-2 py-1 bg-red-100 text-red-700 rounded text-xs font-semibold"
                      >
                        Required
                      </span>
                      <span 
                        v-else
                        class="px-2 py-1 bg-blue-100 text-blue-700 rounded text-xs font-semibold"
                      >
                        Preferred
                      </span>
                      <span 
                        v-if="pref.priority > 0"
                        class="px-2 py-1 bg-purple-100 text-purple-700 rounded text-xs font-semibold"
                      >
                        Priority: {{ pref.priority }}
                      </span>
                    </div>
                  </div>
                  <p v-if="pref.notes" class="text-sm text-gray-600 italic">{{ pref.notes }}</p>
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
              <p>No preferred assignments configured yet.</p>
              <p class="text-sm mt-2">Click "+ Add Preferred Assignment" to create one.</p>
            </div>
          </div>

          <!-- Add/Edit Preferred Assignment Modal -->
          <div v-if="showPreferredAssignmentFormModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-[60]">
            <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4 relative">
              <!-- Saved Icon Indicator -->
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
                {{ editingPreferredAssignment ? 'Edit Preferred Assignment' : 'Add Preferred Assignment' }}
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
                  <label class="block text-sm font-medium text-gray-700 mb-1">Job Function</label>
                  <select
                    v-model="preferredAssignmentFormData.job_function_id"
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
                <div class="flex items-center">
                  <input
                    v-model="preferredAssignmentFormData.is_required"
                    type="checkbox"
                    id="pref_required"
                    class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
                  />
                  <label for="pref_required" class="ml-2 block text-sm text-gray-700">
                    Required (employee should always be assigned to this function when available)
                  </label>
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Priority</label>
                  <input
                    v-model.number="preferredAssignmentFormData.priority"
                    type="number"
                    min="0"
                    max="100"
                    class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                  <p class="text-xs text-gray-500 mt-1">Higher priority = assigned first (0 = lowest priority)</p>
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Notes (optional)</label>
                  <textarea
                    v-model="preferredAssignmentFormData.notes"
                    rows="3"
                    class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                    placeholder="Add any notes about this preferred assignment..."
                  ></textarea>
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
const { 
  businessRules, 
  loading, 
  error, 
  fetchBusinessRules, 
  createBusinessRule, 
  updateBusinessRule, 
  deleteBusinessRule 
} = useBusinessRules()

const { jobFunctions, fetchJobFunctions } = useJobFunctions()
const { employees, fetchEmployees } = useEmployees()
const {
  preferredAssignments,
  loading: preferredAssignmentsLoading,
  error: preferredAssignmentsError,
  fetchPreferredAssignments,
  createPreferredAssignment,
  updatePreferredAssignment,
  deletePreferredAssignment
} = usePreferredAssignments()

const showModal = ref(false)
const editingRule = ref<any>(null)
const isGlobalMax = ref(false)

// Preferred Assignments Modal State
const showPreferredAssignmentsModal = ref(false)
const showPreferredAssignmentFormModal = ref(false)
const editingPreferredAssignment = ref<any>(null)
const preferredAssignmentFormData = ref({
  employee_id: '',
  job_function_id: '',
  is_required: false,
  priority: 0,
  notes: ''
})
const showSavedIcon = ref(false)
const showSuccessToast = ref(false)
const successToastMessage = ref('')
let successTimeout: ReturnType<typeof setTimeout> | null = null

const ruleForm = ref({
  job_function_name: '',
  time_slot_start: '08:00',
  time_slot_end: '17:00',
  min_staff: 1,
  max_staff: null as number | null,
  block_size_minutes: 240,
  priority: 0,
  is_active: true,
  notes: '',
  fan_out_enabled: false,
  fan_out_prefix: ''
})

const sortedRules = computed(() => {
  return [...businessRules.value].sort((a, b) => {
    if (a.job_function_name !== b.job_function_name) {
      return a.job_function_name.localeCompare(b.job_function_name)
    }
    if (a.priority !== b.priority) {
      return (a.priority || 0) - (b.priority || 0)
    }
    return a.time_slot_start.localeCompare(b.time_slot_start)
  })
})

const formatTime = (time: string | null | undefined) => {
  if (!time) return '-'
  const [hourPart = '0', minutePart = '00'] = String(time).split(':')
  let hour = parseInt(hourPart, 10)
  if (Number.isNaN(hour)) return '-'
  const minutes = minutePart.slice(0, 2)
  const period = hour >= 12 ? 'PM' : 'AM'
  hour = hour % 12
  if (hour === 0) hour = 12
  return `${hour}:${minutes} ${period}`
}

const sortedJobFunctions = computed(() => {
  return [...(jobFunctions.value || [])]
    .filter(jf => jf.is_active !== false)
    .sort((a, b) => {
      // Sort by name, but put individual meters last
      const aIsMeter = a.name?.startsWith('Meter ')
      const bIsMeter = b.name?.startsWith('Meter ')
      if (aIsMeter && !bIsMeter) return 1
      if (!aIsMeter && bIsMeter) return -1
      return (a.name || '').localeCompare(b.name || '')
    })
})

const openAddModal = () => {
  editingRule.value = null
  isGlobalMax.value = false
  ruleForm.value = {
    job_function_name: '',
    time_slot_start: '08:00',
    time_slot_end: '17:00',
    min_staff: 1,
    max_staff: null,
    block_size_minutes: 240,
    priority: 0,
    is_active: true,
    notes: '',
    fan_out_enabled: false,
    fan_out_prefix: ''
  }
  showModal.value = true
}

const editRule = (rule: any) => {
  editingRule.value = rule
  isGlobalMax.value = rule.min_staff === null
  ruleForm.value = {
    job_function_name: rule.job_function_name,
    time_slot_start: rule.time_slot_start,
    time_slot_end: rule.time_slot_end,
    min_staff: rule.min_staff,
    max_staff: rule.max_staff,
    block_size_minutes: rule.block_size_minutes || 0,
    priority: rule.priority || 0,
    is_active: rule.is_active,
    notes: rule.notes || '',
    fan_out_enabled: !!rule.fan_out_enabled,
    fan_out_prefix: rule.fan_out_prefix || ''
  }
  showModal.value = true
}

const closeModal = () => {
  showModal.value = false
  editingRule.value = null
  isGlobalMax.value = false
}

const saveRule = async () => {
  if (!ruleForm.value.job_function_name) {
    alert('Please enter a job function name')
    return
  }

  if (!isGlobalMax.value && (!ruleForm.value.min_staff || ruleForm.value.min_staff < 0)) {
    alert('Please enter a valid minimum staff count')
    return
  }

  if (ruleForm.value.fan_out_enabled && !ruleForm.value.fan_out_prefix?.trim()) {
    alert('Please enter a prefix to match job functions when fan-out is enabled.')
    return
  }

  const ruleData: any = {
    job_function_name: ruleForm.value.job_function_name.trim(),
    time_slot_start: ruleForm.value.time_slot_start,
    time_slot_end: ruleForm.value.time_slot_end,
    min_staff: isGlobalMax.value ? null : ruleForm.value.min_staff,
    max_staff: ruleForm.value.max_staff || null,
    block_size_minutes: isGlobalMax.value ? 0 : ruleForm.value.block_size_minutes,
    priority: ruleForm.value.priority || 0,
    is_active: ruleForm.value.is_active,
    notes: ruleForm.value.notes?.trim() || null,
    fan_out_enabled: !!ruleForm.value.fan_out_enabled,
    fan_out_prefix: ruleForm.value.fan_out_enabled
      ? (ruleForm.value.fan_out_prefix?.trim() || null)
      : null
  }

  try {
    if (editingRule.value) {
      await updateBusinessRule(editingRule.value.id, ruleData)
      showSuccessIndicator('Business rule updated')
    } else {
      await createBusinessRule(ruleData)
      showSuccessIndicator('Business rule created')
    }
    closeModal()
  } catch (e: any) {
    alert(`Error saving rule: ${e.message || 'Unknown error'}`)
  }
}

const deleteRule = async (id: string) => {
  try {
    const success = await deleteBusinessRule(id)
    if (!success) {
      alert('Error deleting rule. Please try again.')
      return
    }
    showSuccessIndicator('Business rule deleted')
  } catch (e: any) {
    alert(`Error deleting rule: ${e.message || 'Unknown error'}`)
  }
}

const showSuccessIndicator = (message: string) => {
  successToastMessage.value = message
  showSuccessToast.value = true
  if (successTimeout) {
    clearTimeout(successTimeout)
  }
  successTimeout = setTimeout(() => {
    showSuccessToast.value = false
  }, 2000)
}

watch(
  () => ruleForm.value.job_function_name,
  newName => {
    if (
      newName &&
      newName.toLowerCase() === 'meter' &&
      !ruleForm.value.fan_out_prefix
    ) {
      ruleForm.value.fan_out_prefix = 'Meter '
    }
  }
)

watch(
  () => ruleForm.value.fan_out_enabled,
  enabled => {
    if (enabled) {
      if (!ruleForm.value.fan_out_prefix) {
        if (ruleForm.value.job_function_name?.toLowerCase() === 'meter') {
          ruleForm.value.fan_out_prefix = 'Meter '
        }
      }
    } else {
      ruleForm.value.fan_out_prefix = ''
    }
  }
)

const handleLogout = async () => {
  if (confirm('Are you sure you want to logout?')) {
    await logout()
  }
}

// Preferred Assignments Functions
const openPreferredAssignmentsModal = async () => {
  showPreferredAssignmentsModal.value = true
  await fetchPreferredAssignments()
  if (employees.value.length === 0) {
    await fetchEmployees(false) // Get all employees including inactive
  }
}

const closePreferredAssignmentsModal = () => {
  showPreferredAssignmentsModal.value = false
  showPreferredAssignmentFormModal.value = false
  editingPreferredAssignment.value = null
}

const openAddPreferredAssignmentModal = () => {
  editingPreferredAssignment.value = null
  preferredAssignmentFormData.value = {
    employee_id: '',
    job_function_id: '',
    is_required: false,
    priority: 0,
    notes: ''
  }
  showPreferredAssignmentFormModal.value = true
}

const openEditPreferredAssignmentModal = (pref: any) => {
  editingPreferredAssignment.value = pref
  preferredAssignmentFormData.value = {
    employee_id: pref.employee_id,
    job_function_id: pref.job_function_id,
    is_required: pref.is_required || false,
    priority: pref.priority || 0,
    notes: pref.notes || ''
  }
  showPreferredAssignmentFormModal.value = true
}

const closePreferredAssignmentFormModal = () => {
  showPreferredAssignmentFormModal.value = false
  editingPreferredAssignment.value = null
}

const handlePreferredAssignmentSubmit = async () => {
  try {
    if (editingPreferredAssignment.value) {
      await updatePreferredAssignment(editingPreferredAssignment.value.id, preferredAssignmentFormData.value)
    } else {
      await createPreferredAssignment(preferredAssignmentFormData.value)
    }
    await fetchPreferredAssignments() // Refresh list
    
    // Show saved icon
    showSavedIcon.value = true
    setTimeout(() => {
      showSavedIcon.value = false
      closePreferredAssignmentFormModal()
    }, 1500) // Hide icon and close modal after 1.5 seconds
  } catch (e: any) {
    alert(`Error saving preferred assignment: ${e.message || 'Unknown error'}`)
  }
}

const deletePreferredAssignmentHandler = async (id: string) => {
  if (confirm('Are you sure you want to delete this preferred assignment?')) {
    try {
      await deletePreferredAssignment(id)
      await fetchPreferredAssignments() // Refresh list
    } catch (e: any) {
      alert(`Error deleting preferred assignment: ${e.message || 'Unknown error'}`)
    }
  }
}

// Load rules and job functions on mount
onMounted(async () => {
  await Promise.all([
    fetchBusinessRules(),
    fetchJobFunctions(),
    fetchEmployees(false) // Get all employees including inactive
  ])
})

onBeforeUnmount(() => {
  if (successTimeout) {
    clearTimeout(successTimeout)
  }
})
</script>

