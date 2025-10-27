<template>
  <div class="min-h-screen bg-gray-50">
    <div class="container mx-auto px-4 py-8">
      <!-- Header -->
      <div class="flex items-center justify-between mb-4">
        <h1 class="text-3xl font-bold text-gray-800">Employees & Training Matrix</h1>
        <NuxtLink to="/" class="btn-secondary">
          ← Back to Home
        </NuxtLink>
      </div>

      <!-- Search Bar -->
      <div class="card mb-4">
        <input
          v-model="searchQuery"
          type="text"
          placeholder="Search employees..."
          class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>

      <!-- Loading State -->
      <div v-if="loading" class="card text-center py-8">
        <p class="text-gray-600">Loading job functions...</p>
      </div>

      <!-- Error State -->
      <div v-else-if="error" class="bg-red-50 border border-red-200 rounded-lg p-4 mb-4">
        <p class="text-red-600">{{ error }}</p>
      </div>

      <!-- Employee Management Header -->
      <div v-else class="card mb-4">
        <div class="flex justify-between items-center">
          <h2 class="text-xl font-bold text-gray-800">Employee Management</h2>
          <div class="flex space-x-2">
            <button
              @click="openAddEmployeeModal"
              class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition text-sm"
            >
              + Add Employee
            </button>
          </div>
        </div>
      </div>

      <!-- Training Matrix -->
      <div v-if="!loading && !error" class="card">
        <!-- Debug info -->
        <div v-if="employees.length === 0" class="text-center py-8 text-gray-500">
          <p>No employees found. {{ employeesLoading ? 'Still loading employees...' : 'Try adding some employees.' }}</p>
        </div>
        <div class="space-y-3">
          <div
            v-for="employee in filteredEmployees"
            :key="employee.id"
            :data-employee-id="employee.id"
            class="border-b border-gray-200 pb-3 last:border-b-0"
          >
            <!-- Employee Header with Controls -->
            <div class="flex justify-between items-start mb-2">
              <div class="flex items-center space-x-4">
                <div class="flex items-center space-x-2">
                  <h3 class="text-lg font-semibold text-gray-800">
                    {{ employee.last_name }}, {{ employee.first_name }}
                  </h3>
                  
                  <!-- Individual Save Status Indicators -->
                  <div :data-status-indicator="employee.id" class="flex items-center space-x-1">
                    <!-- Status will be dynamically inserted here via DOM manipulation -->
                  </div>
                </div>
                
                <!-- Shift Selection -->
                <div class="flex items-center space-x-2">
                  <label class="text-sm text-gray-600">Shift:</label>
                  <select
                    :value="employeeShifts[employee.id] || ''"
                    @change="updateEmployeeShift(employee.id, $event)"
                    class="text-sm border border-gray-300 rounded px-2 py-1 focus:outline-none focus:ring-1 focus:ring-blue-500"
                  >
                    <option value="">Select Shift</option>
                    <option v-for="shift in shifts" :key="shift.id" :value="shift.id">
                      {{ shift.name }}
                    </option>
                  </select>
                </div>
              </div>
              
              <!-- Employee Actions -->
              <div class="flex items-center space-x-2">
                <button
                  :data-save-button="employee.id"
                  @click="saveEmployeeTraining(employee.id)"
                  disabled
                  class="px-3 py-1 bg-gray-300 text-gray-500 rounded cursor-not-allowed text-sm"
                >
                  No Changes
                </button>
                <button
                  @click="openEditEmployeeModal(employee)"
                  class="px-3 py-1 bg-blue-100 text-blue-600 rounded hover:bg-blue-200 transition text-sm"
                >
                  Edit
                </button>
                <button
                  @click="deleteEmployee(employee.id)"
                  class="px-3 py-1 bg-red-100 text-red-600 rounded hover:bg-red-200 transition text-sm"
                >
                  Delete
                </button>
              </div>
            </div>
            
            <!-- Training Matrix -->
            <div class="grid grid-cols-3 md:grid-cols-5 lg:grid-cols-6 xl:grid-cols-9 gap-2">
              <label
                v-for="jobFunction in getGroupedJobFunctions()"
                :key="jobFunction.id"
                class="flex items-center space-x-1 cursor-pointer hover:bg-gray-50 p-1 rounded text-xs transition-colors"
              >
                <input
                  type="checkbox"
                  :data-employee-id="employee.id"
                  :data-job-function-id="jobFunction.id"
                  :checked="isEmployeeTrained(employee.id, jobFunction.id)"
                  @change="toggleTraining(employee.id, jobFunction.id)"
                  class="w-3 h-3 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
                />
                <div class="flex items-center space-x-1">
                  <div
                    class="w-3 h-3 rounded border border-gray-300"
                    :style="{ backgroundColor: jobFunction.color_code }"
                  ></div>
                  <span class="text-xs text-gray-700 truncate">{{ jobFunction.name }}</span>
                </div>
              </label>
            </div>
          </div>
        </div>

        <!-- Save Instructions -->
        <div class="mt-4 pt-4 border-t border-gray-200">
          <div class="flex items-center justify-center">
            <div class="text-sm text-gray-500">
              <span class="inline-flex items-center">
                <svg class="w-4 h-4 mr-1 text-blue-500" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M4 4a2 2 0 00-2 2v8a2 2 0 002 2h12a2 2 0 002-2V6a2 2 0 00-2-2H4zm2 6a1 1 0 011-1h6a1 1 0 110 2H7a1 1 0 01-1-1zm1 3a1 1 0 100 2h6a1 1 0 100-2H7z" clip-rule="evenodd"></path>
                </svg>
                Click checkboxes to make changes, then click "Save Changes" for each employee
              </span>
            </div>
          </div>
          
          <!-- Training Data Loading Indicator -->
          <div v-if="trainingDataLoading" class="mt-2 text-center">
            <div class="inline-flex items-center text-sm text-blue-500">
              <svg class="animate-spin h-4 w-4 mr-2" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              Loading training data...
            </div>
          </div>
        </div>
      </div>

      <!-- Add/Edit Employee Modal -->
      <div v-if="showEmployeeModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4">
          <h3 class="text-xl font-bold mb-4">
            {{ editingEmployee ? 'Edit Employee' : 'Add New Employee' }}
          </h3>
          
          <form @submit.prevent="handleEmployeeSubmit" class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">First Name</label>
              <input
                v-model="employeeFormData.first_name"
                type="text"
                required
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Last Name</label>
              <input
                v-model="employeeFormData.last_name"
                type="text"
                required
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>

            <div class="flex items-center">
              <input
                v-model="employeeFormData.is_active"
                type="checkbox"
                id="is_active"
                class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
              />
              <label for="is_active" class="ml-2 block text-sm text-gray-700">
                Active
              </label>
            </div>

            <div class="flex justify-end space-x-3 pt-4">
              <button
                type="button"
                @click="closeEmployeeModal"
                class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                class="btn-primary"
              >
                {{ editingEmployee ? 'Update' : 'Create' }}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onBeforeRouteLeave } from 'vue-router'

