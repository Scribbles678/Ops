import bcrypt from 'bcryptjs'
import { query, transaction } from '../../utils/db'
import { requireAuth } from '../../utils/authorize'
import { setSessionCookie } from '../../utils/jwt'
import { assertNewPassword, setPassword } from '../../utils/password'
import { logAccountChange } from '../../utils/auditLog'

/**
 * Settings → My account → Change password. Needs the current password.
 *
 * Every OTHER session of this account is signed out (setPassword); this browser is
 * given a fresh cookie so it stays signed in. Written to the change log.
 */
export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const body = await readBody(event)
  const { current_password } = body ?? {}

  if (!current_password || !body?.new_password) {
    throw createError({ statusCode: 400, message: 'current_password and new_password are required' })
  }
  const newPassword = assertNewPassword(body.new_password, 'New password')

  // Fetch current hash
  const result = await query<{ password_hash: string }>(
    'SELECT password_hash FROM user_profiles WHERE id = $1',
    [user.id]
  )
  const profile = result.rows[0]
  if (!profile) {
    throw createError({ statusCode: 404, message: 'User not found' })
  }

  // 400, not 401: a 401 means "your session ended" everywhere else, and the app
  // answers it by asking you to sign in again — not the right response to a typo.
  const valid = await bcrypt.compare(current_password, profile.password_hash)
  if (!valid) {
    throw createError({ statusCode: 400, message: 'Current password is incorrect' })
  }

  await transaction(async (client) => {
    await setPassword(client, user.id, newPassword)
    await logAccountChange(client, {
      actor: user,
      // Under the account's own team, not whichever one this session is working in.
      account: { ...user, team_id: user.home_team_id ?? user.team_id },
      summary: 'Changed their own password. Their other devices were signed out.',
    })
  })
  // Issued after the change, so this browser stays signed in.
  setSessionCookie(event, user)

  return { success: true }
})
