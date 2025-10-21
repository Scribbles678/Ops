<template>
  <div class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100">
    <div class="container mx-auto px-4 py-8">
      <!-- Header -->
      <div class="text-center mb-12">
        <h1 class="text-5xl font-bold text-gray-800 mb-3">
          Operations Scheduling Tool
        </h1>
        <p class="text-xl text-gray-600">
          Distribution Center Schedule Management
        </p>
      </div>

      <!-- Main Menu Buttons -->
      <div class="max-w-4xl mx-auto grid grid-cols-1 md:grid-cols-2 gap-6">
        <!-- Update Training Button -->
        <NuxtLink
          to="/training"
          class="card hover:shadow-xl transition-all transform hover:scale-105 cursor-pointer"
        >
          <div class="flex flex-col items-center justify-center py-8">
            <div class="bg-blue-100 rounded-full p-6 mb-4">
              <svg class="w-16 h-16 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
              </svg>
            </div>
            <h2 class="text-2xl font-bold text-gray-800 mb-2">Update Training</h2>
            <p class="text-gray-600 text-center">
              Manage employee job function training
            </p>
          </div>
        </NuxtLink>

        <!-- Details Button -->
        <NuxtLink
          to="/details"
          class="card hover:shadow-xl transition-all transform hover:scale-105 cursor-pointer"
        >
          <div class="flex flex-col items-center justify-center py-8">
            <div class="bg-purple-100 rounded-full p-6 mb-4">
              <svg class="w-16 h-16 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
              </svg>
            </div>
            <h2 class="text-2xl font-bold text-gray-800 mb-2">Details</h2>
            <p class="text-gray-600 text-center">
              Configure job functions, shifts, and employees
            </p>
          </div>
        </NuxtLink>

        <!-- Edit Today's Schedule Button -->
        <NuxtLink
          :to="`/schedule/${today}`"
          class="card hover:shadow-xl transition-all transform hover:scale-105 cursor-pointer"
        >
          <div class="flex flex-col items-center justify-center py-8">
            <div class="bg-green-100 rounded-full p-6 mb-4">
              <svg class="w-16 h-16 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
              </svg>
            </div>
            <h2 class="text-2xl font-bold text-gray-800 mb-2">Edit Today's Schedule</h2>
            <p class="text-gray-600 text-center">
              Modify the current day's assignments
            </p>
          </div>
        </NuxtLink>

        <!-- Make Tomorrow's Schedule Button -->
        <NuxtLink
          to="/schedule/tomorrow"
          class="card hover:shadow-xl transition-all transform hover:scale-105 cursor-pointer"
        >
          <div class="flex flex-col items-center justify-center py-8">
            <div class="bg-orange-100 rounded-full p-6 mb-4">
              <svg class="w-16 h-16 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
              </svg>
            </div>
            <h2 class="text-2xl font-bold text-gray-800 mb-2">Make Tomorrow's Schedule</h2>
            <p class="text-gray-600 text-center">
              Create next day's schedule from scratch or copy
            </p>
          </div>
        </NuxtLink>
      </div>

      <!-- Display Mode Link -->
      <div class="text-center mt-12">
        <NuxtLink
          to="/display"
          class="inline-flex items-center px-6 py-3 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition"
        >
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
          </svg>
          Open Display Mode (TV View)
        </NuxtLink>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const today = computed(() => {
  const date = new Date()
  return date.toISOString().split('T')[0]
})
</script>

