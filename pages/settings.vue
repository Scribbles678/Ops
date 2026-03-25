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
      <div class="bg-white shadow rounded-lg p-6 mb-6">
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
            <dd class="mt-1 flex items-center gap-2">
              <span v-if="userProfile?.teams?.name" class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-indigo-100 text-indigo-800">
                {{ userProfile.teams.name }}
              </span>
              <span v-else class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-gray-100 text-gray-800">
                No Team
              </span>
              <button
                v-if="userProfile?.is_super_admin || userProfile?.is_admin"
                @click="showEditOwnTeamModal = true"
                class="ml-2 text-xs text-blue-600 hover:text-blue-800 underline"
              >
                Change Team
              </button>
            </dd>
          </div>
          <div>
            <dt class="text-sm font-medium text-gray-500">Role</dt>
            <dd class="mt-1">
              <span v-if="userProfile?.is_super_admin" class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-purple-100 text-purple-800">
                Super Admin
              </span>
              <span v-else-if="userProfile?.is_admin" class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-blue-100 text-blue-800">
                Admin
              </span>
              <span v-else class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-gray-100 text-gray-800">
                User
              </span>
            </dd>
          </div>
        </dl>
      </div>

      <!-- Request Rules Section (Admin/Super Admin only) -->
      <div v-if="userProfile?.is_admin || userProfile?.is_super_admin" class="bg-white shadow rounded-lg p-6 mb-6">
        <h2 class="text-xl font-semibold text-gray-900 mb-1">Request Rules</h2>
        <p class="text-sm text-gray-500 mb-4">Configure auto-approval limits for time-off and schedule change requests.</p>

        <div v-if="teamSettingsLoading" class="text-sm text-gray-500">Loading settings...</div>
        <div v-else class="space-y-4">
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Max PTO Hours / Day (team-wide)</label>
              <input
                v-model.number="ruleFields.max_pto_hours_per_day"
                type="number"
                min="0"
                class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              />
              <p class="mt-1 text-xs text-gray-400">Total approved PTO hours allowed across the team per day</p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Max Shift Swaps / Day (team-wide)</label>
              <input
                v-model.number="ruleFields.max_shift_swaps_per_day"
                type="number"
                min="0"
                class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              />
              <p class="mt-1 text-xs text-gray-400">Total shift swaps allowed per day across the team</p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Max Leave-Early / Employee / Day</label>
              <input
                v-model.number="ruleFields.max_leave_early_per_employee_per_day"
                type="number"
                min="0"
                class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              />
              <p class="mt-1 text-xs text-gray-400">How many times one employee can leave early per day</p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Max Shift Changes / Employee / Day</label>
              <input
                v-model.number="ruleFields.max_shift_change_per_employee_per_day"
                type="number"
                min="0"
                class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              />
              <p class="mt-1 text-xs text-gray-400">How many shift change requests one employee can make per day</p>
            </div>
          </div>

          <div v-if="teamSettingsError" class="bg-red-50 border border-red-200 rounded-md p-3">
            <p class="text-sm text-red-600">{{ teamSettingsError }}</p>
          </div>
          <div v-if="teamSettingsSuccess" class="bg-green-50 border border-green-200 rounded-md p-3">
            <p class="text-sm text-green-600">{{ teamSettingsSuccess }}</p>
          </div>

          <div class="flex justify-end">
            <button
              @click="saveRequestRules"
              :disabled="savingRules"
              class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50"
            >
              {{ savingRules ? 'Saving...' : 'Save Rules' }}
            </button>
          </div>
        </div>
      </div>

      <!-- Super Admin Management Section -->
      <div v-if="userProfile?.is_super_admin" class="space-y-6">
        <!-- Users Management -->
        <div id="user-management" class="bg-white shadow rounded-lg p-6 scroll-mt-8">
          <div class="flex justify-between items-center mb-4">
            <div>
              <h2 class="text-xl font-semibold text-gray-900">User Management</h2>
              <p class="text-sm text-gray-600">Total: {{ users.length }}</p>
            </div>
            <button
              @click="showCreateModal = true"
              class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              + Create User
            </button>
          </div>

          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Email</th>
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Full Name</th>
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Team</th>
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Role</th>
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <tr v-for="u in users" :key="u.id">
                  <td class="px-4 py-3 whitespace-nowrap text-sm font-medium text-gray-900">
                    {{ u.email || u.username }}
                  </td>
                  <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-500">
                    {{ u.full_name || '-' }}
                  </td>
                  <td class="px-4 py-3 whitespace-nowrap">
                    <span v-if="u.team?.name" class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-indigo-100 text-indigo-800">
                      {{ u.team.name }}
                    </span>
                    <span v-else class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-gray-100 text-gray-800">
                      No Team
                    </span>
                  </td>
                  <td class="px-4 py-3 whitespace-nowrap">
                    <span v-if="u.is_super_admin" class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-purple-100 text-purple-800">
                      Super Admin
                    </span>
                    <span v-else-if="u.is_admin" class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-blue-100 text-blue-800">
                      Admin
                    </span>
                    <span v-else class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-gray-100 text-gray-800">
                      User
                    </span>
                  </td>
                  <td class="px-4 py-3 whitespace-nowrap">
                    <span v-if="u.is_active" class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800">
                      Active
                    </span>
                    <span v-else class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-red-100 text-red-800">
                      Inactive
                    </span>
                  </td>
                  <td class="px-4 py-3 whitespace-nowrap text-sm font-medium">
                    <button
                      @click="editUser(u)"
                      class="text-blue-600 hover:text-blue-900 mr-3"
                    >
                      Edit
                    </button>
                    <button
                      @click="resetUserPassword(u)"
                      class="text-indigo-600 hover:text-indigo-900 mr-3"
                    >
                      Reset Password
                    </button>
                    <button
                      @click="toggleUserStatus(u)"
                      class="text-gray-600 hover:text-gray-900"
                    >
                      {{ u.is_active ? 'Deactivate' : 'Activate' }}
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <!-- Teams Management -->
        <div class="bg-white shadow rounded-lg p-6">
          <div class="flex justify-between items-center mb-4">
            <div>
              <h2 class="text-xl font-semibold text-gray-900">Team Management</h2>
              <p class="text-sm text-gray-600">Total: {{ teams.length }}</p>
            </div>
            <button
              @click="showTeamModal = true"
              class="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500"
            >
              + Create Team
            </button>
          </div>

          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Team Name</th>
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Users</th>
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <tr v-for="team in teams" :key="team.id">
                  <td class="px-4 py-3 whitespace-nowrap text-sm font-medium text-gray-900">
                    {{ team.name }}
                  </td>
                  <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-500">
                    {{ getUserCountForTeam(team.id) }}
                  </td>
                  <td class="px-4 py-3 whitespace-nowrap text-sm font-medium">
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
    </div>
  </div>

  <!-- Modals -->
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
          <label class="block text-sm font-medium text-gray-700 mb-1">Team</label>
          <select
            v-model="newUser.team_id"
            class="w-full px-3 py-2 border border-gray-300 rounded-md"
          >
            <option value="">No Team</option>
            <option v-for="team in teams" :key="team.id" :value="team.id">
              {{ team.name }}
            </option>
          </select>
        </div>

        <div class="space-y-2">
          <div class="flex items-center">
            <input
              id="is_admin"
              v-model="newUser.is_admin"
              type="checkbox"
              class="h-4 w-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
            />
            <label for="is_admin" class="ml-2 block text-sm text-gray-900">Admin (Team Manager)</label>
          </div>
          <div class="flex items-center">
            <input
              id="is_super_admin"
              v-model="newUser.is_super_admin"
              type="checkbox"
              class="h-4 w-4 text-purple-600 border-gray-300 rounded focus:ring-purple-500"
            />
            <label for="is_super_admin" class="ml-2 block text-sm text-gray-900">Super Admin (System Administrator)</label>
          </div>
          <p class="text-xs text-gray-500 ml-6">
            Super Admin includes all Admin permissions plus system-wide access.
          </p>
        </div>
        
        <div v-if="error" class="bg-red-50 border border-red-200 rounded-md p-3">
          <p class="text-sm text-red-600">{{ error }}</p>
        </div>
        
        <div class="flex justify-end space-x-2">
          <button
            type="button"
            @click="showCreateModal = false"
            class="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-200 rounded-md hover:bg-gray-300"
          >
            Cancel
          </button>
          <button
            type="submit"
            :disabled="creating"
            class="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-md hover:bg-blue-700 disabled:opacity-50"
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
        
        <div class="space-y-2">
          <div>
            <label class="flex items-center">
              <input
                v-model="editUserData.is_admin"
                type="checkbox"
                class="mr-2"
                :disabled="editingUser?.is_super_admin"
              />
              <span class="text-sm text-gray-700">Admin (Team Manager)</span>
            </label>
          </div>
          <div>
            <label class="flex items-center">
              <input
                v-model="editUserData.is_super_admin"
                type="checkbox"
                class="mr-2"
              />
              <span class="text-sm text-gray-700">Super Admin (System Administrator)</span>
            </label>
          </div>
          <p class="text-xs text-gray-500 ml-6">
            Only Super Admins can change roles. Super Admin includes all Admin permissions.
          </p>
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
      <h3 class="text-lg font-bold text-gray-900 mb-4">Reset Password for {{ userToReset?.email || userToReset?.username }}</h3>
      
      <form @submit.prevent="handleResetPassword" class="space-y-4">
        <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">New Password *</label>
              <input
                v-model="newPasswordReset"
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
                v-model="confirmNewPasswordReset"
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
        
        <div class="flex justify-end space-x-2">
          <button
            type="button"
            @click="showResetPasswordModal = false; error = ''; resetSuccess = false"
            class="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-200 rounded-md hover:bg-gray-300"
          >
            Cancel
          </button>
          <button
            type="submit"
            :disabled="resettingPassword || newPasswordReset !== confirmNewPasswordReset || newPasswordReset.length < 6"
            class="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-md hover:bg-blue-700 disabled:opacity-50"
          >
            {{ resettingPassword ? 'Resetting...' : 'Reset Password' }}
          </button>
        </div>
      </form>
    </div>
  </div>

  <!-- Edit Own Team Modal -->
  <div v-if="showEditOwnTeamModal" class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50" @click.self="showEditOwnTeamModal = false">
    <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
      <h3 class="text-lg font-bold text-gray-900 mb-4">Change Your Team</h3>
      
      <form @submit.prevent="saveOwnTeam" class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Team</label>
          <select
            v-model="ownTeamData.team_id"
            class="w-full px-3 py-2 border border-gray-300 rounded-md"
          >
            <option value="">No Team</option>
            <option v-for="team in teams" :key="team.id" :value="team.id">
              {{ team.name }}
            </option>
          </select>
        </div>
        
        <div v-if="error" class="bg-red-50 border border-red-200 rounded-md p-3">
          <p class="text-sm text-red-600">{{ error }}</p>
        </div>
        
        <div class="flex justify-end space-x-3">
          <button
            type="button"
            @click="showEditOwnTeamModal = false; error = ''"
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
</template>

