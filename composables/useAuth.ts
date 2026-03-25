/**
 * Auth composable - replaces @nuxtjs/supabase auth
 * Uses custom JWT stored in an HttpOnly cookie (set server-side).
 * The cookie is never readable from JavaScript - only the server can see it.
 *
 * Uses shallowRef instead of useState to avoid "instance unavailable" during
 * early app bootstrap (middleware runs before Nuxt context is ready).
 */

export interface AppUser {
  id: string
  email: string
  username: string
  full_name: string | null
  team_id: string | null
  is_admin: boolean
  is_super_admin: boolean
  is_display_user: boolean
  is_active: boolean
  employee_id: string | null
}

// Global reactive state - shallowRef avoids Nuxt context dependency
const currentUser = shallowRef<AppUser | null>(null)
const authLoading = shallowRef(false)

export const useAuth = () => {
  const isAuthenticated = computed(() => !!currentUser.value)

  /**
   * Fetch the current user from the server (validates JWT cookie).
   * Call this on app init and after login.
   */
  const fetchCurrentUser = async (): Promise<AppUser | null> => {
    try {
      const data = await $fetch<{ user: AppUser }>('/api/auth/me')
      currentUser.value = data.user
      return data.user
    } catch {
      currentUser.value = null
      return null
    }
  }

  const login = async (email: string, password: string): Promise<AppUser> => {
    authLoading.value = true
    try {
      const data = await $fetch<{ success: boolean; user: AppUser }>('/api/auth/login', {
        method: 'POST',
        body: { email, password },
      })
      currentUser.value = data.user
      return data.user
    } finally {
      authLoading.value = false
    }
  }

  const logout = async () => {
    try {
      await $fetch('/api/auth/logout', { method: 'POST' })
    } finally {
      currentUser.value = null
      await navigateTo('/login')
    }
  }

  const changePassword = async (current_password: string, new_password: string) => {
    await $fetch('/api/auth/change-password', {
      method: 'POST',
      body: { current_password, new_password },
    })
  }

  return {
    user: currentUser,
    isAuthenticated,
    authLoading,
    fetchCurrentUser,
    login,
    logout,
    changePassword,
  }
}
