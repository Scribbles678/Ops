<template>
  <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4" @click.self="$emit('close')">
    <div class="bg-white rounded-xl shadow-2xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
      <div class="p-6">
        <div class="flex justify-between items-center mb-4">
          <h2 class="text-xl font-bold text-gray-900">Time Off / Schedule Change</h2>
          <button
            @click="$emit('close')"
            aria-label="Close"
            class="flex h-11 w-11 items-center justify-center rounded-lg text-2xl leading-none text-gray-400 transition-colors hover:bg-gray-100 hover:text-gray-600 active:bg-gray-200"
          >&times;</button>
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

        <!-- Multi-day result summary (shown after a date-range submit) -->
        <div v-else-if="submitResultsMulti.length" class="mb-4 space-y-3">
          <div>
            <h3 class="font-semibold text-lg text-gray-900">Multi-day request submitted</h3>
            <p class="text-sm text-gray-600">{{ multiApprovedCount }} approved, {{ submitResultsMulti.length - multiApprovedCount }} not approved.</p>
          </div>
          <div class="border border-gray-200 rounded-md divide-y max-h-60 overflow-y-auto">
            <div v-for="(r, i) in submitResultsMulti" :key="i" class="flex items-start justify-between gap-2 px-3 py-2 text-sm">
              <span class="text-gray-700 font-medium whitespace-nowrap">{{ r.date }}</span>
              <span class="text-right" :class="r.status === 'approved' ? 'text-green-700' : 'text-red-700'">
                {{ r.status }}<span v-if="r.reason" class="text-gray-400 block text-xs">{{ r.reason }}</span>
              </span>
            </div>
          </div>
          <button
            @click="resetForm"
            class="w-full px-4 py-2 bg-gray-100 text-gray-700 rounded-md hover:bg-gray-200 text-sm"
          >
            Submit Another Request
          </button>
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
              <!-- 44x44 tap targets. These were a 16px icon with 2px padding (20x20),
                   well under the 44x44 that Apple's guidelines and WCAG 2.5.5 both ask
                   for, and this form is used on the wall-mounted iPad. The visible
                   button is smaller than the target so the strip does not look clumsy;
                   the extra area is padding you can still hit. Active states matter
                   more than hover here — a touchscreen has no hover. -->
              <div class="flex items-center gap-1">
                <button
                  type="button"
                  @click="weekOffset--"
                  aria-label="Previous week"
                  class="flex h-11 w-11 items-center justify-center rounded-lg text-gray-500 transition-colors hover:bg-gray-200 hover:text-gray-800 active:bg-gray-300 active:text-gray-900"
                >
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M15 19l-7-7 7-7" /></svg>
                </button>
                <span class="text-xs font-medium text-gray-500 tabular-nums">{{ weekLabel }}</span>
                <button
                  type="button"
                  @click="weekOffset++"
                  aria-label="Next week"
                  class="flex h-11 w-11 items-center justify-center rounded-lg text-gray-500 transition-colors hover:bg-gray-200 hover:text-gray-800 active:bg-gray-300 active:text-gray-900"
                >
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M9 5l7 7-7 7" /></svg>
                </button>
              </div>
            </div>
            <div class="grid grid-cols-5 gap-2">
              <div
                v-for="day in weekAvailability"
                :key="day.date"
                class="text-center rounded-md py-2 px-1.5 transition-colors border"
                :class="[
                  !day.eligible
                    ? 'bg-gray-100 border-gray-300 cursor-not-allowed opacity-70'
                    : form.request_date === day.date
                      ? 'border-blue-500 bg-blue-50 ring-1 ring-blue-300 cursor-pointer'
                      : 'border-transparent hover:bg-gray-100 cursor-pointer',
                  day.isToday ? 'font-bold' : ''
                ]"
                :title="day.eligible
                  ? `${day.used}h of ${day.cap}h used`
                  : `${day.ineligibleReason} — ${day.used}h of ${day.cap}h used`"
                @click="day.eligible ? (form.request_date = day.date) : null"
              >
                <div class="text-[11px] text-gray-500">{{ day.dayName }}</div>
                <div class="text-base font-semibold leading-tight" :class="[
                  !day.eligible ? 'text-gray-400 line-through' :
                  day.isToday ? 'text-blue-600' : 'text-gray-800'
                ]">{{ day.dayNum }}</div>
                <div
                  v-if="day.isBlocked"
                  class="text-[11px] font-semibold mt-1 rounded px-1 py-0.5 text-red-700 bg-red-100"
                >
                  Blocked
                </div>
                <div
                  v-else-if="!day.eligible"
                  class="text-[11px] font-semibold mt-1 rounded px-1 py-0.5 text-gray-500 bg-gray-200"
                >
                  {{ day.isPast ? 'Past' : 'Notice' }}
                </div>
                <div
                  v-else
                  class="text-[11px] font-medium mt-1 rounded px-1 py-0.5"
                  :class="day.remaining >= day.cap
                    ? 'text-green-700 bg-green-100'
                    : day.remaining > 0
                      ? 'text-yellow-700 bg-yellow-100'
                      : 'text-red-700 bg-red-100'"
                >
                  {{ day.remaining }}h left
                </div>
              </div>
            </div>
            <p v-if="availabilityError" class="text-[10px] text-gray-400 mt-1.5">
              {{ availabilityError }}
            </p>
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
              <option value="leave_on_time">Leave on Time</option>
              <option value="arrive_late">Arrive Late</option>
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

          <!-- Full day off: optional end date for a multi-day range -->
          <div v-if="form.request_type === 'pto_full_day'">
            <label class="block text-sm font-medium text-gray-700 mb-1">End Date <span class="font-normal text-gray-400">(optional — for multiple days off)</span></label>
            <input
              v-model="form.end_date"
              type="date"
              :min="form.request_date"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500 bg-white text-gray-900"
            />
            <p class="text-xs text-gray-500 mt-1">
              Leave blank for a single day. A range submits one full-day request per day (each day is approved/rejected on its own — e.g. a blocked day in the middle is skipped).
            </p>
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

          <!-- Arrive late: new start time -->
          <div v-if="form.request_type === 'arrive_late'">
            <label class="block text-sm font-medium text-gray-700 mb-1">Arrive At (new start time)</label>
            <input
              v-model="form.start_time"
              type="time"
              required
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500 bg-white text-gray-900"
            />
          </div>

          <!-- Leave on time: informational note -->
          <div v-if="form.request_type === 'leave_on_time'" class="bg-blue-50 border border-blue-200 rounded-md p-3 text-xs text-blue-700">
            Notifies that this employee will leave at their scheduled end time (declining overtime).
            Scheduled hours are unchanged.
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
            :disabled="submitting || checkingRange"
            class="w-full px-4 py-2.5 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 font-medium"
          >
            {{ checkingRange ? 'Checking availability...' : submitting ? 'Submitting...' : 'Submit Request' }}
          </button>
        </form>
      </div>
    </div>

    <!-- Range confirmation: some days in the requested range can't be approved.
         Nothing has been submitted at this point — the user chooses. -->
    <div
      v-if="rangePreview"
      class="fixed inset-0 bg-black/60 flex items-center justify-center z-[60] p-4"
      @click.self="cancelRange"
    >
      <div class="bg-white rounded-xl shadow-2xl max-w-lg w-full max-h-[85vh] overflow-y-auto">
        <div class="p-6">
          <h3 class="text-lg font-bold text-gray-900 mb-1">Some days aren't available</h3>
          <p class="text-sm text-gray-600 mb-4">
            <template v-if="availableDates.length">
              {{ availableDates.length }} of {{ rangePreview.results.length }} day<span v-if="rangePreview.results.length !== 1">s</span>
              in this range can be approved. Nothing has been submitted yet.
            </template>
            <template v-else>
              None of the {{ rangePreview.results.length }} days in this range can be approved. Nothing has been submitted.
            </template>
          </p>

          <div class="mb-4">
            <h4 class="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">
              Not available ({{ unavailableRows.length }})
            </h4>
            <div class="border border-red-200 rounded-md divide-y divide-red-100 max-h-52 overflow-y-auto">
              <div v-for="row in unavailableRows" :key="row.date" class="px-3 py-2 bg-red-50">
                <div class="text-sm font-medium text-red-800">{{ formatLongDate(row.date) }}</div>
                <div class="text-xs text-red-600 mt-0.5">{{ row.rejectionReason || 'Not available' }}</div>
              </div>
            </div>
          </div>

          <div v-if="availableDates.length" class="mb-5">
            <h4 class="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">
              Will be requested ({{ availableDates.length }})
            </h4>
            <div class="border border-green-200 rounded-md bg-green-50 px-3 py-2 max-h-32 overflow-y-auto">
              <span
                v-for="d in availableDates"
                :key="d"
                class="inline-block text-xs text-green-800 mr-2 mb-1 whitespace-nowrap"
              >{{ formatLongDate(d) }}</span>
            </div>
          </div>

          <div class="flex gap-3">
            <button
              type="button"
              @click="cancelRange"
              class="flex-1 px-4 py-2.5 bg-gray-100 text-gray-700 rounded-md hover:bg-gray-200 font-medium"
            >
              Cancel entire request
            </button>
            <button
              v-if="availableDates.length"
              type="button"
              @click="confirmAvailableOnly"
              :disabled="submitting"
              class="flex-1 px-4 py-2.5 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 font-medium"
            >
              Submit {{ availableDates.length }} available day<span v-if="availableDates.length !== 1">s</span>
            </button>
          </div>
        </div>
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

