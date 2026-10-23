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
  is_team_lead: boolean
  is_display_user: boolean
  is_active: boolean
  employee_id: string | null
  /** The team's time zone, e.g. "America/New_York" (from /api/auth/me). */
  team_timezone?: string | null
  /** The account's own team. `team_id` is the one this session works in (migration 027). */
  home_team_id?: string | null
}

/** A team this account may work in (server/utils/teamMembership.ts). */
export interface TeamOption {
  id: string
  name: string
  timezone: string
  home: boolean
}

// Global reactive state - shallowRef avoids Nuxt context dependency
const currentUser = shallowRef<AppUser | null>(null)
/** Every team the signed-in account may work in; more than one shows the team switcher. */
const myTeams = shallowRef<TeamOption[]>([])
const authLoading = shallowRef(false)
/**
 * Set by plugins/session.client.ts when an API call comes back 401: the session
 * expired (8 hours idle), was signed out in another tab, or the account was
 * deactivated. components/SessionEndedModal.vue asks the person to sign in again
 * over the page they were on. Before Sep 2026 nothing did, and every screen just
 * showed raw "401 Unauthorized" errors.
 */
const sessionEnded = shallowRef(false)

/**
 * Other tabs of this browser listen here (plugins/session.client.ts). They reload
 * when a different person signs in, someone signs out, or a super admin changes
 * team, so no tab keeps showing — or saving into — the previous user's or team's
 * data. The same person signing back in just clears their "session ended" prompt.
 */
export const AUTH_CHANNEL = 'scheduling-auth'
export interface AuthChange { userId: string | null; teamId: string | null }
export const announceAuthChange = (u: { id: string; team_id: string | null } | null) => {
  if (typeof BroadcastChannel === 'undefined') return
  const channel = new BroadcastChannel(AUTH_CHANNEL)
  channel.postMessage({ userId: u?.id ?? null, teamId: u?.team_id ?? null } satisfies AuthChange)
  channel.close()
}

export const useAuth = () => {
  const isAuthenticated = computed(() => !!currentUser.value)

  /**
   * Fetch the current user from the server (validates JWT cookie).
   * Call this on app init and after login.
   */
  const fetchCurrentUser = async (): Promise<AppUser | null> => {
    try {
      const data = await $fetch<{ user: AppUser; teams?: TeamOption[] }>('/api/auth/me')
      currentUser.value = data.user
      myTeams.value = data.teams ?? []
      return data.user
    } catch {
      currentUser.value = null
      myTeams.value = []
      return null
    }
  }

  /**
   * `kioskOnly`: on the wall display, refuse anything but a kiosk account — a
   * supervisor signing in there used to leave the board running as them for good.
   * `teamId`: carry on in that team if this account works in it (the "session
   * ended" prompt passes the team its page showed); otherwise the home team.
   */
  const login = async (email: string, password: string, opts: { kioskOnly?: boolean; teamId?: string | null } = {}): Promise<AppUser> => {
    authLoading.value = true
    try {
      const data = await $fetch<{ success: boolean; user: AppUser }>('/api/auth/login', {
        method: 'POST',
        body: { email, password, team_id: opts.teamId ?? undefined },
      })
      if (opts.kioskOnly && !data.user.is_display_user) {
        await $fetch('/api/auth/logout', { method: 'POST' }).catch(() => {})
        throw new Error("On the display board, sign in with this site's kiosk account.")
      }
      // Check the browser kept the session cookie before calling this a sign-in. One
      // that drops it (cookies blocked, or an old build's HTTPS-only cookie on an
      // http:// address) looked signed in while every later call failed with 401.
      try {
        myTeams.value = (await $fetch<{ teams?: TeamOption[] }>('/api/auth/me')).teams ?? []
      } catch {
        throw new Error("Signed in, but this browser didn't keep the session, so nothing would load. Check that cookies aren't blocked for this site, or ask IT.")
      }
      currentUser.value = data.user
      sessionEnded.value = false
      announceAuthChange(data.user)
      return data.user
    } finally {
      authLoading.value = false
    }
  }

  const logout = async () => {
    try {
      await $fetch('/api/auth/logout', { method: 'POST' })
    } catch {
      // Pretending here would leave the session cookie behind for the next person
      // at this computer.
      alert("Couldn't sign out — the app didn't answer. Try again in a moment, or close the browser.")
      return
    }
    currentUser.value = null
    myTeams.value = []
    announceAuthChange(null)
    // A full page load, not an in-app navigation, so nothing from this session
    // stays in memory.
    window.location.href = '/login'
  }

  const changePassword = async (current_password: string, new_password: string) => {
    await $fetch('/api/auth/change-password', {
      method: 'POST',
      body: { current_password, new_password },
    })
  }

  /**
   * Work in another of this account's teams. A plain form POST, so the browser asks
   * about unsaved edits BEFORE anything changes — cancel and nothing switched. The
   * server re-issues this browser's session and sends it back to this page (only a
   * `tab` kept: an id in the address would belong to the old team); the page then
   * tells this browser's other tabs (components/TeamBar.vue).
   */
  const switchTeam = (teamId: string) => {
    const here = new URL(window.location.href)
    const tab = here.searchParams.get('tab')
    const form = document.createElement('form')
    form.method = 'POST'
    form.action = '/api/auth/switch-team'
    for (const [name, value] of [['team_id', teamId], ['return_to', here.pathname + (tab ? `?tab=${encodeURIComponent(tab)}` : '')]]) {
      const input = document.createElement('input')
      input.type = 'hidden'
      input.name = name!
      input.value = value!
      form.appendChild(input)
    }
    document.body.appendChild(form)
    form.submit()
  }

  return {
    user: currentUser,
    myTeams,
    switchTeam,
    isAuthenticated,
    authLoading,
    sessionEnded,
    fetchCurrentUser,
    login,
    logout,
    changePassword,
  }
}
