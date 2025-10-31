<template>
  <div class="min-h-screen bg-gray-50">
    <div class="container mx-auto px-4 py-8">
      <!-- Header -->
      <div class="flex items-center justify-between mb-8">
        <div>
          <h1 class="text-4xl font-bold text-gray-800">Business Rules</h1>
          <p class="text-gray-600 mt-2">Configure AI schedule generation rules</p>
        </div>
        <div class="flex space-x-4">
          <button @click="handleLogout" class="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-lg text-sm font-medium transition-colors">
            Logout
          </button>
          <NuxtLink to="/" class="btn-secondary">
            ← Back to Home
          </NuxtLink>
        </div>
      </div>

      <!-- Add New Rule Button -->
      <div class="mb-6">
        <button
          @click="openAddModal"
          class="btn-primary flex items-center"
        >
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
          </svg>
          Add Business Rule
        </button>
      </div>

      <!-- Rules Table -->
      <div class="card">
        <div v-if="loading" class="text-center py-8">
          <p class="text-gray-600">Loading rules...</p>
        </div>
        
        <div v-else-if="error" class="text-center py-8">
          <p class="text-red-600">Error: {{ error }}</p>
        </div>

        <div v-else-if="businessRules.length === 0" class="text-center py-8">
          <p class="text-gray-600">No business rules found. Click "Add Business Rule" to create one.</p>
        </div>

        <div v-else class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Job Function</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Time Slot</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Min Staff</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Max Staff</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Block Size</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Priority</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Notes</th>
                <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <tr v-for="rule in sortedRules" :key="rule.id" :class="{ 'bg-gray-50': !rule.is_active }">
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">{{ rule.job_function_name }}</td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{{ rule.time_slot_start }} - {{ rule.time_slot_end }}</td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  <span v-if="rule.min_staff !== null">{{ rule.min_staff }}</span>
                  <span v-else class="text-gray-400 italic">Global Max</span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{{ rule.max_staff || '-' }}</td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{{ rule.block_size_minutes }} min</td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{{ rule.priority }}</td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span 
                    class="px-2 py-1 inline-flex text-xs leading-5 font-semibold rounded-full"
                    :class="rule.is_active ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'"
                  >
                    {{ rule.is_active ? 'Active' : 'Inactive' }}
                  </span>
                </td>
                <td class="px-6 py-4 text-sm text-gray-500">{{ rule.notes || '-' }}</td>
                <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  <button
                    @click="editRule(rule)"
                    class="text-blue-600 hover:text-blue-900 mr-4"
                  >
                    Edit
                  </button>
                  <button
                    @click="deleteRule(rule.id)"
                    class="text-red-600 hover:text-red-900"
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
        <div class="bg-white rounded-lg p-6 max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto">
          <h3 class="text-xl font-bold mb-4">
            {{ editingRule ? 'Edit Business Rule' : 'Add Business Rule' }}
          </h3>

          <div class="space-y-4">
            <!-- Job Function -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Job Function Name</label>
              <select
                v-model="ruleForm.job_function_name"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
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
            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Start Time</label>
                <input
                  v-model="ruleForm.time_slot_start"
                  type="time"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">End Time</label>
                <input
                  v-model="ruleForm.time_slot_end"
                  type="time"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
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
                <span class="ml-2 text-sm text-gray-700">Global Max Limit (no minimum staff)</span>
              </label>
            </div>

            <!-- Min/Max Staff -->
            <div class="grid grid-cols-2 gap-4" v-if="!isGlobalMax">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Min Staff</label>
                <input
                  v-model.number="ruleForm.min_staff"
                  type="number"
                  min="0"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Max Staff (optional)</label>
                <input
                  v-model.number="ruleForm.max_staff"
                  type="number"
                  min="0"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  placeholder="Leave empty for no limit"
                />
              </div>
            </div>

            <!-- Max Staff Only (for Global Max) -->
            <div v-if="isGlobalMax">
              <label class="block text-sm font-medium text-gray-700 mb-1">Max Staff</label>
              <input
                v-model.number="ruleForm.max_staff"
                type="number"
                min="1"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
              <p class="mt-1 text-xs text-gray-500">Global maximum staff for this job function across all time slots</p>
            </div>

            <!-- Block Size -->
            <div v-if="!isGlobalMax">
              <label class="block text-sm font-medium text-gray-700 mb-1">Block Size (minutes)</label>
              <input
                v-model.number="ruleForm.block_size_minutes"
                type="number"
                min="0"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="e.g., 390 for 6.5 hours"
              />
            </div>

            <!-- Priority -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Priority</label>
              <input
                v-model.number="ruleForm.priority"
                type="number"
                min="0"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
              <p class="mt-1 text-xs text-gray-500">Lower numbers are processed first. 0 = highest priority.</p>
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
              <label class="block text-sm font-medium text-gray-700 mb-1">Notes (optional)</label>
              <textarea
                v-model="ruleForm.notes"
                rows="2"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="e.g., Morning pick coverage"
              ></textarea>
            </div>
          </div>

          <!-- Modal Actions -->
          <div class="flex justify-end space-x-3 mt-6">
            <button
              @click="closeModal"
              class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50"
            >
              Cancel
            </button>
            <button
              @click="saveRule"
              :disabled="!ruleForm.job_function_name || (!isGlobalMax && (!ruleForm.min_staff || ruleForm.min_staff < 0)) || (isGlobalMax && !ruleForm.max_staff)"
              class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {{ editingRule ? 'Update Rule' : 'Create Rule' }}
            </button>
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

const showModal = ref(false)
const editingRule = ref<any>(null)
const isGlobalMax = ref(false)

const ruleForm = ref({
  job_function_name: '',
  time_slot_start: '08:00',
  time_slot_end: '17:00',
  min_staff: 1,
  max_staff: null as number | null,
  block_size_minutes: 240,
  priority: 0,
  is_active: true,
  notes: ''
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
    notes: ''
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
    notes: rule.notes || ''
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

  const ruleData: any = {
    job_function_name: ruleForm.value.job_function_name.trim(),
    time_slot_start: ruleForm.value.time_slot_start,
    time_slot_end: ruleForm.value.time_slot_end,
    min_staff: isGlobalMax.value ? null : ruleForm.value.min_staff,
    max_staff: ruleForm.value.max_staff || null,
    block_size_minutes: isGlobalMax.value ? 0 : ruleForm.value.block_size_minutes,
    priority: ruleForm.value.priority || 0,
    is_active: ruleForm.value.is_active,
    notes: ruleForm.value.notes?.trim() || null
  }

  try {
    if (editingRule.value) {
      await updateBusinessRule(editingRule.value.id, ruleData)
      alert('Business rule updated successfully!')
    } else {
      await createBusinessRule(ruleData)
      alert('Business rule created successfully!')
    }
    closeModal()
  } catch (e: any) {
    alert(`Error saving rule: ${e.message || 'Unknown error'}`)
  }
}

const deleteRule = async (id: string) => {
  if (!confirm('Are you sure you want to delete this business rule?')) {
    return
  }

  try {
    const success = await deleteBusinessRule(id)
    if (success) {
      alert('Business rule deleted successfully!')
    } else {
      alert('Error deleting rule. Please try again.')
    }
  } catch (e: any) {
    alert(`Error deleting rule: ${e.message || 'Unknown error'}`)
  }
}

const handleLogout = async () => {
  if (confirm('Are you sure you want to logout?')) {
    await logout()
  }
}

// Load rules and job functions on mount
onMounted(async () => {
  await Promise.all([
    fetchBusinessRules(),
    fetchJobFunctions()
  ])
})
</script>