// Get Supabase client
const { $supabase } = useNuxtApp()
const { 
  employees, 
  loading: employeesLoading, 
  error: employeesError, 
  fetchEmployees, 
  updateEmployeeTraining, 
  getEmployeeTraining,
  getAllEmployeeTraining,
  createEmployee,
  updateEmployee,
  deleteEmployee: deleteEmployeeApi
} = useEmployees()
const { jobFunctions, loading: functionsLoading, fetchJobFunctions, getGroupedJobFunctions, getAllMeterJobFunctions, isMeterJobFunction } = useJobFunctions()
const { shifts, fetchShifts } = useSchedule()

const searchQuery = ref('')
const employeeTraining = ref<Record<string, string[]>>({})
const originalTraining = ref<Record<string, string[]>>({})
const employeeShifts = ref<Record<string, string>>({})
const trainingDataLoading = ref(false)

// Non-reactive state for pending changes (no Vue reactivity)
const pendingChanges = new Map<string, string[]>()
const saveStates = new Map<string, 'idle' | 'saving' | 'saved' | 'error'>()

// Employee modal state
const showEmployeeModal = ref(false)
const editingEmployee = ref(null)
const employeeFormData = ref({
  first_name: '',
  last_name: '',
  is_active: true
})

const loading = computed(() => functionsLoading.value)
const error = computed(() => employeesError.value)

