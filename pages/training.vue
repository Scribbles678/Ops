<template>
  <div class="min-h-screen bg-gray-50">
    <div class="container mx-auto px-4 py-8">
      <!-- Header -->
      <div class="flex items-center justify-between mb-8">
        <h1 class="text-4xl font-bold text-gray-800">Update Training</h1>
        <NuxtLink to="/" class="btn-secondary">
          ← Back to Home
        </NuxtLink>
      </div>

      <!-- Search Bar -->
      <div class="card mb-6">
        <input
          v-model="searchQuery"
          type="text"
          placeholder="Search employees..."
          class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
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

      <!-- Training Matrix -->
      <div v-else class="card">
        <div class="space-y-6">
          <div
            v-for="employee in filteredEmployees"
            :key="employee.id"
            class="border-b border-gray-200 pb-6 last:border-b-0"
          >
            <h3 class="text-lg font-semibold text-gray-800 mb-3">
              {{ employee.last_name }}, {{ employee.first_name }}
            </h3>
            
            <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3">
              <label
                v-for="jobFunction in jobFunctions"
                :key="jobFunction.id"
                class="flex items-center space-x-2 cursor-pointer hover:bg-gray-50 p-2 rounded"
              >
                <input
                  type="checkbox"
                  :checked="isEmployeeTrained(employee.id, jobFunction.id)"
                  @change="toggleTraining(employee.id, jobFunction.id)"
                  class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
                />
                <div class="flex items-center space-x-2">
                  <div
                    class="w-4 h-4 rounded"
                    :style="{ backgroundColor: jobFunction.color_code }"
                  ></div>
                  <span class="text-sm text-gray-700">{{ jobFunction.name }}</span>
                </div>
              </label>
            </div>
          </div>
        </div>

        <!-- Save Button -->
        <div class="mt-6 pt-6 border-t border-gray-200 flex justify-end">
          <button
            @click="saveChanges"
            :disabled="!hasChanges || saving"
            class="btn-primary disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {{ saving ? 'Saving...' : 'Save Changes' }}
          </button>
        </div>

        <!-- Success Message -->
        <div v-if="showSuccess" class="mt-4 bg-green-50 border border-green-200 rounded-lg p-4">
          <p class="text-green-600">✓ Training updates saved successfully!</p>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const { employees, loading: employeesLoading, error: employeesError, fetchEmployees, updateEmployeeTraining, getEmployeeTraining } = useEmployees()
const { jobFunctions, loading: functionsLoading, fetchJobFunctions } = useJobFunctions()

const searchQuery = ref('')
const employeeTraining = ref<Record<string, string[]>>({})
const originalTraining = ref<Record<string, string[]>>({})
const saving = ref(false)
const showSuccess = ref(false)

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
</script>

