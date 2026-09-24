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
      <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-6 mb-8">
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
          @click="generateSchedule()"
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

      <!-- (A dated Training & Coverage Preview sat here until Sep 2026. It was
           replaced by Team Setup → Training Matrix, which is not tied to a date.) -->

      <!-- Replace an existing schedule? Building and Copy Today both replace the
           whole day, so a day that may carry hand edits gets asked about first. -->
      <div v-if="replacePrompt" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4 shadow-xl">
          <h3 class="text-xl font-bold text-gray-800 mb-3">Replace the existing schedule?</h3>
          <p class="text-sm text-gray-700 mb-2">
            {{ formatDate(replacePrompt.date) }} already has
            {{ replacePrompt.count }} assignment{{ replacePrompt.count === 1 ? '' : 's' }}.
          </p>
          <p class="text-sm text-gray-700 mb-5">
            {{ replacePrompt.action }} replaces all of them, including any changes made by hand.
          </p>
          <div class="flex justify-end gap-3">
            <button
              @click="answerReplacePrompt(false)"
              class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition-colors"
            >
              Cancel
            </button>
            <button
              @click="answerReplacePrompt(true)"
              class="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors font-medium"
            >
              Replace
            </button>
          </div>
        </div>
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

      <!-- Build result. One headline, then only what matters, most urgent first:
           what a person must fix (each linked to where it is fixed), where the day
           is still short and why, and where the spare people went. Short enough to
           read whole, so there is no "Show details". Keyed off whether a schedule
           was produced — never off message text. -->
      <div v-if="buildResult" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-white rounded-lg max-w-2xl w-full mx-4 shadow-xl max-h-[90vh] overflow-y-auto">
          <!-- Headline -->
          <div class="flex items-start gap-3 px-6 pt-6">
            <span
              class="flex h-9 w-9 shrink-0 items-center justify-center rounded-full"
              :class="buildResult.schedule.length ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'"
            >
              <svg v-if="buildResult.schedule.length" class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7" />
              </svg>
              <svg v-else class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </span>
            <div class="flex-1 min-w-0">
              <h3 class="text-xl font-bold text-gray-900">
                {{ buildResult.schedule.length ? 'Schedule saved' : 'Schedule not built' }}
              </h3>
              <p class="text-sm text-gray-600 mt-0.5">
                {{ resultHeadline }}<span v-if="buildResult.noWork" class="font-medium text-amber-700">
                  · {{ buildResult.noWork }} with no work</span>
              </p>
            </div>
            <button @click="closeBuildResult" class="text-gray-400 hover:text-gray-600" aria-label="Close">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <div class="px-6 py-5 space-y-6">
            <!-- Things to fix: the only part styled to demand attention. Red when
                 nothing was built, because then these are why. -->
            <section v-if="buildResult.fixes.length">
              <h4 v-if="buildResult.schedule.length" class="text-sm font-semibold text-amber-900 mb-2">
                {{ buildResult.fixes.length }} thing{{ buildResult.fixes.length === 1 ? '' : 's' }} to fix
              </h4>
              <ul
                class="rounded-lg border divide-y"
                :class="buildResult.schedule.length
                  ? 'border-amber-200 bg-amber-50 divide-amber-200 text-amber-900'
                  : 'border-red-200 bg-red-50 divide-red-200 text-red-900'"
              >
                <li
                  v-for="(fix, index) in buildResult.fixes"
                  :key="index"
                  class="flex flex-col gap-1 px-3 py-2.5 text-sm sm:flex-row sm:items-start sm:justify-between sm:gap-4"
                >
                  <span>{{ fix.message }}</span>
                  <NuxtLink
                    v-if="fix.fix"
                    :to="FIX_LINKS[fix.fix].to"
                    class="shrink-0 whitespace-nowrap font-medium underline underline-offset-2 hover:no-underline"
                  >
                    {{ FIX_LINKS[fix.fix].label }} →
                  </NuxtLink>
                </li>
              </ul>
            </section>

            <!-- Still short: a row per job a person could do something about, then
                 one whole-floor line for what no schedule can cover. -->
            <section v-if="shortHours > 0">
              <div class="flex items-baseline justify-between border-b border-gray-200 pb-1.5">
                <h4 class="text-sm font-semibold text-gray-900">Still short</h4>
                <span class="text-sm font-semibold tabular-nums text-gray-900">{{ formatHours(shortHours) }} h</span>
              </div>
              <ul class="divide-y divide-gray-100">
                <li v-for="row in buildResult.short" :key="row.functionName + row.cause" class="flex gap-4 py-2 text-sm">
                  <span class="w-24 sm:w-28 shrink-0 font-medium text-gray-900">{{ row.functionName }}</span>
                  <span class="flex-1 min-w-0">
                    <span class="text-gray-700">
                      <!-- One unbreakable span per window, so a narrow screen wraps
                           between windows, never inside "19:15–20:00". -->
                      <template v-for="(w, i) in row.windows" :key="w"><span v-if="i" class="text-gray-400"> · </span><span class="whitespace-nowrap">{{ w }}</span></template>
                    </span>
                    <span class="block text-xs text-gray-500">{{ SHORT_REASON[row.cause] }}</span>
                  </span>
                  <span class="shrink-0 tabular-nums text-gray-700">{{ formatHours(row.hours) }} h</span>
                </li>
                <!-- Not a job: the floor as a whole. Muted, because nobody can act
                     on it from here. -->
                <li v-if="buildResult.unavoidable.hours > 0" class="flex gap-4 py-2 text-sm">
                  <span class="w-24 sm:w-28 shrink-0 font-medium text-gray-500">Whole floor</span>
                  <span class="flex-1 min-w-0">
                    <span class="text-gray-700">
                      <template v-for="(w, i) in buildResult.unavoidable.windows" :key="w"><span v-if="i" class="text-gray-400"> · </span><span class="whitespace-nowrap">{{ w }}</span></template>
                    </span>
                    <span class="block text-xs text-gray-500">{{ SHORT_REASON['floor-short'] }}</span>
                  </span>
                  <span class="shrink-0 tabular-nums text-gray-700">{{ formatHours(buildResult.unavoidable.hours) }} h</span>
                </li>
              </ul>
            </section>

            <p v-if="buildResult.schedule.length && shortHours === 0" class="text-sm text-green-800">
              Every target is covered.
            </p>

            <!-- Extra coverage: targets are a minimum, so spare people keep working.
                 Informational, so plain chips and no explanation. -->
            <section v-if="buildResult.extra.length">
              <div class="flex items-baseline justify-between border-b border-gray-200 pb-1.5 mb-2.5">
                <h4 class="text-sm font-semibold text-gray-900">Extra coverage</h4>
                <span class="text-sm font-semibold tabular-nums text-gray-900">{{ formatHours(extraHours) }} h</span>
              </div>
              <div class="flex flex-wrap gap-1.5">
                <span
                  v-for="e in buildResult.extra"
                  :key="e.functionName"
                  class="inline-flex items-center gap-1 rounded-full border border-blue-200 bg-blue-50 px-2.5 py-0.5 text-xs text-blue-800"
                >
                  {{ e.functionName }}
                  <span class="font-semibold tabular-nums">+{{ formatHours(e.hours) }} h</span>
                </span>
              </div>
            </section>

            <ul v-if="buildResult.notes.length" class="space-y-1 text-xs text-gray-500">
              <li v-for="(note, index) in buildResult.notes" :key="index">{{ note }}</li>
            </ul>
          </div>

          <div class="flex justify-end px-6 pb-6">
            <button
              v-if="buildResult.schedule.length"
              @click="viewBuiltSchedule"
              class="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium"
            >
              View schedule
            </button>
            <button
              v-else
              @click="closeBuildResult"
              class="px-6 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition-colors font-medium"
            >
              Close
            </button>
          </div>
        </div>
      </div>

    </div>
  </div>
