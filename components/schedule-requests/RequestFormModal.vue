<template>
  <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4" @click.self="$emit('close')">
    <div class="bg-white rounded-xl shadow-2xl max-w-lg w-full max-h-[90vh] overflow-y-auto">
      <div class="p-6">
        <div class="flex justify-between items-center mb-4">
          <h2 class="text-xl font-bold text-gray-900">Time Off / Schedule Change</h2>
          <button @click="$emit('close')" class="text-gray-400 hover:text-gray-600 text-2xl leading-none">&times;</button>
        </div>

        <!-- Result banner (shown after submit) -->
        <div v-if="submitResult" class="mb-4">
          <ScheduleRequestsRequestResultBanner
            :status="submitResult.status"
            :rule-results="submitResult.ruleResults"
            :rejection-reason="submitResult.request.rejection_reason"
          />
          <button
            @click="resetForm"
            class="mt-3 w-full px-4 py-2 bg-gray-100 text-gray-700 rounded-md hover:bg-gray-200 text-sm"
          >
            Submit Another Request
          </button>
        </div>

        <!-- Form -->
        <form v-else @submit.prevent="handleSubmit" class="space-y-4">
          <!-- Employee selector -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Employee</label>
            <select
              v-model="form.employee_id"
              required
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            >
              <option value="">Select employee...</option>
              <option v-for="emp in employees" :key="emp.id" :value="emp.id">
                {{ emp.name }}
              </option>
            </select>
          </div>

          <!-- Request type -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Request Type</label>
            <select
              v-model="form.request_type"
              required
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            >
              <option value="">Select type...</option>
              <option value="leave_early">Leave Early</option>
              <option value="pto_full_day">Full Day Off</option>
              <option value="pto_partial">Partial Day Off</option>
              <option value="shift_swap">Shift Change</option>
            </select>
          </div>

          <!-- Date -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Date</label>
            <input
              v-model="form.request_date"
              type="date"
              required
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
          </div>

          <!-- Leave early: new end time -->
          <div v-if="form.request_type === 'leave_early'">
            <label class="block text-sm font-medium text-gray-700 mb-1">Leave At (new end time)</label>
            <input
              v-model="form.start_time"
              type="time"
              required
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
          </div>

          <!-- Partial PTO: start & end time -->
          <div v-if="form.request_type === 'pto_partial'" class="grid grid-cols-2 gap-3">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Absence Start</label>
              <input
                v-model="form.start_time"
                type="time"
                required
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Absence End</label>
              <input
                v-model="form.end_time"
                type="time"
                required
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              />
            </div>
          </div>

          <!-- Shift swap: original and requested shift -->
          <div v-if="form.request_type === 'shift_swap'" class="space-y-3">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Current Shift</label>
              <select
                v-model="form.original_shift_id"
                required
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              >
                <option value="">Select current shift...</option>
                <option v-for="s in shifts" :key="s.id" :value="s.id">
                  {{ s.name }} ({{ s.start_time }} - {{ s.end_time }})
                </option>
              </select>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Requested Shift</label>
              <select
                v-model="form.requested_shift_id"
                required
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              >
                <option value="">Select requested shift...</option>
                <option v-for="s in shifts" :key="s.id" :value="s.id" :disabled="s.id === form.original_shift_id">
                  {{ s.name }} ({{ s.start_time }} - {{ s.end_time }})
                </option>
              </select>
            </div>
          </div>

          <!-- Notes -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Notes (optional)</label>
            <textarea
              v-model="form.notes"
              rows="2"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              placeholder="Any additional details..."
            ></textarea>
          </div>

          <!-- Error -->
          <div v-if="submitError" class="bg-red-50 border border-red-200 rounded-md p-3">
            <p class="text-sm text-red-600">{{ submitError }}</p>
          </div>

          <!-- Submit -->
          <button
            type="submit"
            :disabled="submitting"
            class="w-full px-4 py-2.5 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 font-medium"
          >
            {{ submitting ? 'Submitting...' : 'Submit Request' }}
          </button>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { SubmitResult } from '~/composables/useScheduleRequests'

const props = defineProps<{
  preselectedEmployeeId?: string | null
}>()

const emit = defineEmits<{
  close: []
  submitted: [result: SubmitResult]
}>()

const { submitRequest } = useScheduleRequests()

const employees = ref<any[]>([])
const shifts = ref<any[]>([])
const submitting = ref(false)
const submitError = ref<string | null>(null)
const submitResult = ref<SubmitResult | null>(null)

// Default date = tomorrow
const tomorrow = new Date()
tomorrow.setDate(tomorrow.getDate() + 1)
const defaultDate = tomorrow.toISOString().split('T')[0]

const form = ref({
  employee_id: props.preselectedEmployeeId || '',
  request_type: '',
  request_date: defaultDate,
  start_time: '',
  end_time: '',
  original_shift_id: '',
  requested_shift_id: '',
  notes: '',
})

// Clear type-specific fields when type changes
watch(() => form.value.request_type, () => {
  form.value.start_time = ''
  form.value.end_time = ''
  form.value.original_shift_id = ''
  form.value.requested_shift_id = ''
})

const handleSubmit = async () => {
  submitting.value = true
  submitError.value = null
  try {
    const result = await submitRequest({
      employee_id: form.value.employee_id,
      request_type: form.value.request_type,
      request_date: form.value.request_date,
      start_time: form.value.start_time || null,
      end_time: form.value.end_time || null,
      original_shift_id: form.value.original_shift_id || null,
      requested_shift_id: form.value.requested_shift_id || null,
      notes: form.value.notes || null,
    })
    submitResult.value = result
    emit('submitted', result)
  } catch (e: any) {
    submitError.value = e.data?.message || e.message || 'Failed to submit request'
  } finally {
    submitting.value = false
  }
}

const resetForm = () => {
  submitResult.value = null
  submitError.value = null
  form.value = {
    employee_id: props.preselectedEmployeeId || '',
    request_type: '',
    request_date: defaultDate,
    start_time: '',
    end_time: '',
    original_shift_id: '',
    requested_shift_id: '',
    notes: '',
  }
}

onMounted(async () => {
  const [empData, shiftData] = await Promise.all([
    $fetch<any[]>('/api/employees', { params: { active: 'true' } }),
    $fetch<any[]>('/api/shifts'),
  ])
  employees.value = empData
  shifts.value = shiftData
})
</script>