<script setup lang="ts">
// Page is protected by auth.global.ts middleware

const route = useRoute()
const { user, fetchCurrentUser, changePassword: changePasswordApi } = useAuth()
const { isSuperAdmin, checkIsSuperAdmin, fetchAllTeams, createTeam: createTeamFn, deleteTeam: deleteTeamFn } = useTeam()
const { fetchSettings, saveSetting, getSetting, loading: teamSettingsLoading, error: teamSettingsError } = useTeamSettings()

// Request rules state
const ruleFields = ref({
  max_pto_hours_per_day: 8,
  max_shift_swaps_per_day: 3,
  max_leave_early_per_employee_per_day: 1,
  max_shift_change_per_employee_per_day: 1,
})
const savingRules = ref(false)
const teamSettingsSuccess = ref('')

// Password change state
const currentPassword = ref('')
const newPassword = ref('')
const confirmPassword = ref('')
const loading = ref(false)
const error = ref('')
const success = ref('')
const userProfile = ref<any>(null)

// User/Team management state
const users = ref<any[]>([])
const teams = ref<any[]>([])
const showCreateModal = ref(false)
const showTeamModal = ref(false)
const showEditModal = ref(false)
const showResetPasswordModal = ref(false)
const showEditOwnTeamModal = ref(false)
const ownTeamData = ref({ team_id: '' })
const creating = ref(false)
const creatingTeam = ref(false)
const resettingPassword = ref(false)
const resetSuccess = ref(false)
const userToReset = ref<any>(null)
const editingUser = ref<any>(null)
const newPasswordReset = ref('')
const confirmNewPasswordReset = ref('')
const editUserData = ref({
  full_name: '',
  team_id: '',
  is_admin: false,
  is_super_admin: false,
  is_active: true
})
const newUser = ref({
  email: '',
  password: '',
  full_name: '',
  team_id: '',
  is_admin: false,
  is_super_admin: false
})
const newTeam = ref({
  name: ''
})

