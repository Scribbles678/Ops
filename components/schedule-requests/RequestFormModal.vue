<template>
  <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4" @click.self="$emit('close')">
    <div class="bg-white rounded-xl shadow-2xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
      <div class="p-6">
        <div class="flex justify-between items-center mb-4">
          <h2 class="text-xl font-bold text-gray-900">Time Off / Schedule Change</h2>
          <button @click="$emit('close')" class="text-gray-400 hover:text-gray-600 text-2xl leading-none">&times;</button>
        </div>

        <!-- Inline login (when not authenticated) -->
        <div v-if="needsLogin">
          <p class="text-sm text-gray-600 mb-3">Please sign in to submit a request.</p>
          <form @submit.prevent="handleLogin" class="space-y-3">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Email</label>
              <input
                v-model="loginEmail"
                type="email"
                required
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500 bg-white text-gray-900"
                placeholder="you@example.com"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Password</label>
              <input
                v-model="loginPassword"
                type="password"
                required
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500 bg-white text-gray-900"
              />
            </div>
            <div v-if="loginError" class="bg-red-50 border border-red-200 rounded-md p-3">
              <p class="text-sm text-red-600">{{ loginError }}</p>
            </div>
            <button
              type="submit"
              :disabled="loggingIn"
              class="w-full px-4 py-2.5 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 font-medium"
            >
              {{ loggingIn ? 'Signing in...' : 'Sign In' }}
            </button>
          </form>
        </div>

        <!-- Result banner (shown after submit) -->
        <div v-else-if="submitResult" class="mb-4">
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
          <!-- Weekly Availability Strip -->
          <div v-if="weekAvailability.length > 0" class="rounded-lg border border-gray-200 bg-gray-50 p-3">
            <div class="flex items-center justify-between mb-2">
              <h3 class="text-xs font-semibold text-gray-600 uppercase tracking-wide">Week Availability</h3>
              <div class="flex items-center gap-2">
                <button type="button" @click="weekOffset--" class="text-gray-400 hover:text-gray-700 p-0.5">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" /></svg>
                </button>
                <span class="text-[10px] text-gray-400">{{ weekLabel }}</span>
                <button type="button" @click="weekOffset++" class="text-gray-400 hover:text-gray-700 p-0.5">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" /></svg>
                </button>
              </div>
            </div>
            <div class="grid grid-cols-7 gap-1.5">
              <div
                v-for="day in weekAvailability"
                :key="day.date"
                class="text-center rounded-md py-1.5 px-1 transition-colors border"
                :class="[
                  day.isBlocked
                    ? 'bg-gray-100 border-gray-300 cursor-not-allowed opacity-70'
                    : form.request_date === day.date
                      ? 'border-blue-500 bg-blue-50 ring-1 ring-blue-300 cursor-pointer'
                      : 'border-transparent hover:bg-gray-100 cursor-pointer',
                  day.isToday ? 'font-bold' : ''
                ]"
                :title="day.isBlocked ? `Blocked: ${day.blockReason || 'No requests allowed'}` : ''"
                @click="day.isBlocked ? null : (form.request_date = day.date)"
              >
                <div class="text-[10px] text-gray-500">{{ day.dayName }}</div>
                <div class="text-sm font-semibold" :class="[
                  day.isBlocked ? 'text-gray-400 line-through' :
                  day.isToday ? 'text-blue-600' : 'text-gray-800'
                ]">{{ day.dayNum }}</div>
                <div
                  v-if="day.isBlocked"
                  class="text-[10px] font-semibold mt-0.5 rounded px-1 text-red-700 bg-red-100"
                >
                  Blocked
                </div>
                <div
                  v-else
                  class="text-[10px] font-medium mt-0.5 rounded px-1"
                  :class="day.hoursRemaining > 8
                    ? 'text-green-700 bg-green-100'
                    : day.hoursRemaining > 0
                      ? 'text-yellow-700 bg-yellow-100'
                      : 'text-red-700 bg-red-100'"
                >
                  {{ day.hoursRemaining }}h left
                </div>
              </div>
            </div>
          </div>

          <!-- Employee selector -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Employee</label>
            <select
              v-model="form.employee_id"
              required
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500 bg-white text-gray-900"
            >
              <option value="">Select employee...</option>
              <option v-for="emp in employees" :key="emp.id" :value="emp.id">
                {{ emp.last_name }}, {{ emp.first_name }}
              </option>
            </select>
          </div>

          <!-- Request type -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Request Type</label>
            <select
              v-model="form.request_type"
              required
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500 bg-white text-gray-900"
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
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500 bg-white text-gray-900"
            />
            <div v-if="selectedDateBlock" class="mt-2 bg-red-50 border border-red-200 rounded-md p-2 text-xs text-red-700">
              <strong>Date is blocked.</strong> Requests for this date will be auto-rejected.
              <span v-if="selectedDateBlock.reason">Reason: {{ selectedDateBlock.reason }}</span>
            </div>
          </div>

          <!-- Leave early: new end time -->
          <div v-if="form.request_type === 'leave_early'">
            <label class="block text-sm font-medium text-gray-700 mb-1">Leave At (new end time)</label>
            <input
              v-model="form.start_time"
              type="time"
              required
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500 bg-white text-gray-900"
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
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500 bg-white text-gray-900"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Absence End</label>
              <input
                v-model="form.end_time"
                type="time"
                required
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500 bg-white text-gray-900"
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
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500 bg-white text-gray-900"
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
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500 bg-white text-gray-900"
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
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500 bg-white text-gray-900"
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

