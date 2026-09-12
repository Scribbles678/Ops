<template>
  <div class="business-rules-page min-h-screen bg-gray-50">
    <div class="container mx-auto px-3 md:px-4 py-4 md:py-6">
      <!-- Header -->
      <div class="flex items-center justify-between mb-4 md:mb-6">
        <div>
          <h1 class="text-2xl md:text-3xl font-semibold text-gray-800 leading-tight">Staffing Targets</h1>
          <p class="text-gray-600 mt-1 text-xs md:text-sm">Set target headcount per job function per hour for automated scheduling</p>
        </div>
        <div class="flex space-x-2 md:space-x-3">
          <NuxtLink to="/" class="btn-secondary">
            ← Back to Home
          </NuxtLink>
        </div>
      </div>

      <!-- Action Buttons -->
      <div class="mb-4 flex flex-wrap gap-2">
        <button
          @click="openPreferredAssignmentsModal"
          class="btn-secondary-sm md:btn-secondary flex items-center"
        >
          <svg class="w-4 h-4 md:w-5 md:h-5 mr-1.5 md:mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
          </svg>
          Required Assignments
        </button>
      </div>

      <!-- Success Toast -->
      <div
        v-if="showSuccessToast"
        class="fixed top-20 right-6 z-50 bg-green-100 border border-green-200 text-green-700 px-3 py-2 rounded-lg shadow-md flex items-center space-x-2 text-sm md:text-base"
      >
        <svg class="w-4 h-4 md:w-5 md:h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
        </svg>
        <span class="font-medium">{{ successToastMessage }}</span>
      </div>

      <!-- Staffing Targets Grid -->
      <div class="card p-3 md:p-4">
        <div v-if="loading" class="text-center py-5 text-sm text-gray-600">
          Loading staffing targets...
        </div>

        <div v-else-if="gridError" class="text-center py-5 text-sm text-red-600">
          Error: {{ gridError }}
        </div>

        <div v-else-if="gridJobFunctions.length === 0" class="text-center py-5 text-sm text-gray-600">
          No job functions found. Please create job functions first.
        </div>

        <div v-else-if="gridHours.length === 0" class="text-center py-5 text-sm text-gray-600">
          No active shifts are set up, so there are no hours to set targets for.
          Add shifts in <NuxtLink to="/details?tab=shifts" class="text-blue-600 hover:underline">Team Setup → Shift Management</NuxtLink>.
        </div>

        <div v-else>
          <div class="overflow-x-auto -mx-1 md:-mx-2">
            <table class="min-w-full text-xs md:text-sm">
              <thead class="bg-gray-50 text-xs uppercase tracking-wide text-gray-500">
                <tr>
                  <th class="px-3 md:px-4 py-2 text-left sticky left-0 bg-gray-50 z-10 min-w-[140px]">Job Function</th>
                  <th
                    v-for="hour in gridHours"
                    :key="hour.value"
                    class="px-2 py-2 text-center min-w-[60px]"
                    :class="hour.staffed ? '' : 'bg-amber-50 text-amber-700'"
                    :title="hour.staffed ? '' : 'No shift covers this hour — anything set here can never be staffed'"
                  >
                    {{ hour.label }}
                  </th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <tr v-for="jf in gridJobFunctions" :key="jf.id">
                  <td class="px-3 md:px-4 py-2 whitespace-nowrap font-medium text-gray-900 sticky left-0 bg-white z-10">
                    {{ jf.name }}
                  </td>
                  <td
                    v-for="hour in gridHours"
                    :key="hour.value"
                    class="px-1 py-1 text-center"
                    :class="hour.staffed ? '' : 'bg-amber-50'"
                  >
                    <input
                      type="number"
                      min="0"
                      :value="getGridValue(jf.id, hour.value)"
                      @input="setGridValue(jf.id, hour.value, ($event.target as HTMLInputElement).value)"
                      class="w-14 px-1 py-1 text-center border border-gray-200 rounded focus:outline-none focus:ring-1 focus:ring-blue-500 text-sm"
                    />
                  </td>
                </tr>
              </tbody>
              <!-- Per-hour summary. Targeted is live against the inputs above, so the
                   effect of an edit is visible before saving. -->
              <tfoot>
                <tr class="border-t-2 border-gray-300">
                  <td class="px-3 md:px-4 py-1.5 whitespace-nowrap text-xs font-semibold text-gray-700 sticky left-0 bg-white z-10">
                    Targeted
                  </td>
                  <td v-for="hour in gridHours" :key="'t' + hour.value"
                      class="px-1 py-1.5 text-center text-xs font-semibold text-gray-900 tabular-nums">
                    {{ targetedByHour[hour.value] }}
                  </td>
                </tr>
                <tr>
                  <td class="px-3 md:px-4 py-1.5 whitespace-nowrap text-xs text-gray-600 sticky left-0 bg-white z-10">
                    On shift
                  </td>
                  <td v-for="hour in gridHours" :key="'a' + hour.value"
                      class="px-1 py-1.5 text-center text-xs text-gray-600 tabular-nums">
                    {{ staffOnShiftByHour[hour.value] }}
                  </td>
                </tr>
                <tr>
                  <td class="px-3 md:px-4 py-1.5 whitespace-nowrap text-xs text-gray-600 sticky left-0 bg-white z-10">
                    Spare
                  </td>
                  <td v-for="hour in gridHours" :key="'s' + hour.value"
                      class="px-1 py-1.5 text-center text-xs tabular-nums"
                      :class="spareClass(spareByHour[hour.value])">
                    {{ spareByHour[hour.value] > 0 ? '+' : '' }}{{ spareByHour[hour.value] }}
                  </td>
                </tr>
              </tfoot>
            </table>
          </div>

          <p v-if="unstaffedHours.length > 0" class="mt-3 text-xs text-amber-700 bg-amber-50 border border-amber-200 rounded-lg px-3 py-2">
            <strong>{{ unstaffedHours.map(h => h.label).join(', ') }}</strong>
            {{ unstaffedHours.length === 1 ? 'is' : 'are' }} shaded because no shift covers
            {{ unstaffedHours.length === 1 ? 'that hour' : 'those hours' }} — targets set there can never
            be staffed and the builder ignores them. Set them to 0 to clear them, or add a shift that covers
            {{ unstaffedHours.length === 1 ? 'it' : 'them' }}.
          </p>

          <p class="mt-3 text-xs text-gray-500">
            <span class="font-medium text-gray-600">On shift</span> counts everyone whose shift covers
            that hour. It ignores time off, breaks and lunch — for the real picture on a specific day,
            use the Training &amp; Coverage Preview on the Create Schedule page.
          </p>
          <p class="mt-1.5 text-xs text-gray-500">
            Columns follow your active shifts, set in
            <NuxtLink to="/details?tab=shifts" class="text-blue-600 hover:underline">Team Setup → Shift Management</NuxtLink>.
          </p>

          <div class="flex justify-end mt-4">
            <button
              @click="saveAllTargets"
              :disabled="saving || !hasChanges"
              class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed text-sm font-medium transition-colors"
            >
              {{ saving ? 'Saving...' : 'Save All' }}
            </button>
          </div>
        </div>
      </div>

      <!-- Required Assignments Modal -->
      <div v-if="showPreferredAssignmentsModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-white rounded-lg p-6 max-w-4xl w-full mx-4 max-h-[90vh] overflow-y-auto">
          <div class="flex items-center justify-between mb-6">
            <h3 class="text-2xl font-bold text-gray-800">Required Assignments</h3>
            <button @click="closePreferredAssignmentsModal" class="text-gray-400 hover:text-gray-600">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <div class="mb-6">
            <button @click="openAddPreferredAssignmentModal" class="btn-primary flex items-center">
              <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
              </svg>
              Add Required Assignment
            </button>
          </div>

          <div v-if="preferredAssignmentsLoading" class="text-center py-8">
            <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
            <p class="mt-2 text-gray-600">Loading required assignments...</p>
          </div>

          <div v-else-if="preferredAssignmentsError" class="bg-red-50 border border-red-200 rounded-lg p-4 mb-6">
            <p class="text-red-600">Error loading required assignments: {{ preferredAssignmentsError }}</p>
          </div>

          <div v-else class="space-y-4">
            <div
              v-for="pref in preferredAssignments"
              :key="pref.id"
              class="border border-gray-200 rounded-lg p-4 hover:shadow-md transition"
            >
              <div class="flex items-center justify-between">
                <div class="flex-1">
                  <div class="flex items-center space-x-4 mb-2">
                    <div class="flex-1">
                      <h4 class="text-lg font-semibold text-gray-800">
                        {{ pref.employee?.first_name }} {{ pref.employee?.last_name }}
                      </h4>
                      <template v-if="pref.blocks && pref.blocks.length">
                        <p v-for="(b, i) in pref.blocks" :key="i" class="text-sm text-gray-600">
                          {{ fmtTime12(b.start_time) }}–{{ fmtTime12(b.end_time) }}:
                          <span class="font-medium">{{ getJfName(b.job_function_id) }}</span>
                        </p>
                      </template>
                      <template v-else-if="!pref.am_job_function_id && !pref.pm_job_function_id">
                        <p class="text-sm text-gray-600">
                          1st &amp; 2nd Half: <span class="font-medium">{{ pref.job_function?.name }}</span>
                        </p>
                      </template>
                      <template v-else>
                        <p class="text-sm text-gray-600">
                          1st Half: <span class="font-medium">{{ pref.am_job_function_id ? getJfName(pref.am_job_function_id) : 'Not assigned' }}</span>
                        </p>
                        <p class="text-sm text-gray-600">
                          2nd Half: <span class="font-medium">{{ pref.pm_job_function_id ? getJfName(pref.pm_job_function_id) : 'Not assigned' }}</span>
                        </p>
                      </template>
                    </div>
                  </div>
                </div>
                <div class="flex space-x-2 ml-4">
                  <button
                    @click="openEditPreferredAssignmentModal(pref)"
                    class="px-4 py-2 bg-blue-100 text-blue-600 rounded hover:bg-blue-200 transition"
                  >
                    Edit
                  </button>
                  <button
                    @click="deletePreferredAssignmentHandler(pref.id)"
                    class="px-4 py-2 bg-red-100 text-red-600 rounded hover:bg-red-200 transition"
                  >
                    Delete
                  </button>
                </div>
              </div>
            </div>

            <div v-if="preferredAssignments.length === 0" class="text-center py-8 text-gray-500">
              <p>No required assignments configured yet.</p>
              <p class="text-sm mt-2">Click "+ Add Required Assignment" to create one.</p>
            </div>
          </div>

          <!-- Add/Edit Required Assignment Modal -->
          <div v-if="showPreferredAssignmentFormModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-[60]">
            <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4 relative">
              <div
                v-if="showSavedIcon"
                class="absolute inset-0 bg-white bg-opacity-95 flex items-center justify-center z-10 rounded-lg transition-opacity duration-300"
              >
                <div class="flex flex-col items-center">
                  <svg class="w-16 h-16 text-green-500 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                  </svg>
                  <span class="text-lg font-semibold text-green-600">Saved</span>
                </div>
              </div>

              <h4 class="text-xl font-bold mb-4">
                {{ editingPreferredAssignment ? 'Edit Required Assignment' : 'Add Required Assignment' }}
              </h4>
              <form @submit.prevent="handlePreferredAssignmentSubmit" class="space-y-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Employee</label>
                  <select
                    v-model="preferredAssignmentFormData.employee_id"
                    required
                    class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                  >
                    <option value="">Select employee...</option>
                    <option
                      v-for="employee in employees"
                      :key="employee.id"
                      :value="employee.id"
                    >
                      {{ employee.first_name }} {{ employee.last_name }}
                    </option>
                  </select>
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Time Blocks</label>
                  <div class="space-y-2">
                    <div
                      v-for="(blk, idx) in preferredAssignmentFormData.blocks"
                      :key="idx"
                      class="flex items-center gap-2"
                    >
                      <input
                        v-model="blk.start_time"
                        type="time"
                        class="px-2 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 w-28"
                      />
                      <span class="text-gray-400">–</span>
                      <input
                        v-model="blk.end_time"
                        type="time"
                        class="px-2 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 w-28"
                      />
                      <select
                        v-model="blk.job_function_id"
                        class="flex-1 px-2 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                      >
                        <option value="">Select function…</option>
                        <option v-for="jf in sortedJobFunctions" :key="jf.id" :value="jf.id">{{ jf.name }}</option>
                      </select>
                      <button
                        type="button"
                        @click="preferredAssignmentFormData.blocks.splice(idx, 1)"
                        class="px-2 py-1 text-red-500 hover:text-red-700"
                        title="Remove block"
                      >✕</button>
                    </div>
                  </div>
                  <button
                    type="button"
                    @click="addBlockRow"
                    class="mt-2 px-3 py-1.5 text-sm border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50"
                  >+ Add block</button>
                  <p class="text-xs text-gray-500 mt-2">
                    Pin this employee to a function for each time block. Times are clock times (clipped to their shift; breaks auto-removed). Leave a gap to fill that time by demand. At least one block is required.
                  </p>
                </div>
                <div class="flex justify-end space-x-3 pt-4">
                  <button
                    type="button"
                    @click="closePreferredAssignmentFormModal"
                    class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    class="btn-primary"
                  >
                    {{ editingPreferredAssignment ? 'Update' : 'Create' }}
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const { jobFunctions, fetchJobFunctions } = useJobFunctions()
const { employees, fetchEmployees } = useEmployees()
const { shifts, fetchShifts } = useSchedule()
const { targets, loading: targetsLoading, error: targetsError, fetchTargets, saveTargets } = useStaffingTargets()
const {
  preferredAssignments,
  loading: preferredAssignmentsLoading,
  error: preferredAssignmentsError,
  fetchPreferredAssignments,
  createPreferredAssignment,
  updatePreferredAssignment,
  deletePreferredAssignment
} = usePreferredAssignments()