// Fetch user profile - use auth/me which returns user; merge with team from /api/teams
const fetchUserProfile = async () => {
  if (!user.value?.id) return
  try {
    const authUser = user.value
    let teamData = null
    if (authUser.team_id) {
      const teams = await $fetch<any[]>('/api/teams')
      teamData = teams.find((t) => t.id === authUser.team_id) ?? null
    }
    userProfile.value = {
      id: authUser.id,
      email: authUser.email,
      username: authUser.username,
      full_name: authUser.full_name,
      team_id: authUser.team_id,
      is_admin: authUser.is_admin,
      is_super_admin: authUser.is_super_admin,
      is_active: authUser.is_active,
      teams: teamData ? { id: teamData.id, name: teamData.name } : null,
    }
    error.value = ''
  } catch (err: any) {
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

  if (newPassword.value.length < 8) {
    error.value = 'New password must be at least 8 characters'
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
    await changePasswordApi(currentPassword.value, newPassword.value)

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

// Fetch data functions
const fetchUsers = async () => {
  if (!isSuperAdmin.value) return
  try {
    users.value = await $fetch<any[]>('/api/admin/users')
  } catch (err: any) {
    error.value = `Failed to fetch users: ${err.message}`
  }
}

const fetchTeams = async () => {
  if (!isSuperAdmin.value) return
  try {
    teams.value = await fetchAllTeams()
  } catch (err: any) {
    error.value = `Failed to fetch teams: ${err.message}`
  }
}

const getUserCountForTeam = (teamId: string) => {
  return users.value.filter(u => u.team_id === teamId).length
}

// Create user
const createUser = async () => {
  creating.value = true
  error.value = ''
  
  try {
    await $fetch('/api/admin/users/create', {
      method: 'POST',
      body: {
        email: newUser.value.email.trim().toLowerCase(),
        password: newUser.value.password,
        full_name: newUser.value.full_name || null,
        team_id: newUser.value.team_id || null,
        is_admin: newUser.value.is_admin || false,
        is_super_admin: newUser.value.is_super_admin || false
      }
    })
    
    newUser.value = {
      email: '',
      password: '',
      full_name: '',
      team_id: '',
      is_admin: false,
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
    if (!isSuperAdmin.value) {
      error.value = 'Only super admins can create teams. Please refresh the page and try again.'
      creatingTeam.value = false
      return
    }
    
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

// Save own team assignment
const saveOwnTeam = async () => {
  if (!userProfile.value) return
  
  try {
    await $fetch('/api/auth/me', {
      method: 'PUT',
      body: { team_id: ownTeamData.value.team_id || null }
    })
    await fetchUserProfile()
    await checkIsSuperAdmin()
    showEditOwnTeamModal.value = false
    ownTeamData.value.team_id = ''
    error.value = ''
  } catch (err: any) {
    error.value = err.data?.message || err.message || 'Failed to update team'
  }
}

// Edit user
const editUser = (u: any) => {
  editingUser.value = u
  editUserData.value = {
    full_name: u.full_name || '',
    team_id: u.team_id || '',
    is_admin: u.is_admin || false,
    is_super_admin: u.is_super_admin || false,
    is_active: u.is_active !== false
  }
  showEditModal.value = true
  error.value = ''
}

const saveUserEdit = async () => {
  if (!editingUser.value) return
  
  try {
    await $fetch(`/api/admin/users/${editingUser.value.id}`, {
      method: 'PUT',
      body: {
        full_name: editUserData.value.full_name || null,
        team_id: editUserData.value.team_id || null,
        is_admin: editUserData.value.is_admin,
        is_super_admin: editUserData.value.is_super_admin,
        is_active: editUserData.value.is_active
      }
    })
    
    const wasEditingSelf = editingUser.value?.id === user.value?.id
    showEditModal.value = false
    editingUser.value = null
    await fetchUsers()
    if (wasEditingSelf) await checkIsSuperAdmin()
    await fetchUserProfile()
  } catch (err: any) {
    error.value = err.data?.message || err.message || 'Failed to update user'
  }
}

// Toggle user status
const toggleUserStatus = async (u: any) => {
  if (!confirm(`Are you sure you want to ${u.is_active ? 'deactivate' : 'activate'} this user?`)) {
    return
  }
  
  try {
    await $fetch(`/api/admin/users/${u.id}`, {
      method: 'PUT',
      body: { is_active: !u.is_active }
    })
    await fetchUsers()
  } catch (err: any) {
    error.value = err.data?.message || err.message || 'Failed to update user'
  }
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

// Reset user password (admin function)
const resetUserPassword = (u: any) => {
  userToReset.value = u
  newPasswordReset.value = ''
  confirmNewPasswordReset.value = ''
  resetSuccess.value = false
  error.value = ''
  showResetPasswordModal.value = true
}

const handleResetPassword = async () => {
  error.value = ''
  resetSuccess.value = false
  
  if (newPasswordReset.value !== confirmNewPasswordReset.value) {
    error.value = 'Passwords do not match'
    return
  }
  
  if (newPasswordReset.value.length < 6) {
    error.value = 'Password must be at least 6 characters'
    return
  }
  
  resettingPassword.value = true
  
  try {
    await $fetch('/api/admin/users/reset-password', {
      method: 'POST',
      body: {
        user_id: userToReset.value.id,
        new_password: newPasswordReset.value
      }
    })
    
    resetSuccess.value = true
    
    setTimeout(() => {
      showResetPasswordModal.value = false
      userToReset.value = null
      newPasswordReset.value = ''
      confirmNewPasswordReset.value = ''
      resetSuccess.value = false
    }, 2000)
  } catch (err: any) {
    error.value = err.data?.message || err.message || 'Failed to reset password'
  } finally {
    resettingPassword.value = false
  }
}

// Save request rules
const saveRequestRules = async () => {
  savingRules.value = true
  teamSettingsSuccess.value = ''
  try {
    const keys = Object.keys(ruleFields.value) as (keyof typeof ruleFields.value)[]
    for (const key of keys) {
      await saveSetting(key, ruleFields.value[key])
    }
    teamSettingsSuccess.value = 'Rules saved successfully!'
    setTimeout(() => { teamSettingsSuccess.value = '' }, 3000)
  } catch (err: any) {
    // error is set by composable
  } finally {
    savingRules.value = false
  }
}

// Load request rules from team settings
const loadRequestRules = async () => {
  await fetchSettings()
  ruleFields.value = {
    max_pto_hours_per_day: parseInt(getSetting('max_pto_hours_per_day', '8'), 10),
    max_shift_swaps_per_day: parseInt(getSetting('max_shift_swaps_per_day', '3'), 10),
    max_leave_early_per_employee_per_day: parseInt(getSetting('max_leave_early_per_employee_per_day', '1'), 10),
    max_shift_change_per_employee_per_day: parseInt(getSetting('max_shift_change_per_employee_per_day', '1'), 10),
  }
}

// Fetch profile on mount
onMounted(async () => {
  await fetchCurrentUser()
  let retries = 0
  const maxRetries = 20
  
  while (retries < maxRetries) {
    if (user.value?.id) {
      await fetchUserProfile()
      ownTeamData.value.team_id = userProfile.value?.team_id || ''
      if (user.value?.is_admin || user.value?.is_super_admin) {
        await loadRequestRules()
      }
      if (isSuperAdmin.value) {
        await Promise.all([fetchUsers(), fetchTeams()])
      }
      if (route.hash === '#user-management') {
        await nextTick()
        document.getElementById('user-management')?.scrollIntoView({ behavior: 'smooth', block: 'start' })
      }
      return
    }
    await new Promise(resolve => setTimeout(resolve, 100))
    retries++
  }
  
  error.value = 'Unable to load user session. Please try logging out and back in.'
})

// Watch for user changes - debounced to avoid request storms (was causing 429 rate limit)
let fetchDebounceTimer: ReturnType<typeof setTimeout> | null = null
watch(user, (newUser) => {
  if (!newUser?.id) return
  if (fetchDebounceTimer) clearTimeout(fetchDebounceTimer)
  fetchDebounceTimer = setTimeout(async () => {
    fetchDebounceTimer = null
    await fetchUserProfile()
    // Don't call checkIsSuperAdmin here - it triggers fetchCurrentUser which can re-trigger this watch
    if (isSuperAdmin.value) {
      await Promise.all([fetchUsers(), fetchTeams()])
    }
  }, 300)
}, { immediate: false })
</script>

