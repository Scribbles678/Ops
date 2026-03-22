import bcrypt from 'bcryptjs'
import { query } from '../../../utils/db'
import { requireSuperAdmin } from '../../../utils/authorize'

export default defineEventHandler(async (event) => {
  if (event.method !== 'POST') {
    throw createError({ statusCode: 405, message: 'Method not allowed' })
  }

  requireSuperAdmin(event)

  const body = await readBody(event)
  const { user_id, new_password } = body ?? {}

  if (!user_id || !new_password) {
    throw createError({ statusCode: 400, message: 'User ID and new password are required' })
  }

  if (new_password.length < 8) {
    throw createError({ statusCode: 400, message: 'Password must be at least 8 characters' })
  }

  // Verify the target user exists
  const userCheck = await query('SELECT id FROM user_profiles WHERE id = $1', [user_id])
  if (userCheck.rows.length === 0) {
    throw createError({ statusCode: 404, message: 'User not found' })
  }

  const password_hash = await bcrypt.hash(new_password, 12)
  await query(
    'UPDATE user_profiles SET password_hash = $1, updated_at = NOW() WHERE id = $2',
    [password_hash, user_id]
  )

  return { success: true, message: 'Password reset successfully' }
})