const loading = ref(true)
const saving = ref(false)
const gridError = ref<string | null>(null)
const showSuccessToast = ref(false)
const successToastMessage = ref('')
let successTimeout: ReturnType<typeof setTimeout> | null = null

// Required Assignments Modal State
const showPreferredAssignmentsModal = ref(false)
const showPreferredAssignmentFormModal = ref(false)
const editingPreferredAssignment = ref<any>(null)
interface AssignmentBlock { start_time: string; end_time: string; job_function_id: string }
const preferredAssignmentFormData = ref<{ employee_id: string; blocks: AssignmentBlock[] }>({ employee_id: '', blocks: [] })

const addBlockRow = () => {
  preferredAssignmentFormData.value.blocks.push({ start_time: '', end_time: '', job_function_id: '' })
}
const showSavedIcon = ref(false)

// Grid data: { "jfId|hour": headcount }
const gridData = ref<Record<string, number>>({})
const originalGridData = ref<Record<string, number>>({})

/** "HH:MM[:SS]" -> minutes past midnight, or null. */
const timeToMinutes = (t: string | null | undefined): number | null => {
  if (!t) return null
  const parts = String(t).split(':')
  const h = Number(parts[0])
  const m = Number(parts[1] ?? 0)
  if (Number.isNaN(h) || Number.isNaN(m)) return null
  return h * 60 + m
}

