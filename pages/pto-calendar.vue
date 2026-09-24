<template>
  <div class="min-h-screen bg-gray-50 py-8">
    <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
      <!-- Header -->
      <div class="mb-6">
        <NuxtLink to="/" class="btn-secondary inline-block mb-3">
          ← Back to Home
        </NuxtLink>
        <div class="flex items-center justify-between flex-wrap gap-3">
          <h1 class="text-2xl font-bold text-gray-900">PTO Calendar</h1>
          <div class="flex items-center gap-2">
            <button
              @click="showRequestModal = true"
              class="px-4 py-1.5 bg-blue-600 text-white rounded-md hover:bg-blue-700 text-sm font-medium mr-2"
            >
              New Request
            </button>
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

      <p v-if="calendarError" role="alert" class="mb-3 text-sm text-red-700 bg-red-50 border border-red-200 rounded-md px-3 py-2">
        {{ calendarError }}
      </p>

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
            class="p-1.5 border-r last:border-r-0 relative flex flex-col"
            :class="[
              day.isToday ? 'bg-blue-50/30' : '',
              getBlockForDate(day.date) ? 'bg-red-50' : ''
            ]"
          >
            <div class="space-y-1 flex-1">
            <div
              v-if="getBlockForDate(day.date)"
              class="text-[10px] font-semibold text-red-700 bg-red-100 border border-red-200 rounded px-1.5 py-0.5 mb-1"
              :title="getBlockForDate(day.date)?.reason || 'No requests allowed'"
            >
              🚫 Blocked<span v-if="getBlockForDate(day.date)?.reason">: {{ getBlockForDate(day.date)?.reason }}</span>
            </div>
            <!-- Two lines, not one. On a single line the cell truncated mid-label
                 ("Leave Earl…") and the TIME — the only part that matters for a
                 partial absence — was cut off entirely, reachable only by hover. -->
            <div
              v-for="entry in getEntriesForDate(day.date)"
              :key="entry.id"
              class="text-xs rounded px-1.5 py-1 leading-tight"
              :class="entry.status === 'approved'
                ? 'bg-green-100 text-green-800 border border-green-200'
                : 'bg-yellow-100 text-yellow-800 border border-yellow-200'"
              :title="`${entry.employee_name} - ${entry.typeLabel}${entry.time ? ' (' + entry.time + ')' : ''}${entry.notes ? ': ' + entry.notes : ''}`"
            >
              <div class="font-medium truncate">{{ entry.employee_name }}</div>
              <div class="opacity-75 text-[11px]">{{ entryDetail(entry) }}</div>
            </div>
            </div>

            <!-- Hours off for the day, itemised by where they came from.
                 These numbers are computed server-side by the SAME accounting the
                 approval rule measures against the daily cap (getUsedHoursBreakdown-
                 ByDate). The component must never total hours itself — the strip and
                 the rule drifting apart is exactly how this area broke twice. -->
            <div
              v-if="hoursFor(day.date).total > 0"
              class="mt-2 pt-1.5 border-t border-gray-200 text-[10px] leading-snug"
            >
              <div v-if="hoursFor(day.date).approved > 0" class="flex justify-between text-gray-500">
                <span>Approved</span><span>{{ fmtHours(hoursFor(day.date).approved) }}</span>
              </div>
              <div v-if="hoursFor(day.date).callIn > 0" class="flex justify-between text-amber-700">
                <span>Call-ins</span><span>{{ fmtHours(hoursFor(day.date).callIn) }}</span>
              </div>
              <div v-if="hoursFor(day.date).manual > 0" class="flex justify-between text-gray-500">
                <span>Manual</span><span>{{ fmtHours(hoursFor(day.date).manual) }}</span>
              </div>
              <div class="flex justify-between font-semibold text-gray-800 mt-0.5 pt-0.5 border-t border-gray-100">
                <span>Total</span><span>{{ fmtHours(hoursFor(day.date).total) }}</span>
              </div>
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
              <!-- The name alone said nothing: "Lor, Xai" gave no clue whether that
                   was a full day, a call-in or a 20-minute late start. -->
              <div
                v-for="entry in monthEntriesFor(day.date)"
                :key="entry.id"
                class="text-[10px] rounded px-1 py-0.5 leading-tight"
                :class="entry.status === 'approved'
                  ? 'bg-green-100 text-green-800'
                  : 'bg-yellow-100 text-yellow-800'"
                :title="entry.employee_name + ' - ' + entry.typeLabel + (entry.time ? ' (' + entry.time + ')' : '')"
              >
                <div class="truncate">{{ entry.employee_name }}</div>
                <div class="opacity-70 truncate">{{ entryDetailShort(entry) }}</div>
              </div>
              <!-- "+N more" used to be a dead end — the only way to see the rest was
                   to switch to week view and navigate to that week. -->
              <button
                v-if="getEntriesForDate(day.date).length > MONTH_ENTRY_LIMIT"
                @click="toggleDayExpanded(day.date)"
                class="text-[10px] text-blue-600 hover:text-blue-800 hover:underline px-1"
              >
                {{ expandedDays.has(day.date)
                  ? 'Show less'
                  : `+${getEntriesForDate(day.date).length - MONTH_ENTRY_LIMIT} more` }}
              </button>
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
              <span v-if="requestTimeLabel(req)" class="text-sm text-gray-400 ml-1">({{ requestTimeLabel(req) }})</span>
              <span class="text-sm text-gray-500 ml-2">{{ formatDate(req.request_date) }}</span>
              <span v-if="req.notes" class="text-xs text-gray-400 ml-2">— {{ req.notes }}</span>
              <div class="text-xs text-gray-400 mt-0.5" :title="formatFullTimestamp(req.created_at)">
                Submitted {{ formatSubmitted(req.created_at) }}
              </div>
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

      <!-- All Requests Table. Shows the calendar's period, or — while a name is
           typed in the search box — every request for matching people, all dates. -->
      <div class="mt-6 bg-white shadow rounded-lg p-6">
        <div class="flex flex-wrap items-center justify-between gap-3 mb-4">
          <div>
            <h2 class="text-lg font-semibold text-gray-900">Requests</h2>
            <p class="text-xs text-gray-500 mt-0.5">
              <template v-if="requestSearch.trim()">
                Everyone matching “{{ requestSearch.trim() }}”, all dates
                <span v-if="requestsLoading"> · searching…</span>
              </template>
              <template v-else>{{ dateRangeLabel }}</template>
            </p>
          </div>
          <div class="flex items-center gap-2">
            <!-- Who approved, rejected or deleted what. Supervisors and above. -->
            <button
              v-if="canManageTeam(user)"
              type="button"
              @click="showChangeLog = true"
              class="px-3 py-1.5 text-sm rounded-md border border-gray-300 text-gray-700 hover:bg-gray-50 whitespace-nowrap"
            >Change log</button>
            <div class="relative">
              <input
                v-model="requestSearch"
                type="search"
                placeholder="Search by name…"
                aria-label="Search requests by employee name"
                class="w-56 pl-8 pr-3 py-1.5 text-sm border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 bg-white"
              />
              <svg class="w-4 h-4 text-gray-400 absolute left-2.5 top-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-4.35-4.35M17 11A6 6 0 115 11a6 6 0 0112 0z" />
              </svg>
            </div>
            <span v-if="allRequests.length > REQUESTS_PAGE_SIZE" class="text-xs text-gray-500 tabular-nums whitespace-nowrap">
              {{ requestRange.from }}–{{ requestRange.to }} of {{ allRequests.length }}
            </span>
          </div>
        </div>
        <div v-if="allRequests.length === 0" class="text-sm text-gray-500">
          {{ requestSearch.trim() ? `No requests found for “${requestSearch.trim()}”.` : 'No requests for this period.' }}
        </div>
        <div v-else class="overflow-x-auto">
          <table class="min-w-full text-sm">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-3 py-2 text-left font-medium text-gray-500">Employee</th>
                <th class="px-3 py-2 text-left font-medium text-gray-500">Type</th>
                <th class="px-3 py-2 text-left font-medium text-gray-500">Time</th>
                <th class="px-3 py-2 text-left font-medium text-gray-500">Date</th>
                <th class="px-3 py-2 text-left font-medium text-gray-500">Submitted</th>
                <th class="px-3 py-2 text-left font-medium text-gray-500">Status</th>
                <th class="px-3 py-2 text-left font-medium text-gray-500">Notes</th>
                <th v-if="isAdmin" class="px-3 py-2 text-left font-medium text-gray-500">Actions</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              <tr v-for="req in requestPage" :key="req.id">
                <td class="px-3 py-2">{{ req.employee_name }}</td>
                <td class="px-3 py-2">{{ formatRequestType(req.request_type) }}</td>
                <td class="px-3 py-2 text-gray-500 whitespace-nowrap">{{ requestTimeLabel(req) || '—' }}</td>
                <td class="px-3 py-2">{{ formatDate(req.request_date) }}</td>
                <td
                  class="px-3 py-2 text-gray-500 whitespace-nowrap"
                  :title="formatFullTimestamp(req.created_at)"
                >{{ formatSubmitted(req.created_at) }}</td>
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
        <div v-if="requestPageCount > 1" class="flex items-center justify-between mt-3 pt-3 border-t border-gray-100 text-xs">
          <button
            type="button"
            @click="requestPageIndex--"
            :disabled="requestPageIndex === 0"
            class="px-3 py-1.5 rounded-md border border-gray-300 text-gray-700 hover:bg-gray-50 disabled:opacity-40 disabled:hover:bg-white"
          >← Newer</button>
          <span class="text-gray-500 tabular-nums">Page {{ requestPageIndex + 1 }} of {{ requestPageCount }}</span>
          <button
            type="button"
            @click="requestPageIndex++"
            :disabled="requestPageIndex >= requestPageCount - 1"
            class="px-3 py-1.5 rounded-md border border-gray-300 text-gray-700 hover:bg-gray-50 disabled:opacity-40 disabled:hover:bg-white"
          >Older →</button>
        </div>
      </div>

    </div>

    <AuditChangeLogModal
      v-if="showChangeLog"
      title="Request change log"
      subtitle="Every request approved, rejected or deleted by hand, and who did it."
      :entity="['request']"
      @close="showChangeLog = false"
    />

    <!-- Request Modal -->
    <ScheduleRequestsRequestFormModal
      v-if="showRequestModal"
      @close="showRequestModal = false"
      @submitted="onRequestSubmitted"
    />
  </div>
