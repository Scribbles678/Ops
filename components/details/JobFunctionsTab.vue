<template>
  <div>
    <div class="flex justify-between items-center mb-3">
      <h2 class="text-lg md:text-xl font-semibold text-gray-800">Job Functions</h2>
      <button @click="openAddModal" class="btn-primary">
        + Add New Job Function
      </button>
    </div>

    <!-- Loading State -->
    <div v-if="loading" class="text-center py-4">
      <p class="text-gray-600">Loading job functions...</p>
    </div>

    <!-- Error State -->
    <div v-else-if="error" class="bg-red-50 border border-red-200 rounded-lg p-3 mb-3 text-xs md:text-sm">
      <p class="text-red-600">{{ error }}</p>
    </div>

    <!-- Job Functions List -->
    <div v-else class="space-y-2.5">
      <div
        v-for="jobFunction in jobFunctionsList"
        :key="jobFunction.id"
        class="border border-gray-200 rounded-lg p-2.5 md:p-3.5 hover:shadow-md transition"
      >
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-2.5 md:space-x-3.5">
            <div
              class="w-8 h-8 md:w-10 md:h-10 rounded"
              :style="{ backgroundColor: jobFunction.color_code }"
            ></div>
            <div>
              <h3 class="text-sm md:text-base font-semibold text-gray-800">{{ jobFunction.name }}</h3>
              <p class="text-[11px] md:text-xs text-gray-600">
                Rate: {{ jobFunction.productivity_rate || 'N/A' }} cartons/hour
              </p>
            </div>
          </div>
          <div class="flex space-x-2">
            <button
              @click="openEditModal(jobFunction)"
              class="px-2.5 py-1 text-xs md:text-sm bg-blue-100 text-blue-600 rounded hover:bg-blue-200 transition"
            >
              Edit
            </button>
            <button
              @click="handleDelete(jobFunction.id)"
              class="px-2.5 py-1 text-xs md:text-sm bg-red-100 text-red-600 rounded hover:bg-red-200 transition"
            >
              Delete
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Add/Edit Modal -->
    <div v-if="showModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div class="bg-white rounded-lg p-4 md:p-5 max-w-md w-full mx-4">
        <h3 class="text-base md:text-lg font-semibold mb-3">
          {{ editingJobFunction ? 'Edit Job Function' : 'Add New Job Function' }}
        </h3>
        
        <form @submit.prevent="handleSubmit" class="space-y-3 text-xs md:text-sm">
          <div>
            <label class="block font-medium text-gray-700 mb-1">Name</label>
            <input
              v-model="formData.name"
              type="text"
              required
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          <div>
            <label class="block font-medium text-gray-700 mb-1">Color</label>
            <input
              v-model="formData.color_code"
              type="color"
              class="w-full h-10 border border-gray-300 rounded-lg cursor-pointer"
            />
          </div>

          <div>
            <label class="block font-medium text-gray-700 mb-1">
              Productivity Rate (cartons/hour)
            </label>
            <input
              v-model.number="formData.productivity_rate"
              type="number"
              min="0"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          <div>
            <label class="block font-medium text-gray-700 mb-1">Sort Order</label>
            <input
              v-model.number="formData.sort_order"
              type="number"
              min="0"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
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
              {{ editingJobFunction ? 'Update' : 'Create' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const { jobFunctions, loading, error, fetchJobFunctions, createJobFunction, updateJobFunction, deleteJobFunction } = useJobFunctions()

const showModal = ref(false)
const editingJobFunction = ref<any | null>(null)
const formData = ref({
  name: '',
  color_code: '#3B82F6',
  productivity_rate: null,
  sort_order: 0
})

onMounted(() => {
  fetchJobFunctions(false)
})

const jobFunctionsList = computed<any[]>(() => jobFunctions.value || [])

const openAddModal = () => {
  editingJobFunction.value = null
  formData.value = {
    name: '',
    color_code: '#3B82F6',
    productivity_rate: null,
    sort_order: jobFunctionsList.value.length
  }
  showModal.value = true
}

const openEditModal = (jobFunction: any) => {
  editingJobFunction.value = jobFunction
  formData.value = {
    name: jobFunction.name,
    color_code: jobFunction.color_code,
    productivity_rate: jobFunction.productivity_rate,
    sort_order: jobFunction.sort_order
  }
  showModal.value = true
}

const closeModal = () => {
  showModal.value = false
  editingJobFunction.value = null
}

const handleSubmit = async () => {
  if (editingJobFunction.value) {
    await updateJobFunction(editingJobFunction.value.id, formData.value)
  } else {
    await createJobFunction(formData.value)
  }
  closeModal()
}

const handleDelete = async (id: string) => {
  if (confirm('Are you sure you want to delete this job function?')) {
    await deleteJobFunction(id)
  }
}
</script>