/**
 * Hours covered by at least one ACTIVE shift.
 *
 * An hour column is included when any part of it is worked: a 07:00-14:30 shift
 * covers 7AM through 2PM, because the 2PM column means 14:00-15:00 and half of it
 * is staffed.
 */
const staffedHours = computed<Set<number>>(() => {
  const set = new Set<number>()
  for (const sh of shifts.value || []) {
    if (!sh || sh.is_active === false) continue
    const start = timeToMinutes(sh.start_time)
    let end = timeToMinutes(sh.end_time)
    if (start == null || end == null) continue
    if (end <= start) end += 24 * 60 // crosses midnight
    for (let h = Math.floor(start / 60); h <= Math.ceil(end / 60) - 1; h++) {
      set.add(((h % 24) + 24) % 24)
    }
  }
  return set
})

/**
 * Hours that already carry a target, whether or not a shift covers them.
 *
 * These have to stay visible even when no shift reaches them. A target left
 * behind by a retired shift is exactly what the builder warns about ("clear those
 * cells in the Target Hours grid") — and if the column were hidden, there would
 * be no way to do that.
 */
const hoursWithTargets = computed<Set<number>>(() => {
  const set = new Set<number>()
  for (const t of targets.value || []) {
    if (!((t.headcount ?? 0) > 0)) continue
    const h = Number(String(t.hour_start).slice(0, 2))
    if (!Number.isNaN(h)) set.add(h)
  }
  return set
})

