<template>
  <div class="min-h-screen bg-gray-50 py-8">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <!-- Header -->
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-gray-900">User Management</h1>
        <p class="mt-2 text-sm text-gray-600">
          Manage user accounts and team assignments. Only super admins can access this page.
        </p>
      </div>

      <!-- Super Admin Check -->
      <div v-if="!isSuperAdmin && !loading" class="bg-red-50 border border-red-200 rounded-md p-4">
        <p class="text-red-800">You do not have permission to access this page.</p>
      </div>

      <!-- Loading State -->
      <div v-if="loading" class="text-center py-12">
        <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        <p class="mt-2 text-gray-600">Loading...</p>
      </div>

      <!-- Main Content -->
      <div v-if="isSuperAdmin && !loading" class="space-y-6">
        <!-- Create User Button -->
        <div class="flex justify-between items-center">
          <div>
            <h2 class="text-xl font-semibold text-gray-900">Users</h2>
            <p class="text-sm text-gray-600">Total: {{ users.length }}</p>
          </div>
          <button
            @click="showCreateModal = true"
            class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            + Create User
          </button>
        </div>

        <!-- Users Table -->
        <div class="bg-white shadow rounded-lg overflow-hidden">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Username</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Full Name</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Team</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Role</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <tr v-for="user in users" :key="user.id">
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                  {{ getUserEmail(user) }}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {{ user.full_name || '-' }}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {{ user.teams?.name || 'No Team' }}
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span v-if="user.is_super_admin" class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-purple-100 text-purple-800">
                    Super Admin
                  </span>
                  <span v-else class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-gray-100 text-gray-800">
                    User
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span v-if="user.is_active" class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800">
                    Active
                  </span>
                  <span v-else class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-red-100 text-red-800">
                    Inactive
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                  <button
                    @click="editUser(user)"
                    class="text-blue-600 hover:text-blue-900 mr-4"
                  >
                    Edit
                  </button>
                  <button
                    @click="resetPassword(user)"
                    class="text-indigo-600 hover:text-indigo-900 mr-4"
                  >
                    Reset Password
                  </button>
                  <button
                    @click="toggleUserStatus(user)"
                    class="text-gray-600 hover:text-gray-900"
                  >
                    {{ user.is_active ? 'Deactivate' : 'Activate' }}
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- Teams Section -->
        <div class="mt-8">
          <div class="flex justify-between items-center mb-4">
            <div>
              <h2 class="text-xl font-semibold text-gray-900">Teams</h2>
              <p class="text-sm text-gray-600">Total: {{ teams.length }}</p>
            </div>
            <button
              @click="showTeamModal = true"
              class="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500"
            >
              + Create Team
            </button>
          </div>

          <div class="bg-white shadow rounded-lg overflow-hidden">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Team Name</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Users</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <tr v-for="team in teams" :key="team.id">
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                    {{ team.name }}
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {{ getUserCountForTeam(team.id) }}
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                    <button
                      @click="editTeam(team)"
                      class="text-blue-600 hover:text-blue-900 mr-4"
                    >
                      Edit
                    </button>
                    <button
                      @click="deleteTeam(team)"
                      class="text-red-600 hover:text-red-900"
                    >
                      Delete
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <!-- Create User Modal -->
      <div v-if="showCreateModal" class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50" @click.self="showCreateModal = false">
        <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
          <h3 class="text-lg font-bold text-gray-900 mb-4">Create New User</h3>
          
          <form @submit.prevent="createUser" class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Email *</label>
              <input
                v-model="newUser.email"
                type="email"
                required
                placeholder="john.doe@example.com"
                class="w-full px-3 py-2 border border-gray-300 rounded-md"
              />
            </div>
            
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Password *</label>
              <input
                v-model="newUser.password"
                type="password"
                required
                minlength="6"
                class="w-full px-3 py-2 border border-gray-300 rounded-md"
              />
            </div>
            
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Full Name</label>
              <input
                v-model="newUser.full_name"
                type="text"
                class="w-full px-3 py-2 border border-gray-300 rounded-md"
              />
            </div>
            
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Team *</label>
              <select
                v-model="newUser.team_id"
                required
                class="w-full px-3 py-2 border border-gray-300 rounded-md"
              >
                <option value="">Select a team</option>
                <option v-for="team in teams" :key="team.id" :value="team.id">
                  {{ team.name }}
                </option>
              </select>
            </div>
            
            <div>
              <label class="flex items-center">
                <input
                  v-model="newUser.is_super_admin"
                  type="checkbox"
                  class="mr-2"
                />
                <span class="text-sm text-gray-700">Super Admin</span>
              </label>
            </div>
            
            <div v-if="error" class="bg-red-50 border border-red-200 rounded-md p-3">
              <p class="text-sm text-red-600">{{ error }}</p>
            </div>
            
            <div class="flex justify-end space-x-3">
              <button
                type="button"
                @click="showCreateModal = false"
                class="px-4 py-2 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                :disabled="creating"
                class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50"
              >
                {{ creating ? 'Creating...' : 'Create User' }}
              </button>
            </div>
          </form>
        </div>
      </div>

      <!-- Edit User Modal -->
      <div v-if="showEditModal" class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50" @click.self="showEditModal = false">
        <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
          <h3 class="text-lg font-bold text-gray-900 mb-4">Edit User: {{ editingUser?.email || editingUser?.username }}</h3>
          
          <form @submit.prevent="saveUserEdit" class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Full Name</label>
              <input
                v-model="editUserData.full_name"
                type="text"
                placeholder="John Doe"
                class="w-full px-3 py-2 border border-gray-300 rounded-md"
              />
            </div>
            
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Team</label>
              <select
                v-model="editUserData.team_id"
                class="w-full px-3 py-2 border border-gray-300 rounded-md"
              >
                <option value="">No Team</option>
                <option v-for="team in teams" :key="team.id" :value="team.id">
                  {{ team.name }}
                </option>
              </select>
            </div>
            
            <div>
              <label class="flex items-center">
                <input
                  v-model="editUserData.is_super_admin"
                  type="checkbox"
                  class="mr-2"
                />
                <span class="text-sm text-gray-700">Super Admin</span>
              </label>
            </div>
            
            <div>
              <label class="flex items-center">
                <input
                  v-model="editUserData.is_active"
                  type="checkbox"
                  class="mr-2"
                />
                <span class="text-sm text-gray-700">Active</span>
              </label>
            </div>
            
            <div v-if="error" class="bg-red-50 border border-red-200 rounded-md p-3">
              <p class="text-sm text-red-600">{{ error }}</p>
            </div>
            
            <div class="flex justify-end space-x-3">
              <button
                type="button"
                @click="showEditModal = false; editingUser = null"
                class="px-4 py-2 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
              >
                Save Changes
              </button>
            </div>
          </form>
        </div>
      </div>

      <!-- Create Team Modal -->
      <div v-if="showTeamModal" class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50" @click.self="showTeamModal = false">
        <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
          <h3 class="text-lg font-bold text-gray-900 mb-4">Create New Team</h3>
          
          <form @submit.prevent="createTeam" class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Team Name *</label>
              <input
                v-model="newTeam.name"
                type="text"
                required
                placeholder="Department 1"
                class="w-full px-3 py-2 border border-gray-300 rounded-md"
              />
            </div>
            
            <div v-if="error" class="bg-red-50 border border-red-200 rounded-md p-3">
              <p class="text-sm text-red-600">{{ error }}</p>
            </div>
            
            <div class="flex justify-end space-x-3">
              <button
                type="button"
                @click="showTeamModal = false"
                class="px-4 py-2 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                :disabled="creatingTeam"
                class="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 disabled:opacity-50"
              >
                {{ creatingTeam ? 'Creating...' : 'Create Team' }}
              </button>
            </div>
          </form>
        </div>
      </div>

      <!-- Reset Password Modal -->
      <div v-if="showResetPasswordModal" class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50" @click.self="showResetPasswordModal = false">
        <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
          <h3 class="text-lg font-bold text-gray-900 mb-4">Reset Password for {{ resetPasswordUser?.username }}</h3>
          
          <form @submit.prevent="handleResetPassword" class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">New Password *</label>
              <input
                v-model="resetPasswordData.password"
                type="password"
                required
                minlength="6"
                class="w-full px-3 py-2 border border-gray-300 rounded-md"
              />
            </div>
            
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Confirm Password *</label>
              <input
                v-model="resetPasswordData.confirmPassword"
                type="password"
                required
                minlength="6"
                class="w-full px-3 py-2 border border-gray-300 rounded-md"
              />
            </div>
            
            <div v-if="error" class="bg-red-50 border border-red-200 rounded-md p-3">
              <p class="text-sm text-red-600">{{ error }}</p>
            </div>
            
            <div v-if="resetPasswordSuccess" class="bg-green-50 border border-green-200 rounded-md p-3">
              <p class="text-sm text-green-600">Password updated successfully!</p>
            </div>
            
            <div class="flex justify-end space-x-3">
              <button
                type="button"
                @click="showResetPasswordModal = false"
                class="px-4 py-2 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                :disabled="resettingPassword"
                class="px-4 py-2 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 disabled:opacity-50"
              >
                {{ resettingPassword ? 'Resetting...' : 'Reset Password' }}
              </button>
            </div>
          </form>
        </div>
      </div>

      <!-- Reset Password Modal -->
      <div v-if="showResetPasswordModal" class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50" @click.self="showResetPasswordModal = false">
        <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
          <h3 class="text-lg font-bold text-gray-900 mb-4">Reset Password for {{ userToReset?.username }}</h3>
          
          <form @submit.prevent="confirmResetPassword" class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">New Password *</label>
              <input
                v-model="newPassword"
                type="password"
                required
                minlength="6"
                placeholder="Enter new password"
                class="w-full px-3 py-2 border border-gray-300 rounded-md"
              />
            </div>
            
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Confirm Password *</label>
              <input
                v-model="confirmNewPassword"
                type="password"
                required
                minlength="6"
                placeholder="Confirm new password"
                class="w-full px-3 py-2 border border-gray-300 rounded-md"
              />
            </div>
            
            <div v-if="error" class="bg-red-50 border border-red-200 rounded-md p-3">
              <p class="text-sm text-red-600">{{ error }}</p>
            </div>
            
            <div v-if="resetSuccess" class="bg-green-50 border border-green-200 rounded-md p-3">
              <p class="text-sm text-green-600">Password reset successfully!</p>
            </div>
            
            <div class="flex justify-end space-x-3">
              <button
                type="button"
                @click="showResetPasswordModal = false; error = ''; resetSuccess = false"
                class="px-4 py-2 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                :disabled="resettingPassword || newPassword !== confirmNewPassword"
                class="px-4 py-2 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 disabled:opacity-50"
              >
                {{ resettingPassword ? 'Resetting...' : 'Reset Password' }}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({
  middleware: 'auth'
})

