import bcrypt from 'bcryptjs'
import { query } from '../../utils/db'
import { signToken, COOKIE_NAME } from '../../utils/jwt'

export default defineEventHandler(async (event) => {
  const body = await readBody(event)
  const { email, password } = body ?? {}

  if (!email || !password) {
    throw createError({ statusCode: 400, message: 'Email and password are required' })
  }

  // Fetch user by email
  const result = await query<{
    id: string
    email: string
    username: string
    full_name: string | null
    team_id: string | null
    is_admin: boolean
    is_super_admin: boolean
    is_display_user: boolean
    is_active: boolean
    password_hash: string
  }>(
    `SELECT id, email, username, full_name, team_id, is_admin, is_super_admin,
            is_display_user, is_active, password_hash
     FROM user_profiles
     WHERE email = $1
     LIMIT 1`,
    [email.trim().toLowerCase()]
  )

  const user = result.rows[0]

  // Use constant-time comparison to prevent timing attacks.
  // Always run bcrypt even if user not found (with a dummy hash) to avoid
  // leaking whether the email exists via response timing differences.
  const dummyHash = '$2b$12$invalidhashusedtopreventtimingattacksxxxxxxxxxxxxxxxxxx'
  const hashToCompare = user?.password_hash ?? dummyHash
  const passwordValid = await bcrypt.compare(password, hashToCompare)

  if (!user || !passwordValid) {
    throw createError({ statusCode: 401, message: 'Invalid email or password' })
  }

  if (!user.is_active) {
    throw createError({ statusCode: 403, message: 'Account is inactive. Contact your administrator.' })
  }

  // Update last_login timestamp
  await query('UPDATE user_profiles SET last_login = NOW() WHERE id = $1', [user.id])

  // Sign JWT and set as HttpOnly cookie
  const { password_hash: _, ...userWithoutHash } = user
  const token = signToken(userWithoutHash)

  setCookie(event, COOKIE_NAME, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict',
    maxAge: 60 * 60 * 8, // 8 hours, matches JWT expiry
    path: '/',
  })

  return { success: true, user: userWithoutHash }
})
