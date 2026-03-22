<template>
  <div class="min-h-screen bg-gradient-to-br from-blue-900 via-blue-800 to-indigo-900 flex items-center justify-center px-4">
    <div class="max-w-md w-full">
      <div class="text-center mb-8">
        <img src="/abbott_full_logo.png" alt="Abbott" class="mx-auto h-auto max-h-20 mb-4 object-contain" />
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