const supabase = useSupabaseClient()
const { isSuperAdmin, checkIsSuperAdmin, fetchAllTeams, createTeam: createTeamFn, updateTeam: updateTeamFn, deleteTeam: deleteTeamFn } = useTeam()

const users = ref<any[]>([])
const teams = ref<any[]>([])
const loading = ref(true)
const error = ref('')

const showCreateModal = ref(false)
const showTeamModal = ref(false)
const showEditModal = ref(false)
const showResetPasswordModal = ref(false)
const creating = ref(false)
const creatingTeam = ref(false)
const resettingPassword = ref(false)
const resetSuccess = ref(false)
const userToReset = ref<any>(null)
const editingUser = ref<any>(null)
const newPassword = ref('')
const confirmNewPassword = ref('')
const editUserData = ref({
  full_name: '',
  team_id: '',
  is_super_admin: false,
  is_active: true
})

const newUser = ref({
  email: '',
  password: '',
  full_name: '',
  team_id: '',
  is_super_admin: false
})

const newTeam = ref({
  name: ''
})

// Fetch data
const fetchUsers = async () => {
  if (!isSuperAdmin.value) return
  
  const { data, error: err } = await supabase
    .from('user_profiles')
    .select('*, teams(*)')
    .order('username')
  
  if (err) {
    error.value = err.message
    return
  }
  
  users.value = data || []
}