const { user, login: authLogin, fetchCurrentUser } = useAuth()

const employees = ref<any[]>([])
const shifts = ref<any[]>([])
const submitting = ref(false)
const submitError = ref<string | null>(null)
const submitResult = ref<SubmitResult | null>(null)
const needsLogin = ref(false)
const loginEmail = ref('')
const loginPassword = ref('')
const loginError = ref('')
const loggingIn = ref(false)

// Weekly availability data
const maxPtoHoursPerDay = ref(8)
const weekRequests = ref<any[]>([])
const weekPtoDays = ref<any[]>([])
const weekBlockedDates = ref<any[]>([])
const weekOffset = ref(0)

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

// Week helpers
const getMonday = (d: Date): Date => {
  const date = new Date(d)
  const day = date.getDay()
  const diff = day === 0 ? -6 : 1 - day
  date.setDate(date.getDate() + diff)
  return date
}

const formatDateStr = (d: Date): string => {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

const selectedWeekMonday = computed(() => {
  const d = form.value.request_date ? new Date(form.value.request_date + 'T00:00:00') : new Date()
  const mon = getMonday(d)
  mon.setDate(mon.getDate() + weekOffset.value * 7)
  return mon
})

const weekLabel = computed(() => {
  const mon = selectedWeekMonday.value
  const sun = new Date(mon)
  sun.setDate(mon.getDate() + 6)
  return `${formatDateStr(mon)} — ${formatDateStr(sun)}`
})

const todayStr = formatDateStr(new Date())

// Banner shown when selected date is in the blocked list (drives auto-rejection)
const selectedDateBlock = computed(() => {
  if (!form.value.request_date) return null
  return weekBlockedDates.value.find((b) => {
    const bd = b.blocked_date?.split('T')[0] ?? b.blocked_date
    return bd === form.value.request_date
  }) || null
})

const weekAvailability = computed(() => {
  const mon = selectedWeekMonday.value
  const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
  const days = []

  // Build a set of pto_day IDs linked from requests to avoid double-counting
  const linkedPtoIds = new Set(
    weekRequests.value
      .filter(r => r.created_pto_id)
      .map(r => r.created_pto_id)
  )

  for (let i = 0; i < 7; i++) {
    const d = new Date(mon)
    d.setDate(mon.getDate() + i)
    const dateStr = formatDateStr(d)

    // Sum approved PTO hours from schedule_requests for this day
    let dayPtoUsed = 0
    for (const req of weekRequests.value) {
      const reqDate = req.request_date?.split('T')[0] ?? req.request_date
      if (reqDate !== dateStr) continue
      if (req.status !== 'approved') continue
      if (!['pto_full_day', 'pto_partial', 'leave_early'].includes(req.request_type)) continue
      if (req.request_type === 'pto_full_day') dayPtoUsed += 8
      else if (req.request_type === 'leave_early') dayPtoUsed += 2
      else if (req.request_type === 'pto_partial' && req.start_time && req.end_time) {
        const [sh, sm] = String(req.start_time).split(':').map(Number)
        const [eh, em] = String(req.end_time).split(':').map(Number)
        dayPtoUsed += Math.max(0, (eh * 60 + em - sh * 60 - sm) / 60)
      }
    }

    // Also count manually-entered pto_days for this day (not linked to requests)
    for (const pto of weekPtoDays.value) {
      if (linkedPtoIds.has(pto.id)) continue
      const ptoDate = pto.pto_date?.split('T')[0] ?? pto.pto_date
      if (ptoDate !== dateStr) continue
      if (pto.pto_type === 'full_day') dayPtoUsed += 8
      else if (pto.start_time && pto.end_time) {
        const [sh, sm] = String(pto.start_time).split(':').map(Number)
        const [eh, em] = String(pto.end_time).split(':').map(Number)
        dayPtoUsed += Math.max(0, (eh * 60 + em - sh * 60 - sm) / 60)
      } else {
        dayPtoUsed += 2
      }
    }

    const blocked = weekBlockedDates.value.find((b) => {
      const bd = b.blocked_date?.split('T')[0] ?? b.blocked_date
      return bd === dateStr
    })

    days.push({
      date: dateStr,
      dayName: dayNames[i],
      dayNum: d.getDate(),
      isToday: dateStr === todayStr,
      hoursRemaining: Math.max(0, maxPtoHoursPerDay.value - dayPtoUsed),
      isBlocked: !!blocked,
      blockReason: blocked?.reason || null,
    })
  }
  return days
})

// Clear type-specific fields when type changes
watch(() => form.value.request_type, () => {
  form.value.start_time = ''
  form.value.end_time = ''
  form.value.original_shift_id = ''
  form.value.requested_shift_id = ''
})

// Reload availability when the selected week changes
watch(selectedWeekMonday, () => {
  loadWeekAvailability()
})

// Reset week offset when the date field changes
watch(() => form.value.request_date, () => {
  weekOffset.value = 0
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

const loadWeekAvailability = async () => {
  try {
    const mon = selectedWeekMonday.value
    const sun = new Date(mon)
    sun.setDate(mon.getDate() + 6)
    const dateFrom = formatDateStr(mon)
    const dateTo = formatDateStr(sun)

    const [requests, calendar, settings, blocked] = await Promise.all([
      $fetch<any[]>('/api/schedule-requests', {
        params: { date_from: dateFrom, date_to: dateTo },
      }),
      $fetch<any>('/api/pto-calendar', {
        params: { date_from: dateFrom, date_to: dateTo },
      }),
      $fetch<any[]>('/api/team-settings'),
      $fetch<any[]>('/api/team-blocked-dates'),
    ])

    weekRequests.value = requests
    weekPtoDays.value = calendar?.pto_days || []
    weekBlockedDates.value = blocked || []

    for (const s of settings) {
      if (s.setting_key === 'max_pto_hours_per_day') {
        maxPtoHoursPerDay.value = parseInt(s.setting_value, 10) || 8
      }
    }
  } catch {
    // silently fail — availability strip just won't show
  }
}

const loadFormData = async () => {
  try {
    const [empData, shiftData] = await Promise.all([
      $fetch<any[]>('/api/employees', { params: { active: 'true' } }),
      $fetch<any[]>('/api/shifts'),
    ])
    employees.value = empData
    shifts.value = shiftData
    needsLogin.value = false
    await loadWeekAvailability()
  } catch (e: any) {
    if (e.statusCode === 401 || e.status === 401) {
      needsLogin.value = true
    }
  }
}

const handleLogin = async () => {
  loggingIn.value = true
  loginError.value = ''
  try {
    await authLogin(loginEmail.value, loginPassword.value)
    await loadFormData()
  } catch (e: any) {
    loginError.value = e.data?.message || e.message || 'Login failed'
  } finally {
    loggingIn.value = false
  }
}

onMounted(async () => {
  if (!user.value) {
    await fetchCurrentUser()
  }
  await loadFormData()
})
</script>
