import bcrypt from 'bcryptjs'
import { query } from '../../utils/db'
import { setSessionCookie } from '../../utils/jwt'

// A real cost-12 bcrypt hash of a throwaway string, compared against when the
// email is unknown so that answer takes as long as a wrong password. The old
// placeholder was 62 characters; bcryptjs returns false at once for anything that
// isn't a 60-character hash, so an unknown email answered in ~2 ms and a real one
// in ~240 ms — which told anyone which emails have accounts.
const DUMMY_HASH = '$2b$12$dyju293u16xpKym7fzhVE.HsuVLU7loE1vienwFnkJ9x2j6WaZXlC'

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
    is_team_lead: boolean
    is_display_user: boolean
    is_active: boolean
    employee_id: string | null
    password_hash: string
  }>(
    `SELECT id, email, username, full_name, team_id, is_admin, is_super_admin,
            is_team_lead, is_display_user, is_active, employee_id, password_hash
     FROM user_profiles
     WHERE email = $1
     LIMIT 1`,
    [email.trim().toLowerCase()]
  )

  const user = result.rows[0]

  // Always run bcrypt even if user not found (with a dummy hash) to avoid
  // leaking whether the email exists via response timing differences.
  const hashToCompare = user?.password_hash ?? DUMMY_HASH
  const passwordValid = await bcrypt.compare(password, hashToCompare)

  if (!user || !passwordValid) {
    throw createError({ statusCode: 401, message: 'Invalid email or password' })
  }

  if (!user.is_active) {
    throw createError({ statusCode: 403, message: 'Account is inactive. Contact your administrator.' })
  }

  // Update last_login timestamp
  await query('UPDATE user_profiles SET last_login = NOW() WHERE id = $1', [user.id])

  // Sign JWT and set as HttpOnly cookie (8h idle normally; 30d for kiosk accounts)
  const { password_hash: _, ...userWithoutHash } = user
  setSessionCookie(event, userWithoutHash)

  return { success: true, user: userWithoutHash }
})
