<template>
  <div class="min-h-screen bg-gray-50 py-8">
    <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
      <!-- Header -->
      <div class="mb-6">
        <NuxtLink to="/" class="text-blue-600 hover:text-blue-800 mb-3 inline-block text-sm">
          &larr; Back to Home
        </NuxtLink>
        <div class="flex items-center justify-between flex-wrap gap-3">
          <h1 class="text-2xl font-bold text-gray-900">PTO Calendar</h1>
          <div class="flex items-center gap-2">
            <button
              @click="viewMode = 'week'"
              :class="viewMode === 'week' ? 'bg-blue-600 text-white' : 'bg-white text-gray-700 border border-gray-300'"
              class="px-3 py-1.5 rounded-md text-sm font-medium"
            >
              Week
            </button>
            <button
              @click="viewMode = 'month'"
              :class="viewMode === 'month' ? 'bg-blue-600 text-white' : 'bg-white text-gray-700 border border-gray-300'"
              class="px-3 py-1.5 rounded-md text-sm font-medium"
            >
              Month
            </button>
          </div>
        </div>
        <!-- Navigation -->
        <div class="flex items-center gap-3 mt-3">
          <button @click="navigate(-1)" class="px-2 py-1 rounded bg-white border border-gray-300 hover:bg-gray-50 text-sm">&larr;</button>
          <span class="text-sm font-medium text-gray-700">{{ dateRangeLabel }}</span>
          <button @click="navigate(1)" class="px-2 py-1 rounded bg-white border border-gray-300 hover:bg-gray-50 text-sm">&rarr;</button>
          <button @click="goToToday" class="px-3 py-1 rounded bg-white border border-gray-300 hover:bg-gray-50 text-sm">Today</button>
        </div>
      </div>

      <!-- Legend -->
      <div class="flex items-center gap-4 mb-4 text-xs">
        <span class="flex items-center gap-1"><span class="w-3 h-3 rounded bg-green-500 inline-block"></span> Approved</span>
        <span class="flex items-center gap-1"><span class="w-3 h-3 rounded bg-yellow-400 inline-block"></span> Pending</span>
        <span class="flex items-center gap-1"><span class="w-3 h-3 rounded bg-red-200 border border-red-400 inline-block"></span> Blocked (no requests allowed)</span>
      </div>

      <!-- Loading -->
      <div v-if="loading" class="text-center py-12 text-gray-500">Loading calendar data...</div>

      <!-- Week View -->
      <div v-else-if="viewMode === 'week'" class="bg-white shadow rounded-lg overflow-hidden">
        <div class="grid grid-cols-7 border-b">
          <div
            v-for="day in weekDays"
            :key="day.date"
            class="p-2 text-center border-r last:border-r-0"
            :class="day.isToday ? 'bg-blue-50' : 'bg-gray-50'"
          >
            <div class="text-xs font-medium text-gray-500">{{ day.dayName }}</div>
            <div class="text-sm font-bold" :class="day.isToday ? 'text-blue-600' : 'text-gray-900'">{{ day.dayNum }}</div>
          </div>
        </div>
        <div class="grid grid-cols-7 min-h-[300px]">
          <div
            v-for="day in weekDays"
            :key="day.date"
            class="p-1.5 border-r last:border-r-0 space-y-1 relative"
            :class="[
              day.isToday ? 'bg-blue-50/30' : '',
              getBlockForDate(day.date) ? 'bg-red-50' : ''
            ]"
          >
            <div
              v-if="getBlockForDate(day.date)"
              class="text-[10px] font-semibold text-red-700 bg-red-100 border border-red-200 rounded px-1.5 py-0.5 mb-1"
              :title="getBlockForDate(day.date)?.reason || 'No requests allowed'"
            >
              🚫 Blocked<span v-if="getBlockForDate(day.date)?.reason">: {{ getBlockForDate(day.date)?.reason }}</span>
            </div>
            <div
              v-for="entry in getEntriesForDate(day.date)"
              :key="entry.id"
              class="text-xs rounded px-1.5 py-1 truncate"
              :class="entry.status === 'approved'
                ? 'bg-green-100 text-green-800 border border-green-200'
                : 'bg-yellow-100 text-yellow-800 border border-yellow-200'"
              :title="`${entry.employee_name} - ${entry.typeLabel}${entry.notes ? ': ' + entry.notes : ''}`"
            >
              <span class="font-medium">{{ entry.employee_name }}</span>
              <span class="opacity-70 ml-1">{{ entry.typeLabel }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Month View -->
      <div v-else class="bg-white shadow rounded-lg overflow-hidden">
        <div class="grid grid-cols-7 border-b bg-gray-50">
          <div v-for="d in ['Mon','Tue','Wed','Thu','Fri','Sat','Sun']" :key="d" class="p-2 text-center text-xs font-medium text-gray-500 border-r last:border-r-0">
            {{ d }}
          </div>
        </div>
        <div class="grid grid-cols-7">
          <div
            v-for="day in monthDays"
            :key="day.date"
            class="min-h-[80px] p-1 border-r border-b last:border-r-0"
            :class="[
              day.isCurrentMonth ? '' : 'bg-gray-50/50',
              day.isToday ? 'bg-blue-50/40' : '',
              getBlockForDate(day.date) ? 'bg-red-50' : ''
            ]"
            :title="getBlockForDate(day.date) ? `Blocked: ${getBlockForDate(day.date)?.reason || 'No requests allowed'}` : ''"
          >
            <div class="flex items-center justify-between mb-0.5">
              <span class="text-xs" :class="[
                day.isToday ? 'font-bold text-blue-600' : day.isCurrentMonth ? 'text-gray-700' : 'text-gray-400'
              ]">
                {{ day.dayNum }}
              </span>
              <span v-if="getBlockForDate(day.date)" class="text-[9px] text-red-600 font-semibold">🚫</span>
            </div>
            <div class="space-y-0.5">
              <div
                v-for="entry in getEntriesForDate(day.date).slice(0, 3)"
                :key="entry.id"
                class="text-[10px] rounded px-1 py-0.5 truncate"
                :class="entry.status === 'approved'
                  ? 'bg-green-100 text-green-800'
                  : 'bg-yellow-100 text-yellow-800'"
                :title="entry.employee_name + ' - ' + entry.typeLabel"
              >
                {{ entry.employee_name }}
              </div>
              <div
                v-if="getEntriesForDate(day.date).length > 3"
                class="text-[10px] text-gray-400 px-1"
              >
                +{{ getEntriesForDate(day.date).length - 3 }} more
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Admin: Pending Requests -->
      <div v-if="isAdmin && pendingRequests.length > 0" class="mt-6 bg-white shadow rounded-lg p-6">
        <h2 class="text-lg font-semibold text-gray-900 mb-4">Pending Requests ({{ pendingRequests.length }})</h2>
        <div class="space-y-3">
          <div
            v-for="req in pendingRequests"
            :key="req.id"
            class="flex items-center justify-between p-3 border border-yellow-200 bg-yellow-50 rounded-lg"
          >
            <div>
              <span class="font-medium text-gray-900">{{ req.employee_name }}</span>
              <span class="text-sm text-gray-500 ml-2">{{ formatRequestType(req.request_type) }}</span>
              <span class="text-sm text-gray-500 ml-2">{{ formatDate(req.request_date) }}</span>
              <span v-if="req.notes" class="text-xs text-gray-400 ml-2">— {{ req.notes }}</span>
            </div>
            <div class="flex items-center gap-2">
              <button
                @click="handleOverride(req.id, 'approved')"
                class="px-3 py-1 bg-green-600 text-white text-sm rounded hover:bg-green-700"
              >
                Approve
              </button>
              <button
                @click="handleOverride(req.id, 'rejected')"
                class="px-3 py-1 bg-red-600 text-white text-sm rounded hover:bg-red-700"
              >
                Reject
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- All Requests Table -->
      <div class="mt-6 bg-white shadow rounded-lg p-6">
        <h2 class="text-lg font-semibold text-gray-900 mb-4">Requests</h2>
        <div v-if="allRequests.length === 0" class="text-sm text-gray-500">No requests for this period.</div>
        <div v-else class="overflow-x-auto">
          <table class="min-w-full text-sm">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-3 py-2 text-left font-medium text-gray-500">Employee</th>
                <th class="px-3 py-2 text-left font-medium text-gray-500">Type</th>
                <th class="px-3 py-2 text-left font-medium text-gray-500">Date</th>
                <th class="px-3 py-2 text-left font-medium text-gray-500">Status</th>
                <th class="px-3 py-2 text-left font-medium text-gray-500">Notes</th>
                <th v-if="isAdmin" class="px-3 py-2 text-left font-medium text-gray-500">Actions</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              <tr v-for="req in allRequests" :key="req.id">
                <td class="px-3 py-2">{{ req.employee_name }}</td>
                <td class="px-3 py-2">{{ formatRequestType(req.request_type) }}</td>
                <td class="px-3 py-2">{{ formatDate(req.request_date) }}</td>
                <td class="px-3 py-2">
                  <span
                    class="px-2 py-0.5 rounded-full text-xs font-medium"
                    :class="{
                      'bg-green-100 text-green-800': req.status === 'approved',
                      'bg-yellow-100 text-yellow-800': req.status === 'pending',
                      'bg-red-100 text-red-800': req.status === 'rejected',
                    }"
                  >{{ req.status }}</span>
                </td>
                <td class="px-3 py-2 text-gray-500 max-w-[200px] truncate">{{ req.rejection_reason || req.notes || '-' }}</td>
                <td v-if="isAdmin" class="px-3 py-2">
                  <button
                    v-if="req.status !== 'approved'"
                    @click="handleOverride(req.id, 'approved')"
                    class="text-green-600 hover:text-green-800 text-xs mr-2"
                  >Approve</button>
                  <button
                    v-if="req.status !== 'rejected'"
                    @click="handleOverride(req.id, 'rejected')"
                    class="text-red-600 hover:text-red-800 text-xs mr-2"
                  >Reject</button>
                  <button
                    @click="handleCancel(req.id)"
                    class="text-gray-500 hover:text-gray-700 text-xs"
                  >Delete</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- New Request card -->
      <div class="mt-6 bg-white shadow rounded-lg p-6 flex items-center justify-between">
        <div>
          <h2 class="text-lg font-semibold text-gray-900">Add or Edit a Request</h2>
          <p class="text-sm text-gray-500 mt-1">Submit a new time-off or schedule-change request for an employee.</p>
        </div>
        <button
          @click="showRequestModal = true"
          class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 text-sm font-medium"
        >
          New Request
        </button>
      </div>
    </div>

    <!-- Request Modal -->
    <ScheduleRequestsRequestFormModal
      v-if="showRequestModal"
      @close="showRequestModal = false"
      @submitted="onRequestSubmitted"
    />
  </div>