const filteredEmployees = computed(() => {
  if (!searchQuery.value) return employees.value

  const query = searchQuery.value.toLowerCase()
  return employees.value.filter((emp: any) => {
    const fullName = `${emp.first_name} ${emp.last_name}`.toLowerCase()
    return fullName.includes(query)
  })
})

// hasChanges computed property removed since we're auto-saving

onMounted(async () => {
  try {
    // Load core data in parallel for immediate UI display
    const [employeesResult, jobFunctionsResult, shiftsResult] = await Promise.all([
      fetchEmployees(),
      fetchJobFunctions(),
      fetchShifts()
    ])
    
    console.log('Loaded employees:', employeesResult?.length || 0)
    console.log('Loaded job functions:', jobFunctionsResult?.length || 0)
    console.log('Loaded shifts:', shiftsResult?.length || 0)
    
    // Load training data and employee shifts in the background (non-blocking)
    // This allows the UI to show immediately while data loads
    Promise.all([
      loadTrainingData().catch(error => {
        console.error('Error loading training data:', error)
      }),
      loadEmployeeShifts().catch(error => {
        console.error('Error loading employee shifts:', error)
      })
    ])
  } catch (error) {
    console.error('Error loading initial data:', error)
  }
})

// Navigation warning (backup safety measure)
onBeforeRouteLeave((to, from, next) => {
  // Since we're auto-saving, this is just a backup warning
  // In case auto-save fails, we can still warn the user
  const hasUnsavedChanges = JSON.stringify(employeeTraining.value) !== JSON.stringify(originalTraining.value)
  
  if (hasUnsavedChanges) {
    if (confirm('You have unsaved training changes. Are you sure you want to leave this page?')) {
      next()
    } else {
      next(false)
    }
  } else {
    next()
  }
})

const loadTrainingData = async () => {
  if (employees.value.length === 0) return
  
  trainingDataLoading.value = true
  
  try {
    // Use bulk fetch for much faster loading
    const employeeIds = employees.value.map(emp => emp.id)
    const training = await getAllEmployeeTraining(employeeIds)
    
    employeeTraining.value = training
    originalTraining.value = JSON.parse(JSON.stringify(training))
  } finally {
    trainingDataLoading.value = false
  }
}

const loadEmployeeShifts = async () => {
  if (employees.value.length === 0) return
  
  try {
    // Load employee shifts from database using the composable
    const { data, error } = await $supabase
      .from('employees')
      .select('id, shift_id')
      .in('id', employees.value.map(emp => emp.id))
    
    if (error) {
      console.error('Error loading employee shifts:', error)
      return
    }
    
    // Build employee shifts object
    const shifts: Record<string, string> = {}
    data.forEach(emp => {
      if (emp.shift_id) {
        shifts[emp.id] = emp.shift_id
      }
    })
    
    employeeShifts.value = shifts
  } catch (error) {
    console.error('Error loading employee shifts:', error)
  }
}

const isEmployeeTrained = (employeeId: string, jobFunctionId: string): boolean => {
  // Special handling for meter group
  if (jobFunctionId === 'meter-group') {
    // Check if employee is trained on ANY meter
    const allMeters = getAllMeterJobFunctions()
    return allMeters.some(meter => {
      if (pendingChanges.has(employeeId)) {
        return pendingChanges.get(employeeId)!.includes(meter.id)
      }
      return employeeTraining.value[employeeId]?.includes(meter.id) || false
    })
  }
  
  // Check pending changes first (for immediate UI updates)
  if (pendingChanges.has(employeeId)) {
    return pendingChanges.get(employeeId)!.includes(jobFunctionId)
  }
  // Fall back to reactive state
  return employeeTraining.value[employeeId]?.includes(jobFunctionId) || false
}


