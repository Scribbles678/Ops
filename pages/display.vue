<template>
  <div class="display-page min-h-screen text-white" style="background: linear-gradient(135deg, #1a1f4e 0%, #182078 50%, #1a1f4e 100%)">
    <!-- Header bar -->
    <div class="sticky top-0 z-30 px-4 py-2 flex items-center justify-between" style="background: rgba(15, 18, 60, 0.9); backdrop-filter: blur(8px); border-bottom: 1px solid rgba(255,255,255,0.08)">
      <div class="flex items-center gap-3">
        <h1 class="text-xl font-bold tracking-wide text-white">Today's Schedule</h1>
        <span class="text-base text-white/60">{{ formattedDate }}</span>
      </div>
      <div class="flex items-center gap-3">
        <span class="text-xs text-white/50 uppercase tracking-widest">{{ lastUpdated ? `Updated ${lastUpdated}` : '' }}</span>
        <button
          @click="showRequestModal = true"
          class="px-4 py-2 rounded-md text-sm text-white font-medium tracking-wide transition-colors"
          style="background: rgba(255,255,255,0.12); border: 1px solid rgba(255,255,255,0.15)"
          onmouseover="this.style.background='rgba(255,255,255,0.2)'"
          onmouseout="this.style.background='rgba(255,255,255,0.12)'"
        >
          Time Off / Schedule Change
        </button>
      </div>
    </div>

    <!-- The last refresh failed. Without this the board looked normal while showing
         stale data, or nothing at all. Big and amber: it is read from across the floor. -->
    <div v-if="loadFailed" role="alert" class="px-4 py-2 text-center text-lg font-semibold bg-amber-300 text-amber-950">
      Can't reach the schedule right now — retrying every 2 minutes.<template v-if="lastUpdated"> Showing the board as of {{ lastUpdated }}.</template>
    </div>

    <div class="max-w-[1500px] mx-auto px-4 py-3 space-y-3">
      <!-- Loading (initial load only) -->
      <div v-if="!initialLoadDone" class="flex items-center justify-center h-[60vh]">
        <div class="flex flex-col items-center gap-3 text-white/60">
          <svg class="animate-spin h-6 w-6 text-blue-300" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="3"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          <p class="text-sm">Loading schedule...</p>
        </div>
      </div>

      <!-- Schedule -->
      <div v-else class="space-y-3">
        <section
          v-for="shift in shiftsWithAssignments"
          :key="shift.id"
          class="rounded-lg overflow-hidden"
          style="background: rgba(255,255,255,0.06); border: 1px solid rgba(255,255,255,0.08)"
        >
          <!-- Shift header -->
          <div class="flex items-center justify-between px-4 py-2" style="background: rgba(255,255,255,0.05); border-bottom: 1px solid rgba(255,255,255,0.06)">
            <div class="flex items-center gap-2">
              <div class="w-1.5 h-7 rounded-full bg-blue-400"></div>
              <h2 class="text-lg font-bold tracking-wide text-white uppercase">{{ shift.name }}</h2>
            </div>
            <div class="flex items-center gap-3">
              <span class="text-xs text-white/60 uppercase tracking-widest">
                {{ getAssignedCount(shift) }} assigned
              </span>
              <span class="text-xs text-white/40 uppercase tracking-widest">
                {{ shift.employees?.length || 0 }} total
              </span>
            </div>
          </div>

          <!-- Assigned employees -->
          <div v-if="getAssignedEmployees(shift).length > 0" class="divide-y divide-white/5">
            <article
              v-for="employee in getAssignedEmployees(shift)"
              :key="employee.id"
              class="flex items-center gap-4 px-4 py-1"
            >
              <div class="w-48 flex-shrink-0 text-base font-semibold uppercase tracking-wider text-white/95">
                {{ employee.last_name }}, {{ employee.first_name }}
              </div>
              <div class="flex flex-wrap gap-1.5 flex-1">
                <div
                  v-for="item in getEmployeeScheduleItems(employee)"
                  :key="item.id"
                  class="flex items-center gap-2 px-3 py-1.5 rounded-md min-w-[10rem]"
                  :style="{
                    backgroundColor: item.assignment.job_function.color_code,
                    color: getTextColor(item.assignment.job_function.color_code),
                  }"
                >
                  <div class="w-1 h-9 rounded-full flex-shrink-0" :style="{ backgroundColor: darkenColor(item.assignment.job_function.color_code) }"></div>
                  <div class="flex flex-col leading-tight">
                    <span class="font-bold text-base uppercase tracking-wide">{{ item.assignment.job_function.name }}</span>
                    <span class="text-xs font-semibold opacity-90">{{ item.timeRange }}</span>
                  </div>
                </div>
              </div>
            </article>
          </div>

          <!-- Unassigned employees (collapsed) -->
          <div v-if="getUnassignedEmployees(shift).length > 0" class="px-4 py-1.5" style="background: rgba(255,255,255,0.02); border-top: 1px solid rgba(255,255,255,0.04)">
            <div class="flex flex-wrap gap-x-4 gap-y-0.5">
              <span class="text-xs text-white/45 uppercase tracking-wider font-medium mr-1">Unassigned:</span>
              <span
                v-for="emp in getUnassignedEmployees(shift)"
                :key="emp.id"
                class="text-xs text-white/55"
              >
                {{ emp.last_name }}, {{ emp.first_name }}
              </span>
            </div>
          </div>

          <div v-if="!shift.employees || shift.employees.length === 0" class="px-4 py-3 text-sm text-white/50 text-center">
            No team members assigned to this shift
          </div>
        </section>

        <div v-if="shiftsWithAssignments.length === 0" class="text-center py-16 text-white/40">
          <p class="text-sm">No schedule available for today</p>
          <NuxtLink to="/" class="inline-flex items-center text-blue-300 hover:text-blue-200 text-xs mt-2 underline decoration-dotted">
            Open Operations Console
          </NuxtLink>
        </div>
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
import { describePto, ptoTimeToMinutes, subtractPto } from '~/utils/ptoDisplay'

