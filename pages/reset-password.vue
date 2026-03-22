<template>
  <div class="min-h-screen bg-gradient-to-br from-blue-900 via-blue-800 to-indigo-900 flex items-center justify-center px-4">
    <div class="max-w-md w-full">
      <div class="text-center mb-8">
        <img src="/abbott_full_logo.png" alt="Abbott" class="mx-auto h-auto max-h-14 mb-4 object-contain" />
        <h1 class="text-3xl font-bold text-white mb-2">Operations Scheduler</h1>
        <p class="text-blue-200">Reset Your Password</p>
      </div>

      <div class="bg-white rounded-lg shadow-xl p-8">
        <!-- Step 1: Request reset (enter email) -->
        <div v-if="!hasToken" class="space-y-4">
          <h2 class="text-2xl font-bold text-gray-900 mb-2">Forgot your password?</h2>
          <p class="text-gray-600 mb-4">
            Enter your email address and we'll send you a link to reset your password.
          </p>
          <form @submit.prevent="requestReset" class="space-y-4">
            <div>
              <label for="email" class="block text-sm font-medium text-gray-700 mb-1">Email</label>
              <input
                id="email"
                v-model="email"
                type="email"
                required
                autocomplete="email"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="you@example.com"
              />
            </div>
            <p v-if="requestMessage" :class="requestSuccess ? 'text-green-600' : 'text-red-600'" class="text-sm">
              {{ requestMessage }}
            </p>
            <div class="flex gap-3">
              <button
                type="submit"
                :disabled="requesting || !email"
                class="flex-1 px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {{ requesting ? 'Sending...' : 'Send reset link' }}
              </button>
              <NuxtLink
                to="/login"
                class="px-4 py-2 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50"
              >
                Back to Login
              </NuxtLink>
            </div>
          </form>
        </div>

        <!-- Step 2: Set new password (have token from email link) -->
        <div v-else class="space-y-4">
          <h2 class="text-2xl font-bold text-gray-900 mb-2">Set new password</h2>
          <p class="text-gray-600 mb-4">
            Enter your new password below.
          </p>
          <form @submit.prevent="submitNewPassword" class="space-y-4">
            <div>
              <label for="new-password" class="block text-sm font-medium text-gray-700 mb-1">New password</label>
              <input
                id="new-password"
                v-model="newPassword"
                :type="showPassword ? 'text' : 'password'"
                required
                minlength="8"
                autocomplete="new-password"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="At least 8 characters"
              />
            </div>
            <div>
              <label for="confirm-password" class="block text-sm font-medium text-gray-700 mb-1">Confirm password</label>
              <input
                id="confirm-password"
                v-model="confirmPassword"
                :type="showPassword ? 'text' : 'password'"
                required
                autocomplete="new-password"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="Confirm your password"
              />
            </div>
            <p v-if="resetMessage" :class="resetSuccess ? 'text-green-600' : 'text-red-600'" class="text-sm">
              {{ resetMessage }}
            </p>
            <div v-if="resetSuccess" class="pt-2">
              <NuxtLink
                to="/login"
                class="inline-flex px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
              >
                Go to Login
              </NuxtLink>
            </div>
            <div v-else class="flex gap-3">
              <button
                type="submit"
                :disabled="resetting || !newPassword || !confirmPassword || newPassword !== confirmPassword || newPassword.length < 8"
                class="flex-1 px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {{ resetting ? 'Resetting...' : 'Reset password' }}
              </button>
              <NuxtLink
                to="/reset-password"
                class="px-4 py-2 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50"
              >
                Back
              </NuxtLink>
            </div>
          </form>
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

const route = useRoute()

const hasToken = computed(() => !!route.query.token)

const email = ref('')
const requesting = ref(false)
const requestMessage = ref('')
const requestSuccess = ref(false)

const newPassword = ref('')
const confirmPassword = ref('')
const showPassword = ref(false)
const resetting = ref(false)
const resetMessage = ref('')
const resetSuccess = ref(false)

const token = computed(() => (route.query.token as string) || '')

async function requestReset() {
  requesting.value = true
  requestMessage.value = ''
  try {
    await $fetch('/api/auth/forgot-password', {
      method: 'POST',
      body: { email: email.value.trim().toLowerCase() }
    })
    requestSuccess.value = true
    requestMessage.value = "If that email is registered, you'll receive a reset link shortly. Check your inbox and spam folder."
  } catch (err: any) {
    requestSuccess.value = false
    requestMessage.value = err.data?.message || err.message || 'Something went wrong. Try again later.'
  } finally {
    requesting.value = false
  }
}

async function submitNewPassword() {
  if (newPassword.value !== confirmPassword.value) {
    resetMessage.value = 'Passwords do not match'
    return
  }
  if (newPassword.value.length < 8) {
    resetMessage.value = 'Password must be at least 8 characters'
    return
  }

  resetting.value = true
  resetMessage.value = ''
  try {
    await $fetch('/api/auth/reset-password', {
      method: 'POST',
      body: { token: token.value, new_password: newPassword.value }
    })
    resetSuccess.value = true
    resetMessage.value = 'Password has been reset. You can now log in.'
  } catch (err: any) {
    resetSuccess.value = false
    resetMessage.value = err.data?.message || err.message || 'Invalid or expired link. Please request a new reset.'
  } finally {
    resetting.value = false
  }
}
</script>
