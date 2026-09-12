import bcrypt from 'bcryptjs'
import { query } from '../../../utils/db'
import { requireSuperAdmin } from '../../../utils/authorize'
import { flagsForRole, isRole } from '../../../../utils/roles'

export default defineEventHandler(async (event) => {
  if (event.method !== 'POST') {
    throw createError({ statusCode: 405, message: 'Method not allowed' })
  }

  requireSuperAdmin(event)

  const body = await readBody(event)
  const { email, password, full_name, team_id, role } = body ?? {}

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

  // Exactly one role, always. An account with no role can do nothing, so
  // creating one would just produce a login that is refused on every screen.
  if (!isRole(role)) {
    throw createError({ statusCode: 400, message: 'A role is required (Super Admin, Supervisor, Team Lead / Coordinator or Kiosk)' })
  }
  const flags = flagsForRole(role)

  // Every account must belong to a team. A team-less account can neither read
  // nor write any data (see getTeamFilter), so creating one just produces a
  // login that errors on every screen.
  if (!team_id) {
    throw createError({ statusCode: 400, message: 'A team is required' })
  }
  const team = await query('SELECT id FROM teams WHERE id = $1', [team_id])
  if (!team.rows.length) {
    throw createError({ statusCode: 400, message: 'Team not found' })
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
       (username, email, password_hash, full_name, team_id,
        is_admin, is_super_admin, is_team_lead, is_display_user, is_active)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, true)
     RETURNING id, username, email, full_name, team_id,
               is_admin, is_super_admin, is_team_lead, is_display_user, is_active, created_at`,
    [
      username,
      normalizedEmail,
      password_hash,
      full_name ?? null,
      team_id,
      flags.is_admin,
      flags.is_super_admin,
      flags.is_team_lead,
      flags.is_display_user,
    ]
  )

  return { success: true, user: result.rows[0] }
})