const { formatTime, formatDate } = useLaborCalculations()
const {
  scheduleAssignments: assignments,
  shifts,
  error: scheduleError,
  fetchShifts,
  fetchScheduleForDate
} = useSchedule()

// PTO
const { ptoByEmployeeId, error: ptoError, fetchPTOForDate } = usePTO()

// Shift Swaps
const { swapByEmployeeId, error: swapsError, fetchShiftSwapsForDate } = useShiftSwaps()

const {
  employees,
  loading: employeesLoading,
  error: employeesError,
  fetchEmployees
} = useEmployees()

// True when the last refresh failed. The loaders catch their own errors and
// return empty lists, so a failed refresh used to look like a good one: the board
// went blank (or stayed stale) and "Updated" kept moving forward.
const loadFailed = ref(false)

const showRequestModal = ref(false)

const onRequestSubmitted = () => {
  // Refresh data after a request is submitted (approved PTO/swap may affect display)
  loadData()
}

const initialLoadDone = ref(false)
const lastUpdated = ref('')
const refreshInterval = ref<NodeJS.Timeout | null>(null)
const rolloverInterval = ref<NodeJS.Timeout | null>(null)

// Timezone-aware date helper (America/Chicago) to avoid UTC off-by-one
import { getTZISODate } from '~/utils/localDate'

// Today as a reactive ref in America/Chicago timezone
const TIMEZONE = 'America/Chicago'
const today = ref(getTZISODate(TIMEZONE))

const formattedDate = computed(() => {
  return formatDate(today.value)
})

