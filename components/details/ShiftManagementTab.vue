<template>
  <div>
    <div class="flex justify-between items-center mb-6">
      <h2 class="text-2xl font-bold text-gray-800">Shift Management</h2>
      <button @click="openAddModal" class="btn-primary">
        + Add New Shift
      </button>
    </div>

    <!-- Sample Shifts (for testing without database) -->
    <div class="space-y-4">
      <div
        v-for="shift in sampleShifts"
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
                <span class="text-gray-600 ml-2">
                  {{ shift.break_1_start }} - {{ shift.break_1_end }}
                </span>
              </div>
              
              <div v-if="shift.break_2_start">
                <span class="font-medium text-gray-700">Break 2:</span>
                <span class="text-gray-600 ml-2">
                  {{ shift.break_2_start }} - {{ shift.break_2_end }}
                </span>
              </div>
              
              <div v-if="shift.lunch_start">
                <span class="font-medium text-gray-700">Lunch:</span>
                <span class="text-gray-600 ml-2">
                  {{ shift.lunch_start }} - {{ shift.lunch_end }}
                </span>
              </div>
            </div>
          </div>
          
          <div class="flex space-x-2 ml-4">
            <button
              @click="openEditModal(shift)"
              class="px-4 py-2 bg-blue-100 text-blue-600 rounded hover:bg-blue-200 transition"
            >
              Edit
            </button>
            <button
              @click="handleDelete(shift.id)"
              class="px-4 py-2 bg-red-100 text-red-600 rounded hover:bg-red-200 transition"
            >
              Delete
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Add/Edit Modal -->
    <div v-if="showModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div class="bg-white rounded-lg p-6 max-w-lg w-full mx-4 max-h-[90vh] overflow-y-auto">
        <h3 class="text-xl font-bold mb-4">
          {{ editingShift ? 'Edit Shift' : 'Add New Shift' }}
        </h3>
        
        <form @submit.prevent="handleSubmit" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Shift Name</label>
            <input
              v-model="formData.name"
              type="text"
              required
              placeholder="e.g., 6:00 AM - 2:30 PM"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Start Time</label>
              <input
                v-model="formData.start_time"
                type="time"
                required
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">End Time</label>
              <input
                v-model="formData.end_time"
                type="time"
                required
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
          </div>

          <div class="border-t pt-4">
            <h4 class="font-medium text-gray-700 mb-3">Break Times (Optional)</h4>
            
            <div class="grid grid-cols-2 gap-4 mb-3">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Break 1 Start</label>
                <input
                  v-model="formData.break_1_start"
                  type="time"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Break 1 End</label>
                <input
                  v-model="formData.break_1_end"
                  type="time"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </div>
            </div>

            <div class="grid grid-cols-2 gap-4 mb-3">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Break 2 Start</label>
                <input
                  v-model="formData.break_2_start"
                  type="time"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Break 2 End</label>
                <input
                  v-model="formData.break_2_end"
                  type="time"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </div>
            </div>

            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Lunch Start</label>
                <input
                  v-model="formData.lunch_start"
                  type="time"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Lunch End</label>
                <input
                  v-model="formData.lunch_end"
                  type="time"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </div>
            </div>
          </div>

          <div class="flex justify-end space-x-3 pt-4">
            <button
              type="button"
              @click="closeModal"
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
// Sample shifts data for testing (replace with database calls later)
const sampleShifts = ref([
  {
    id: '1',
    name: '6:00 AM - 2:30 PM',
    start_time: '6:00 AM',
    end_time: '2:30 PM',
    break_1_start: '7:45 AM',
    break_1_end: '8:00 AM',
    break_2_start: '9:45 AM',
    break_2_end: '10:00 AM',
    lunch_start: '12:30 PM',
    lunch_end: '1:00 PM'
  },
  {
    id: '2',
    name: '7:00 AM - 3:30 PM',
    start_time: '7:00 AM',
    end_time: '3:30 PM',
    break_1_start: '9:45 AM',
    break_1_end: '10:00 AM',
    break_2_start: '2:45 PM',
    break_2_end: '3:00 PM',
    lunch_start: '12:30 PM',
    lunch_end: '1:00 PM'
  },
  {
    id: '3',
    name: '4:00 PM - 8:30 PM',
    start_time: '4:00 PM',
    end_time: '8:30 PM',
    break_1_start: null,
    break_1_end: null,
    break_2_start: null,
    break_2_end: null,
    lunch_start: null,
    lunch_end: null
  }
])

const showModal = ref(false)
const editingShift = ref(null)
const formData = ref({
  name: '',
  start_time: '',
  end_time: '',
  break_1_start: '',
  break_1_end: '',
  break_2_start: '',
  break_2_end: '',
  lunch_start: '',
  lunch_end: ''
})

const openAddModal = () => {
  editingShift.value = null
  formData.value = {
    name: '',
    start_time: '',
    end_time: '',
    break_1_start: '',
    break_1_end: '',
    break_2_start: '',
    break_2_end: '',
    lunch_start: '',
    lunch_end: ''
  }
  showModal.value = true
}

const openEditModal = (shift: any) => {
  editingShift.value = shift
  formData.value = {
    name: shift.name,
    start_time: shift.start_time?.substring(0, 5) || '',
    end_time: shift.end_time?.substring(0, 5) || '',
    break_1_start: shift.break_1_start?.substring(0, 5) || '',
    break_1_end: shift.break_1_end?.substring(0, 5) || '',
    break_2_start: shift.break_2_start?.substring(0, 5) || '',
    break_2_end: shift.break_2_end?.substring(0, 5) || '',
    lunch_start: shift.lunch_start?.substring(0, 5) || '',
    lunch_end: shift.lunch_end?.substring(0, 5) || ''
  }
  showModal.value = true
}

const closeModal = () => {
  showModal.value = false
  editingShift.value = null
}

const handleSubmit = async () => {
  // Here you would implement the shift creation/update logic
  // For now, we'll just close the modal
  console.log('Shift data:', formData.value)
  closeModal()
}

const handleDelete = async (id: string) => {
  if (confirm('Are you sure you want to delete this shift?')) {
    // Here you would implement the shift deletion logic
    console.log('Delete shift:', id)
  }
}
</script>
