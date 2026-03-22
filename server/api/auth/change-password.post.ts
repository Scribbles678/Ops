import bcrypt from 'bcryptjs'
import { query } from '../../utils/db'
import { requireAuth } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const body = await readBody(event)
  const { current_password, new_password } = body ?? {}

  if (!current_password || !new_password) {
    throw createError({ statusCode: 400, message: 'current_password and new_password are required' })
  }

  if (new_password.length < 8) {
    throw createError({ statusCode: 400, message: 'New password must be at least 8 characters' })
  }

  // Fetch current hash
  const result = await query<{ password_hash: string }>(
    'SELECT password_hash FROM user_profiles WHERE id = $1',
    [user.id]
  )

  const profile = result.rows[0]
  if (!profile) {
    throw createError({ statusCode: 404, message: 'User not found' })
  }

  const valid = await bcrypt.compare(current_password, profile.password_hash)
  if (!valid) {
    throw createError({ statusCode: 401, message: 'Current password is incorrect' })
  }

  const newHash = await bcrypt.hash(new_password, 12)
  await query('UPDATE user_profiles SET password_hash = $1, updated_at = NOW() WHERE id = $2', [
    newHash,
    user.id,
  ])

  return { success: true }
})
