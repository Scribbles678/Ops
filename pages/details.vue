<template>
  <div class="details-page min-h-screen bg-gray-50">
    <div class="container mx-auto px-4 py-6 md:py-8">
      <!-- Header -->
      <div class="flex items-center justify-between mb-5">
        <h1 class="text-2xl md:text-3xl font-semibold text-gray-800">Details & Settings</h1>
        <NuxtLink to="/" class="btn-secondary">
          ← Back to Home
        </NuxtLink>
      </div>

      <!-- Tabs -->
      <div class="mb-5">
        <div class="border-b border-gray-200">
          <nav class="-mb-px flex flex-wrap gap-2 md:gap-4">
            <button
              @click="activeTab = 'job-functions'"
              :class="[
                'py-2 md:py-3 px-1 border-b-2 font-medium text-sm transition',
                activeTab === 'job-functions'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              ]"
            >
              Job Functions
            </button>
            <button
              @click="activeTab = 'shifts'"
              :class="[
                'py-2 md:py-3 px-1 border-b-2 font-medium text-sm transition',
                activeTab === 'shifts'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              ]"
            >
              Shift Management
            </button>
            <button
              @click="activeTab = 'cleanup'"
              :class="[
                'py-2 md:py-3 px-1 border-b-2 font-medium text-sm transition',
                activeTab === 'cleanup'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              ]"
            >
              Database Cleanup
            </button>
            <button
              @click="activeTab = 'target-hours'"
              :class="[
                'py-2 md:py-3 px-1 border-b-2 font-medium text-sm transition',
                activeTab === 'target-hours'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              ]"
            >
              Target Hours
            </button>
          </nav>
        </div>
      </div>

      <!-- Tab Content -->
      <div class="card">
        <!-- Job Functions Tab -->
        <div v-if="activeTab === 'job-functions'">
          <div class="p-4 md:p-5">
            <div class="flex justify-between items-center mb-4">
              <h2 class="text-xl md:text-2xl font-semibold text-gray-800">Job Functions</h2>
              <button @click="openAddJobFunctionModal" class="btn-primary">
                + Add New Job Function
              </button>
            </div>

            <!-- Loading State -->
            <div v-if="loading" class="text-center py-6">
              <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
              <p class="mt-2 text-gray-600">Loading job functions...</p>
            </div>

            <!-- Error State -->
            <div v-else-if="error" class="bg-red-50 border border-red-200 rounded-lg p-3 mb-4 text-sm">
              <p class="text-red-600">Error loading job functions: {{ error }}</p>
            </div>

            <!-- Job Functions List -->
            <div v-else class="space-y-3">
              <div 
                v-for="jobFunction in jobFunctions" 
                :key="jobFunction.id"
                class="border border-gray-200 rounded-lg p-3 md:p-4 hover:shadow-md transition"
              >
                <div class="flex items-center justify-between">
                  <div class="flex items-center space-x-3 md:space-x-4">
                    <div 
                      class="w-10 h-10 md:w-12 md:h-12 rounded border border-gray-300" 
                      :style="{ backgroundColor: jobFunction.color_code }"
                    ></div>
                    <div>
                      <h3 class="text-base md:text-lg font-semibold text-gray-800">{{ jobFunction.name }}</h3>
                      <p class="text-xs md:text-sm text-gray-600">
                        <span class="font-medium text-gray-700">Rate:</span>
                        <span v-if="jobFunction.productivity_rate !== null && jobFunction.productivity_rate !== undefined">
                          {{ jobFunction.productivity_rate }}
                        </span>
                        <span v-else>N/A</span>
                        <span v-if="getJobFunctionUnitLabel(jobFunction)" class="ml-1">
                          {{ getJobFunctionUnitLabel(jobFunction) }}
                        </span>
                      </p>
                    </div>
                  </div>
                  <div class="flex space-x-2">
                    <button 
                      @click="openEditJobFunctionModal(jobFunction)"
                      class="px-3 py-1.5 text-sm bg-blue-100 text-blue-600 rounded hover:bg-blue-200 transition"
                    >
                      Edit
                    </button>
                    <button 
                      @click="deleteJobFunctionHandler(jobFunction.id)"
                      class="px-3 py-1.5 text-sm bg-red-100 text-red-600 rounded hover:bg-red-200 transition"
                    >
                      Delete
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Shift Management Tab -->
        <div v-else-if="activeTab === 'shifts'">
          <div class="p-4 md:p-5">
            <div class="flex justify-between items-center mb-4">
              <h2 class="text-xl md:text-2xl font-semibold text-gray-800">Shift Management</h2>
              <button @click="openAddShiftModal" class="btn-primary">
                + Add New Shift
              </button>
            </div>

            <!-- Loading State -->
            <div v-if="loading" class="text-center py-6">
              <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
              <p class="mt-2 text-gray-600">Loading shifts...</p>
            </div>

            <!-- Error State -->
            <div v-else-if="error" class="bg-red-50 border border-red-200 rounded-lg p-3 mb-4 text-sm">
              <p class="text-red-600">Error loading shifts: {{ error }}</p>
            </div>

            <!-- Shifts List -->
            <div v-else class="space-y-3">
              <div 
                v-for="shift in shifts" 
                :key="shift.id"
                class="border border-gray-200 rounded-lg p-3 md:p-4 hover:shadow-md transition"
              >
                <div class="flex justify-between items-start">
                  <div class="flex-1">
                    <h3 class="text-base md:text-lg font-semibold text-gray-800 mb-2">{{ shift.name }}</h3>
                    <div class="grid grid-cols-2 md:grid-cols-3 gap-3 text-xs md:text-sm">
                      <div>
                        <span class="font-medium text-gray-700">Start Time:</span>
                        <span class="text-gray-600 ml-2">{{ shift.start_time }}</span>
                      </div>
                      <div>
                        <span class="font-medium text-gray-700">End Time:</span>
                        <span class="text-gray-600 ml-2">{{ shift.end_time }}</span>
                      </div>
                      <div v-if="shift.break_1_start">
                        <span class="font-medium text-gray-700">Break 1:</span>
                        <span class="text-gray-600 ml-2">{{ shift.break_1_start }} - {{ shift.break_1_end }}</span>
                      </div>
                      <div v-if="shift.break_2_start">
                        <span class="font-medium text-gray-700">Break 2:</span>
                        <span class="text-gray-600 ml-2">{{ shift.break_2_start }} - {{ shift.break_2_end }}</span>
                      </div>
                      <div v-if="shift.lunch_start">
                        <span class="font-medium text-gray-700">Lunch:</span>
                        <span class="text-gray-600 ml-2">{{ shift.lunch_start }} - {{ shift.lunch_end }}</span>
                      </div>
                    </div>
                  </div>
                  <div class="flex space-x-2 ml-4">
                    <button 
                      @click="openEditShiftModal(shift)"
                      class="px-3 py-1.5 text-sm bg-blue-100 text-blue-600 rounded hover:bg-blue-200 transition"
                    >
                      Edit
                    </button>
                    <button 
                      @click="deleteShiftHandler(shift.id)"
                      class="px-3 py-1.5 text-sm bg-red-100 text-red-600 rounded hover:bg-red-200 transition"
                    >
                      Delete
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Database Cleanup Tab -->
        <div v-else-if="activeTab === 'cleanup'">
          <div class="p-4 md:p-5">
            <div class="flex justify-between items-center mb-6">
              <h2 class="text-2xl font-bold text-gray-800">Database Cleanup</h2>
              <button 
                @click="refreshCleanupStats" 
                :disabled="cleanupLoading"
                class="btn-secondary disabled:opacity-50"
              >
                <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                </svg>
                Refresh Stats
              </button>
            </div>

            <!-- Cleanup Statistics -->
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 md:gap-6 mb-6">
              <div class="card">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs md:text-sm font-medium text-gray-600">Current Schedules</p>
                    <p class="text-xl md:text-2xl font-bold text-gray-900">{{ cleanupStats?.total_assignments || 0 }}</p>
                  </div>
                  <div class="bg-blue-100 rounded-full p-2.5 md:p-3">
                    <svg class="w-5 h-5 md:w-6 md:h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                    </svg>
                  </div>
                </div>
              </div>

              <div class="card">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs md:text-sm font-medium text-gray-600">Archived Schedules</p>
                    <p class="text-xl md:text-2xl font-bold text-gray-900">{{ cleanupStats?.total_archived_assignments || 0 }}</p>
                  </div>
                  <div class="bg-yellow-100 rounded-full p-2.5 md:p-3">
                    <svg class="w-5 h-5 md:w-6 md:h-6 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 8l4 4-4 4m5-4h6" />
                    </svg>
                  </div>
                </div>
              </div>

              <div class="card">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs md:text-sm font-medium text-gray-600">To Cleanup</p>
                    <p class="text-xl md:text-2xl font-bold text-red-600">{{ cleanupStats?.assignments_to_cleanup || 0 }}</p>
                  </div>
                  <div class="bg-red-100 rounded-full p-2.5 md:p-3">
                    <svg class="w-5 h-5 md:w-6 md:h-6 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                    </svg>
                  </div>
                </div>
              </div>

              <div class="card">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-xs md:text-sm font-medium text-gray-600">Date Range</p>
                    <p class="text-xs md:text-sm font-bold text-gray-900">
                      {{ formatDate(cleanupStats?.oldest_schedule_date) }} - {{ formatDate(cleanupStats?.newest_schedule_date) }}
                    </p>
                  </div>
                  <div class="bg-green-100 rounded-full p-2.5 md:p-3">
                    <svg class="w-5 h-5 md:w-6 md:h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                    </svg>
                  </div>
                </div>
              </div>
            </div>

            <!-- Cleanup Actions -->
            <div class="card mb-8">
              <h3 class="text-xl font-bold text-gray-800 mb-4">Cleanup Actions</h3>
              <div class="space-y-4">
                <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
                  <div class="flex items-center">
                    <svg class="w-5 h-5 text-yellow-600 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z" />
                    </svg>
                    <p class="text-sm text-yellow-800">
                      <strong>Retention Policy:</strong> Schedules older than 7 days are automatically archived and deleted from the main table.
                    </p>
                  </div>
                </div>

                <div class="flex space-x-4">
                  <button 
                    @click="exportToExcel" 
                    :disabled="exporting || !cleanupStats?.assignments_to_cleanup"
                    class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg text-sm font-medium transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center"
                  >
                    <svg v-if="exporting" class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" fill="none" viewBox="0 0 24 24">
                      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                    </svg>
                    <svg v-else class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                    </svg>
                    {{ exporting ? 'Exporting...' : 'Export to Excel' }}
                  </button>
                  
                  <button 
                    @click="runManualCleanup" 
                    :disabled="cleanupLoading || !cleanupStats?.assignments_to_cleanup"
                    class="btn-primary disabled:opacity-50 disabled:cursor-not-allowed flex items-center"
                  >
                    <svg v-if="cleanupLoading" class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" fill="none" viewBox="0 0 24 24">
                      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                    </svg>
                    {{ cleanupLoading ? 'Running Cleanup...' : 'Run Cleanup Now' }}
                  </button>
                </div>

                <div v-if="cleanupResult" class="bg-green-50 border border-green-200 rounded-lg p-4">
                  <h4 class="font-semibold text-green-800 mb-2">Cleanup Completed Successfully!</h4>
                  <div class="text-sm text-green-700">
                    <p>Archived {{ cleanupResult.archived_assignments }} schedule assignments</p>
                    <p>Cleanup date: {{ formatDateTime(cleanupResult.cleanup_date) }}</p>
                  </div>
                </div>

                <div v-if="cleanupError" class="bg-red-50 border border-red-200 rounded-lg p-4">
                  <h4 class="font-semibold text-red-800 mb-2">Cleanup Error</h4>
                  <p class="text-sm text-red-700">{{ cleanupError }}</p>
                </div>
              </div>
            </div>

            <!-- Cleanup Status Table -->
            <div class="card mb-8">
              <h3 class="text-xl font-bold text-gray-800 mb-4">Database Status</h3>
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
              <h3 class="text-xl font-bold text-gray-800 mb-4">Recent Cleanup Operations</h3>
              <div class="overflow-x-auto">
                <table class="min-w-full divide-y divide-gray-200">
                  <thead class="bg-gray-50">
                    <tr>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Date</th>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Assignments</th>
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

        <!-- Target Hours Tab -->
        <div v-else-if="activeTab === 'target-hours'">
          <div class="p-4 md:p-5">
            <div class="flex justify-between items-center mb-6">
              <h2 class="text-2xl font-bold text-gray-800">Target Hours</h2>
              <button 
                @click="saveTargetHours" 
                :disabled="targetHoursLoading"
                class="btn-primary disabled:opacity-50 disabled:cursor-not-allowed flex items-center"
              >
                <svg v-if="targetHoursLoading" class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                {{ targetHoursLoading ? 'Saving...' : 'Save Changes' }}
              </button>
            </div>

            <!-- Loading State -->
            <div v-if="loading" class="text-center py-8">
              <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
              <p class="mt-2 text-gray-600">Loading target hours...</p>
            </div>

            <!-- Error State -->
            <div v-else-if="error" class="bg-red-50 border border-red-200 rounded-lg p-4 mb-6">
              <p class="text-red-600">Error loading target hours: {{ error }}</p>
            </div>

            <!-- Target Hours Table -->
            <div v-else class="overflow-x-auto">
              <table class="w-full border-collapse">
                <thead>
                  <tr class="bg-gray-50">
                    <th class="border border-gray-200 px-4 py-3 text-left text-sm font-medium text-gray-700">Job Function</th>
                    <th class="border border-gray-200 px-4 py-3 text-left text-sm font-medium text-gray-700">Target Hours</th>
                    <th class="border border-gray-200 px-4 py-3 text-left text-sm font-medium text-gray-700">Description</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="jobFunction in jobFunctions" :key="jobFunction.id">
                    <td class="border border-gray-200 px-4 py-3">
                      <div class="flex items-center space-x-3">
                        <div 
                          class="w-4 h-4 rounded border border-gray-300" 
                          :style="{ backgroundColor: jobFunction.color_code }"
                        ></div>
                        <span class="font-medium text-gray-800">{{ jobFunction.name }}</span>
                      </div>
                    </td>
                    <td class="border border-gray-200 px-4 py-3">
                      <input 
                        type="number" 
                        :value="getTargetHours(jobFunction.id)" 
                        @change="updateTargetHours(jobFunction.id, $event.target.value)"
                        min="0"
                        step="0.25"
                        class="w-20 px-2 py-1 border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500"
                      />
                    </td>
                    <td class="border border-gray-200 px-4 py-3">
                      <span class="text-sm text-gray-600">
                        Daily target hours for {{ jobFunction.name.toLowerCase() }} operations
                      </span>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>

            <!-- Help Text -->
            <div class="mt-6 p-4 bg-blue-50 border border-blue-200 rounded-lg">
              <h4 class="font-semibold text-blue-800 mb-2">About Target Hours</h4>
              <p class="text-sm text-blue-700">
                Target hours represent the ideal number of hours each job function should be staffed per day. 
                These values are used to compare against actual scheduled hours in the schedule view.
              </p>
            </div>

          </div>
        </div>

      </div>
    </div>

    <!-- Notification Modal -->
    <div v-if="showNotificationModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div class="bg-white rounded-lg p-4 md:p-5 max-w-md w-full mx-4 shadow-xl">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-xl font-bold text-gray-800">{{ notificationType === 'success' ? '✅ Success' : '❌ Error' }}</h3>
          <button @click="closeNotificationModal" class="text-gray-400 hover:text-gray-600">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
        <div :class="notificationType === 'success' ? 'bg-green-50 border border-green-200 rounded-lg p-4 mb-4' : 'bg-red-50 border border-red-200 rounded-lg p-4 mb-4'">
          <p :class="notificationType === 'success' ? 'text-green-800' : 'text-red-800'" class="text-sm">{{ notificationMessage }}</p>
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

    <!-- Job Function Modal -->
    <div v-if="showJobFunctionModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div class="bg-white rounded-lg p-4 md:p-5 max-w-md w-full mx-4">
        <h3 class="text-xl font-bold mb-4">
          {{ editingJobFunction ? 'Edit Job Function' : 'Add New Job Function' }}
        </h3>
        <form @submit.prevent="handleJobFunctionSubmit" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Name</label>
            <input
              v-model="jobFunctionFormData.name"
              type="text"
              required
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Color</label>
            <input
              v-model="jobFunctionFormData.color_code"
              type="color"
              class="w-full h-10 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Productivity Rate</label>
            <input
              v-model.number="jobFunctionFormData.productivity_rate"
              type="number"
              min="0"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Unit of Measure</label>
            <select
              v-model="jobFunctionFormData.unit_of_measure"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="">Select unit</option>
              <option value="cartons/hour">Cartons/Hour</option>
              <option value="boxes/hour">Boxes/Hour</option>
              <option value="units/hour">Units/Hour</option>
              <option value="pieces/hour">Pieces/Hour</option>
              <option value="orders/hour">Orders/Hour</option>
              <option value="pallets/hour">Pallets/Hour</option>
              <option value="cases/hour">Cases/Hour</option>
              <option value="items/hour">Items/Hour</option>
              <option value="custom">Custom</option>
            </select>
          </div>
          <div v-if="jobFunctionFormData.unit_of_measure === 'custom'">
            <label class="block text-sm font-medium text-gray-700 mb-1">Custom Unit</label>
            <input
              v-model="jobFunctionFormData.custom_unit"
              type="text"
              placeholder="Enter custom unit"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <div class="flex items-center">
            <input
              v-model="jobFunctionFormData.is_active"
              type="checkbox"
              id="jobFunction_active"
              class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
            />
            <label for="jobFunction_active" class="ml-2 block text-sm text-gray-700">
              Active
            </label>
          </div>
          <div class="flex justify-end space-x-3 pt-4">
            <button
              type="button"
              @click="closeJobFunctionModal"
              class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50"
            >
              Cancel
            </button>
            <button
              type="submit"
              class="btn-primary"
            >
              {{ editingJobFunction ? 'Update' : 'Create' }}
            </button>
          </div>
        </form>
      </div>
    </div>

    <!-- Shift Modal -->
    <div v-if="showShiftModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div class="bg-white rounded-lg p-4 md:p-5 max-w-lg w-full mx-4">
        <h3 class="text-xl font-bold mb-4">
          {{ editingShift ? 'Edit Shift' : 'Add New Shift' }}
        </h3>
        <form @submit.prevent="handleShiftSubmit" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Shift Name</label>
            <input
              v-model="shiftFormData.name"
              type="text"
              required
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Start Time</label>
              <input
                v-model="shiftFormData.start_time"
                type="time"
                required
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">End Time</label>
              <input
                v-model="shiftFormData.end_time"
                type="time"
                required
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
          </div>
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Break 1 Start</label>
              <input
                v-model="shiftFormData.break_1_start"
                type="time"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Break 1 End</label>
              <input
                v-model="shiftFormData.break_1_end"
                type="time"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
          </div>
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Break 2 Start</label>
              <input
                v-model="shiftFormData.break_2_start"
                type="time"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Break 2 End</label>
              <input
                v-model="shiftFormData.break_2_end"
                type="time"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
          </div>
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Lunch Start</label>
              <input
                v-model="shiftFormData.lunch_start"
                type="time"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Lunch End</label>
              <input
                v-model="shiftFormData.lunch_end"
                type="time"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
          </div>
          <div class="flex items-center">
            <input
              v-model="shiftFormData.is_active"
              type="checkbox"
              id="shift_active"
              class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
            />
            <label for="shift_active" class="ml-2 block text-sm text-gray-700">
              Active
            </label>
          </div>
          <div class="flex justify-end space-x-3 pt-4">
            <button
              type="button"
              @click="closeShiftModal"
              class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50"
            >
              Cancel
            </button>
            <button
              type="submit"
              class="btn-primary"
            >
              {{ editingShift ? 'Update' : 'Create' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const activeTab = ref('job-functions')

// Supabase client
const supabase = useSupabaseClient()

// Composables
const { 
  jobFunctions, 
  loading: jobFunctionsLoading, 
  error: jobFunctionsError, 
  fetchJobFunctions, 
  createJobFunction, 
  updateJobFunction, 
  deleteJobFunction 
} = useJobFunctions()

const { 
  shifts, 
  loading: shiftsLoading, 
  error: shiftsError, 
  fetchShifts, 
  createShift, 
  updateShift, 
  deleteShift 
} = useSchedule()

const { 
  employees, 
  fetchEmployees: fetchEmployeesForDetails, 
  loading: employeesLoading 
} = useEmployees()


// Cleanup composables
const { 
  runCleanup, 
  getCleanupStats, 
  getCleanupLog, 
  getCleanupStatus,
  fetchOldSchedulesForExport
} = useSchedule()

// Cleanup state
const cleanupStats = ref(null)
const cleanupStatus = ref([])
const cleanupLog = ref([])
const cleanupResult = ref(null)
const cleanupError = ref('')
const cleanupLoading = ref(false)
const exporting = ref(false)

// Target hours state
const targetHours = ref({})
const targetHoursLoading = ref(false)

// Notification modal state
const showNotificationModal = ref(false)
const notificationMessage = ref('')
const notificationType = ref<'success' | 'error'>('success')

// Modal states
const showJobFunctionModal = ref(false)
const showShiftModal = ref(false)
const editingJobFunction = ref(null)
const editingShift = ref(null)

// Form data
const jobFunctionFormData = ref({
  name: '',
  color_code: '#3B82F6',
  productivity_rate: null,
  unit_of_measure: '',
  custom_unit: '',
  is_active: true,
  sort_order: 0
})

const getJobFunctionUnitLabel = (jobFunction) => {
  if (!jobFunction) return ''
  if (jobFunction.unit_of_measure === 'custom') {
    return jobFunction.custom_unit || ''
  }
  return jobFunction.unit_of_measure || ''
}

const shiftFormData = ref({
  name: '',
  start_time: '',
  end_time: '',
  break_1_start: null,
  break_1_end: null,
  break_2_start: null,
  break_2_end: null,
  lunch_start: null,
  lunch_end: null,
  is_active: true
})


// Loading and error states
const loading = computed(() => jobFunctionsLoading.value || shiftsLoading.value)
const error = computed(() => jobFunctionsError.value || shiftsError.value)

// Job Functions functions
const openAddJobFunctionModal = () => {
  editingJobFunction.value = null
  jobFunctionFormData.value = {
    name: '',
    color_code: '#3B82F6',
    productivity_rate: null,
    unit_of_measure: '',
    custom_unit: '',
    is_active: true,
    sort_order: jobFunctions.value.length
  }
  showJobFunctionModal.value = true
}

const openEditJobFunctionModal = (jobFunction) => {
  editingJobFunction.value = jobFunction
  jobFunctionFormData.value = {
    name: jobFunction.name,
    color_code: jobFunction.color_code,
    productivity_rate: jobFunction.productivity_rate,
    unit_of_measure: jobFunction.unit_of_measure || '',
    custom_unit: jobFunction.custom_unit || '',
    is_active: jobFunction.is_active,
    sort_order: jobFunction.sort_order
  }
  showJobFunctionModal.value = true
}

const closeJobFunctionModal = () => {
  showJobFunctionModal.value = false
  editingJobFunction.value = null
}

const handleJobFunctionSubmit = async () => {
  try {
    if (jobFunctionFormData.value.unit_of_measure !== 'custom') {
      jobFunctionFormData.value.custom_unit = ''
    }
    if (editingJobFunction.value) {
      await updateJobFunction(editingJobFunction.value.id, jobFunctionFormData.value)
    } else {
      await createJobFunction(jobFunctionFormData.value)
    }
    closeJobFunctionModal()
  } catch (e) {
    console.error('Error saving job function:', e)
  }
}

const deleteJobFunctionHandler = async (jobFunctionId) => {
  if (confirm('Are you sure you want to delete this job function?')) {
    await deleteJobFunction(jobFunctionId)
  }
}

// Shifts functions
const openAddShiftModal = () => {
  editingShift.value = null
  shiftFormData.value = {
    name: '',
    start_time: '',
    end_time: '',
    break_1_start: null,
    break_1_end: null,
    break_2_start: null,
    break_2_end: null,
    lunch_start: null,
    lunch_end: null,
    is_active: true
  }
  showShiftModal.value = true
}

const openEditShiftModal = (shift) => {
  editingShift.value = shift
  shiftFormData.value = {
    name: shift.name,
    start_time: shift.start_time,
    end_time: shift.end_time,
    break_1_start: shift.break_1_start,
    break_1_end: shift.break_1_end,
    break_2_start: shift.break_2_start,
    break_2_end: shift.break_2_end,
    lunch_start: shift.lunch_start,
    lunch_end: shift.lunch_end,
    is_active: shift.is_active
  }
  showShiftModal.value = true
}

const closeShiftModal = () => {
  showShiftModal.value = false
  editingShift.value = null
}

const handleShiftSubmit = async () => {
  try {
    if (editingShift.value) {
      await updateShift(editingShift.value.id, shiftFormData.value)
    } else {
      await createShift(shiftFormData.value)
    }
    closeShiftModal()
  } catch (e) {
    console.error('Error saving shift:', e)
  }
}

const deleteShiftHandler = async (shiftId) => {
  if (confirm('Are you sure you want to delete this shift?')) {
    await deleteShift(shiftId)
  }
}

// Target hours functions
const getTargetHours = (jobFunctionId) => {
  return targetHours.value[jobFunctionId] || 8.00
}

const updateTargetHours = async (jobFunctionId, hours) => {
  try {
    // Only update local state, don't save yet
    targetHours.value[jobFunctionId] = parseFloat(hours) || 0
    console.log(`Updated local target hours for job function ${jobFunctionId} to ${hours}`)
  } catch (error) {
    console.error('Error updating target hours:', error)
  }
}

const fetchTargetHours = async () => {
  try {
    targetHoursLoading.value = true
    
    // Load from database
    const { data, error } = await supabase
      .from('target_hours')
      .select('job_function_id, target_hours')
    
    if (error) throw error
    
    // Convert array to object format
    const targetHoursData = {}
    if (data) {
      data.forEach(item => {
        targetHoursData[item.job_function_id] = item.target_hours
      })
    }
    
    // Initialize with default values for any missing job functions
    jobFunctions.value.forEach(jf => {
      if (!targetHoursData[jf.id]) {
        targetHoursData[jf.id] = 8.00
      }
    })
    
    targetHours.value = targetHoursData
    console.log('Loaded target hours from database:', targetHours.value)
    
  } catch (error) {
    console.error('Error fetching target hours:', error)
    // Fallback to defaults
    const defaultTargetHours = {}
    jobFunctions.value.forEach(jf => {
      defaultTargetHours[jf.id] = 8.00
    })
    targetHours.value = defaultTargetHours
  } finally {
    targetHoursLoading.value = false
  }
}

const saveTargetHours = async () => {
  try {
    targetHoursLoading.value = true
    
    // Ensure all job functions are included in the save (even if not explicitly changed)
    // This prevents losing values for job functions that weren't touched
    const allTargetHours = { ...targetHours.value }
    
    // Add any job functions that aren't in the local state yet (use default 8.00)
    jobFunctions.value.forEach(jf => {
      if (!(jf.id in allTargetHours)) {
        allTargetHours[jf.id] = 8.00
      }
    })
    
    // Prepare data for upsert - save ALL job functions
    const upsertData = Object.entries(allTargetHours).map(([jobFunctionId, hours]) => ({
      job_function_id: jobFunctionId,
      target_hours: parseFloat(hours) || 0
    }))
    
    console.log('Saving target hours:', upsertData)
    
    // Save to database using upsert
    const { error } = await supabase
      .from('target_hours')
      .upsert(upsertData, { 
        onConflict: 'job_function_id',
        ignoreDuplicates: false 
      })
    
    if (error) throw error
    
    console.log('Saved target hours to database successfully')
    
    // Update local state with what we just saved (preserve all values)
    targetHours.value = allTargetHours
    
    // Don't refetch - we know what was saved, so keep the local state
    // This prevents any timing issues or race conditions
    
    // Show success modal
    showNotification('Target hours saved successfully!', 'success')
    
  } catch (error) {
    console.error('Error saving target hours:', error)
    showNotification('Error saving target hours. Please try again.', 'error')
  } finally {
    targetHoursLoading.value = false
  }
}

// Notification modal functions
const showNotification = (message: string, type: 'success' | 'error' = 'success') => {
  notificationMessage.value = message
  notificationType.value = type
  showNotificationModal.value = true
}

const closeNotificationModal = () => {
  showNotificationModal.value = false
}

// Cleanup functions
const refreshCleanupStats = async () => {
  try {
    cleanupLoading.value = true
    const [stats, status, log] = await Promise.all([
      getCleanupStats(),
      getCleanupStatus(),
      getCleanupLog(10)
    ])
    
    cleanupStats.value = stats
    cleanupStatus.value = status
    cleanupLog.value = log
  } catch (error) {
    console.error('Error refreshing cleanup stats:', error)
    cleanupError.value = 'Failed to refresh cleanup statistics'
  } finally {
    cleanupLoading.value = false
  }
}

const runManualCleanup = async () => {
  try {
    cleanupLoading.value = true
    cleanupError.value = ''
    cleanupResult.value = null
    
    const result = await runCleanup()
    
    if (result) {
      cleanupResult.value = result
      // Refresh stats after cleanup
      await refreshCleanupStats()
    } else {
      cleanupError.value = 'Cleanup failed - no result returned'
    }
  } catch (error) {
    console.error('Error running cleanup:', error)
    cleanupError.value = `Cleanup failed: ${error.message || 'Unknown error'}`
  } finally {
    cleanupLoading.value = false
  }
}

const formatDate = (dateString) => {
  if (!dateString) return 'N/A'
  return new Date(dateString).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric'
  })
}

