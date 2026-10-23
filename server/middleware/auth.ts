import { verifyToken, setSessionCookie, COOKIE_NAME, SESSION_RENEW_AFTER_SECONDS } from '../utils/jwt'
import { query } from '../utils/db'
import type { AuthUser } from '../utils/authorize'

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

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
 *
 * A token issued before the account's password last changed is refused, so a reset
 * signs the person out on every device — the wall kiosk included.
 *
 * An account may work in several teams (migration 027), one at a time: the token
 * carries which, per device, and the sliding renewal below keeps it.
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

  // The team this session works in: the token's team_id (the home team at sign-in,
  // then whatever POST /api/auth/switch-team set), but only while the account may
  // still work there (server/utils/teamMembership.ts — the same rule, in SQL).
  // user.team_id is that ACTIVE team, so every getTeamFilter / getWriteTeamId route
  // works in it unchanged; user.home_team_id is the account's own team.
  const wanted = typeof claims.team_id === 'string' && UUID.test(claims.team_id) ? claims.team_id : null
  const result = await query<AuthUser & { password_changed_at: Date | null }>(
    `SELECT up.id, up.email, up.username, up.full_name, up.team_id AS home_team_id,
            up.is_admin, up.is_super_admin, up.is_team_lead, up.is_display_user, up.is_active,
            up.employee_id, up.password_changed_at,
            act.id AS team_id, act.timezone AS team_timezone
     FROM user_profiles up
     LEFT JOIN teams act ON act.id = COALESCE($2::uuid, up.team_id)
       AND (act.id = up.team_id
            OR up.is_super_admin
            OR ((up.is_admin OR up.is_team_lead)
                AND EXISTS (SELECT 1 FROM user_teams ut WHERE ut.user_id = up.id AND ut.team_id = act.id)))
     WHERE up.id = $1`,
    [claims.id, wanted]
  )
  const row = result.rows[0]
  if (!row || !row.is_active) return
  // The session's team is no longer one this account works in (a Super Admin took it
  // away, moved the account, or the team was deleted): signed out. The page it was on
  // showed that team, so carrying on in another one would save into the wrong site.
  if (wanted && !row.team_id) return
  // A token issued before the password last changed is signed out (migration 026):
  // a reset, or the person changing it, ends every other session. Both sides are
  // whole seconds of the app's clock (server/utils/password.ts setPassword).
  const { password_changed_at: changedAt, ...user } = row
  if (changedAt && (claims.iat ?? 0) < Math.floor(new Date(changedAt).getTime() / 1000)) return
  event.context.user = user

  // Login and logout set or clear the cookie themselves.
  const ownsCookie = event.path.startsWith('/api/auth/login') || event.path.startsWith('/api/auth/logout')
  const age = Date.now() / 1000 - (claims.iat ?? 0)
  if (!ownsCookie && age > SESSION_RENEW_AFTER_SECONDS) setSessionCookie(event, user)
})