</template>

<script setup lang="ts">
import { ptoTimeLabel, ptoTypeLabel } from '~/utils/ptoDisplay'
import { requestTimeLabel, requestTypeLabel as formatRequestType } from '~/utils/requestDisplay'
import { canLead, canManageTeam } from '~/utils/roles'

const { user } = useAuth()
const { fetchRequests, requests, overrideRequest, cancelRequest, loading } = useScheduleRequests()
const { blockedDates, fetchBlockedDates } = useTeamBlockedDates()

const viewMode = ref<'week' | 'month'>('week')
const referenceDate = ref(new Date())
const showRequestModal = ref(false)
const showChangeLog = ref(false)



const onRequestSubmitted = () => {
  loadCalendar()
}

// Team Lead and above may approve, reject and delete (utils/roles.ts).
const isAdmin = computed(() => canLead(user.value))

// Calendar data from the PTO calendar API
const calendarData = ref<{ pto_days: any[]; requests: any[]; hours_by_date?: Record<string, DayHours> }>({ pto_days: [], requests: [] })

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
  time: string
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
      typeLabel: ptoTypeLabel(pto.pto_type),
      time: ptoTimeLabel(pto),
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
      time: requestTimeLabel(req),
      notes: req.notes,
      date,
    })
  }

  return map
})