</template>

<script setup lang="ts">
const { user } = useAuth()
const { fetchRequests, requests, overrideRequest, cancelRequest, loading } = useScheduleRequests()
const { blockedDates, fetchBlockedDates } = useTeamBlockedDates()

const viewMode = ref<'week' | 'month'>('week')
const referenceDate = ref(new Date())
const showRequestModal = ref(false)

const onRequestSubmitted = () => {
  loadCalendar()
}

const isAdmin = computed(() => user.value?.is_admin || user.value?.is_super_admin)

// Calendar data from the PTO calendar API
const calendarData = ref<{ pto_days: any[]; requests: any[] }>({ pto_days: [], requests: [] })

const todayStr = computed(() => {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
})

// Week helpers
const getMonday = (d: Date): Date => {
  const date = new Date(d)
  const day = date.getDay()
  const diff = day === 0 ? -6 : 1 - day
  date.setDate(date.getDate() + diff)
  return date
}

const weekDays = computed(() => {
  const monday = getMonday(referenceDate.value)
  const days = []
  const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
  for (let i = 0; i < 7; i++) {
    const d = new Date(monday)
    d.setDate(monday.getDate() + i)
    const dateStr = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
    days.push({
      date: dateStr,
      dayName: dayNames[i],
      dayNum: d.getDate(),
      isToday: dateStr === todayStr.value,
    })
  }
  return days
})