// Completely non-reactive checkbox handling
const toggleTraining = (employeeId: string, jobFunctionId: string) => {
  // Get current state from DOM or initialize
  if (!pendingChanges.has(employeeId)) {
    pendingChanges.set(employeeId, [...(employeeTraining.value[employeeId] || [])])
  }
  
  const currentTraining = pendingChanges.get(employeeId)!
  
  // Special handling for meter group
  if (jobFunctionId === 'meter-group') {
    const allMeters = getAllMeterJobFunctions()
    const isCurrentlyTrained = allMeters.some(meter => currentTraining.includes(meter.id))
    
    if (isCurrentlyTrained) {
      // Remove training from all meters
      allMeters.forEach(meter => {
        const index = currentTraining.indexOf(meter.id)
        if (index > -1) {
          currentTraining.splice(index, 1)
        }
      })
    } else {
      // Add training to all meters
      allMeters.forEach(meter => {
        if (!currentTraining.includes(meter.id)) {
          currentTraining.push(meter.id)
        }
      })
    }
  } else {
    // Regular job function handling
    const index = currentTraining.indexOf(jobFunctionId)
    
    if (index > -1) {
      currentTraining.splice(index, 1)
    } else {
      currentTraining.push(jobFunctionId)
    }
  }
  
  // Update the checkbox state in DOM (no reactive state changes)
  const checkbox = document.querySelector(`[data-employee-id="${employeeId}"][data-job-function-id="${jobFunctionId}"]`) as HTMLInputElement
  if (checkbox) {
    checkbox.checked = isEmployeeTrained(employeeId, jobFunctionId)
  }
  
  // Update save button state
  updateSaveButtonState(employeeId)
}

// Update save button appearance based on pending changes
const updateSaveButtonState = (employeeId: string) => {
  const saveButton = document.querySelector(`[data-save-button="${employeeId}"]`) as HTMLButtonElement
  if (!saveButton) return
  
  const hasChanges = pendingChanges.has(employeeId) && 
    JSON.stringify(pendingChanges.get(employeeId)) !== JSON.stringify(employeeTraining.value[employeeId] || [])
  
  if (hasChanges) {
    saveButton.disabled = false
    saveButton.textContent = 'Save Changes'
    saveButton.className = 'px-3 py-1 bg-blue-600 text-white rounded hover:bg-blue-700 transition text-sm'
  } else {
    saveButton.disabled = true
    saveButton.textContent = 'No Changes'
    saveButton.className = 'px-3 py-1 bg-gray-300 text-gray-500 rounded cursor-not-allowed text-sm'
  }
}