/**
 * Hour columns, derived from the team's shifts rather than hardcoded.
 *
 * This grid used to run a fixed 6AM-8PM, so it offered hours nobody works and
 * would have hidden any hour worked outside that window.
 */
const gridHours = computed(() => {
  const hours = [...new Set([...staffedHours.value, ...hoursWithTargets.value])].sort((a, b) => a - b)
  return hours.map((h) => {
    const value = `${String(h).padStart(2, '0')}:00`
    const period = h >= 12 ? 'PM' : 'AM'
    const display = h > 12 ? h - 12 : h === 0 ? 12 : h
    return { value, label: `${display}${period}`, staffed: staffedHours.value.has(h) }
  })
})

/**
 * People whose shift covers any part of each hour — the labour you have to spend.
 *
 * Counts a person once per hour their shift overlaps, matching how the grid treats
 * an hourly target. Deliberately ignores time off: this is a planning template, not
 * a specific date, so there is no PTO to apply. It also ignores breaks and lunch —
 * for the real, dated picture (breaks, lunch, PTO and the worst 15 minutes) use the
 * Training & Coverage Preview on the Create Schedule page.
 */
const staffOnShiftByHour = computed<Record<string, number>>(() => {
  const out: Record<string, number> = {}
  const activeShifts = new Map(
    (shifts.value || []).filter((sh: any) => sh && sh.is_active !== false).map((sh: any) => [sh.id, sh])
  )
  for (const h of gridHours.value) {
    const hourStart = Number(h.value.slice(0, 2)) * 60
    const hourEnd = hourStart + 60
    let n = 0
    for (const e of employees.value || []) {
      if (!e || e.is_active === false || !e.shift_id) continue
      const sh: any = activeShifts.get(e.shift_id)
      if (!sh) continue
      const start = timeToMinutes(sh.start_time)
      let end = timeToMinutes(sh.end_time)
      if (start == null || end == null) continue
      if (end <= start) end += 24 * 60 // crosses midnight
      if (start < hourEnd && end > hourStart) n++
    }
    out[h.value] = n
  }
  return out
})

