import bcrypt from 'bcryptjs'
import { query } from '../../../utils/db'
import { requireSuperAdmin } from '../../../utils/authorize'

export default defineEventHandler(async (event) => {
  if (event.method !== 'POST') {
    throw createError({ statusCode: 405, message: 'Method not allowed' })
  }

  requireSuperAdmin(event)

  const body = await readBody(event)
  const { email, password, full_name, team_id, is_admin, is_super_admin, is_display_user } = body ?? {}

  if (!email || !password) {
    throw createError({ statusCode: 400, message: 'Email and password are required' })
  }

  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
  if (!emailRegex.test(email)) {
    throw createError({ statusCode: 400, message: 'Invalid email format' })
  }

  if (password.length < 8) {
    throw createError({ statusCode: 400, message: 'Password must be at least 8 characters' })
  }

  const normalizedEmail = email.trim().toLowerCase()

  // Check for duplicate email
  const existing = await query(
    'SELECT id FROM user_profiles WHERE email = $1',
    [normalizedEmail]
  )
  if (existing.rows.length > 0) {
    throw createError({ statusCode: 400, message: 'A user with this email already exists' })
  }

  const username = normalizedEmail.split('@')[0]
  const password_hash = await bcrypt.hash(password, 12)

  const result = await query<{ id: string; username: string; email: string }>(
    `INSERT INTO user_profiles
       (username, email, password_hash, full_name, team_id, is_admin, is_super_admin, is_display_user, is_active)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, true)
     RETURNING id, username, email, full_name, team_id, is_admin, is_super_admin, is_display_user, is_active, created_at`,
    [
      username,
      normalizedEmail,
      password_hash,
      full_name ?? null,
      team_id ?? null,
      is_admin ?? false,
      is_super_admin ?? false,
      is_display_user ?? false,
    ]
  )

  return { success: true, user: result.rows[0] }
})