</template>

<script setup lang="ts">
import { toLocalISO, addDays } from '~/utils/localDate'
import type { BuildOutcome } from '~/composables/useScheduleBuilderV2'
import type { FixPlace, GapCause } from '~/utils/scheduleEngineV2/types'

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

// Builder state. `buildResult` is what the last build returned, plus the date it
// was for, while its result window is open; null when closed. The date is kept so
// "View schedule" opens the day that was built even if the picker has moved since.
const generating = ref(false)
const buildResult = ref<(BuildOutcome & { date: string }) | null>(null)

/** Where each kind of fix is made. The result window links straight there. */
const FIX_LINKS: Record<FixPlace, { label: string; to: string }> = {
  'rules-and-targets': { label: 'Rules & Targets', to: '/admin/business-rules' },
  'required-assignments': { label: 'Required Assignments', to: '/admin/business-rules?open=required' },
  employees: { label: 'Employees & Training', to: '/details?tab=employees' },
  'job-functions': { label: 'Job Functions', to: '/details?tab=job-functions' },
  shifts: { label: 'Shifts', to: '/details?tab=shifts' },
}

/** Why a job went short, in a few words. */
const SHORT_REASON: Record<GapCause, string> = {
  'all-trained-busy': 'everyone trained was on other work',
  capped: 'at its max headcount',
  'no-availability': 'trained staff free for under 30 minutes',
  'no-one-trained-on-shift': 'no one trained is on shift then',
  'no-one-trained': 'no one is trained for it',
  'floor-short': 'more work than people on shift',
}