const fetchTeams = async () => {
  if (!isSuperAdmin.value) return
  
  const teamsData = await fetchAllTeams()
  teams.value = teamsData || []
}

const getUserCountForTeam = (teamId: string) => {
  return users.value.filter(u => u.team_id === teamId).length
}

// Create user
const createUser = async () => {
  creating.value = true
  error.value = ''
  
  try {
    // Get current session token
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) {
      error.value = 'Not authenticated'
      return
    }
    
    // Call server route to create user (uses service role key)
    const response = await $fetch('/api/admin/users/create', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${session.access_token}`
      },
      body: {
        email: newUser.value.email.trim().toLowerCase(),
        password: newUser.value.password,
        full_name: newUser.value.full_name || null,
        team_id: newUser.value.team_id || null,
        is_super_admin: newUser.value.is_super_admin || false
      }
    })
    
    // Reset form and close modal
    newUser.value = {
      email: '',
      password: '',
      full_name: '',
      team_id: '',
      is_super_admin: false
    }
    showCreateModal.value = false
    await fetchUsers()
  } catch (err: any) {
    error.value = err.data?.message || err.message || 'Failed to create user'
  } finally {
    creating.value = false
  }
}

// Create team
const createTeam = async () => {
  creatingTeam.value = true
  error.value = ''
  
  try {
    await createTeamFn(newTeam.value.name)
    newTeam.value.name = ''
    showTeamModal.value = false
    await fetchTeams()
  } catch (err: any) {
    error.value = err.message || 'Failed to create team'
  } finally {
    creatingTeam.value = false
  }
}

// Reset user password
const resetPassword = (user: any) => {
  resetPasswordUser.value = user
  resetPasswordData.value = {
    password: '',
    confirmPassword: ''
  }
  resetPasswordSuccess.value = false
  error.value = ''
  showResetPasswordModal.value = true
}

const handleResetPassword = async () => {
  error.value = ''
  resetPasswordSuccess.value = false
  
  if (resetPasswordData.value.password !== resetPasswordData.value.confirmPassword) {
    error.value = 'Passwords do not match'
    return
  }
  
  if (resetPasswordData.value.password.length < 6) {
    error.value = 'Password must be at least 6 characters'
    return
  }
  
  resettingPassword.value = true
  
  try {
    // Get current session token
    const { data: { session } } = await supabase.auth.getSession()
    if (!session) {
      error.value = 'Not authenticated'
      return
    }
    
    // Call server route to reset password (uses service role key)
    const response = await $fetch('/api/admin/users/reset-password', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${session.access_token}`
      },
      body: {
        user_id: resetPasswordUser.value.id,
        new_password: resetPasswordData.value.password
      }
    })
    
    resetPasswordSuccess.value = true
    
    // Close modal after 2 seconds
    setTimeout(() => {
      showResetPasswordModal.value = false
      resetPasswordUser.value = null
      resetPasswordData.value = {
        password: '',
        confirmPassword: ''
      }
    }, 2000)
  } catch (err: any) {
    error.value = err.data?.message || err.message || 'Failed to reset password'
  } finally {
    resettingPassword.value = false
  }
}