// Save changes for a specific employee
const saveEmployeeTraining = async (employeeId: string) => {
  if (!pendingChanges.has(employeeId)) return
  
  const saveButton = document.querySelector(`[data-save-button="${employeeId}"]`) as HTMLButtonElement
  const statusIndicator = document.querySelector(`[data-status-indicator="${employeeId}"]`)
  
  // Set saving state
  saveStates.set(employeeId, 'saving')
  saveButton.disabled = true
  saveButton.textContent = 'Saving...'
  saveButton.className = 'px-3 py-1 bg-yellow-600 text-white rounded cursor-not-allowed text-sm'
  
  if (statusIndicator) {
    statusIndicator.innerHTML = `
      <div class="flex items-center">
        <svg class="animate-spin h-4 w-4 text-blue-500" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        <span class="text-xs text-blue-500 ml-1">Saving...</span>
      </div>
    `
  }
  
  try {
    const newTraining = pendingChanges.get(employeeId)!
    await updateEmployeeTraining(employeeId, newTraining)
    
    // Update reactive state only after successful save
    employeeTraining.value[employeeId] = [...newTraining]
    originalTraining.value[employeeId] = [...newTraining]
    
    // Clear pending changes
    pendingChanges.delete(employeeId)
    saveStates.set(employeeId, 'saved')
    
    // Show success state
    saveButton.textContent = 'Saved!'
    saveButton.className = 'px-3 py-1 bg-green-600 text-white rounded text-sm'
    
    if (statusIndicator) {
      statusIndicator.innerHTML = `
        <div class="flex items-center animate-pulse">
          <svg class="h-4 w-4 text-green-500" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"></path>
          </svg>
          <span class="text-xs text-green-500 ml-1">Saved</span>
        </div>
      `
    }
    
    // Reset button after 2 seconds
    setTimeout(() => {
      updateSaveButtonState(employeeId)
      if (statusIndicator) {
        statusIndicator.innerHTML = ''
      }
    }, 2000)
    
  } catch (e) {
    console.error('Error saving training:', e)
    saveStates.set(employeeId, 'error')
    
    saveButton.textContent = 'Error - Try Again'
    saveButton.className = 'px-3 py-1 bg-red-600 text-white rounded hover:bg-red-700 transition text-sm'
    saveButton.disabled = false
    
    if (statusIndicator) {
      statusIndicator.innerHTML = `
        <div class="flex items-center">
          <svg class="h-4 w-4 text-red-500" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd"></path>
          </svg>
          <span class="text-xs text-red-500 ml-1">Error</span>
        </div>
      `
    }
  }
}

// Auto-save functionality is now handled in toggleTraining()

// Employee management functions
const openAddEmployeeModal = () => {
  editingEmployee.value = null
  employeeFormData.value = {
    first_name: '',
    last_name: '',
    is_active: true
  }
  showEmployeeModal.value = true
}

const openEditEmployeeModal = (employee: any) => {
  editingEmployee.value = employee
  employeeFormData.value = {
    first_name: employee.first_name,
    last_name: employee.last_name,
    is_active: employee.is_active
  }
  showEmployeeModal.value = true
}

const closeEmployeeModal = () => {
  showEmployeeModal.value = false
  editingEmployee.value = null
}

const handleEmployeeSubmit = async () => {
  try {
    if (editingEmployee.value) {
      await updateEmployee(editingEmployee.value.id, employeeFormData.value)
    } else {
      await createEmployee(employeeFormData.value)
    }
    
    await fetchEmployees()
    closeEmployeeModal()
    showSuccess.value = true
    
    setTimeout(() => {
      showSuccess.value = false
    }, 3000)
  } catch (e) {
    console.error('Error saving employee:', e)
  }
}

const deleteEmployee = async (employeeId: string) => {
  if (confirm('Are you sure you want to delete this employee? This will also remove all their training records.')) {
    try {
      await deleteEmployeeApi(employeeId)
      await fetchEmployees()
      showSuccess.value = true
      
      setTimeout(() => {
        showSuccess.value = false
      }, 3000)
    } catch (e) {
      console.error('Error deleting employee:', e)
    }
  }
}

const updateEmployeeShift = async (employeeId: string, event: Event) => {
  const shiftId = (event.target as HTMLSelectElement).value
  employeeShifts.value[employeeId] = shiftId
  
  // Show loading state
  const selectElement = event.target as HTMLSelectElement
  const originalText = selectElement.selectedOptions[0]?.textContent || ''
  selectElement.disabled = true
  
  try {
    // Update the employee's shift in the database
    const { error } = await $supabase
      .from('employees')
      .update({ shift_id: shiftId || null })
      .eq('id', employeeId)
    
    if (error) {
      console.error('Error updating employee shift:', error)
      alert('Failed to save shift assignment. Please try again.')
      return
    }
    
    console.log(`Employee ${employeeId} assigned to shift ${shiftId}`)
    
    // Show success feedback
    selectElement.style.backgroundColor = '#d4edda'
    setTimeout(() => {
      selectElement.style.backgroundColor = ''
    }, 1000)
    
  } catch (error) {
    console.error('Error updating employee shift:', error)
    alert('Failed to save shift assignment. Please try again.')
  } finally {
    selectElement.disabled = false
  }
}
</script>