// Month helpers
const monthDays = computed(() => {
  const year = referenceDate.value.getFullYear()
  const month = referenceDate.value.getMonth()
  const firstDay = new Date(year, month, 1)
  const lastDay = new Date(year, month + 1, 0)

  // Start from Monday of the week containing the 1st
  const startDate = getMonday(firstDay)
  const days = []

  const current = new Date(startDate)
  // Fill 6 weeks (42 days) to always have a complete grid
  for (let i = 0; i < 42; i++) {
    const dateStr = `${current.getFullYear()}-${String(current.getMonth() + 1).padStart(2, '0')}-${String(current.getDate()).padStart(2, '0')}`
    days.push({
      date: dateStr,
      dayNum: current.getDate(),
      isCurrentMonth: current.getMonth() === month,
      isToday: dateStr === todayStr.value,
    })
    current.setDate(current.getDate() + 1)
  }
  return days
})

const dateRangeLabel = computed(() => {
  if (viewMode.value === 'week') {
    const start = weekDays.value[0]
    const end = weekDays.value[6]
    return `${start.date} — ${end.date}`
  } else {
    return referenceDate.value.toLocaleString('en-US', { month: 'long', year: 'numeric' })
  }
})

const dateFrom = computed(() => {
  if (viewMode.value === 'week') return weekDays.value[0].date
  return monthDays.value[0].date
})

