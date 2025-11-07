<template>
  <div>
    <div class="flex justify-between items-center mb-3">
      <h2 class="text-lg md:text-xl font-semibold text-gray-800">Employees</h2>
      <button @click="openAddModal" class="btn-primary">
        + Add New Employee
      </button>
    </div>

    <!-- Loading State -->
    <div v-if="loading" class="text-center py-4">
      <p class="text-gray-600">Loading employees...</p>
    </div>

    <!-- Error State -->
    <div v-else-if="error" class="bg-red-50 border border-red-200 rounded-lg p-3 mb-3 text-sm">
      <p class="text-red-600">{{ error }}</p>
    </div>

    <!-- Employees List -->
    <div v-else class="space-y-2.5">
      <div
        v-for="employee in employees"
        :key="employee.id"
        class="border border-gray-200 rounded-lg p-2.5 md:p-3.5 hover:shadow-md transition flex items-center justify-between"
      >
        <div class="pr-3">
          <h3 class="text-sm md:text-base font-semibold text-gray-800">
            {{ employee.last_name }}, {{ employee.first_name }}
          </h3>
          <p class="text-[11px] md:text-xs text-gray-600">
            <span
              :class="employee.is_active ? 'text-green-600' : 'text-red-600'"
            >
              {{ employee.is_active ? 'Active' : 'Inactive' }}
            </span>
          </p>
        </div>
        <div class="flex space-x-2">
          <button
            @click="openEditModal(employee)"
            class="px-2.5 py-1 text-xs md:text-sm bg-blue-100 text-blue-600 rounded hover:bg-blue-200 transition"
          >
            Edit
          </button>
          <button
            @click="toggleActive(employee)"
            class="px-2.5 py-1 text-xs md:text-sm bg-yellow-100 text-yellow-600 rounded hover:bg-yellow-200 transition"
          >
            {{ employee.is_active ? 'Deactivate' : 'Activate' }}
          </button>
        </div>
      </div>
    </div>

    <!-- Add/Edit Modal -->
    <div v-if="showModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div class="bg-white rounded-lg p-4 md:p-5 max-w-md w-full mx-4">
        <h3 class="text-base md:text-lg font-semibold mb-3">
          {{ editingEmployee ? 'Edit Employee' : 'Add New Employee' }}
        </h3>
        
        <form @submit.prevent="handleSubmit" class="space-y-3 text-xs md:text-sm">
          <div>
            <label class="block font-medium text-gray-700 mb-1">First Name</label>
            <input
              v-model="formData.first_name"
              type="text"
              required
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          <div>
            <label class="block font-medium text-gray-700 mb-1">Last Name</label>
            <input
              v-model="formData.last_name"
              type="text"
              required
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          <div class="flex items-center">
            <input
              v-model="formData.is_active"
              type="checkbox"
              id="is_active"
              class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
            />
            <label for="is_active" class="ml-2 block text-gray-700">
              Active
            </label>
          </div>

          <div class="flex justify-end space-x-2.5 pt-3">
            <button
              type="button"
              @click="closeModal"
              class="px-3 py-1.5 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50"
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
</template>

<script setup lang="ts">
const { employees, loading, error, fetchEmployees, createEmployee, updateEmployee } = useEmployees()

const showModal = ref(false)
const editingEmployee = ref(null)
const formData = ref({
  first_name: '',
  last_name: '',
  is_active: true
})

onMounted(() => {
  fetchEmployees(false)
})

const openAddModal = () => {
  editingEmployee.value = null
  formData.value = {
    first_name: '',
    last_name: '',
    is_active: true
  }
  showModal.value = true
}

const openEditModal = (employee: any) => {
  editingEmployee.value = employee
  formData.value = {
    first_name: employee.first_name,
    last_name: employee.last_name,
    is_active: employee.is_active
  }
  showModal.value = true
}

const closeModal = () => {
  showModal.value = false
  editingEmployee.value = null
}

const handleSubmit = async () => {
  if (editingEmployee.value) {
    await updateEmployee(editingEmployee.value.id, formData.value)
  } else {
    await createEmployee(formData.value)
  }
  closeModal()
}

const toggleActive = async (employee: any) => {
  await updateEmployee(employee.id, { is_active: !employee.is_active })
}
</script>

