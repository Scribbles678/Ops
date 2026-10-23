import bcrypt from 'bcryptjs'
import { query } from '../../utils/db'
import { setSessionCookie } from '../../utils/jwt'
import { teamsFor } from '../../utils/teamMembership'

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
    team_timezone: string | null
  }>(
    // The team's time zone too, as /api/auth/me returns it: the display board reads
    // it straight after signing in, and without it fell back to the device's clock.
    `SELECT up.id, up.email, up.username, up.full_name, up.team_id, up.is_admin, up.is_super_admin,
            up.is_team_lead, up.is_display_user, up.is_active, up.employee_id, up.password_hash,
            t.timezone AS team_timezone
     FROM user_profiles up LEFT JOIN teams t ON t.id = up.team_id
     WHERE up.email = $1
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

  // Which team the session starts in (migration 027): the home team — unless the
  // caller asks to carry on in another team this account works in. The "session
  // ended" prompt does, so signing back in over a page keeps the team it showed.
  const { password_hash: _, ...profile } = user
  const homeTeamId = profile.team_id
  let session = { ...profile, home_team_id: homeTeamId }
  if (typeof body?.team_id === 'string' && body.team_id !== homeTeamId) {
    const team = (await teamsFor({ query }, profile, homeTeamId)).find((t) => t.id === body.team_id)
    if (team) session = { ...session, team_id: team.id, team_timezone: team.timezone }
  }

  // Sign JWT and set as HttpOnly cookie (8h idle normally; 30d for kiosk accounts)
  setSessionCookie(event, session)

  return { success: true, user: session }
})
