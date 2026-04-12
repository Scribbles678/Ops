<template>
  <div class="min-h-screen bg-gray-50">
    <div class="container mx-auto px-4 py-8">
      <!-- Header -->
      <div class="flex items-center justify-between mb-8">
        <div>
          <h1 class="text-4xl font-bold text-gray-800">Create Schedule</h1>
          <p class="text-gray-600 mt-2">Choose a date and create a schedule</p>
        </div>
        <div class="flex space-x-4">
          <button @click="handleLogout" class="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-lg text-sm font-medium transition-colors">
            Logout
          </button>
          <NuxtLink to="/" class="btn-secondary">
            ← Back to Home
          </NuxtLink>
        </div>
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
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-8">
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

        <!-- AI Generated Schedule -->
        <div class="card hover:shadow-lg transition-all cursor-pointer" @click="openBuildReview" :class="{ 'opacity-50 cursor-not-allowed': generating }">
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
              {{ generating ? '⏳ Generating Schedule...' : 'Automated Schedule Builder' }}
            </h3>
            <p class="text-gray-600">
              {{ generating ? 'Please wait while we create your optimized schedule...' : 'Generate an optimized schedule based on staffing targets, training, and required assignments' }}
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
      </div>

      <!-- Business Rules shortcut -->
      <div class="flex justify-center gap-4 mt-6">
        <NuxtLink
          to="/admin/business-rules"
          class="inline-flex items-center px-5 py-2.5 border border-gray-300 rounded-lg text-sm text-gray-600 hover:bg-gray-50 transition"
        >
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
          </svg>
          Business Rules &amp; Targets
        </NuxtLink>
        <NuxtLink
          to="/pto-calendar"
          class="inline-flex items-center px-5 py-2.5 border border-gray-300 rounded-lg text-sm text-gray-600 hover:bg-gray-50 transition"
        >
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
          </svg>
          PTO Calendar
        </NuxtLink>
      </div>

      <!-- Build Review Modal -->
      <div v-if="showBuildReview" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-white rounded-xl p-6 max-w-lg w-full mx-4 shadow-xl">
          <!-- Header -->
          <div class="flex items-center justify-between mb-1">
            <h3 class="text-xl font-bold text-gray-800">Build Schedule</h3>
            <button @click="showBuildReview = false" class="text-gray-400 hover:text-gray-600">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
          <p class="text-sm text-gray-500 mb-5">{{ formatDate(selectedDate || '') }}</p>

          <!-- Loading -->
          <div v-if="buildReviewLoading" class="py-10 text-center text-gray-500">
            <div class="flex justify-center mb-3">
              <svg class="animate-spin h-8 w-8 text-purple-500" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
            </div>
            <p class="text-sm">Checking schedule inputs…</p>
          </div>

          <!-- Preflight checklist -->
          <div v-else class="space-y-2.5 mb-5">

            <!-- Staffing Targets -->
            <div class="flex items-center justify-between p-3.5 rounded-lg"
              :class="reviewData.staffingFunctionsCount === 0 ? 'bg-red-50' : 'bg-green-50'">
              <div class="flex items-center space-x-3">
                <span class="text-xl leading-none">{{ reviewData.staffingFunctionsCount === 0 ? '🔴' : '✅' }}</span>
                <div>
                  <p class="text-sm font-semibold text-gray-800">Staffing Targets</p>
                  <p class="text-xs text-gray-500 mt-0.5">
                    {{ reviewData.staffingFunctionsCount === 0
                      ? 'No targets configured — schedule cannot be built'
                      : `${reviewData.staffingFunctionsCount} job function${reviewData.staffingFunctionsCount === 1 ? '' : 's'} with headcount targets` }}
                  </p>
                </div>
              </div>
              <NuxtLink to="/admin/business-rules" @click="showBuildReview = false"
                class="text-xs text-blue-600 hover:underline font-medium shrink-0 ml-3">Edit →</NuxtLink>
            </div>

            <!-- Required Assignments -->
            <div class="flex items-center justify-between p-3.5 rounded-lg"
              :class="reviewData.requiredCount === 0 ? 'bg-yellow-50' : 'bg-green-50'">
              <div class="flex items-center space-x-3">
                <span class="text-xl leading-none">{{ reviewData.requiredCount === 0 ? '⚠️' : '✅' }}</span>
                <div>
                  <p class="text-sm font-semibold text-gray-800">Required Assignments</p>
                  <p class="text-xs text-gray-500 mt-0.5">
                    {{ reviewData.requiredCount === 0
                      ? 'None pinned — all roles filled by demand only'
                      : `${reviewData.requiredCount} pinned assignment${reviewData.requiredCount === 1 ? '' : 's'} (e.g. Coordinator, TL)` }}
                  </p>
                </div>
              </div>
              <NuxtLink to="/admin/business-rules" @click="showBuildReview = false"
                class="text-xs text-blue-600 hover:underline font-medium shrink-0 ml-3">Edit →</NuxtLink>
            </div>

            <!-- PTO -->
            <div class="flex items-center justify-between p-3.5 rounded-lg"
              :class="reviewData.ptoCount === 0 ? 'bg-gray-50' : 'bg-blue-50'">
              <div class="flex items-center space-x-3">
                <span class="text-xl leading-none">{{ reviewData.ptoCount === 0 ? '✅' : 'ℹ️' }}</span>
                <div>
                  <p class="text-sm font-semibold text-gray-800">PTO</p>
                  <p class="text-xs text-gray-500 mt-0.5">
                    {{ reviewData.ptoCount === 0
                      ? 'No employees on PTO this day'
                      : `${reviewData.ptoCount} employee${reviewData.ptoCount === 1 ? '' : 's'} on PTO — excluded or adjusted automatically` }}
                  </p>
                </div>
              </div>
              <NuxtLink to="/pto-calendar" @click="showBuildReview = false"
                class="text-xs text-blue-600 hover:underline font-medium shrink-0 ml-3">View →</NuxtLink>
            </div>

            <!-- Active Employees -->
            <div class="flex items-center justify-between p-3.5 rounded-lg"
              :class="reviewData.activeEmployeesCount === 0 ? 'bg-red-50' : 'bg-green-50'">
              <div class="flex items-center space-x-3">
                <span class="text-xl leading-none">{{ reviewData.activeEmployeesCount === 0 ? '🔴' : '✅' }}</span>
                <div>
                  <p class="text-sm font-semibold text-gray-800">Active Employees</p>
                  <p class="text-xs text-gray-500 mt-0.5">
                    {{ reviewData.activeEmployeesCount === 0
                      ? 'No active employees found — schedule cannot be built'
                      : `${reviewData.activeEmployeesCount} active employee${reviewData.activeEmployeesCount === 1 ? '' : 's'} will be considered` }}
                  </p>
                </div>
              </div>
            </div>

          </div>

          <!-- Blocker message -->
          <div v-if="!buildReviewLoading && buildReviewHasBlockers"
            class="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg">
            <p class="text-sm text-red-700">Resolve the issues above before building.</p>
          </div>

          <!-- Actions -->
          <div class="flex justify-end space-x-3 pt-1">
            <button @click="showBuildReview = false"
              class="px-4 py-2 border border-gray-300 rounded-lg text-sm text-gray-700 hover:bg-gray-50">
              Cancel
            </button>
            <button
              @click="confirmAndBuild"
              :disabled="buildReviewLoading || buildReviewHasBlockers"
              class="px-5 py-2 bg-purple-600 text-white rounded-lg text-sm font-medium hover:bg-purple-700 disabled:opacity-40 disabled:cursor-not-allowed transition"
            >
              Build Schedule →
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
          
          <!-- Success with gaps -->
          <div v-if="scheduleGaps.length > 0" class="mb-4 p-4 bg-yellow-50 border border-yellow-200 rounded-lg">
            <p class="text-yellow-800 font-medium">
              Schedule generated, but some staffing targets could not be met.
            </p>
          </div>

          <!-- Success with warnings only -->
          <div v-else-if="scheduleWarnings.length > 0 && !scheduleWarnings.some(w => w.includes('Error') || w.includes('No schedule') || w.includes('not configured'))" class="mb-4 p-4 bg-green-50 border border-green-200 rounded-lg">
            <p class="text-green-800 font-medium">
              Schedule generated successfully with some notes.
            </p>
          </div>

          <!-- Errors -->
          <div v-else-if="scheduleWarnings.length > 0" class="mb-4 p-4 bg-red-50 border border-red-200 rounded-lg">
            <p class="text-red-800 font-medium">
              Schedule could not be generated. Please review the issues below.
            </p>
          </div>

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

          <!-- Other warnings -->
          <div v-if="scheduleWarnings.length > 0" class="mb-6">
            <h4 class="text-lg font-semibold text-gray-700 mb-3">Details:</h4>
            <div class="space-y-2">
              <div
                v-for="(warning, index) in scheduleWarnings"
                :key="index"
                :class="warning.includes('Error') || warning.includes('No schedule') || warning.includes('not configured')
                  ? 'p-3 bg-red-50 border border-red-200 rounded-lg'
                  : 'p-3 bg-yellow-50 border border-yellow-200 rounded-lg'"
              >
                <p :class="warning.includes('Error') || warning.includes('No schedule') || warning.includes('not configured')
                  ? 'text-sm text-red-800'
                  : 'text-sm text-yellow-800'"
                >{{ warning }}</p>
              </div>
            </div>
          </div>

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
import { useAIScheduleBuilder } from '~/composables/useAIScheduleBuilder'