// Weekly availability. The per-day numbers come straight from /api/pto/availability,
// which shares its cap lookup and hours math with the auto-approval rule — do NOT
// recompute them here, that divergence is exactly what used to make this strip lie.
const availabilityDays = ref<any[]>([])
const availabilityError = ref('')
const weekBlockedDates = ref<any[]>([])
const weekOffset = ref(0)

// Local-timezone YYYY-MM-DD. toISOString() would render the UTC date, which rolls
// over to the next day during the evening in any US timezone.
const formatDateStr = (d: Date): string => {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

// Default date = tomorrow
const defaultDate = (() => {
  const t = new Date()
  t.setDate(t.getDate() + 1)
  return formatDateStr(t)
})()

const form = ref({
  employee_id: props.preselectedEmployeeId || '',
  request_type: '',
  request_date: defaultDate,
  end_date: '', // optional: full-day multi-day range end (inclusive)
  start_time: '',
  end_time: '',
  original_shift_id: '',
  requested_shift_id: '',
  notes: '',
})

// Multi-day (date-range) submit results, one entry per day.
const submitResultsMulti = ref<{ date: string; status: string; reason: string | null }[]>([])
const multiApprovedCount = computed(() => submitResultsMulti.value.filter((r) => r.status === 'approved').length)

// Dry-run of a date range, held while the user decides what to do about the days
// that would be refused. Nothing has been submitted while this is set.
interface RangePreviewRow {
  date: string
  status: string
  rejectionReason: string | null
  requestedHours: number
  cap: number
  usedHours: number
}
interface RangePreview {
  results: RangePreviewRow[]
  approvedCount: number
  rejectedCount: number
}
const rangePreview = ref<RangePreview | null>(null)
const checkingRange = ref(false)

const availableDates = computed(() =>
  (rangePreview.value?.results ?? []).filter((r) => r.status === 'approved').map((r) => r.date)
)
const unavailableRows = computed(() =>
  (rangePreview.value?.results ?? []).filter((r) => r.status !== 'approved')
)

// Week helpers
const getMonday = (d: Date): Date => {
  const date = new Date(d)
  const day = date.getDay()
  const diff = day === 0 ? -6 : 1 - day
  date.setDate(date.getDate() + diff)
  return date
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

// "2026-08-03" -> "Mon, Aug 3" for the range confirmation dialog.
const formatLongDate = (dateStr: string): string => {
  const [y, m, d] = dateStr.split('-').map(Number)
  if (!y || !m || !d) return dateStr
  return new Date(y, m - 1, d).toLocaleDateString('en-US', {
    weekday: 'short', month: 'short', day: 'numeric',
  })
}

// Banner shown when selected date is in the blocked list (drives auto-rejection)
const selectedDateBlock = computed(() => {
  if (!form.value.request_date) return null
  return weekBlockedDates.value.find((b) => {
    const bd = b.blocked_date?.split('T')[0] ?? b.blocked_date
    return bd === form.value.request_date
  }) || null
})

// Presentation only — every number here is computed server-side by the same code
// that runs the approval rule. This just adds the day labels.
//
// Weekends are dropped from the strip (Mon–Fri only) so the five weekday cards get
// the full width. The endpoint still returns all seven and the weekend caps still
// apply — a Saturday typed into the Date field is evaluated normally, it just isn't
// clickable here.
const weekAvailability = computed(() => {
  const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
  return availabilityDays.value
    .map((day, i) => ({
      ...day,
      dayName: dayNames[i] ?? '',
      dayNum: Number(day.date.split('-')[2]),
      weekdayIndex: i,
    }))
    .filter((day) => day.weekdayIndex < 5)
})

// Clear type-specific fields when type changes
watch(() => form.value.request_type, () => {
  form.value.start_time = ''
  form.value.end_time = ''
  form.value.original_shift_id = ''
  form.value.requested_shift_id = ''
  form.value.end_date = ''
})

// Reload availability when the selected week changes
watch(selectedWeekMonday, () => {
  loadWeekAvailability()
})

// The cap is team-wide, so switching employee can switch which team's budget applies.
watch(() => form.value.employee_id, () => {
  loadWeekAvailability()
})

// Reset week offset when the date field changes
watch(() => form.value.request_date, () => {
  weekOffset.value = 0
})

// Build the inclusive list of dates to submit. Only full-day requests support a
// multi-day range; every other type is a single day.
const datesToSubmit = (): string[] => {
  const start = form.value.request_date
  const end = form.value.end_date
  if (form.value.request_type !== 'pto_full_day' || !end || end <= start) return [start]
  const out: string[] = []
  const [sy, sm, sd] = start.split('-').map(Number)
  const [ey, em, ed] = end.split('-').map(Number)
  const cur = new Date(sy, sm - 1, sd)
  const last = new Date(ey, em - 1, ed)
  while (cur <= last) {
    out.push(`${cur.getFullYear()}-${String(cur.getMonth() + 1).padStart(2, '0')}-${String(cur.getDate()).padStart(2, '0')}`)
    cur.setDate(cur.getDate() + 1)
  }
  return out
}

const buildBody = (date: string) => ({
  employee_id: form.value.employee_id,
  request_type: form.value.request_type,
  request_date: date,
  start_time: form.value.start_time || null,
  end_time: form.value.end_time || null,
  original_shift_id: form.value.original_shift_id || null,
  requested_shift_id: form.value.requested_shift_id || null,
  notes: form.value.notes || null,
})

// Actually submit a list of dates, one request per day.
const runSubmit = async (dates: string[]) => {
  submitting.value = true
  try {
    if (dates.length === 1) {
      const result = await submitRequest(buildBody(dates[0]))
      submitResult.value = result
      emit('submitted', result)
      return
    }

    const results: { date: string; status: string; reason: string | null }[] = []
    let last = null
    for (const d of dates) {
      try {
        const r = await submitRequest(buildBody(d))
        results.push({ date: d, status: r.status, reason: r.request.rejection_reason })
        last = r
      } catch (e: any) {
        results.push({ date: d, status: 'error', reason: e.data?.message || e.message || 'Failed' })
      }
    }
    submitResultsMulti.value = results
    if (last) emit('submitted', last)
  } catch (e: any) {
    submitError.value = e.data?.message || e.message || 'Failed to submit request'
  } finally {
    submitting.value = false
  }
}

const handleSubmit = async () => {
  submitError.value = null

  if (form.value.request_type === 'pto_full_day' && form.value.end_date && form.value.end_date < form.value.request_date) {
    submitError.value = 'End date must be on or after the start date'
    return
  }

  const dates = datesToSubmit()

  // Single day: submit straight away — the result banner already explains a rejection.
  if (dates.length === 1) {
    await runSubmit(dates)
    return
  }

  // Multi-day range: dry-run every day FIRST so the user can decide what to do about
  // the unavailable ones, rather than finding out after the good days are committed.
  checkingRange.value = true
  try {
    const preview = await $fetch<RangePreview>('/api/schedule-requests/preview', {
      method: 'POST',
      body: {
        employee_id: form.value.employee_id,
        request_type: form.value.request_type,
        dates,
        start_time: form.value.start_time || null,
        end_time: form.value.end_time || null,
      },
    })

    if (preview.rejectedCount > 0) {
      rangePreview.value = preview
      return // wait for the user's choice in the confirmation dialog
    }
    await runSubmit(dates)
  } catch (e: any) {
    // Preview failed (offline, server error) — don't silently commit a partial range.
    submitError.value = e.data?.message || e.message || 'Could not check availability for this range'
  } finally {
    checkingRange.value = false
  }
}

// --- Range confirmation dialog -------------------------------------------------
const confirmAvailableOnly = async () => {
  const dates = availableDates.value
  rangePreview.value = null
  if (dates.length) await runSubmit(dates)
}

const cancelRange = () => {
  rangePreview.value = null
}

const resetForm = () => {
  submitResult.value = null
  submitResultsMulti.value = []
  submitError.value = null
  rangePreview.value = null
  // Pull fresh numbers — the request just submitted has changed the day's budget.
  loadWeekAvailability()
  form.value = {
    employee_id: props.preselectedEmployeeId || '',
    request_type: '',
    request_date: defaultDate,
    end_date: '',
    start_time: '',
    end_time: '',
    original_shift_id: '',
    requested_shift_id: '',
    notes: '',
  }
}

const loadWeekAvailability = async () => {
  try {
    availabilityError.value = ''
    const mon = selectedWeekMonday.value
    const sun = new Date(mon)
    sun.setDate(mon.getDate() + 6)

    const params: Record<string, string> = {
      date_from: formatDateStr(mon),
      date_to: formatDateStr(sun),
    }
    // Scope to the selected employee's team — that's the budget the rule measures
    // against. Without it a super admin would see a cross-team total.
    if (form.value.employee_id) params.employee_id = form.value.employee_id

    const [availability, blocked] = await Promise.all([
      $fetch<{ days: any[] }>('/api/pto/availability', { params }),
      $fetch<any[]>('/api/team-blocked-dates'),
    ])

    availabilityDays.value = availability?.days || []
    weekBlockedDates.value = blocked || []
  } catch (e: any) {
    availabilityDays.value = []
    availabilityError.value = 'Availability unavailable — limits still apply on submit.'
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
