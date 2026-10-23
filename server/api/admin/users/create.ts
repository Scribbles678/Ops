import { assertNewPassword, hashPassword } from '../../../utils/password'
import { query, transaction } from '../../../utils/db'
import { requireSupervisor, getWriteTeamId } from '../../../utils/authorize'
import { flagsForRole, isRole } from '../../../../utils/roles'
import { canHoldExtraTeams, setExtraTeams } from '../../../utils/teamMembership'
import { logTeamAccessChanges } from '../../../utils/auditLog'

export default defineEventHandler(async (event) => {
  if (event.method !== 'POST') {
    throw createError({ statusCode: 405, message: 'Method not allowed' })
  }

  // A supervisor adds accounts to their own team (never a Super Admin); a super
  // admin, to any team.
  const actor = requireSupervisor(event)

  const body = await readBody(event)
  const { email, password, full_name, team_id, role, extra_team_ids } = body ?? {}

  if (!email || !password) {
    throw createError({ statusCode: 400, message: 'Email and password are required' })
  }

  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
  if (!emailRegex.test(email)) {
    throw createError({ statusCode: 400, message: 'Invalid email format' })
  }

  assertNewPassword(password)

  // Exactly one role, always. An account with no role can do nothing, so
  // creating one would just produce a login that is refused on every screen.
  if (!isRole(role)) {
    throw createError({ statusCode: 400, message: 'A role is required (Super Admin, Supervisor, Team Lead / Coordinator or Kiosk)' })
  }
  if (role === 'super_admin' && !actor.is_super_admin) {
    throw createError({ statusCode: 403, message: 'Only a Super Admin can create a Super Admin account' })
  }
  const flags = flagsForRole(role)

  // Every account must belong to a team. A team-less account can neither read
  // nor write any data (see getTeamFilter), so creating one just produces a
  // login that errors on every screen.
  if (!team_id) {
    throw createError({ statusCode: 400, message: 'A team is required' })
  }
  if (!actor.is_super_admin && team_id !== getWriteTeamId(actor)) {
    throw createError({ statusCode: 403, message: 'You can add accounts to your own team only' })
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

  // The username is the part of the email before the @, and it is unique across
  // the whole install — so the second site's kiosk@… used to fail with a 500
  // because the first site already had "kiosk". Sign-in is by email; the username
  // is only shown, so take the next free "kiosk2", "kiosk3", …
  const base = normalizedEmail.split('@')[0]
  const taken = new Set(
    (await query<{ username: string }>(
      'SELECT username FROM user_profiles WHERE left(username, length($1)) = $1',
      [base]
    )).rows.map((r) => r.username)
  )
  let username = base
  for (let n = 2; taken.has(username); n++) username = `${base}${n}`
  const password_hash = await hashPassword(password)

  // More teams for one account (migration 027): a Super Admin's decision, and only
  // for Supervisors and Team Leads — a kiosk is one screen at one site.
  const extraTeams: string[] = Array.isArray(extra_team_ids) ? extra_team_ids : []
  if (extraTeams.length && !actor.is_super_admin) {
    throw createError({ statusCode: 403, message: 'Only a Super Admin can give an account more teams' })
  }
  if (extraTeams.length && !canHoldExtraTeams(flags)) {
    throw createError({ statusCode: 400, message: 'Only Supervisors and Team Leads can work in more than one team' })
  }

  const created = await transaction(async (client) => {
    const result = await client.query(
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
    const user = result.rows[0]
    if (extraTeams.length) {
      const change = await setExtraTeams(client, user.id, user.team_id, extraTeams)
      await logTeamAccessChanges(client, actor, user, change)
    }
    return user
  })

  return { success: true, user: created }
})
