<template>
  <div class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex flex-col">
    <div class="container mx-auto px-4 py-4 flex-1 flex flex-col max-h-screen overflow-y-auto">
      <!-- Header -->
      <div class="text-center mb-4 relative flex-shrink-0">
        <!-- Logout Button -->
        <div class="absolute top-0 right-0">
          <button
            @click="handleLogout"
            class="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-lg text-sm font-medium transition-colors flex items-center"
          >
            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
            </svg>
            Logout
          </button>
        </div>
        
        <h1 class="text-3xl md:text-4xl font-bold text-gray-800 mb-2">
          Operations Scheduling Tool
        </h1>
        <p class="text-base md:text-lg text-gray-600">
          Distribution Center Schedule Management
        </p>
      </div>

      <!-- Main Menu Buttons -->
      <div class="max-w-4xl mx-auto grid grid-cols-1 md:grid-cols-2 gap-3 md:gap-4 flex-1">
        <!-- Update Training Button -->
        <NuxtLink
          to="/training"
          class="card hover:shadow-xl transition-all transform hover:scale-105 cursor-pointer"
        >
          <div class="flex flex-col items-center justify-center py-4 md:py-6">
            <div class="bg-blue-100 rounded-full p-4 md:p-5 mb-3">
              <svg class="w-12 h-12 md:w-14 md:h-14 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
              </svg>
            </div>
            <h2 class="text-xl md:text-2xl font-bold text-gray-800 mb-1">Employees & Training Matrix</h2>
            <p class="text-sm md:text-base text-gray-600 text-center">
              Manage employees, shifts, and job function training
            </p>
          </div>
        </NuxtLink>

        <!-- Details Button -->
        <NuxtLink
          to="/details"
          class="card hover:shadow-xl transition-all transform hover:scale-105 cursor-pointer"
        >
          <div class="flex flex-col items-center justify-center py-4 md:py-6">
            <div class="bg-purple-100 rounded-full p-4 md:p-5 mb-3">
              <svg class="w-12 h-12 md:w-14 md:h-14 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
              </svg>
            </div>
            <h2 class="text-xl md:text-2xl font-bold text-gray-800 mb-1">Details</h2>
            <p class="text-sm md:text-base text-gray-600 text-center">
              Configure job functions, shifts, and employees
            </p>
          </div>
        </NuxtLink>

        <!-- View/Edit Schedule Button -->
        <NuxtLink
          :to="`/schedule/${today}`"
          class="card hover:shadow-xl transition-all transform hover:scale-105 cursor-pointer"
        >
          <div class="flex flex-col items-center justify-center py-4 md:py-6">
            <div class="bg-green-100 rounded-full p-4 md:p-5 mb-3">
              <svg class="w-12 h-12 md:w-14 md:h-14 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01" />
              </svg>
            </div>
            <h2 class="text-xl md:text-2xl font-bold text-gray-800 mb-1">View/Edit Schedule</h2>
            <p class="text-sm md:text-base text-gray-600 text-center">
              View and edit any schedule (today's, yesterday's, or archived)
            </p>
          </div>
        </NuxtLink>

        <!-- Make Tomorrow's Schedule Button -->
        <NuxtLink
          to="/schedule/tomorrow"
          class="card hover:shadow-xl transition-all transform hover:scale-105 cursor-pointer"
        >
          <div class="flex flex-col items-center justify-center py-4 md:py-6">
            <div class="bg-orange-100 rounded-full p-4 md:p-5 mb-3">
              <svg class="w-12 h-12 md:w-14 md:h-14 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
              </svg>
            </div>
            <h2 class="text-xl md:text-2xl font-bold text-gray-800 mb-1">Create Schedule</h2>
            <p class="text-sm md:text-base text-gray-600 text-center">
              Create next day's schedule from scratch or copy
            </p>
          </div>
        </NuxtLink>
      </div>

      <!-- Display Mode Link -->
      <div class="text-center mt-4 md:mt-6 flex-shrink-0">
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
const { logout } = useAuth()

const today = computed(() => {
  const date = new Date()
  return date.toISOString().split('T')[0]
})

const handleLogout = async () => {
  if (confirm('Are you sure you want to logout?')) {
    await logout()
  }
}
</script>