/** Column total, live against what is typed rather than what is saved. */
const targetedByHour = computed<Record<string, number>>(() => {
  const out: Record<string, number> = {}
  for (const h of gridHours.value) {
    let n = 0
    for (const jf of gridJobFunctions.value) n += getGridValue(jf.id, h.value)
    out[h.value] = n
  }
  return out
})

const spareByHour = computed<Record<string, number>>(() => {
  const out: Record<string, number> = {}
  for (const h of gridHours.value) {
    out[h.value] = (staffOnShiftByHour.value[h.value] ?? 0) - (targetedByHour.value[h.value] ?? 0)
  }
  return out
})

const spareClass = (n: number) =>
  n < 0 ? 'text-red-600 font-semibold' : n === 0 ? 'text-amber-600 font-semibold' : 'text-gray-500'

/** Columns shown only because a stale target sits there. */
const unstaffedHours = computed(() => gridHours.value.filter((h) => !h.staffed))

// Job functions for the grid (active, exclude individual Meter N — use parent Meter,
// and exclude any functions marked as exclude_from_targets)
const gridJobFunctions = computed(() => {
  return [...(jobFunctions.value || [])]
    .filter(jf =>
      jf.is_active !== false &&
      !jf.exclude_from_targets &&
      !/^Meter [0-9]+$/.test(jf.name || '')
    )
    .sort((a, b) => (a.name || '').localeCompare(b.name || ''))
})