// Edit user
const editUser = (user: any) => {
  editingUser.value = user
  editUserData.value = {
    full_name: user.full_name || '',
    team_id: user.team_id || '',
    is_super_admin: user.is_super_admin || false,
    is_active: user.is_active !== false
  }
  showEditModal.value = true
}

const saveUserEdit = async () => {
  if (!editingUser.value) return
  
  try {
    const { error: err } = await supabase
      .from('user_profiles')
      .update({
        full_name: editUserData.value.full_name || null,
        team_id: editUserData.value.team_id || null,
        is_super_admin: editUserData.value.is_super_admin,
        is_active: editUserData.value.is_active
      })
      .eq('id', editingUser.value.id)
    
    if (err) {
      error.value = err.message
      return
    }
    
    showEditModal.value = false
    editingUser.value = null
    await fetchUsers()
  } catch (err: any) {
    error.value = err.message || 'Failed to update user'
  }
}

// Toggle user status
const toggleUserStatus = async (user: any) => {
  if (!confirm(`Are you sure you want to ${user.is_active ? 'deactivate' : 'activate'} this user?`)) {
    return
  }
  
  const { error: err } = await supabase
    .from('user_profiles')
    .update({ is_active: !user.is_active })
    .eq('id', user.id)
  
  if (err) {
    error.value = err.message
    return
  }
  
  await fetchUsers()
}

// Edit team
const editTeam = (team: any) => {
  // TODO: Implement edit team modal
  alert('Edit team functionality coming soon')
}

// Delete team
const deleteTeam = async (team: any) => {
  if (!confirm(`Are you sure you want to delete "${team.name}"? This will affect all users in this team.`)) {
    return
  }
  
  try {
    await deleteTeamFn(team.id)
    await fetchTeams()
    await fetchUsers()
  } catch (err: any) {
    error.value = err.message || 'Failed to delete team'
  }
}

// Get user email (from profile or construct from username for legacy users)
const getUserEmail = (user: any) => {
  // Use stored email if available, otherwise construct from username (legacy)
  return user.email || `${user.username}@internal.local`
}

// Initialize
onMounted(async () => {
  await checkIsSuperAdmin()
  if (isSuperAdmin.value) {
    await Promise.all([fetchUsers(), fetchTeams()])
  }
  loading.value = false
})
</script>

