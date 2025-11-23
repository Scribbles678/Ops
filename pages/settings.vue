<template>
  <div class="min-h-screen bg-gray-50 py-8">
    <div class="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8">
      <!-- Header -->
      <div class="mb-8">
        <NuxtLink to="/" class="text-blue-600 hover:text-blue-800 mb-4 inline-block">
          ← Back to Home
        </NuxtLink>
        <h1 class="text-3xl font-bold text-gray-900">Account Settings</h1>
        <p class="mt-2 text-sm text-gray-600">
          Manage your account settings and password
        </p>
      </div>

      <!-- Change Password Section -->
      <div class="bg-white shadow rounded-lg p-6 mb-6">
        <h2 class="text-xl font-semibold text-gray-900 mb-4">Change Password</h2>
        
        <form @submit.prevent="handleChangePassword" class="space-y-4">
          <!-- Current Password -->
          <div>
            <label for="currentPassword" class="block text-sm font-medium text-gray-700 mb-2">
              Current Password
            </label>
            <input
              id="currentPassword"
              v-model="currentPassword"
              type="password"
              required
              class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              :disabled="loading"
            />
          </div>

          <!-- New Password -->
          <div>
            <label for="newPassword" class="block text-sm font-medium text-gray-700 mb-2">
              New Password
            </label>
            <input
              id="newPassword"
              v-model="newPassword"
              type="password"
              required
              minlength="6"
              class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              :disabled="loading"
            />
            <p class="mt-1 text-xs text-gray-500">Must be at least 6 characters</p>
          </div>

          <!-- Confirm New Password -->
          <div>
            <label for="confirmPassword" class="block text-sm font-medium text-gray-700 mb-2">
              Confirm New Password
            </label>
            <input
              id="confirmPassword"
              v-model="confirmPassword"
              type="password"
              required
              minlength="6"
              class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              :disabled="loading"
            />
          </div>

          <!-- Error Message -->
          <div v-if="error" class="bg-red-50 border border-red-200 rounded-md p-3">
            <p class="text-sm text-red-600">{{ error }}</p>
          </div>

          <!-- Success Message -->
          <div v-if="success" class="bg-green-50 border border-green-200 rounded-md p-3">
            <p class="text-sm text-green-600">{{ success }}</p>
          </div>

          <!-- Submit Button -->
          <button
            type="submit"
            :disabled="loading || !currentPassword || !newPassword || !confirmPassword || newPassword !== confirmPassword"
            class="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <svg v-if="loading" class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            {{ loading ? 'Changing Password...' : 'Change Password' }}
          </button>
        </form>
      </div>

      <!-- User Info Section -->
      <div class="bg-white shadow rounded-lg p-6">
        <h2 class="text-xl font-semibold text-gray-900 mb-4">Account Information</h2>
        <dl class="space-y-4">
          <div>
            <dt class="text-sm font-medium text-gray-500">Email</dt>
            <dd class="mt-1 text-sm text-gray-900">{{ user?.email || userProfile?.email || 'Loading...' }}</dd>
          </div>
          <div>
            <dt class="text-sm font-medium text-gray-500">Username</dt>
            <dd class="mt-1 text-sm text-gray-900">{{ userProfile?.username || 'N/A' }}</dd>
          </div>
          <div v-if="userProfile?.full_name">
            <dt class="text-sm font-medium text-gray-500">Full Name</dt>
            <dd class="mt-1 text-sm text-gray-900">{{ userProfile.full_name }}</dd>
          </div>
          <div>
            <dt class="text-sm font-medium text-gray-500">Team</dt>
            <dd class="mt-1 text-sm text-gray-900">{{ userProfile?.teams?.name || 'No Team' }}</dd>
          </div>
          <div>
            <dt class="text-sm font-medium text-gray-500">Role</dt>
            <dd class="mt-1">
              <span v-if="userProfile?.is_super_admin" class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-purple-100 text-purple-800">
                Super Admin
              </span>
              <span v-else class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-gray-100 text-gray-800">
                User
              </span>
            </dd>
          </div>
        </dl>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
// Page is protected by auth.global.ts middleware

const supabase = useSupabaseClient()
const user = useSupabaseUser()

const currentPassword = ref('')
const newPassword = ref('')
const confirmPassword = ref('')
const loading = ref(false)
const error = ref('')
const success = ref('')
const userProfile = ref<any>(null)

// Fetch user profile
const fetchUserProfile = async () => {
  if (!user.value) {
    console.log('No user found, waiting...')
    return
  }

  try {
    const { data, error: err } = await supabase
      .from('user_profiles')
      .select('*, teams(*)')
      .eq('id', user.value.id)
      .maybeSingle() // Use maybeSingle to avoid errors if profile doesn't exist

    if (err) {
      console.error('Error fetching profile:', err)
      error.value = `Failed to load profile: ${err.message}`
      return
    }

    if (!data) {
      console.warn('No profile found for user')
      error.value = 'Profile not found. Please contact your administrator.'
      return
    }

    userProfile.value = data
  } catch (err: any) {
    console.error('Unexpected error fetching profile:', err)
    error.value = 'Failed to load profile information'
  }
}

// Handle password change
const handleChangePassword = async () => {
  error.value = ''
  success.value = ''

  // Validation
  if (!currentPassword.value || !newPassword.value || !confirmPassword.value) {
    error.value = 'Please fill in all fields'
    return
  }

  if (newPassword.value.length < 6) {
    error.value = 'New password must be at least 6 characters'
    return
  }

  if (newPassword.value !== confirmPassword.value) {
    error.value = 'New passwords do not match'
    return
  }

  if (currentPassword.value === newPassword.value) {
    error.value = 'New password must be different from current password'
    return
  }

  loading.value = true

  try {
    // First, verify current password by trying to sign in
    // Use the actual email from auth user
    const email = user.value?.email
    if (!email) {
      error.value = 'Unable to determine email address'
      return
    }

    // Verify current password
    const { error: signInError } = await supabase.auth.signInWithPassword({
      email: email,
      password: currentPassword.value
    })

    if (signInError) {
      error.value = 'Current password is incorrect'
      return
    }

    // Update password
    const { error: updateError } = await supabase.auth.updateUser({
      password: newPassword.value
    })

    if (updateError) {
      error.value = updateError.message || 'Failed to update password'
      return
    }

    // Success!
    success.value = 'Password changed successfully!'
    currentPassword.value = ''
    newPassword.value = ''
    confirmPassword.value = ''

    // Clear success message after 3 seconds
    setTimeout(() => {
      success.value = ''
    }, 3000)
  } catch (err: any) {
    error.value = err.message || 'An unexpected error occurred'
  } finally {
    loading.value = false
  }
}

// Fetch profile on mount
onMounted(async () => {
  // Wait for user to be available
  if (!user.value) {
    // Wait a bit for auth to initialize
    await new Promise(resolve => setTimeout(resolve, 500))
  }
  
  await fetchUserProfile()
})

// Also watch for user changes
watch(user, async (newUser) => {
  if (newUser) {
    await fetchUserProfile()
  }
}, { immediate: true })
</script>

