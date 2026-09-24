import bcrypt from 'bcryptjs'
import { query, transaction } from '../../utils/db'

export default defineEventHandler(async (event) => {
  const body = await readBody(event)
  const { token, new_password } = body ?? {}

  if (!token || !new_password) {
    throw createError({ statusCode: 400, message: 'Token and new password are required' })
  }

  if (new_password.length < 8) {
    throw createError({ statusCode: 400, message: 'Password must be at least 8 characters' })
  }

  const parts = token.split('.')
  if (parts.length !== 2) {
    throw createError({ statusCode: 400, message: 'Invalid or expired reset link. Please request a new one.' })
  }
  const [tokenId, secret] = parts

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

  const newHash = await bcrypt.hash(new_password, 12)

  // One connection for the whole transaction. This used to send BEGIN/COMMIT through
  // the shared pool, where each statement can land on a different connection and a
  // stray BEGIN leaves one "idle in transaction" for the next request to inherit.
  await transaction(async (client) => {
    await client.query(
      'UPDATE user_profiles SET password_hash = $1, updated_at = NOW() WHERE id = $2',
      [newHash, row.user_id]
    )
    await client.query(
      'UPDATE password_reset_tokens SET used_at = NOW() WHERE id = $1',
      [row.id]
    )
  })

  return { success: true, message: 'Password has been reset. You can now log in.' }
})