const { copySchedule } = useSchedule()
const { logout } = useAuth()
const { fetchJobFunctions } = useJobFunctions()
const { generateAISchedule: generateAIScheduleFromBuilder, applyAISchedule } = useAIScheduleBuilder()
const { fetchTargets } = useStaffingTargets()
const { fetchPreferredAssignments } = usePreferredAssignments()
const { fetchPTOForDate } = usePTO()
const { fetchEmployees } = useEmployees()

// Tomorrow's date
const tomorrowDate = computed(() => {
  const tomorrow = new Date()
  tomorrow.setDate(tomorrow.getDate() + 1)
  return tomorrow.toISOString().split('T')[0]
})

// Today's date
const today = computed(() => {
  return new Date().toISOString().split('T')[0]
})

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
const scheduleGaps = ref<{ job_function_name: string; hour: string; shortfall: number }[]>([])

// Build Review state
const showBuildReview = ref(false)
const buildReviewLoading = ref(false)
const reviewData = ref({
  staffingFunctionsCount: 0,
  requiredCount: 0,
  ptoCount: 0,
  activeEmployeesCount: 0,
})
const buildReviewHasBlockers = computed(
  () => reviewData.value.staffingFunctionsCount === 0 || reviewData.value.activeEmployeesCount === 0
)

