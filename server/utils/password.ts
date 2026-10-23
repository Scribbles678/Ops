import bcrypt from 'bcryptjs'

/**
 * Setting a password, in one place: an admin's reset (Settings → Users), the
 * person's own change (Settings → My account) and an emailed reset link all go
 * through setPassword(), so each one signs the person out everywhere else and
 * cancels any reset link still waiting in their inbox.
 */
export const MIN_PASSWORD_LENGTH = 8
const BCRYPT_COST = 12

interface Queryable {
  query(sql: string, params?: unknown[]): Promise<{ rows: any[] }>
}

/** 400 unless `value` is a usable new password. */
export function assertNewPassword(value: unknown, label = 'Password'): string {
  if (typeof value !== 'string' || !value) {
    throw createError({ statusCode: 400, message: `${label} is required` })
  }
  if (value.length < MIN_PASSWORD_LENGTH) {
    throw createError({ statusCode: 400, message: `${label} must be at least ${MIN_PASSWORD_LENGTH} characters` })
  }
  return value
}

export const hashPassword = (value: string) => bcrypt.hash(value, BCRYPT_COST)

/**
 * Store a new password for `userId`. Returns the moment it changed.
 *
 * password_changed_at (migration 026) makes server/middleware/auth.ts refuse every
 * session token issued before it, so the person is signed out on every device. It is
 * taken from THIS clock, whole seconds, because a token's `iat` is this clock's
 * seconds too: the database's clock can run a second ahead, and would then refuse the
 * fresh cookie that keeps the person's own browser signed in after they change it.
 */
export async function setPassword(db: Queryable, userId: string, value: string): Promise<Date> {
  const changedAt = new Date(Math.floor(Date.now() / 1000) * 1000)
  const hash = await hashPassword(value)
  await db.query(
    'UPDATE user_profiles SET password_hash = $1, password_changed_at = $2, updated_at = NOW() WHERE id = $3',
    [hash, changedAt, userId]
  )
  // A reset link sent earlier would otherwise still set a password for an hour.
  await db.query(
    'UPDATE password_reset_tokens SET expires_at = NOW() WHERE user_id = $1 AND used_at IS NULL AND expires_at > NOW()',
    [userId]
  )
  return changedAt
}
