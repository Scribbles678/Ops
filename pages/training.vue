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
        <p class="text-gray-600">Loading training data...</p>
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
        <div class="space-y-3">
          <div
            v-for="employee in filteredEmployees"
            :key="employee.id"
            class="border-b border-gray-200 pb-3 last:border-b-0"
          >
            <!-- Employee Header with Controls -->
            <div class="flex justify-between items-start mb-2">
              <div class="flex items-center space-x-4">
                <h3 class="text-lg font-semibold text-gray-800">
                  {{ employee.last_name }}, {{ employee.first_name }}
                </h3>
                
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
                v-for="jobFunction in jobFunctions"
                :key="jobFunction.id"
                class="flex items-center space-x-1 cursor-pointer hover:bg-gray-50 p-1 rounded text-xs"
              >
                <input
                  type="checkbox"
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

        <!-- Save Button -->
        <div class="mt-4 pt-4 border-t border-gray-200 flex justify-end">
          <button
            @click="saveChanges"
            :disabled="!hasChanges || saving"
            class="btn-primary disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {{ saving ? 'Saving...' : 'Save Changes' }}
          </button>
        </div>

        <!-- Success Message -->
        <div v-if="showSuccess" class="mt-3 bg-green-50 border border-green-200 rounded-lg p-3">
          <p class="text-green-600 text-sm">✓ Training updates saved successfully!</p>
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
const { 
  employees, 
  loading: employeesLoading, 
  error: employeesError, 
  fetchEmployees, 
  updateEmployeeTraining, 
  getEmployeeTraining,
  createEmployee,
  updateEmployee,
  deleteEmployee: deleteEmployeeApi
} = useEmployees()
const { jobFunctions, loading: functionsLoading, fetchJobFunctions } = useJobFunctions()
const { shifts, fetchShifts } = useSchedule()

const searchQuery = ref('')
const employeeTraining = ref<Record<string, string[]>>({})
const originalTraining = ref<Record<string, string[]>>({})
const employeeShifts = ref<Record<string, string>>({})
const saving = ref(false)
const showSuccess = ref(false)

// Employee modal state
const showEmployeeModal = ref(false)
const editingEmployee = ref(null)
const employeeFormData = ref({
  first_name: '',
  last_name: '',
  is_active: true
})

const loading = computed(() => employeesLoading.value || functionsLoading.value)
const error = computed(() => employeesError.value)

const filteredEmployees = computed(() => {
  if (!searchQuery.value) return employees.value

  const query = searchQuery.value.toLowerCase()
  return employees.value.filter((emp: any) => {
    const fullName = `${emp.first_name} ${emp.last_name}`.toLowerCase()
    return fullName.includes(query)
  })
})

const hasChanges = computed(() => {
  return JSON.stringify(employeeTraining.value) !== JSON.stringify(originalTraining.value)
})

onMounted(async () => {
  await fetchEmployees()
  await fetchJobFunctions()
  await fetchShifts()
  await loadTrainingData()
})

const loadTrainingData = async () => {
  const training: Record<string, string[]> = {}
  
  for (const employee of employees.value) {
    training[employee.id] = await getEmployeeTraining(employee.id)
  }
  
  employeeTraining.value = training
  originalTraining.value = JSON.parse(JSON.stringify(training))
}

const isEmployeeTrained = (employeeId: string, jobFunctionId: string): boolean => {
  return employeeTraining.value[employeeId]?.includes(jobFunctionId) || false
}

const toggleTraining = (employeeId: string, jobFunctionId: string) => {
  if (!employeeTraining.value[employeeId]) {
    employeeTraining.value[employeeId] = []
  }

  const index = employeeTraining.value[employeeId].indexOf(jobFunctionId)
  if (index > -1) {
    employeeTraining.value[employeeId].splice(index, 1)
  } else {
    employeeTraining.value[employeeId].push(jobFunctionId)
  }
}

const saveChanges = async () => {
  saving.value = true
  showSuccess.value = false

  try {
    // Save training for each employee that has changes
    for (const employeeId in employeeTraining.value) {
      if (JSON.stringify(employeeTraining.value[employeeId]) !== JSON.stringify(originalTraining.value[employeeId])) {
        await updateEmployeeTraining(employeeId, employeeTraining.value[employeeId])
      }
    }

    originalTraining.value = JSON.parse(JSON.stringify(employeeTraining.value))
    showSuccess.value = true

    setTimeout(() => {
      showSuccess.value = false
    }, 3000)
  } catch (e) {
    console.error('Error saving training changes:', e)
  } finally {
    saving.value = false
  }
}

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
  
  // Here you would typically save the shift assignment to the database
  // For now, we'll just store it in local state
  console.log(`Employee ${employeeId} assigned to shift ${shiftId}`)
}
</script>

