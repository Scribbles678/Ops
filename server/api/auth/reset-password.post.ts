import bcrypt from 'bcryptjs'
import { query, transaction } from '../../utils/db'
import { assertNewPassword, setPassword } from '../../utils/password'
import { logAccountChange } from '../../utils/auditLog'

/**
 * The emailed "Forgot your password?" link: set a new password with its token.
 * Like every password change (setPassword), it signs the person out everywhere and
 * cancels their other reset links; it is written to the change log as theirs.
 */
export default defineEventHandler(async (event) => {
  const body = await readBody(event)
  const { token } = body ?? {}

  if (!token || !body?.new_password) {
    throw createError({ statusCode: 400, message: 'Token and new password are required' })
  }
  const newPassword = assertNewPassword(body.new_password)

  const parts = String(token).split('.')
  if (parts.length !== 2) {
    throw createError({ statusCode: 400, message: 'Invalid or expired reset link. Please request a new one.' })
  }
  const [tokenId, secret] = parts as [string, string]

  const result = await query<{
    id: string
    user_id: string
    token_hash: string
    expires_at: Date
    used_at: Date | null
  }>(
    `SELECT id, user_id, token_hash, expires_at, used_at
     FROM password_reset_tokens
     WHERE id = $1 AND expires_at > NOW() AND used_at IS NULL
     LIMIT 1`,
    [tokenId]
  )

  const row = result.rows[0]
  if (!row || !(await bcrypt.compare(secret, row.token_hash))) {
    throw createError({ statusCode: 400, message: 'Invalid or expired reset link. Please request a new one.' })
  }

  // One connection for the whole transaction. This used to send BEGIN/COMMIT through
  // the shared pool, where each statement can land on a different connection and a
  // stray BEGIN leaves one "idle in transaction" for the next request to inherit.
  await transaction(async (client) => {
    await client.query('UPDATE password_reset_tokens SET used_at = NOW() WHERE id = $1', [row.id])
    await setPassword(client, row.user_id, newPassword)
    const account = (await client.query(
      'SELECT id, email, username, full_name, team_id FROM user_profiles WHERE id = $1',
      [row.user_id]
    )).rows[0]
    if (account) {
      await logAccountChange(client, {
        actor: account,
        account,
        summary: 'Reset their own password with an emailed link. They were signed out on every device.',
      })
    }
  })

  return { success: true, message: 'Password has been reset. You can now log in.' }
})