const sortedJobFunctions = computed(() => {
  return [...(jobFunctions.value || [])]
    .filter(jf => jf.is_active !== false)
    .sort((a, b) => {
      const aIsMeter = a.name?.startsWith('Meter ')
      const bIsMeter = b.name?.startsWith('Meter ')
      if (aIsMeter && !bIsMeter) return 1
      if (!aIsMeter && bIsMeter) return -1
      return (a.name || '').localeCompare(b.name || '')
    })
})

const hasChanges = computed(() => {
  return JSON.stringify(gridData.value) !== JSON.stringify(originalGridData.value)
})

// Look up a job function name by ID (used for AM/PM display in the list)
const getJfName = (id: string | null | undefined): string | null => {
  if (!id) return null
  return jobFunctions.value?.find((jf: any) => jf.id === id)?.name ?? null
}

// Format "HH:MM[:SS]" as "h:MM AM/PM" for the block list display.
const fmtTime12 = (t: string | null | undefined): string => {
  if (!t) return ''
  const [h, m] = String(t).split(':').map(Number)
  if (Number.isNaN(h)) return ''
  const ampm = h >= 12 ? 'PM' : 'AM'
  const hr = h % 12 === 0 ? 12 : h % 12
  return `${hr}:${String(m || 0).padStart(2, '0')} ${ampm}`
}

const gridKey = (jfId: string, hour: string) => `${jfId}|${hour}`

const getGridValue = (jfId: string, hour: string): number => {
  return gridData.value[gridKey(jfId, hour)] ?? 0
}

const setGridValue = (jfId: string, hour: string, rawValue: string) => {
  const val = parseInt(rawValue, 10)
  gridData.value[gridKey(jfId, hour)] = isNaN(val) || val < 0 ? 0 : val
}

const loadGridFromTargets = () => {
  const data: Record<string, number> = {}
  for (const t of targets.value) {
    // DB returns TIME as "HH:MM:SS"; normalize to "HH:MM" to match gridHours keys
    const hour = typeof t.hour_start === 'string' ? t.hour_start.substring(0, 5) : t.hour_start
    data[gridKey(t.job_function_id, hour)] = t.headcount
  }
  gridData.value = { ...data }
  originalGridData.value = { ...data }
}

const saveAllTargets = async () => {
  saving.value = true
  try {
    // Only send cells that actually changed — never zero-out untouched hours
    const items: { job_function_id: string; hour_start: string; headcount: number }[] = []
    for (const jf of gridJobFunctions.value) {
      for (const hour of gridHours.value) {
        const key = gridKey(jf.id, hour.value)
        const current = gridData.value[key] ?? 0
        const original = originalGridData.value[key] ?? 0
        if (current !== original) {
          items.push({ job_function_id: jf.id, hour_start: hour.value, headcount: current })
        }
      }
    }
    if (items.length > 0) {
      await saveTargets(items)
    }
    loadGridFromTargets()
    showSuccessIndicator('Staffing targets saved')
  } catch (e: any) {
    gridError.value = e.message || 'Error saving targets'
  } finally {
    saving.value = false
  }
}

const showSuccessIndicator = (message: string) => {
  successToastMessage.value = message
  showSuccessToast.value = true
  if (successTimeout) clearTimeout(successTimeout)
  successTimeout = setTimeout(() => { showSuccessToast.value = false }, 2000)
}


// Required Assignments Functions
const openPreferredAssignmentsModal = async () => {
  showPreferredAssignmentsModal.value = true
  await fetchPreferredAssignments()
  if (employees.value.length === 0) {
    await fetchEmployees(false)
  }
}

const closePreferredAssignmentsModal = () => {
  showPreferredAssignmentsModal.value = false
  showPreferredAssignmentFormModal.value = false
  editingPreferredAssignment.value = null
}

const openAddPreferredAssignmentModal = () => {
  editingPreferredAssignment.value = null
  preferredAssignmentFormData.value = {
    employee_id: '',
    blocks: [{ start_time: '', end_time: '', job_function_id: '' }],
  }
  showPreferredAssignmentFormModal.value = true
}