const dateTo = computed(() => {
  if (viewMode.value === 'week') return weekDays.value[6].date
  return monthDays.value[monthDays.value.length - 1].date
})

// Combined entries for calendar display
interface CalendarEntry {
  id: string
  employee_name: string
  status: 'approved' | 'pending'
  typeLabel: string
  notes: string | null
  date: string
}

const entriesByDate = computed(() => {
  const map: Record<string, CalendarEntry[]> = {}

  // From PTO days (all approved)
  for (const pto of calendarData.value.pto_days) {
    const date = pto.pto_date?.split('T')[0] || pto.pto_date
    if (!map[date]) map[date] = []
    map[date].push({
      id: `pto-${pto.id}`,
      employee_name: pto.employee_name || 'Unknown',
      status: 'approved',
      typeLabel: pto.pto_type === 'full_day' ? 'Full Day' : (pto.pto_type || 'PTO'),
      notes: pto.notes,
      date,
    })
  }

  // From schedule requests (approved/pending that don't already have a PTO entry)
  const ptoPtoIds = new Set(calendarData.value.pto_days.map((p: any) => p.id))
  for (const req of calendarData.value.requests) {
    // Skip if this request's created_pto_id is already shown as a PTO day
    if (req.created_pto_id && ptoPtoIds.has(req.created_pto_id)) continue
    const date = req.request_date?.split('T')[0] || req.request_date
    if (!map[date]) map[date] = []
    map[date].push({
      id: `req-${req.id}`,
      employee_name: req.employee_name || 'Unknown',
      status: req.status,
      typeLabel: formatRequestType(req.request_type),
      notes: req.notes,
      date,
    })
  }

  return map
})

const getEntriesForDate = (date: string): CalendarEntry[] => {
  return entriesByDate.value[date] || []
}

const blockedByDate = computed(() => {
  const map: Record<string, { reason: string | null }> = {}
  for (const b of blockedDates.value) {
    const d = typeof b.blocked_date === 'string' ? b.blocked_date.split('T')[0] : b.blocked_date
    if (d) map[d] = { reason: b.reason }
  }
  return map
})

const getBlockForDate = (date: string): { reason: string | null } | null => {
  return blockedByDate.value[date] || null
}

// Requests lists
const allRequests = computed(() => requests.value)
const pendingRequests = computed(() => requests.value.filter(r => r.status === 'pending'))

const formatDate = (dateStr: string | null | undefined) => {
  if (!dateStr) return ''
  const datePart = dateStr.split('T')[0]
  const [y, m, d] = datePart.split('-').map(Number)
  if (!y || !m || !d) return dateStr
  const date = new Date(y, m - 1, d)
  return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
}

const formatRequestType = (type: string) => {
  const labels: Record<string, string> = {
    leave_early: 'Leave Early',
    pto_full_day: 'Full Day Off',
    pto_partial: 'Partial Day',
    shift_swap: 'Shift Change',
  }
  return labels[type] || type
}

const navigate = (direction: number) => {
  const d = new Date(referenceDate.value)
  if (viewMode.value === 'week') {
    d.setDate(d.getDate() + direction * 7)
  } else {
    d.setMonth(d.getMonth() + direction)
  }
  referenceDate.value = d
}

const goToToday = () => {
  referenceDate.value = new Date()
}

const loadCalendar = async () => {
  const [calData] = await Promise.all([
    $fetch<{ pto_days: any[]; requests: any[] }>('/api/pto-calendar', {
      params: { date_from: dateFrom.value, date_to: dateTo.value },
    }),
    fetchRequests({ date_from: dateFrom.value, date_to: dateTo.value }),
    fetchBlockedDates(),
  ])
  calendarData.value = calData
}

// Admin actions
const handleOverride = async (id: string, status: string) => {
  try {
    await overrideRequest(id, { status })
    await loadCalendar()
  } catch {
    // error shown by composable
  }
}

const handleCancel = async (id: string) => {
  if (!confirm('Delete this request and any associated PTO/swap records?')) return
  try {
    await cancelRequest(id)
    await loadCalendar()
  } catch {
    // error shown by composable
  }
}

// Reload when view or date changes
watch([dateFrom, dateTo], () => {
  loadCalendar()
})

onMounted(() => {
  loadCalendar()
})
</script>
