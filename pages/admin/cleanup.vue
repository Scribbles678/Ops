<template>
  <div class="min-h-screen bg-gray-50">
    <div class="container mx-auto px-4 py-8">
      <!-- Header -->
      <div class="flex items-center justify-between mb-8">
        <div>
          <h1 class="text-4xl font-bold text-gray-800">Database Cleanup</h1>
          <p class="text-gray-600 mt-2">Manage schedule data retention and archiving</p>
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

      <!-- Cleanup Statistics -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <div class="card">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm font-medium text-gray-600">Current Schedules</p>
              <p class="text-2xl font-bold text-gray-900">{{ stats?.total_assignments || 0 }}</p>
            </div>
            <div class="bg-blue-100 rounded-full p-3">
              <svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
              </svg>
            </div>
          </div>
        </div>

        <div class="card">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm font-medium text-gray-600">Archived Schedules</p>
              <p class="text-2xl font-bold text-gray-900">{{ stats?.total_archived_assignments || 0 }}</p>
            </div>
            <div class="bg-yellow-100 rounded-full p-3">
              <svg class="w-6 h-6 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 8l4 4-4 4m5-4h6" />
              </svg>
            </div>
          </div>
        </div>

        <div class="card">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm font-medium text-gray-600">To Cleanup</p>
              <p class="text-2xl font-bold text-red-600">{{ stats?.assignments_to_cleanup || 0 }}</p>
            </div>
            <div class="bg-red-100 rounded-full p-3">
              <svg class="w-6 h-6 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
              </svg>
            </div>
          </div>
        </div>

        <div class="card">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm font-medium text-gray-600">Date Range</p>
              <p class="text-sm font-bold text-gray-900">
                {{ formatDate(stats?.oldest_schedule_date) }} - {{ formatDate(stats?.newest_schedule_date) }}
              </p>
            </div>
            <div class="bg-green-100 rounded-full p-3">
              <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
              </svg>
            </div>
          </div>
        </div>
      </div>

      <!-- Cleanup Actions -->
      <div class="card mb-8">
        <h2 class="text-xl font-bold text-gray-800 mb-4">Cleanup Actions</h2>
        <div class="space-y-4">
          <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
            <div class="flex items-center">
              <svg class="w-5 h-5 text-yellow-600 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z" />
              </svg>
              <p class="text-sm text-yellow-800">
                <strong>Retention Policy:</strong> Schedules older than 7 days are deleted from the main table.
              </p>
            </div>
          </div>

          <div class="flex space-x-4">
            <button 
              @click="runManualCleanup" 
              :disabled="loading || !stats?.assignments_to_cleanup"
              class="btn-primary disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <svg v-if="loading" class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              {{ loading ? 'Running Cleanup...' : 'Run Cleanup Now' }}
            </button>

            <button 
              @click="refreshStats" 
              :disabled="loading"
              class="btn-secondary disabled:opacity-50"
            >
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
              </svg>
              Refresh Stats
            </button>
          </div>

          <div v-if="cleanupResult" class="bg-green-50 border border-green-200 rounded-lg p-4">
            <h3 class="font-semibold text-green-800 mb-2">Cleanup Completed Successfully!</h3>
            <div class="text-sm text-green-700">
              <p>Archived {{ cleanupResult.archived_assignments }} schedule assignments</p>
              <p>Archived {{ cleanupResult.archived_targets }} daily targets</p>
              <p>Cleanup date: {{ formatDateTime(cleanupResult.cleanup_date) }}</p>
            </div>
          </div>

          <div v-if="error" class="bg-red-50 border border-red-200 rounded-lg p-4">
            <h3 class="font-semibold text-red-800 mb-2">Cleanup Error</h3>
            <p class="text-sm text-red-700">{{ error }}</p>
          </div>
        </div>
      </div>

      <!-- Cleanup Status Table -->
      <div class="card mb-8">
        <h2 class="text-xl font-bold text-gray-800 mb-4">Database Status</h2>
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Table</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Records</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Oldest Date</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Newest Date</th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <tr v-for="status in cleanupStatus" :key="status.table_name">
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                  {{ status.table_name }}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {{ status.record_count }}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {{ formatDate(status.oldest_date) }}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {{ formatDate(status.newest_date) }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- Cleanup Log -->
      <div class="card">
        <h2 class="text-xl font-bold text-gray-800 mb-4">Recent Cleanup Operations</h2>
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Date</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Assignments</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Targets</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <tr v-for="log in cleanupLog" :key="log.id">
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {{ formatDateTime(log.cleanup_date) }}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {{ log.archived_assignments }}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {{ log.archived_targets }}
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span :class="log.success ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'" 
                        class="inline-flex px-2 py-1 text-xs font-semibold rounded-full">
                    {{ log.success ? 'Success' : 'Failed' }}
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
// Import composables
const { runCleanup, getCleanupStats, getCleanupLog, getCleanupStatus } = useSchedule()
const { logout } = useAuth()

// Reactive data
const stats = ref(null)
const cleanupStatus = ref([])
const cleanupLog = ref([])
const cleanupResult = ref(null)
const loading = ref(false)
const error = ref('')

// Load data on mount
onMounted(async () => {
  await loadData()
})

// Load all cleanup data
const loadData = async () => {
  try {
    loading.value = true
    error.value = ''
    
    const [statsData, statusData, logData] = await Promise.all([
      getCleanupStats(),
      getCleanupStatus(),
      getCleanupLog(20)
    ])
    
    stats.value = statsData
    cleanupStatus.value = statusData
    cleanupLog.value = logData
  } catch (err) {
    error.value = err.message || 'Error loading cleanup data'
    console.error('Error loading cleanup data:', err)
  } finally {
    loading.value = false
  }
}

// Run manual cleanup
const runManualCleanup = async () => {
  if (!confirm('Are you sure you want to run cleanup now? This will archive schedules older than 7 days.')) {
    return
  }
  
  try {
    loading.value = true
    error.value = ''
    cleanupResult.value = null
    
    const result = await runCleanup()
    
    if (result) {
      cleanupResult.value = result
      await loadData() // Refresh stats
    } else {
      error.value = 'Cleanup failed. Please try again.'
    }
  } catch (err) {
    error.value = err.message || 'Error running cleanup'
    console.error('Error running cleanup:', err)
  } finally {
    loading.value = false
  }
}

// Refresh statistics
const refreshStats = async () => {
  await loadData()
}

// Format date
const formatDate = (dateString: string) => {
  if (!dateString) return 'N/A'
  const date = new Date(dateString)
  return date.toLocaleDateString('en-US', { 
    year: 'numeric', 
    month: 'short', 
    day: 'numeric' 
  })
}

// Format date and time
const formatDateTime = (dateString: string) => {
  if (!dateString) return 'N/A'
  const date = new Date(dateString)
  return date.toLocaleString('en-US', { 
    year: 'numeric', 
    month: 'short', 
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  })
}

// Logout handler
const handleLogout = async () => {
  if (confirm('Are you sure you want to logout?')) {
    await logout()
  }
}
</script>
