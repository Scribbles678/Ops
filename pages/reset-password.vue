<template>
  <div class="min-h-screen bg-gradient-to-br from-blue-900 via-blue-800 to-indigo-900 flex items-center justify-center px-4">
    <div class="max-w-md w-full">
      <!-- Logo/Title Section -->
      <div class="text-center mb-8">
        <div class="mx-auto h-16 w-16 bg-white rounded-full flex items-center justify-center mb-4">
          <svg class="h-8 w-8 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01" />
          </svg>
        </div>
        <h1 class="text-3xl font-bold text-white mb-2">Operations Scheduler</h1>
        <p class="text-blue-200">Reset Your Password</p>
      </div>

      <!-- Reset Card -->
      <div class="bg-white rounded-lg shadow-xl p-8">
        <div v-if="!success" class="space-y-4">
          <div class="text-center mb-6">
            <h2 class="text-2xl font-bold text-gray-900">Set New Password</h2>
            <p class="text-sm text-gray-600 mt-1">
              Enter your new password below
            </p>
          </div>

          <form @submit.prevent="handleReset" class="space-y-4">
            <!-- New Password Field -->
            <div>
              <label for="password" class="block text-sm font-medium text-gray-700 mb-2">
                New Password
              </label>
              <div class="relative">
                <input
                  id="password"
                  v-model="password"
                  :type="showPassword ? 'text' : 'password'"
                  required
                  minlength="6"
                  placeholder="••••••••"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 pr-10"
                  :disabled="loading"
                  autocomplete="new-password"
                />
                <button
                  type="button"
                  @click="showPassword = !showPassword"
                  class="absolute inset-y-0 right-0 pr-3 flex items-center text-gray-400 hover:text-gray-600"
                  :disabled="loading"
                >
                  <svg v-if="showPassword" class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />
                  </svg>
                  <svg v-else class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                  </svg>
                </button>
              </div>
            </div>

            <!-- Confirm Password Field -->
            <div>
              <label for="confirmPassword" class="block text-sm font-medium text-gray-700 mb-2">
                Confirm Password
              </label>
              <input
                id="confirmPassword"
                v-model="confirmPassword"
                :type="showPassword ? 'text' : 'password'"
                required
                minlength="6"
                placeholder="••••••••"
                class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                :disabled="loading"
                autocomplete="new-password"
              />
            </div>

            <!-- Error Message -->
            <div v-if="error" class="bg-red-50 border border-red-200 rounded-md p-3">
              <p class="text-sm text-red-600">{{ error }}</p>
            </div>

            <!-- Submit Button -->
            <button
              type="submit"
              :disabled="loading || !password || !confirmPassword || password !== confirmPassword"
              class="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <svg v-if="loading" class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              {{ loading ? 'Resetting...' : 'Reset Password' }}
            </button>
          </form>
        </div>

        <!-- Success Message -->
        <div v-else class="text-center">
          <div class="mb-4">
            <svg class="mx-auto h-12 w-12 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </div>
          <h2 class="text-2xl font-bold text-gray-900 mb-2">Password Reset Successful!</h2>
          <p class="text-gray-600 mb-6">Your password has been updated. You can now log in with your new password.</p>
          <NuxtLink
            to="/login"
            class="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700"
          >
            Go to Login
          </NuxtLink>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
useHead({
  title: 'Reset Password - Operations Scheduler',
  meta: [
    { name: 'robots', content: 'noindex, nofollow' }
  ]
})

const supabase = useSupabaseClient()
const route = useRoute()
const router = useRouter()

// State
const password = ref('')
const confirmPassword = ref('')
const showPassword = ref(false)
const loading = ref(false)
const error = ref('')
const success = ref(false)

// Check for reset token on mount
onMounted(() => {
  if (process.client) {
    // Check URL hash for token
    if (window.location.hash) {
      const hashParams = new URLSearchParams(window.location.hash.substring(1))
      const type = hashParams.get('type')
      const accessToken = hashParams.get('access_token')
      
      if (type === 'recovery' && accessToken) {
        // Token is present, user can proceed
        return
      }
    }
    
    // Check URL query params (some Supabase configs use query params)
    const queryParams = new URLSearchParams(window.location.search)
    if (queryParams.get('token') || queryParams.get('access_token')) {
      // Token in query params
      return
    }
    
    // No token found
    error.value = 'No reset token found. Please use the link from your email.'
  }
})

// Handle password reset
async function handleReset() {
  error.value = ''

  // Validation
  if (!password.value || !confirmPassword.value) {
    error.value = 'Please fill in all fields'
    return
  }

  if (password.value.length < 6) {
    error.value = 'Password must be at least 6 characters'
    return
  }

  if (password.value !== confirmPassword.value) {
    error.value = 'Passwords do not match'
    return
  }

  loading.value = true

  try {
    if (!process.client) {
      error.value = 'This must be done in the browser'
      return
    }

    // Check URL hash first (Supabase default)
    let accessToken: string | null = null
    let type: string | null = null

    if (window.location.hash) {
      const hashParams = new URLSearchParams(window.location.hash.substring(1))
      accessToken = hashParams.get('access_token')
      type = hashParams.get('type')
    }

    // If not in hash, check query params
    if (!accessToken) {
      const queryParams = new URLSearchParams(window.location.search)
      accessToken = queryParams.get('access_token') || queryParams.get('token')
      type = queryParams.get('type') || 'recovery'
    }

    if (!accessToken || type !== 'recovery') {
      error.value = 'Invalid or expired reset link. Please request a new password reset.'
      return
    }

    // For password reset, we need to set the session first
    // Supabase recovery tokens work by setting a temporary session
    const { data: sessionData, error: sessionError } = await supabase.auth.setSession({
      access_token: accessToken,
      refresh_token: '' // Recovery tokens don't include refresh tokens
    })

    if (sessionError) {
      // If setSession fails, the token might be expired or invalid
      error.value = sessionError.message || 'Invalid or expired reset link. Please request a new password reset.'
      return
    }

    // Verify we have a session before updating password
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) {
      error.value = 'Failed to establish session. Please request a new password reset.'
      return
    }

    // Now update the password (user is authenticated via the session)
    const { error: updateError } = await supabase.auth.updateUser({
      password: password.value
    })

    if (updateError) {
      error.value = updateError.message || 'Failed to update password. The reset link may have expired.'
      return
    }

    // Success! Sign out the temporary session
    await supabase.auth.signOut()

    // Success!
    success.value = true
    
    // Clear the hash/query params from URL
    if (process.client) {
      window.history.replaceState(null, '', window.location.pathname)
    }
  } catch (err: any) {
    error.value = err.message || 'An unexpected error occurred'
  } finally {
    loading.value = false
  }
}
</script>

