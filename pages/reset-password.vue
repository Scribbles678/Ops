<template>
  <div class="min-h-screen bg-gradient-to-br from-blue-900 via-blue-800 to-indigo-900 flex items-center justify-center px-4">
    <div class="max-w-md w-full">
      <div class="text-center mb-8">
        <div class="mx-auto h-16 w-16 bg-white rounded-full flex items-center justify-center mb-4">
          <svg class="h-8 w-8 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h.01M9 16h.01" />
          </svg>
        </div>
        <h1 class="text-3xl font-bold text-white mb-2">Operations Scheduler</h1>
        <p class="text-blue-200">Reset Your Password</p>
      </div>

      <div class="bg-white rounded-lg shadow-xl p-8">
        <div class="text-center">
          <h2 class="text-2xl font-bold text-gray-900 mb-2">Password Reset</h2>
          <p class="text-gray-600 mb-6">
            To reset your password, please contact your administrator. They can set a new password for your account from the Settings or Admin Users page.
          </p>
          <NuxtLink
            to="/login"
            class="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700"
          >
            Back to Login
          </NuxtLink>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
useHead({
  title: 'Reset Password - Operations Scheduler',
  meta: [{ name: 'robots', content: 'noindex, nofollow' }]
})
</script>
