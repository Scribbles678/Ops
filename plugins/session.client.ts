import { AUTH_CHANNEL, type AuthChange } from '~/composables/useAuth'

/**
 * Session handling for the whole app.
 *
 * 1. Any API call that comes back 401 means the session is gone: it expired after
 *    8 hours idle, was signed out in another tab, or the account was deactivated.
 *    Flag it, and components/SessionEndedModal.vue asks the person to sign in again
 *    over the page they were on. Until Sep 2026 nothing did: every screen showed
 *    raw `[GET] "/api/…": 401 Unauthorized` text, with no way back but a reload.
 *
 * 2. When another tab signs in as someone else, signs out, or a super admin changes
 *    team there, reload this tab, so it neither shows nor saves into the previous
 *    user's or team's data. The same person signing back in elsewhere only clears
 *    this tab's "session ended" prompt; a reload would throw away unsaved edits.
 */
export default defineNuxtPlugin(() => {
  const { user, sessionEnded } = useAuth()

  globalThis.$fetch = $fetch.create({
    onResponseError({ request, response }) {
      if (response.status !== 401) return
      const url = typeof request === 'string' ? request : request.url
      // A wrong password at sign-in is its own 401, answered on the sign-in form.
      if (url.includes('/api/auth/login') || url.includes('/api/auth/logout')) return
      // Nobody signed in yet: the route guard sends them to /login. The display
      // board is the exception — it is a public page that needs its kiosk session.
      if (!user.value && window.location.pathname !== '/display') return
      sessionEnded.value = true
    },
  })

  if (typeof BroadcastChannel !== 'undefined') {
    new BroadcastChannel(AUTH_CHANNEL).onmessage = (e: MessageEvent<AuthChange>) => {
      const same = !!user.value && e.data?.userId === user.value.id && e.data?.teamId === user.value.team_id
      if (same) sessionEnded.value = false
      else window.location.reload()
    }
  }
})