const shortHours = computed(() =>
  (buildResult.value?.short ?? []).reduce((sum, row) => sum + row.hours, 0) + (buildResult.value?.unavoidable.hours ?? 0)
)
const extraHours = computed(() => (buildResult.value?.extra ?? []).reduce((sum, e) => sum + e.hours, 0))

/** 6.75 -> "6.75", 0.5 -> "0.5", 8 -> "8". */
const formatHours = (h: number) => String(Math.round(h * 100) / 100)

/** "2026-09-24" -> "Thu, Sep 24". A date-time with no offset parses as LOCAL time. */
const shortDate = (iso: string): string =>
  new Date(`${iso}T00:00:00`).toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' })

/** "Thu, Sep 24 · 40 people scheduled · 2 off all day". Zeros are left out. */
const resultHeadline = computed(() => {
  const result = buildResult.value
  if (!result) return ''
  const parts = [shortDate(result.date)]
  if (result.schedule.length) parts.push(`${result.people} ${result.people === 1 ? 'person' : 'people'} scheduled`)
  else parts.push('nothing was saved')
  if (result.offAllDay) parts.push(`${result.offAllDay} off all day`)
  return parts.join(' · ')
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

// Building and Copy Today both REPLACE the whole day, and a day that already has
// a schedule may carry hand edits. Both used to replace it without a word.
const replaceCheckBusy = ref(false)
const replacePrompt = ref<{ date: string; count: number; action: string; resolve: (ok: boolean) => void } | null>(null)

/**
 * Resolves true when it is fine to replace `date`: nothing is scheduled there yet,
 * or the user said yes.
 *
 * Asks the API directly. useSchedule().fetchScheduleForDate turns a failed lookup
 * into an empty list, and "empty" here would mean "overwrite without asking".
 */
const confirmReplace = async (date: string, action: string): Promise<boolean> => {
  // A second click while the check or the question is open does nothing.
  if (replaceCheckBusy.value) return false
  replaceCheckBusy.value = true
  try {
    const existing = await $fetch<any[]>(`/api/schedule/${date}`)
    if (!existing.length) return true
    return await new Promise<boolean>((resolve) => {
      replacePrompt.value = { date, count: existing.length, action, resolve }
    })
  } catch (e: any) {
    showNotification(
      `Could not check whether ${formatDate(date)} already has a schedule, so nothing was changed.\n${e?.data?.message || e?.message || ''}`,
      'error'
    )
    return false
  } finally {
    replaceCheckBusy.value = false
  }
}

const answerReplacePrompt = (ok: boolean) => {
  const prompt = replacePrompt.value
  replacePrompt.value = null
  prompt?.resolve(ok)
}

const copyTodaySchedule = async () => {
  const target = selectedDate.value || ''
  if (!target) return
  if (target === today.value) {
    showNotification('Pick a different date — this would copy today onto itself.', 'error')
    return
  }
  if (!(await confirmReplace(target, "Copying today's schedule"))) return

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

// The Automated Schedule Builder. See composables/useScheduleBuilderV2.ts.
const generateSchedule = async () => {
  if (generating.value || !selectedDate.value) return
  if (!(await confirmReplace(selectedDate.value, 'Building a new schedule'))) return
  const date = selectedDate.value
  try {
    generating.value = true
    buildResult.value = null
    const outcome = await generateV2Schedule(date)
    // Save first, then show what was saved. A build that produced nothing writes
    // nothing, and its window says why.
    if (outcome.schedule.length > 0) await applyV2Schedule(outcome.schedule, date)
    buildResult.value = { ...outcome, date }
  } catch (error: any) {
    console.error('Error generating schedule:', error)
    showNotification(`❌ Error generating schedule: ${error?.message || 'unknown'}`, 'error')
  } finally {
    generating.value = false
  }
}

/** Close the result window and stay here, e.g. to fix something and build again. */
const closeBuildResult = () => {
  buildResult.value = null
}

const viewBuiltSchedule = () => {
  const date = buildResult.value?.date
  buildResult.value = null
  if (date) navigateTo(`/schedule/${date}`)
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