const getEntriesForDate = (date: string): CalendarEntry[] => {
  return entriesByDate.value[date] || []
}

interface DayHours { approved: number; callIn: number; manual: number; total: number }
const NO_HOURS: DayHours = { approved: 0, callIn: 0, manual: 0, total: 0 }

/**
 * Hours off for a date, itemised. Supplied by the API — never derived here, so it
 * cannot disagree with what the approval rule charges against the daily cap.
 */
const hoursFor = (date: string): DayHours => calendarData.value.hours_by_date?.[date] ?? NO_HOURS

/** "8h" / "6.5h" - trailing .0 is noise on a calendar. */
const fmtHours = (h: number): string => `${Number.isInteger(h) ? h : h.toFixed(2).replace(/0$/, '')}h`

/** Week cell second line: what it is, plus when. */
const entryDetail = (e: CalendarEntry): string => (e.time ? `${e.typeLabel} · ${e.time}` : e.typeLabel)

/**
 * Month cell second line. Where there is a time it carries more information than
 * the type does — "leaves 2:00 PM" already implies Leave Early, and a month cell
 * has no room for both.
 */
const entryDetailShort = (e: CalendarEntry): string => e.time || e.typeLabel

/** Entries a month cell shows before "+N more" is expanded. */
const MONTH_ENTRY_LIMIT = 3
const expandedDays = ref<Set<string>>(new Set())

const toggleDayExpanded = (date: string) => {
  // Replace the Set rather than mutating it — Vue does not track Set mutation.
  const next = new Set(expandedDays.value)
  if (next.has(date)) next.delete(date)
  else next.add(date)
  expandedDays.value = next
}