const shiftsWithAssignments = computed(() => {
  console.log('Computing shiftsWithAssignments...')
  // Get all assignments and consolidate them first
  const allAssignments = consolidateAssignments(assignments.value)
  
  // Sort shifts by start time for consistent ordering
  const orderedShifts = [...(shifts.value || [])].sort((a: any, b: any) => String(a.start_time).localeCompare(String(b.start_time)))
  
  // Group assignments by employee for easy lookup
  const employeeAssignments = new Map()
  allAssignments.forEach(assignment => {
    const employeeId = assignment.employee_id
    if (!employeeAssignments.has(employeeId)) {
      employeeAssignments.set(employeeId, [])
    }
    employeeAssignments.get(employeeId).push(assignment)
  })
  
  // Group employees by their actual shift_id (like the schedule page does)
  const shiftMap = new Map<string, any>()
  
  // Initialize all shifts (even empty ones)
  orderedShifts.forEach((shift: any) => {
    shiftMap.set(shift.id, {
      ...shift,
      employees: []
    })
  })
  
  // Absence windows for an employee, interpreted by type (see utils/ptoDisplay).
  const absenceWindowsFor = (empId: string) => {
    const recs = ptoByEmployeeId.value?.[empId] || []
    return recs.map((r: any) => describePto(r)).filter(Boolean) as ReturnType<typeof describePto>[]
  }

  const minutesOf = (t: string) => ptoTimeToMinutes(t) ?? 0
  const toTimeString = (mins: number) =>
    `${String(Math.floor(mins / 60)).padStart(2, '0')}:${String(mins % 60).padStart(2, '0')}:00`

  /**
   * Clip an employee's assignments around their PTO instead of discarding them.
   *
   * The old behaviour dropped any assignment that overlapped PTO at all, so
   * someone off 08:00-10:00 with an 08:00-12:30 block disappeared from the board
   * entirely — hiding 2.5 hours they were genuinely working.
   */
  const trimAssignmentsAroundPTO = (empId: string, list: any[]) => {
    const windows = absenceWindowsFor(empId)
    if (!windows.length) return list
    const out: any[] = []
    for (const a of list) {
      const pieces = subtractPto(minutesOf(String(a.start_time)), minutesOf(String(a.end_time)), windows as any)
      for (const p of pieces) {
        out.push(
          p.start === minutesOf(String(a.start_time)) && p.end === minutesOf(String(a.end_time))
            ? a
            : { ...a, id: `${a.id}-trim-${p.start}`, start_time: toTimeString(p.start), end_time: toTimeString(p.end) }
        )
      }
    }
    return out
  }
  
  // Group employees by their shift_id, accounting for shift swaps
  employees.value.forEach((employee: any) => {
    // Check if employee has a shift swap
    const swap = swapByEmployeeId.value?.[employee.id]
    
    // Determine which shift this employee should appear in
    const targetShiftId = swap ? swap.swapped_shift_id : employee.shift_id
    
    if (shiftMap.has(targetShiftId)) {
      // Only hide employees who are out the WHOLE day (full-day PTO or a call-in).
      // Partial absences (partial PTO, leave-early, arrive-late) still show — their
      // working hours remain on the board; the overlapsPTO filter below trims the
      // off-hours from their blocks.
      const ptoRecords = ptoByEmployeeId.value?.[employee.id] || []
      const isOutAllDay = ptoRecords.some((r: any) =>
        r.pto_type === 'full_day' || r.pto_type === 'call_in' || (!r.start_time && !r.end_time)
      )
      if (isOutAllDay) return

      // Clip assignments around PTO rather than dropping them wholesale.
      //
      // Deliberately NOT filtered by a.shift_id. Each employee lands in exactly
      // one group, so filtering could only ever hide work — and it did: a swapped
      // employee is grouped by the SWAPPED shift while their rows may still carry
      // the original one (any schedule built before the swap, or copied forward).
      // The board then showed them present with an empty day while real
      // assignments sat in the database.
      const employeeAssignmentsList = trimAssignmentsAroundPTO(
        employee.id,
        employeeAssignments.get(employee.id) || []
      )

      // Create employee object with assignments + their absence blocks, so the
      // board says WHY someone isn't on a job rather than leaving a silent hole.
      const employeeWithAssignments = {
        ...employee,
        assignments: employeeAssignmentsList,
        absences: absenceWindowsFor(employee.id).filter((d: any) => d && !d.allDay),
      }
      
      shiftMap.get(targetShiftId).employees.push(employeeWithAssignments)
    }
  })
  
  // Return all shifts in start-time order (including empty ones)
  return orderedShifts.map((s: any) => shiftMap.get(s.id))
})

