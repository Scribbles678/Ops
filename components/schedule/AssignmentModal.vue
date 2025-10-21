<template>
  <div v-if="show" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
    <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4 max-h-[90vh] overflow-y-auto">
      <h3 class="text-xl font-bold mb-4">
        {{ assignment ? 'Edit Assignment' : 'New Assignment' }}
      </h3>

      <!-- Validation Errors -->
      <div v-if="validationErrors.length > 0" class="bg-red-50 border border-red-200 rounded-lg p-3 mb-4">
        <p class="text-red-600 text-sm font-medium mb-1">Validation Errors:</p>
        <ul class="text-red-600 text-sm list-disc list-inside">
          <li v-for="(error, idx) in validationErrors" :key="idx">{{ error }}</li>
        </ul>
      </div>

      <form @submit.prevent="handleSubmit" class="space-y-4">
        <!-- Employee Selection -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Employee</label>
          <select
            v-model="formData.employee_id"
            required
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            <option value="">Select employee...</option>
            <option v-for="emp in employees" :key="emp.id" :value="emp.id">
              {{ emp.last_name }}, {{ emp.first_name }}
            </option>
          </select>
        </div>

        <!-- Job Function Selection -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Job Function</label>
          <select
            v-model="formData.job_function_id"
            required
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            <option value="">Select job function...</option>
            <option v-for="jf in jobFunctions" :key="jf.id" :value="jf.id">
              {{ jf.name }}
            </option>
          </select>
        </div>

        <!-- Shift Selection -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Shift</label>
          <select
            v-model="formData.shift_id"
            required
            @change="updateTimeRange"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            <option value="">Select shift...</option>
            <option v-for="shift in shifts" :key="shift.id" :value="shift.id">
              {{ shift.name }}
            </option>
          </select>
        </div>

        <!-- Start Time -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Start Time</label>
          <input
            v-model="formData.start_time"
            type="time"
            required
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <!-- End Time -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">End Time</label>
          <input
            v-model="formData.end_time"
            type="time"
            required
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <!-- Buttons -->
        <div class="flex justify-between pt-4">
          <button
            v-if="assignment"
            type="button"
            @click="handleDelete"
            class="px-4 py-2 bg-red-100 text-red-600 rounded-lg hover:bg-red-200"
          >
            Delete
          </button>
          <div class="flex space-x-3" :class="{ 'ml-auto': !assignment }">
            <button
              type="button"
              @click="$emit('close')"
              class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50"
            >
              Cancel
            </button>
            <button
              type="submit"
              class="btn-primary"
            >
              {{ assignment ? 'Update' : 'Create' }}
            </button>
          </div>
        </div>
      </form>
    </div>
  </div>
</template>

<script setup lang="ts">
import { validateAssignment } from '~/utils/validationRules'

const props = defineProps<{
  show: boolean
  assignment?: any
  scheduleDate: string
  employees: any[]
  jobFunctions: any[]
  shifts: any[]
  existingAssignments: any[]
}>()

const emit = defineEmits(['close', 'save', 'delete'])

const { getEmployeeTraining } = useEmployees()

const formData = ref({
  employee_id: '',
  job_function_id: '',
  shift_id: '',
  start_time: '',
  end_time: '',
  schedule_date: props.scheduleDate,
  assignment_order: 1
})

const validationErrors = ref<string[]>([])

watch(() => props.show, (newVal) => {
  if (newVal) {
    if (props.assignment) {
      formData.value = {
        employee_id: props.assignment.employee_id,
        job_function_id: props.assignment.job_function_id,
        shift_id: props.assignment.shift_id,
        start_time: props.assignment.start_time.substring(0, 5),
        end_time: props.assignment.end_time.substring(0, 5),
        schedule_date: props.assignment.schedule_date,
        assignment_order: props.assignment.assignment_order
      }
    } else {
      formData.value = {
        employee_id: '',
        job_function_id: '',
        shift_id: '',
        start_time: '',
        end_time: '',
        schedule_date: props.scheduleDate,
        assignment_order: 1
      }
    }
    validationErrors.value = []
  }
})

const updateTimeRange = () => {
  const selectedShift = props.shifts.find(s => s.id === formData.value.shift_id)
  if (selectedShift) {
    formData.value.start_time = selectedShift.start_time.substring(0, 5)
    formData.value.end_time = selectedShift.end_time.substring(0, 5)
  }
}

const handleSubmit = async () => {
  validationErrors.value = []

  // Get employee training
  const training = await getEmployeeTraining(formData.value.employee_id)

  // Validate assignment
  const validation = validateAssignment(
    {
      ...formData.value,
      id: props.assignment?.id,
      start_time: formData.value.start_time + ':00',
      end_time: formData.value.end_time + ':00'
    },
    props.existingAssignments,
    training
  )

  if (!validation.valid) {
    validationErrors.value = validation.errors
    return
  }

  emit('save', {
    ...formData.value,
    start_time: formData.value.start_time + ':00',
    end_time: formData.value.end_time + ':00'
  })
}

const handleDelete = () => {
  if (confirm('Are you sure you want to delete this assignment?')) {
    emit('delete', props.assignment.id)
  }
}
</script>