const monthEntriesFor = (date: string): CalendarEntry[] => {
  const all = getEntriesForDate(date)
  return expandedDays.value.has(date) ? all : all.slice(0, MONTH_ENTRY_LIMIT)
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

// Search by name. While a term is present the table switches from "this
// period" to "every request for matching people, all dates" — looking someone
// up is only useful if it isn't limited to the week on screen. The calendar
// grid above is unaffected. Debounced so a keystroke doesn't fire a request.
const requestSearch = ref('')
const requestsLoading = ref(false)
let searchTimer: ReturnType<typeof setTimeout> | null = null
watch(requestSearch, () => {
  if (searchTimer) clearTimeout(searchTimer)
  searchTimer = setTimeout(loadRequests, 250)
})
onBeforeUnmount(() => { if (searchTimer) clearTimeout(searchTimer) })

// Paged, REQUESTS_PAGE_SIZE rows at a time. Purely a display concern; the API
// already returns newest first.
const REQUESTS_PAGE_SIZE = 15
const requestPageIndex = ref(0)
const requestPageCount = computed(() => Math.max(1, Math.ceil(allRequests.value.length / REQUESTS_PAGE_SIZE)))
const requestPage = computed(() => {
  const start = requestPageIndex.value * REQUESTS_PAGE_SIZE
  return allRequests.value.slice(start, start + REQUESTS_PAGE_SIZE)
})
const requestRange = computed(() => {
  const total = allRequests.value.length
  const from = total ? requestPageIndex.value * REQUESTS_PAGE_SIZE + 1 : 0
  return { from, to: Math.min(from + REQUESTS_PAGE_SIZE - 1, total) }
})
// A fresh list (new period, new search, an approve/delete) starts on page one.
watch(requests, () => { requestPageIndex.value = 0 })

const formatDate = (dateStr: string | null | undefined) => {
  if (!dateStr) return ''
  const datePart = dateStr.split('T')[0]
  const [y, m, d] = datePart.split('-').map(Number)
  if (!y || !m || !d) return dateStr
  const date = new Date(y, m - 1, d)
  return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
}

// When the request was submitted. schedule_requests.created_at has always recorded
// this; it just wasn't surfaced anywhere. Rendered in the viewer's local timezone —
// the column is stored as timestamptz, so the conversion is correct.
const formatSubmitted = (ts: string | null | undefined) => {
  if (!ts) return '—'
  const d = new Date(ts)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleString('en-US', {
    month: 'short', day: 'numeric',
    hour: 'numeric', minute: '2-digit',
  })
}

// Full stamp incl. year and seconds, for the cell's hover title.
const formatFullTimestamp = (ts: string | null | undefined) => {
  if (!ts) return ''
  const d = new Date(ts)
  if (Number.isNaN(d.getTime())) return ''
  return d.toLocaleString('en-US', {
    weekday: 'short', year: 'numeric', month: 'short', day: 'numeric',
    hour: 'numeric', minute: '2-digit', second: '2-digit',
  })
}

// pto_days time detail now comes from the shared helper (utils/ptoDisplay), so
// the calendar and the display board can't drift on how they read a record.

// Request type / time labels come from utils/requestDisplay so the tables here
// and the request modal cannot drift on how they read a request row.

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

/** The Requests table: this period, or every request for a searched name. */
const loadRequests = async () => {
  const q = requestSearch.value.trim()
  requestsLoading.value = true
  try {
    await (q ? fetchRequests({ q }) : fetchRequests({ date_from: dateFrom.value, date_to: dateTo.value }))
  } finally {
    requestsLoading.value = false
  }
}

const calendarError = ref('')
const loadCalendar = async () => {
  calendarError.value = ''
  try {
    const [calData] = await Promise.all([
      $fetch<{ pto_days: any[]; requests: any[] }>('/api/pto-calendar', {
        params: { date_from: dateFrom.value, date_to: dateTo.value },
      }),
      loadRequests(),
      fetchBlockedDates(),
    ])
    calendarData.value = calData
  } catch (e: any) {
    // Uncaught, this left a blank week that read as "nobody is off". A 401 is
    // handled by the sign-in prompt (plugins/session.client.ts); say anything else.
    if (e?.statusCode !== 401 && e?.status !== 401) {
      calendarError.value = `Couldn't load the calendar: ${e?.data?.message || e?.message || 'unknown error'}`
    }
  }
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