const formatDateTime = (dateString) => {
  if (!dateString) return 'N/A'
  return new Date(dateString).toLocaleString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  })
}

// Export to Excel function (client-only)
const exportToExcel = async () => {
  try {
    exporting.value = true
    cleanupError.value = ''
    
    // Dynamically import xlsx only on client side
    const XLSX = await import('xlsx')
    
    // Fetch old schedules with employee, shift, and job function names
    const oldSchedules = await fetchOldSchedulesForExport()
    
    if (!oldSchedules || oldSchedules.length === 0) {
      alert('No old schedules found to export. All schedules are within the 7-day retention period.')
      return
    }
    
    // Format data for Excel (simple flat format)
    const excelData = oldSchedules.map((assignment: any) => ({
      'Date': assignment.schedule_date || '',
      'Employee Name': assignment.employee 
        ? `${assignment.employee.first_name || ''} ${assignment.employee.last_name || ''}`.trim()
        : 'Unknown',
      'Shift Name': assignment.shift?.name || 'Unknown',
      'Job Function': assignment.job_function?.name || 'Unknown',
      'Start Time': assignment.start_time || '',
      'End Time': assignment.end_time || '',
      'Created At': assignment.created_at ? new Date(assignment.created_at).toLocaleString() : ''
    }))
    
    // Create workbook and worksheet
    const ws = XLSX.utils.json_to_sheet(excelData)
    
    // Set column widths for better readability
    const colWidths = [
      { wch: 12 }, // Date
      { wch: 25 }, // Employee Name
      { wch: 20 }, // Shift Name
      { wch: 20 }, // Job Function
      { wch: 12 }, // Start Time
      { wch: 12 }, // End Time
      { wch: 20 }  // Created At
    ]
    ws['!cols'] = colWidths
    
    const wb = XLSX.utils.book_new()
    XLSX.utils.book_append_sheet(wb, ws, 'Old Schedules')
    
    // Generate filename with current date
    const today = new Date().toISOString().split('T')[0]
    const filename = `schedule_export_${today}.xlsx`
    
    // Download the file
    XLSX.writeFile(wb, filename)
    
    // Show success message
    alert(`Successfully exported ${oldSchedules.length} schedule assignments to ${filename}`)
  } catch (err: any) {
    cleanupError.value = err.message || 'Error exporting to Excel'
    alert('Failed to export to Excel. Please try again.')
    console.error('Error exporting to Excel:', err)
  } finally {
    exporting.value = false
  }
}

// Initialize data
onMounted(async () => {
  await Promise.all([
    fetchJobFunctions(false), // Get all job functions including inactive
    fetchShifts(),
    fetchEmployeesForDetails(false) // Get all employees including inactive
  ])
  
  // Load cleanup data if cleanup tab is active
  if (activeTab.value === 'cleanup') {
    await refreshCleanupStats()
  }
})

// Watch for tab changes to load cleanup data
watch(activeTab, async (newTab) => {
  if (newTab === 'cleanup') {
    await refreshCleanupStats()
  } else if (newTab === 'target-hours') {
    await fetchTargetHours()
  }
})
</script>