// Function to consolidate consecutive assignments for the same employee and job function
// Also deduplicates identical assignments
const consolidateAssignments = (assignments: any[]) => {
  if (!assignments || assignments.length === 0) return []
  
  // First, deduplicate identical assignments (same employee, job function, time range)
  const seen = new Set<string>()
  const deduplicated: any[] = []
  
  for (const assignment of assignments) {
    const key = `${assignment.employee_id}-${assignment.job_function_id}-${assignment.start_time}-${assignment.end_time}`
    if (!seen.has(key)) {
      seen.add(key)
      deduplicated.push(assignment)
    }
  }
  
  // Sort assignments by employee, job function, and start time
  const sorted = [...deduplicated].sort((a, b) => {
    if (a.employee_id !== b.employee_id) return a.employee_id.localeCompare(b.employee_id)
    if (a.job_function_id !== b.job_function_id) return a.job_function_id.localeCompare(b.job_function_id)
    return a.start_time.localeCompare(b.start_time)
  })
  
  const consolidated: any[] = []
  let currentBlock: any = null
  
  for (const assignment of sorted) {
    if (!currentBlock) {
      // Start a new block
      currentBlock = { ...assignment }
    } else if (
      currentBlock.employee_id === assignment.employee_id &&
      currentBlock.job_function_id === assignment.job_function_id &&
      currentBlock.shift_id === assignment.shift_id &&
      currentBlock.end_time === assignment.start_time
    ) {
      // Extend the current block
      currentBlock.end_time = assignment.end_time
    } else {
      // Save the current block and start a new one
      consolidated.push(currentBlock)
      currentBlock = { ...assignment }
    }
  }
  
  // Don't forget the last block
  if (currentBlock) {
    consolidated.push(currentBlock)
  }
  
  return consolidated
}

onMounted(() => {
  today.value = getTZISODate(TIMEZONE)
  loadData()

  // Auto-refresh every 2 minutes
  refreshInterval.value = setInterval(() => {
    loadData()
  }, 120000)

  // Update date every minute to catch midnight rollover
  const tick = () => {
    const current = getTZISODate(TIMEZONE)
    if (today.value !== current) {
      today.value = current
      loadData()
    }
  }
  rolloverInterval.value = setInterval(tick, 60000)

  // If the tab was backgrounded/asleep (timers paused), recompute the date and
  // reload + slide the session the moment it becomes visible again.
  document.addEventListener('visibilitychange', handleVisible)
  window.addEventListener('focus', handleVisible)
})

const handleVisible = () => {
  if (document.visibilityState !== 'visible') return
  const current = getTZISODate(TIMEZONE)
  if (today.value !== current) today.value = current
  loadData()
}

onUnmounted(() => {
  if (refreshInterval.value) clearInterval(refreshInterval.value)
  if (rolloverInterval.value) clearInterval(rolloverInterval.value)
  document.removeEventListener('visibilitychange', handleVisible)
  window.removeEventListener('focus', handleVisible)
})

const loadData = async () => {
  try {
    // Slide the session first so a 24/7 kiosk never expires while the page is open.
    await $fetch('/api/auth/refresh', { method: 'POST' }).catch(() => {})
    await Promise.all([
      fetchShifts(),
      fetchEmployees(),
      fetchScheduleForDate(today.value),
      fetchPTOForDate(today.value),
      fetchShiftSwapsForDate(today.value)
    ])
    loadFailed.value = !!(scheduleError.value || ptoError.value || swapsError.value || employeesError.value)
    if (!loadFailed.value) updateLastUpdated()
    initialLoadDone.value = true
  } catch (e) {
    console.error('Failed to load display data:', e)
  }
}

const refreshData = () => {
  loadData()
}

const updateLastUpdated = () => {
  const now = new Date()
  lastUpdated.value = now.toLocaleTimeString('en-US', {
    hour: 'numeric',
    minute: '2-digit',
    hour12: true
  })
}

const addAlpha = (hex: string, alpha: number): string => {
  hex = hex.replace('#', '')
  const r = parseInt(hex.substring(0, 2), 16)
  const g = parseInt(hex.substring(2, 4), 16)
  const b = parseInt(hex.substring(4, 6), 16)
  return `rgba(${r}, ${g}, ${b}, ${alpha})`
}

