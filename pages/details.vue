<template>
  <div class="min-h-screen bg-gray-50">
    <div class="container mx-auto px-4 py-8">
      <!-- Header -->
      <div class="flex items-center justify-between mb-8">
        <h1 class="text-4xl font-bold text-gray-800">Details & Settings</h1>
        <NuxtLink to="/" class="btn-secondary">
          ← Back to Home
        </NuxtLink>
      </div>

      <!-- Tabs -->
      <div class="mb-6">
        <div class="border-b border-gray-200">
          <nav class="-mb-px flex space-x-8">
            <button
              @click="activeTab = 'job-functions'"
              :class="[
                'py-4 px-1 border-b-2 font-medium text-sm transition',
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
                'py-4 px-1 border-b-2 font-medium text-sm transition',
                activeTab === 'shifts'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              ]"
            >
              Shifts
            </button>
            <button
              @click="activeTab = 'employees'"
              :class="[
                'py-4 px-1 border-b-2 font-medium text-sm transition',
                activeTab === 'employees'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              ]"
            >
              Employees
            </button>
          </nav>
        </div>
      </div>

      <!-- Tab Content -->
      <div class="card">
        <!-- Job Functions Tab -->
        <div v-if="activeTab === 'job-functions'">
          <JobFunctionsTab />
        </div>

        <!-- Shifts Tab -->
        <div v-else-if="activeTab === 'shifts'">
          <ShiftsTab />
        </div>

        <!-- Employees Tab -->
        <div v-else-if="activeTab === 'employees'">
          <EmployeesTab />
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const activeTab = ref('job-functions')
</script>

