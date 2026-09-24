import { setSessionCookie } from '../../utils/jwt'
import { requireAuth } from '../../utils/authorize'

/**
 * Slide the session: if the caller is still signed in, re-issue the cookie with a
 * fresh expiry. The /display kiosk pings this on every refresh so a 24/7 wall
 * display never gets logged out. Returns 401 once the session has ended.
 *
 * The user comes from server/middleware/auth.ts, which reads the account from the
 * database, so a deactivated or moved kiosk is refused here instead of being
 * re-signed with its old claims forever (as it was until Sep 2026).
 */
export default defineEventHandler((event) => {
  const user = requireAuth(event)
  setSessionCookie(event, user)
  return { success: true }
})
