import { verifyToken, setSessionCookie, COOKIE_NAME, SESSION_RENEW_AFTER_SECONDS } from '../utils/jwt'
import { query } from '../utils/db'
import type { AuthUser } from '../utils/authorize'

/**
 * Global server middleware: turns the session cookie into event.context.user for
 * the API route handlers (which gate with requireAuth etc. in server/utils/authorize.ts).
 *
 * The signed token only says WHO the caller is. Their team, role and active flag
 * are read from user_profiles on every API call. Until Sep 2026 they came from the
 * token, so deactivating, moving or demoting someone took up to 8 hours to apply —
 * and never for a kiosk, whose refresh re-signed the old claims every 2 minutes. A
 * deleted or deactivated account now gets 401 on its very next call.
 *
 * It also slides the session: a cookie older than SESSION_RENEW_AFTER_SECONDS is
 * re-issued on use, so people stay signed in while they work and are signed out
 * after 8 hours idle (kiosks: 30 days).
 */
export default defineEventHandler(async (event) => {
  // Only the API needs a user; pages and assets don't warrant a database lookup, and
  // the health probe must answer without one. (1.rate-limit.ts runs before this, so
  // a flood is throttled before it reaches the database.)
  if (!event.path.startsWith('/api/') || event.path.startsWith('/api/health')) return

  const token = getCookie(event, COOKIE_NAME)
  if (!token) return
  const claims = verifyToken(token)
  if (!claims?.id) return

  const result = await query<AuthUser>(
    `SELECT id, email, username, full_name, team_id, is_admin, is_super_admin,
            is_team_lead, is_display_user, is_active, employee_id
     FROM user_profiles WHERE id = $1`,
    [claims.id]
  )
  const user = result.rows[0]
  if (!user || !user.is_active) return
  event.context.user = user

  // Login and logout set or clear the cookie themselves.
  const ownsCookie = event.path.startsWith('/api/auth/login') || event.path.startsWith('/api/auth/logout')
  const age = Date.now() / 1000 - (claims.iat ?? 0)
  if (!ownsCookie && age > SESSION_RENEW_AFTER_SECONDS) setSessionCookie(event, user)
})