// Notification modal state
const showNotificationModal = ref(false)
const notificationMessage = ref('')
const notificationType = ref<'success' | 'error'>('success')

const showNotification = (message: string, type: 'success' | 'error' = 'success') => {
  notificationMessage.value = message
  notificationType.value = type
  showNotificationModal.value = true
}

const closeNotificationModal = () => {
  showNotificationModal.value = false
  notificationMessage.value = ''
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

const openBuildReview = async () => {
  showBuildReview.value = true
  buildReviewLoading.value = true
  reviewData.value = { staffingFunctionsCount: 0, requiredCount: 0, ptoCount: 0, activeEmployeesCount: 0 }

  try {
    const [targets, assignments, ptoDays, employees] = await Promise.all([
      fetchTargets(),
      fetchPreferredAssignments(),
      fetchPTOForDate(selectedDate.value || ''),
      fetchEmployees(true),
    ])

    const targetsList = Array.isArray(targets) ? targets : []
    const functionsWithTargets = new Set(
      targetsList.filter((t: any) => (t.headcount ?? 0) > 0).map((t: any) => t.job_function_id)
    )
    reviewData.value.staffingFunctionsCount = functionsWithTargets.size

    const assignmentsList = Array.isArray(assignments) ? assignments : []
    reviewData.value.requiredCount = assignmentsList.filter((a: any) => a.is_required).length

    reviewData.value.ptoCount = Array.isArray(ptoDays) ? ptoDays.length : 0

    reviewData.value.activeEmployeesCount = Array.isArray(employees) ? employees.length : 0
  } catch (e) {
    console.error('Error loading build review data:', e)
  } finally {
    buildReviewLoading.value = false
  }
}

const confirmAndBuild = () => {
  showBuildReview.value = false
  generateAISchedule()
}

const copyTodaySchedule = async () => {
  try {
    const today = new Date().toISOString().split('T')[0]
    
    // Copy today's schedule to selected date
    const success = await copySchedule(today, selectedDate.value || '')
    
    if (success) {
      showNotification(`Today's schedule copied to ${formatDate(selectedDate.value || '')} successfully!`, 'success')
      // Navigate to the selected date's schedule page to see/edit the copied schedule
      navigateTo(`/schedule/${selectedDate.value || ''}`)
    } else {
      showNotification('Error copying schedule. Please try again.', 'error')
    }
  } catch (error) {
    console.error('Error copying schedule:', error)
    showNotification('Error copying schedule. Please try again.', 'error')
  }
}

const generateAISchedule = async () => {
    try {
      generating.value = true
      scheduleWarnings.value = []
      scheduleGaps.value = []

      const { schedule, warnings, errors, gaps } = await generateAIScheduleFromBuilder(selectedDate.value || '')

      if (schedule.length > 0) {
        await applyAISchedule(schedule, selectedDate.value || '')

        scheduleWarnings.value = warnings
        scheduleGaps.value = gaps || []

        if (warnings.length > 0 || scheduleGaps.value.length > 0) {
          showWarningsModal.value = true
        } else {
          showNotification(`Schedule generated successfully! Created ${schedule.length} assignments for ${formatDate(selectedDate.value || '')}. Redirecting...`, 'success')
          setTimeout(() => {
            navigateTo(`/schedule/${selectedDate.value || ''}`)
          }, 500)
        }
      } else {
        scheduleWarnings.value = errors
        showWarningsModal.value = true
      }
    } catch (error) {
      console.error('Error generating schedule:', error)
      showNotification('❌ Error generating schedule.\n\nPlease try again or check the console for details.', 'error')
    } finally {
      generating.value = false
    }
}

const closeWarningsModal = () => {
  showWarningsModal.value = false
  // Navigate to schedule view after closing modal
  navigateTo(`/schedule/${selectedDate.value || ''}`)
}

const goToManualSchedule = () => {
  // Navigate to the selected date's schedule page for manual editing
  navigateTo(`/schedule/${selectedDate.value || ''}`)
}

const handleLogout = async () => {
  await logout()
}

// Date helper functions
const setToTomorrow = () => {
  selectedDate.value = tomorrowDate.value
}

const setToNextMonday = () => {
  const today = new Date()
  const daysUntilMonday = (1 - today.getDay() + 7) % 7
  const nextMonday = new Date(today)
  nextMonday.setDate(today.getDate() + (daysUntilMonday === 0 ? 7 : daysUntilMonday))
  selectedDate.value = nextMonday.toISOString().split('T')[0]
}

// Load job functions on mount
onMounted(async () => {
  await fetchJobFunctions()
})
</script>
