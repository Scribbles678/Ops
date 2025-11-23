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
        <p class="text-blue-200">Secure Access Portal</p>
      </div>

      <!-- Auth Card -->
      <div class="bg-white rounded-lg shadow-xl p-8">
        <div class="text-center mb-6">
          <h2 class="text-2xl font-bold text-gray-900">Welcome Back</h2>
          <p class="text-sm text-gray-600 mt-1">
            Sign in to your account
          </p>
        </div>

        <form @submit.prevent="handleLogin" class="space-y-4">
          <!-- Username Field -->
          <div>
            <label for="username" class="block text-sm font-medium text-gray-700 mb-2">
              Username
            </label>
            <input
              id="username"
              v-model="username"
              type="text"
              required
              placeholder="Enter your username"
              class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              :disabled="loading"
              autocomplete="username"
            />
          </div>

          <!-- Password Field -->
          <div>
            <label for="password" class="block text-sm font-medium text-gray-700 mb-2">
              Password
            </label>
            <div class="relative">
              <input
                id="password"
                v-model="password"
                :type="showPassword ? 'text' : 'password'"
                required
                placeholder="••••••••"
                class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 pr-10"
                :disabled="loading"
                autocomplete="current-password"
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

          <!-- Error Message -->
          <div v-if="error" class="bg-red-50 border border-red-200 rounded-md p-3">
            <p class="text-sm text-red-600">{{ error }}</p>
          </div>

          <!-- Submit Button -->
          <button
            type="submit"
            :disabled="loading || !username || !password"
            class="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <svg v-if="loading" class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            {{ loading ? 'Signing in...' : 'Sign In' }}
          </button>
        </form>

        <!-- Footer -->
        <div class="mt-6 text-center">
          <p class="text-xs text-gray-500">
            Authorized personnel only. All access is logged and monitored.
          </p>
          <p class="text-xs text-gray-400 mt-2">
            Need an account or forgot your password? Contact your administrator.
          </p>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
// Prevent this page from being indexed
useHead({
  title: 'Login - Operations Scheduler',
  meta: [
    { name: 'robots', content: 'noindex, nofollow' }
  ]
})

// Redirect if already authenticated
const user = useSupabaseUser()
if (user.value) {
  await navigateTo('/')
}

const supabase = useSupabaseClient()
const router = useRouter()

// State
const username = ref('')
const password = ref('')
const showPassword = ref(false)
const loading = ref(false)
const error = ref('')

// Handle login
async function handleLogin() {
  error.value = ''

  // Validation
  if (!username.value || !password.value) {
    error.value = 'Please enter your username and password'
    return
  }

  // Validate username format (alphanumeric, dots, underscores, hyphens)
  const usernameRegex = /^[a-zA-Z0-9._-]+$/
  if (!usernameRegex.test(username.value)) {
    error.value = 'Username can only contain letters, numbers, dots, underscores, and hyphens'
    return
  }

  loading.value = true

  try {
    // Convert username to placeholder email for Supabase Auth
    // Supabase requires email field, but we use it as username
    const email = `${username.value.trim().toLowerCase()}@internal.local`
    
    const { data, error: signInError } = await supabase.auth.signInWithPassword({
      email: email,
      password: password.value
    })

    if (signInError) {
      // Provide user-friendly error messages
      if (signInError.message.includes('Invalid login credentials')) {
        error.value = 'Invalid username or password'
      } else if (signInError.message.includes('Email not confirmed')) {
        error.value = 'Account not activated. Please contact your administrator.'
      } else {
        error.value = signInError.message
      }
      return
    }

    if (data.user) {
      // Check if user has a profile (was created by admin)
      const { data: profile, error: profileError } = await supabase
        .from('user_profiles')
        .select('is_active')
        .eq('id', data.user.id)
        .single()

      if (profileError || !profile) {
        error.value = 'Account not found. Please contact your administrator.'
        await supabase.auth.signOut()
        return
      }

      if (!profile.is_active) {
        error.value = 'Account is inactive. Please contact your administrator.'
        await supabase.auth.signOut()
        return
      }

      // Redirect to home
      await router.push('/')
    }
  } catch (err: any) {
    error.value = err.message || 'An unexpected error occurred. Please try again.'
  } finally {
    loading.value = false
  }
}
</script>