// Convert a legacy AM/PM row into explicit time blocks using the employee's shift
// (AM = shift start → lunch, PM = lunch end → shift end). Used when editing old rows.
const legacyAmPmToBlocks = (pref: any): AssignmentBlock[] => {
  const shift = shifts.value?.find((s: any) => s.id === employees.value?.find((e: any) => e.id === pref.employee_id)?.shift_id)
  const bothNull = !pref.am_job_function_id && !pref.pm_job_function_id
  const amJf = pref.am_job_function_id ?? (bothNull ? pref.job_function_id : null)
  const pmJf = pref.pm_job_function_id ?? (bothNull ? pref.job_function_id : null)
  const out: AssignmentBlock[] = []
  if (!shift) return out
  const t = (v: any) => (v ? String(v).substring(0, 5) : '')
  const start = t(shift.start_time)
  const end = t(shift.end_time)
  const lunchStart = t(shift.lunch_start)
  const lunchEnd = t(shift.lunch_end)
  if (amJf) out.push({ start_time: start, end_time: lunchStart || end, job_function_id: amJf })
  if (pmJf && lunchEnd) out.push({ start_time: lunchEnd, end_time: end, job_function_id: pmJf })
  return out
}

const openEditPreferredAssignmentModal = (pref: any) => {
  editingPreferredAssignment.value = pref
  const blocks: AssignmentBlock[] = Array.isArray(pref.blocks) && pref.blocks.length
    ? pref.blocks.map((b: any) => ({
        start_time: String(b.start_time).substring(0, 5),
        end_time: String(b.end_time).substring(0, 5),
        job_function_id: b.job_function_id,
      }))
    : legacyAmPmToBlocks(pref)
  preferredAssignmentFormData.value = {
    employee_id: pref.employee_id,
    blocks: blocks.length ? blocks : [{ start_time: '', end_time: '', job_function_id: '' }],
  }
  showPreferredAssignmentFormModal.value = true
}

const closePreferredAssignmentFormModal = () => {
  showPreferredAssignmentFormModal.value = false
  editingPreferredAssignment.value = null
}

const handlePreferredAssignmentSubmit = async () => {
  try {
    const { employee_id, blocks } = preferredAssignmentFormData.value
    if (!employee_id) {
      alert('Select an employee.')
      return
    }
    const valid = blocks
      .filter((b) => b.start_time && b.end_time && b.job_function_id && b.end_time > b.start_time)
      .map((b) => ({ ...b, start_time: b.start_time, end_time: b.end_time }))
      .sort((a, b) => (a.start_time < b.start_time ? -1 : 1))
    if (valid.length === 0) {
      alert('Add at least one valid time block (start, end with end after start, and a function).')
      return
    }
    // Reject overlapping blocks.
    for (let i = 1; i < valid.length; i++) {
      if (valid[i].start_time < valid[i - 1].end_time) {
        alert('Time blocks overlap. Adjust them so they do not overlap.')
        return
      }
    }
    const payload = {
      employee_id,
      job_function_id: valid[0].job_function_id, // base (NOT NULL); blocks drive the builder
      is_required: true,
      priority: 0,
      notes: '',
      blocks: valid,
    }
    if (editingPreferredAssignment.value) {
      await updatePreferredAssignment(editingPreferredAssignment.value.id, payload)
    } else {
      await createPreferredAssignment(payload)
    }
    await fetchPreferredAssignments()
    showSavedIcon.value = true
    setTimeout(() => {
      showSavedIcon.value = false
      closePreferredAssignmentFormModal()
    }, 1500)
  } catch (e: any) {
    alert(`Error saving required assignment: ${e.message || 'Unknown error'}`)
  }
}

const deletePreferredAssignmentHandler = async (id: string) => {
  try {
    await deletePreferredAssignment(id)
    await fetchPreferredAssignments()
  } catch (e: any) {
    alert(`Error deleting preferred assignment: ${e.message || 'Unknown error'}`)
  }
}

onMounted(async () => {
  try {
    await Promise.all([
      fetchTargets(),
      fetchJobFunctions(),
      fetchEmployees(false),
      fetchShifts()
    ])
    loadGridFromTargets()
  } catch (e: any) {
    gridError.value = e.message || 'Error loading data'
  } finally {
    loading.value = false
  }
})

onBeforeUnmount(() => {
  if (successTimeout) clearTimeout(successTimeout)
})
</script>
