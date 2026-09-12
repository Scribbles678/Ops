<template>
  <div class="min-h-screen bg-gray-50">
    <div class="container mx-auto px-4 py-8">
      <!-- Header -->
      <div class="flex items-center justify-between mb-8">
        <div>
          <h1 class="text-4xl font-bold text-gray-800">Create Schedule</h1>
          <p class="text-gray-600 mt-2">Choose a date and create a schedule</p>
        </div>
        <NuxtLink to="/" class="btn-secondary">
          ← Back to Home
        </NuxtLink>
      </div>

      <!-- Date Selection -->
      <div class="card mb-8">
        <h2 class="text-xl font-bold text-gray-800 mb-4">Select Schedule Date</h2>
        <div class="flex items-center space-x-4">
          <div class="flex-1">
            <label for="schedule-date" class="block text-sm font-medium text-gray-700 mb-2">
              Schedule Date
            </label>
            <input
              id="schedule-date"
              v-model="selectedDate"
              type="date"
              :min="today"
              class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
          </div>
          <div class="flex flex-col space-y-2">
            <button 
              @click="setToTomorrow" 
              class="px-4 py-2 bg-blue-100 text-blue-700 rounded-lg hover:bg-blue-200 transition-colors text-sm"
            >
              Tomorrow
            </button>
            <button 
              @click="setToNextMonday" 
              class="px-4 py-2 bg-green-100 text-green-700 rounded-lg hover:bg-green-200 transition-colors text-sm"
            >
              Next Monday
            </button>
          </div>
        </div>
        <div class="mt-4 p-3 bg-blue-50 rounded-lg">
          <p class="text-sm text-blue-800">
            <strong>Selected:</strong> {{ formatDate(selectedDate || '') }}
            <span v-if="isWeekend" class="ml-2 text-orange-600 font-medium">(Weekend)</span>
          </p>
        </div>
      </div>

      <!-- Schedule Generation Options -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5 gap-6 mb-8">
        <!-- Copy Today's Schedule -->
        <div class="card hover:shadow-lg transition-all cursor-pointer" @click="copyTodaySchedule">
          <div class="text-center py-8">
            <div class="bg-blue-100 rounded-full p-6 mb-4 mx-auto w-20 h-20 flex items-center justify-center">
              <svg class="w-10 h-10 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
              </svg>
            </div>
            <h3 class="text-xl font-bold text-gray-800 mb-2">Copy Today's Schedule</h3>
            <p class="text-gray-600">Copy the current schedule to {{ formatDate(selectedDate || '') }}</p>
            <p class="text-xs text-gray-500 mt-2 italic">Note: PTO for the target date is automatically applied</p>
          </div>
        </div>

        <!-- Automated Schedule Builder. The only engine since V1 was retired
             (Aug 2026) after the team lead confirmed this one schedules better. -->
        <div
          class="card hover:shadow-lg transition-all cursor-pointer"
          @click="generateSchedule('slot')"
          :class="{ 'opacity-50 cursor-not-allowed': generating }"
        >
          <div class="text-center py-8">
            <div class="bg-purple-100 rounded-full p-6 mb-4 mx-auto w-20 h-20 flex items-center justify-center">
              <svg v-if="!generating" class="w-10 h-10 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
              </svg>
              <div v-else class="w-10 h-10 text-purple-600">
                <svg class="animate-spin" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
              </div>
            </div>
            <h3 class="text-xl font-bold text-gray-800 mb-2">
              {{ generating ? '⏳ Generating Schedule…' : 'Automated Schedule Builder' }}
            </h3>
            <p class="text-gray-600">
              {{ generating
                ? 'Please wait while we create your optimized schedule…'
                : 'Generate an optimized schedule based on staffing targets, training, and required assignments' }}
            </p>
          </div>
        </div>

        <!-- Automated Schedule Builder V2 — the period engine. Same inputs, but
             each person keeps one job for each stretch between breaks. -->
        <div
          class="card hover:shadow-lg transition-all cursor-pointer"
          @click="generateSchedule('period')"
          :class="{ 'opacity-50 cursor-not-allowed': generating }"
        >
          <div class="text-center py-8">
            <div class="bg-indigo-100 rounded-full p-6 mb-4 mx-auto w-20 h-20 flex items-center justify-center">
              <svg v-if="!generating" class="w-10 h-10 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h10" />
              </svg>
              <div v-else class="w-10 h-10 text-indigo-600">
                <svg class="animate-spin" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
              </div>
            </div>
            <h3 class="text-xl font-bold text-gray-800 mb-2">
              {{ generating ? '⏳ Generating Schedule…' : 'Automated Schedule Builder V2' }}
            </h3>
            <p class="text-gray-600">
              {{ generating
                ? 'Please wait while we create your optimized schedule…'
                : 'Same targets and training, but each person keeps one job for each stretch between breaks' }}
            </p>
          </div>
        </div>

        <!-- Manual Schedule -->
        <div class="card hover:shadow-lg transition-all cursor-pointer" @click="goToManualSchedule">
          <div class="text-center py-8">
            <div class="bg-green-100 rounded-full p-6 mb-4 mx-auto w-20 h-20 flex items-center justify-center">
              <svg class="w-10 h-10 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
              </svg>
            </div>
            <h3 class="text-xl font-bold text-gray-800 mb-2">Manual Schedule</h3>
            <p class="text-gray-600">Create {{ formatDate(selectedDate || '') }} schedule manually from scratch</p>
          </div>
        </div>

        <!-- Rules & Targets. Amber rather than the blue/purple/green of the three
             cards above: those create a schedule, this configures what they build
             against. -->
        <div class="card hover:shadow-lg transition-all cursor-pointer" @click="goToRulesAndTargets">
          <div class="text-center py-8">
            <div class="bg-amber-100 rounded-full p-6 mb-4 mx-auto w-20 h-20 flex items-center justify-center">
              <svg class="w-10 h-10 text-amber-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
              </svg>
            </div>
            <h3 class="text-xl font-bold text-gray-800 mb-2">Rules &amp; Targets</h3>
            <p class="text-gray-600">Set the headcount each job function needs per hour, and pin required assignments</p>
          </div>
        </div>
      </div>

      <!-- Coverage preview for the selected date. Shows demand vs the people
           actually on the clock BEFORE building, so impossible targets and
           break/lunch cliffs are visible up front rather than discovered after. -->
      <div v-if="selectedDate" class="mt-8">
        <ScheduleCoveragePreview :date="selectedDate" />
      </div>


      <!-- Loading Modal -->
      <div v-if="generating" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-white rounded-lg p-8 max-w-md w-full mx-4 shadow-xl">
          <div class="text-center">
            <div class="mb-4 flex justify-center">
              <svg class="animate-spin h-12 w-12 text-purple-600" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
            </div>
            <h3 class="text-2xl font-bold text-gray-800 mb-2">Generating Schedule</h3>
            <p class="text-gray-600 mb-4">
              Creating optimized schedule for {{ formatDate(selectedDate || '') }}
            </p>
            <p class="text-sm text-gray-500">
              This may take a few moments while we process staffing targets and create assignments...
            </p>
            <div class="mt-6 flex items-center justify-center space-x-2">
              <div class="w-2 h-2 bg-purple-600 rounded-full animate-pulse"></div>
              <div class="w-2 h-2 bg-purple-600 rounded-full animate-pulse" style="animation-delay: 0.2s"></div>
              <div class="w-2 h-2 bg-purple-600 rounded-full animate-pulse" style="animation-delay: 0.4s"></div>
            </div>
          </div>
        </div>
      </div>

      <!-- Notification Modal -->
      <div v-if="showNotificationModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4 shadow-xl">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-xl font-bold text-gray-800">{{ notificationType === 'success' ? '✅ Success' : '❌ Error' }}</h3>
            <button @click="closeNotificationModal" class="text-gray-400 hover:text-gray-600">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
          <div :class="notificationType === 'success' ? 'bg-green-50 border border-green-200 rounded-lg p-4 mb-4' : 'bg-red-50 border border-red-200 rounded-lg p-4 mb-4'">
            <p :class="notificationType === 'success' ? 'text-green-800' : 'text-red-800'" class="text-sm whitespace-pre-line">{{ notificationMessage }}</p>
          </div>
          <div class="flex justify-end">
            <button
              @click="closeNotificationModal"
              :class="notificationType === 'success' ? 'px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium' : 'px-6 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors font-medium'"
            >
              OK
            </button>
          </div>
        </div>
      </div>

      <!-- Warnings Modal -->
      <div v-if="showWarningsModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-white rounded-lg p-6 max-w-2xl w-full mx-4 shadow-xl max-h-[90vh] overflow-y-auto">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-2xl font-bold text-gray-800">Schedule Generation Complete</h3>
            <button @click="closeWarningsModal" class="text-gray-400 hover:text-gray-600">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
          
          <!-- Failure. Checked FIRST so a real failure is never masked, and keyed
               off whether a schedule was actually produced rather than sniffing the
               warning text: V2's own summary says "No schedule can fill these",
               which used to trip the failure test and paint a perfect build red. -->
          <div v-if="buildFailed" class="mb-4 p-4 bg-red-50 border border-red-200 rounded-lg">
            <p class="text-red-800 font-medium">
              Schedule could not be generated. Please review the issues below.
            </p>
          </div>

          <!-- Success with gaps -->
          <div v-else class="mb-5 p-4 rounded-lg border"
            :class="scheduleGaps.length > 0 ? 'bg-amber-50 border-amber-200' : 'bg-green-50 border-green-200'">
            <p class="font-semibold" :class="scheduleGaps.length > 0 ? 'text-amber-900' : 'text-green-900'">
              Schedule created
            </p>
            <p class="text-sm mt-0.5" :class="scheduleGaps.length > 0 ? 'text-amber-800' : 'text-green-800'">
              {{ resultSummary }}
            </p>
          </div>

          <!-- What a person has to go and fix. First, and the only thing styled to
               demand attention: everything else here is either good news or context.
               These come from the engines as a separate `actions` list, not from
               pattern-matching the notes. -->
          <div v-if="resultActions.length > 0" class="mb-5">
            <h4 class="text-base font-semibold text-gray-800 mb-2">
              {{ resultActions.length }} thing{{ resultActions.length === 1 ? '' : 's' }} to fix
            </h4>
            <div class="space-y-2">
              <div
                v-for="(action, index) in resultActions"
                :key="index"
                class="flex items-start gap-2.5 p-3 bg-amber-50 border border-amber-200 rounded-lg"
              >
                <span class="text-amber-500 mt-px shrink-0">&#9888;</span>
                <p class="text-sm text-amber-900">{{ action }}</p>
              </div>
            </div>
          </div>

          <!-- Everything below is detail, hidden until asked for. On a normal day
               it is all expected output, and showing it by default made a healthy
               build look like a list of problems. -->
          <button
            v-if="hasResultDetails"
            @click="showResultDetails = !showResultDetails"
            class="flex items-center gap-1.5 text-sm text-gray-500 hover:text-gray-700 mb-3"
          >
            <span class="transition-transform" :class="showResultDetails ? 'rotate-90' : ''">&#9656;</span>
            {{ showResultDetails ? 'Hide details' : 'Show details' }}
          </button>

          <div v-if="showResultDetails">

          <!-- Staffing Gaps Table -->
          <div v-if="scheduleGaps.length > 0" class="mb-6">
            <h4 class="text-lg font-semibold text-gray-700 mb-3">Uncovered Staffing Gaps:</h4>
            <div class="overflow-x-auto">
              <table class="min-w-full text-sm border border-gray-200 rounded-lg">
                <thead class="bg-gray-50">
                  <tr>
                    <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Job Function</th>
                    <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Hour</th>
                    <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Short By</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200">
                  <tr v-for="(gap, index) in scheduleGaps" :key="index" class="bg-yellow-50">
                    <td class="px-4 py-2 font-medium text-gray-900">{{ gap.job_function_name }}</td>
                    <td class="px-4 py-2 text-gray-600">{{ gap.hour }}</td>
                    <td class="px-4 py-2 text-yellow-700 font-semibold">{{ gap.shortfall }} {{ gap.shortfall === 1 ? 'person' : 'people' }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <!-- Over-target (surplus) summary -->
          <div v-if="overTargetByFunction.length > 0" class="mb-6">
            <h4 class="text-base font-semibold text-gray-800 mb-1">Extra coverage</h4>
            <p class="text-xs text-gray-500 mb-2">
              More staff were available than your targets asked for, so the spare people were put to work here.
              This is normal, not a problem.
            </p>
            <div class="flex flex-wrap gap-2">
              <span
                v-for="(o, index) in overTargetByFunction"
                :key="index"
                class="inline-flex items-center px-3 py-1 rounded-full text-sm bg-blue-50 text-blue-700 border border-blue-200"
              >
                {{ o.job_function_name }}
                <span class="ml-1.5 font-semibold">+{{ o.surplus }} hr{{ o.surplus === 1 ? '' : 's' }}</span>
              </span>
            </div>
          </div>

          <!-- Informational notes. Grey, not yellow: nothing here needs doing, and
               colouring them as warnings is what made a clean build read as a list
               of problems. -->
          <div v-if="scheduleWarnings.length > 0" class="mb-6">
            <h4 class="text-base font-semibold text-gray-800 mb-2">Notes</h4>
            <div class="space-y-2">
              <div
                v-for="(warning, index) in scheduleWarnings"
                :key="index"
                :class="buildFailed
                  ? 'p-3 bg-red-50 border border-red-200 rounded-lg'
                  : 'p-3 bg-gray-50 border border-gray-200 rounded-lg'"
              >
                <p :class="buildFailed ? 'text-sm text-red-800' : 'text-sm text-gray-600'"
                >{{ warning }}</p>
              </div>
            </div>
          </div>

          </div><!-- /details -->

          <div class="flex justify-end">
            <button
              @click="closeWarningsModal"
              class="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium"
            >
              View Schedule
            </button>
          </div>
        </div>
      </div>

    </div>
  </div>
</template>

<script setup lang="ts">
import { toLocalISO, addDays } from '~/utils/localDate'
import type { BuilderEngine } from '~/composables/useScheduleBuilderV2'

// `error` carries the copy endpoint's real message (which row, which rule).
const { copySchedule, error: scheduleError } = useSchedule()
const { fetchJobFunctions } = useJobFunctions()
const { generateV2Schedule, applyV2Schedule } = useScheduleBuilderV2()

// Local calendar dates. These used toISOString(), which is UTC — from 7pm
// Central it already names tomorrow, so an evening "Copy Today" read the wrong
// source day and every default on this page landed one day late.
const tomorrowDate = computed(() => toLocalISO(addDays(new Date(), 1)))
const today = computed(() => toLocalISO(new Date()))

// Selected date for schedule creation
const selectedDate = ref(tomorrowDate.value)

// Check if selected date is weekend
const isWeekend = computed(() => {
  if (!selectedDate.value) return false
  
  let date: Date
  // For YYYY-MM-DD strings, parse as local date to avoid UTC shift
  if (typeof selectedDate.value === 'string' && selectedDate.value.match(/^\d{4}-\d{2}-\d{2}$/)) {
    const [year, month, day] = selectedDate.value.split('-').map(Number)
    date = new Date(year, month - 1, day)
  } else {
    date = new Date(selectedDate.value)
  }
  
  const day = date.getDay()
  return day === 0 || day === 6 // Sunday or Saturday
})

// AI Generation state
const generating = ref(false)
const showWarningsModal = ref(false)
const scheduleWarnings = ref<string[]>([])
// True only when a build produced no schedule at all. The banner used to infer
// this from the warning text, which broke as soon as a warning contained the
// words "No schedule".
const buildFailed = ref(false)
// Things a person must go and fix, supplied by the engines as their own list.
const resultActions = ref<string[]>([])
// One plain-language line under the headline, e.g.
// "204 assignments · everyone has work · all reachable targets met".
const resultSummary = ref('')
const showResultDetails = ref(false)
const hasResultDetails = computed(
  () => scheduleGaps.value.length > 0 || overTargetByFunction.value.length > 0 || scheduleWarnings.value.length > 0
)

/** Build the headline summary from counts, so a zero never gets its own line. */
const summarise = (assignmentCount: number, noWork: number | null, gapCount: number): string => {
  const parts = [`${assignmentCount} assignment${assignmentCount === 1 ? '' : 's'}`]
  if (noWork != null) {
    parts.push(noWork === 0 ? 'everyone has work' : `${noWork} ${noWork === 1 ? 'person has' : 'people have'} no work`)
  }
  parts.push(gapCount === 0 ? 'all reachable targets met' : `${gapCount} target${gapCount === 1 ? '' : 's'} still short`)
  return parts.join(' · ')
}
const scheduleGaps = ref<{ job_function_name: string; hour: string; shortfall: number }[]>([])
const scheduleOverTarget = ref<{ job_function_name: string; hour: string; surplus: number }[]>([])

// Surplus (over-target) staffing aggregated per function for a compact summary.
const overTargetByFunction = computed(() => {
  const map = new Map<string, number>()
  for (const o of scheduleOverTarget.value) {
    map.set(o.job_function_name, (map.get(o.job_function_name) || 0) + o.surplus)
  }
  return Array.from(map, ([job_function_name, surplus]) => ({ job_function_name, surplus }))
    .sort((a, b) => b.surplus - a.surplus)
})

// Notification modal state
const showNotificationModal = ref(false)
const notificationMessage = ref('')
const notificationType = ref<'success' | 'error'>('success')

const showNotification = (message: string, type: 'success' | 'error' = 'success') => {
  notificationMessage.value = message
  notificationType.value = type
  showNotificationModal.value = true
}

// Set by a successful copy so the counts stay readable until the user dismisses
// them; the page used to navigate away under the modal immediately.
const navigateAfterNotification = ref<string | null>(null)

const closeNotificationModal = () => {
  showNotificationModal.value = false
  notificationMessage.value = ''
  const to = navigateAfterNotification.value
  if (to) {
    navigateAfterNotification.value = null
    navigateTo(to)
  }
}

// Functions
const formatDate = (dateString: string) => {
  if (!dateString) return ''
  
  let date: Date
  // For YYYY-MM-DD strings, parse as local date to avoid UTC shift
  if (typeof dateString === 'string' && dateString.match(/^\d{4}-\d{2}-\d{2}$/)) {
    const [year, month, day] = dateString.split('-').map(Number)
    date = new Date(year, month - 1, day)
  } else {
    date = new Date(dateString)
  }
  
  return date.toLocaleDateString('en-US', { 
    weekday: 'long', 
    year: 'numeric', 
    month: 'long', 
    day: 'numeric' 
  })
}

const plural = (n: number, word: string) => `${n} ${word}${n === 1 ? '' : 's'}`

const copyTodaySchedule = async () => {
  const target = selectedDate.value || ''
  if (!target) return
  if (target === today.value) {
    showNotification('Pick a different date — this would copy today onto itself.', 'error')
    return
  }

  const result = await copySchedule(today.value, target)

  if (!result) {
    showNotification(
      `Could not copy the schedule.\n${scheduleError.value || 'The server rejected the request without a reason.'}`,
      'error'
    )
    return
  }

  // Nothing was written. Say so instead of announcing success and opening an
  // empty day.
  if (result.source_empty) {
    showNotification(
      `There is no schedule for today (${formatDate(today.value)}) to copy.\nBuild today's schedule first, or use the Automated Schedule Builder for ${formatDate(target)}.`,
      'error'
    )
    return
  }

  const lines = [`Copied ${plural(result.copied, 'assignment')} from today to ${formatDate(target)}.`]
  if (result.replaced) lines.push(`Replaced the ${plural(result.replaced, 'assignment')} already on that day.`)
  if (result.excluded) lines.push(`${plural(result.excluded, 'assignment')} left off for people who are off that day.`)
  if (result.adjusted) lines.push(`${plural(result.adjusted, 'assignment')} trimmed around a partial absence.`)
  if (result.inactive) lines.push(`${plural(result.inactive, 'assignment')} skipped for people who are no longer active.`)
  if (result.swapped?.length) {
    lines.push(`Not copied because of a shift swap that day — add by hand: ${result.swapped.join(', ')}.`)
  }

  navigateAfterNotification.value = `/schedule/${target}`
  showNotification(lines.join('\n'), 'success')
}

// The schedule builder. Two placement engines share everything else; the card
// chooses. See composables/useScheduleBuilderV2.ts for what each means.
const generateSchedule = async (engine: BuilderEngine) => {
  if (generating.value) return
  try {
    generating.value = true
    buildFailed.value = false
    showResultDetails.value = false
    resultActions.value = []
    resultSummary.value = ''
    scheduleWarnings.value = []
    scheduleGaps.value = []
    scheduleOverTarget.value = []

    const { schedule, warnings, actions, errors, gaps, overTarget, structuralSummary, stats } =
      await generateV2Schedule(selectedDate.value || '', engine)

    if (schedule.length > 0) {
      await applyV2Schedule(schedule, selectedDate.value || '')

      // The headline carries the counts, so they are no longer repeated as notes.
      // Only genuinely actionable gaps reach the table; the unfixable windows
      // (whole shift on break, after-hours targets) are summarised in one line
      // rather than listed as dozens of rows.
      resultSummary.value = summarise(schedule.length, stats?.employeesWithNoWork ?? null, gaps?.length ?? 0)
      resultActions.value = actions || []
      scheduleWarnings.value = [...(structuralSummary || []), ...warnings]
      scheduleGaps.value = gaps || []
      scheduleOverTarget.value = overTarget || []
      showWarningsModal.value = true
    } else {
      buildFailed.value = true
      scheduleWarnings.value = errors.length ? errors : ['The builder produced no assignments.']
      resultSummary.value = ''
      showWarningsModal.value = true
    }
  } catch (error: any) {
    console.error('Error generating schedule:', error)
    showNotification(`❌ Error generating schedule: ${error?.message || 'unknown'}`, 'error')
  } finally {
    generating.value = false
  }
}

const closeWarningsModal = () => {
  showWarningsModal.value = false
  // Navigate to schedule view after closing modal
  navigateTo(`/schedule/${selectedDate.value || ''}`)
}

const goToRulesAndTargets = () => {
  navigateTo('/admin/business-rules')
}

const goToManualSchedule = () => {
  // Navigate to the selected date's schedule page for manual editing
  navigateTo(`/schedule/${selectedDate.value || ''}`)
}


// Date helper functions
const setToTomorrow = () => {
  selectedDate.value = tomorrowDate.value
}

const setToNextMonday = () => {
  const today = new Date()
  const daysUntilMonday = (1 - today.getDay() + 7) % 7
  selectedDate.value = toLocalISO(addDays(today, daysUntilMonday === 0 ? 7 : daysUntilMonday))
}

// Load job functions on mount
onMounted(async () => {
  await fetchJobFunctions()
})
</script>
