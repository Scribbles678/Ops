import { query } from '../../utils/db'
import { requireAuth } from '../../utils/authorize'
import { signToken, COOKIE_NAME, sessionMaxAge } from '../../utils/jwt'

/**
 * Change which team the caller works in.
 *
 * This is a tenant boundary, not a profile preference: team membership decides
 * which team's data you can read and which team your saves land in. It had no
 * role check at all, so any authenticated account — a regular user, or a
 * wall-mounted kiosk login — could move itself into another team and read that
 * team's data. **Super admin only** — an admin who could reassign themselves
 * could walk into another site's data at will, which defeats team isolation.
 *
 * The team also lives in the signed JWT, so the token is re-issued here.
 * Updating only the database row left the OLD team in the cookie: the change
 * appeared to do nothing, then silently took effect at the next login.
 */
export default defineEventHandler(async (event) => {
  const user = requireAuth(event)

  if (!user.is_super_admin) {
    throw createError({ statusCode: 403, message: 'Only super admins can change their team' })
  }

  const body = await readBody(event)
  const { team_id } = body ?? {}

  // Reject an unknown team rather than stranding the account on a dead id.
  if (team_id) {
    const team = await query('SELECT id FROM teams WHERE id = $1', [team_id])
    if (!team.rows.length) {
      throw createError({ statusCode: 400, message: 'Team not found' })
    }
  }

  await query(
    `UPDATE user_profiles SET team_id = $1, updated_at = NOW() WHERE id = $2`,
    [team_id ?? null, user.id]
  )

  // Re-issue the session so the new team applies to the very next request.
  const updated = { ...user, team_id: team_id ?? null }
  setCookie(event, COOKIE_NAME, signToken(updated), {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict',
    maxAge: sessionMaxAge(updated),
    path: '/',
  })

  return { ok: true, user: updated }
})