const darkenColor = (hex: string): string => {
  // Remove # if present
  hex = hex.replace('#', '')
  
  // Convert to RGB
  const r = parseInt(hex.substring(0, 2), 16)
  const g = parseInt(hex.substring(2, 4), 16)
  const b = parseInt(hex.substring(4, 6), 16)
  
  // Darken by 20%
  const darken = (value: number) => Math.max(0, Math.floor(value * 0.8))
  
  // Convert back to hex
  const toHex = (value: number) => {
    const hex = value.toString(16)
    return hex.length === 1 ? '0' + hex : hex
  }
  
  return `#${toHex(darken(r))}${toHex(darken(g))}${toHex(darken(b))}`
}

// Helpers for assigned vs unassigned employees within a shift
const getAssignedEmployees = (shift: any) => {
  return (shift.employees || []).filter((emp: any) => emp.assignments && emp.assignments.length > 0)
}

const getUnassignedEmployees = (shift: any) => {
  return (shift.employees || []).filter((emp: any) => !emp.assignments || emp.assignments.length === 0)
}

const getAssignedCount = (shift: any) => {
  return getAssignedEmployees(shift).length
}

/** WCAG relative luminance of an #rrggbb colour. NaN for anything unparseable. */
const relativeLuminance = (hex: string): number => {
  const h = hex.replace('#', '')
  const channel = (i: number) => {
    const v = parseInt(h.substring(i, i + 2), 16) / 255
    return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
  }
  return 0.2126 * channel(0) + 0.7152 * channel(2) + 0.0722 * channel(4)
}

/**
 * Black or white label text — whichever measurably has more contrast on this chip.
 *
 * This used to be the NTSC luma formula (0.299/0.587/0.114) over raw sRGB with a
 * hard 0.5 cutoff, which is not WCAG relative luminance and picked wrong: X4
 * (#3B82F6) got white at 3.68:1, below the 4.5:1 floor, where black gives 5.71:1.
 * Four of the fifteen job-function colours also sat within 0.06 of that cutoff, so
 * changing a colour by one shade in Job Functions could flip the label unpredictably.
 *
 * Comparing the two real contrast ratios has no threshold to sit near, and stays
 * correct for whatever colour someone picks later.
 */
const getTextColor = (hex: string): string => {
  const l = relativeLuminance(hex)
  if (Number.isNaN(l)) return '#ffffff'
  const onWhite = 1.05 / (l + 0.05)
  const onBlack = (l + 0.05) / 0.05
  return onBlack >= onWhite ? '#000000' : '#ffffff'
}

// Helper to convert time string to minutes
const timeToMinutes = (time: string): number => {
  const parts = time.split(':').map(Number)
  const hours = parts[0] || 0
  const minutes = parts[1] || 0
  return hours * 60 + minutes
}


// Schedule items for an employee: their work blocks PLUS any partial absence,
// sorted by time. The absence is rendered as a neutral grey block so the board
// shows when someone is away instead of leaving an unexplained gap.
const ABSENCE_COLOR = '#94a3b8'

const getEmployeeScheduleItems = (employee: any): Array<{id: string, assignment: any, timeRange: string, sortTime: number}> => {
  const items: Array<{id: string, assignment: any, timeRange: string, sortTime: number}> = []

  for (const a of employee.assignments || []) {
    items.push({
      id: `assignment-${a.id}`,
      assignment: a,
      timeRange: `${formatTime(a.start_time)}-${formatTime(a.end_time)}`,
      sortTime: timeToMinutes(String(a.start_time).substring(0, 5)),
    })
  }

  for (const d of employee.absences || []) {
    items.push({
      id: `absence-${employee.id}-${d.startMin}`,
      // Shaped like an assignment so the existing block template renders it.
      assignment: { job_function: { name: d.label, color_code: ABSENCE_COLOR } },
      timeRange: d.timeText,
      sortTime: d.startMin,
    })
  }

  return items.sort((a, b) => a.sortTime - b.sortTime)
}
</script>

