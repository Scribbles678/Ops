<template>
  <div class="min-h-screen bg-gray-50">
    <div class="container mx-auto px-4 py-8">
      <!-- Header -->
      <div class="flex items-center justify-between mb-8">
        <div>
          <h1 class="text-4xl font-bold text-gray-800">Make Tomorrow's Schedule</h1>
          <p class="text-gray-600 mt-1">{{ tomorrowFormatted }}</p>
        </div>
        <NuxtLink to="/" class="btn-secondary">
          ← Back to Home
        </NuxtLink>
      </div>

      <!-- Options Screen (if schedule doesn't exist) -->
      <div v-if="!scheduleCreated" class="max-w-2xl mx-auto">
        <div class="card space-y-6">
          <h2 class="text-2xl font-bold text-gray-800 text-center mb-6">
            How would you like to start?
          </h2>

          <!-- Start from Blank -->
          <button
            @click="startBlank"
            class="w-full p-6 border-2 border-gray-300 rounded-lg hover:border-blue-500 hover:bg-blue-50 transition text-left group"
          >
            <div class="flex items-center">
              <div class="bg-blue-100 rounded-full p-4 mr-4 group-hover:bg-blue-200">
                <svg class="w-8 h-8 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 13h6m-3-3v6m5 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
              </div>
              <div>
                <h3 class="text-xl font-bold text-gray-800 mb-1">Start from Blank Schedule</h3>
                <p class="text-gray-600">Create tomorrow's schedule from scratch</p>
              </div>
            </div>
          </button>

          <!-- Copy Today's Schedule -->
          <button
            @click="copyToday"
            :disabled="copying"
            class="w-full p-6 border-2 border-gray-300 rounded-lg hover:border-green-500 hover:bg-green-50 transition text-left group disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <div class="flex items-center">
              <div class="bg-green-100 rounded-full p-4 mr-4 group-hover:bg-green-200">
                <svg class="w-8 h-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                </svg>
              </div>
              <div>
                <h3 class="text-xl font-bold text-gray-800 mb-1">
                  {{ copying ? 'Copying...' : 'Copy Today\'s Schedule' }}
                </h3>
                <p class="text-gray-600">Duplicate today's assignments for tomorrow</p>
              </div>
            </div>
          </button>

          <!-- Error Message -->
          <div v-if="error" class="bg-red-50 border border-red-200 rounded-lg p-4">
            <p class="text-red-600">{{ error }}</p>
          </div>

          <!-- Success Message -->
          <div v-if="success" class="bg-green-50 border border-green-200 rounded-lg p-4">
            <p class="text-green-600">✓ Schedule created! Redirecting...</p>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const router = useRouter()
const { formatDate } = useLaborCalculations()
const { copySchedule, loading } = useSchedule()

const copying = ref(false)
const scheduleCreated = ref(false)
const error = ref('')
const success = ref(false)

const tomorrow = computed(() => {
  const date = new Date()
  date.setDate(date.getDate() + 1)
  return date.toISOString().split('T')[0]
})

const today = computed(() => {
  return new Date().toISOString().split('T')[0]
})

const tomorrowFormatted = computed(() => {
  return formatDate(tomorrow.value)
})

const startBlank = () => {
  router.push(`/schedule/${tomorrow.value}`)
}

const copyToday = async () => {
  copying.value = true
  error.value = ''
  
  try {
    const result = await copySchedule(today.value, tomorrow.value)
    
    if (result) {
      success.value = true
      setTimeout(() => {
        router.push(`/schedule/${tomorrow.value}`)
      }, 1000)
    } else {
      error.value = 'Failed to copy schedule. Please try again.'
    }
  } catch (e) {
    error.value = 'An error occurred while copying the schedule.'
    console.error('Copy error:', e)
  } finally {
    copying.value = false
  }
}
</script>

