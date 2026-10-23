import { transaction } from '../../../utils/db'
import { requireSupervisor } from '../../../utils/authorize'
import { assertAccountManageable } from '../../../utils/teamOwnership'
import { canHoldExtraTeams, setExtraTeams, extraTeamsByUser } from '../../../utils/teamMembership'
import { logTeamAccessChanges } from '../../../utils/auditLog'
import { flagsForRole, isRole, roleOf } from '../../../../utils/roles'

export default defineEventHandler(async (event) => {
  // A supervisor edits their own team's accounts, other than Super Admins; a
  // super admin, any account (see assertAccountManageable).
  const actor = requireSupervisor(event)
  const id = getRouterParam(event, 'id')
  await assertAccountManageable(actor, id)
  const body = await readBody(event)
  const { team_id, is_active, full_name, role, extra_team_ids } = body ?? {}

  // A role change writes all four flags together, so an account can never end
  // up holding two. Omit `role` to leave the flags alone.
  if (role !== undefined && !isRole(role)) {
    throw createError({ statusCode: 400, message: 'Unknown role' })
  }
  if (role === 'super_admin' && !actor.is_super_admin) {
    throw createError({ statusCode: 403, message: 'Only a Super Admin can make someone a Super Admin' })
  }
  if (team_id != null && !actor.is_super_admin && team_id !== actor.team_id) {
    throw createError({ statusCode: 403, message: 'Only a Super Admin can move an account to another team' })
  }
  // More teams for one account is a Super Admin's decision, like moving it.
  if (extra_team_ids !== undefined && !actor.is_super_admin) {
    throw createError({ statusCode: 403, message: 'Only a Super Admin can give an account more teams' })
  }
  // Now that every site's supervisors manage accounts, keep anyone from locking
  // themselves out — or the last Super Admin from demoting themselves.
  if (id === actor.id && (is_active === false || (role !== undefined && role !== roleOf(actor)))) {
    throw createError({ statusCode: 400, message: "You can't deactivate your own account or change your own role. Ask another administrator." })
  }
  const flags = role === undefined ? null : flagsForRole(role)

  return transaction(async (client) => {
    const result = await client.query(
      `UPDATE user_profiles
       SET team_id         = COALESCE($1, team_id),
           is_admin        = COALESCE($2, is_admin),
           is_super_admin  = COALESCE($3, is_super_admin),
           is_team_lead    = COALESCE($4, is_team_lead),
           is_display_user = COALESCE($5, is_display_user),
           is_active       = COALESCE($6, is_active),
           full_name       = COALESCE($7, full_name),
           updated_at      = NOW()
       WHERE id = $8
       RETURNING id, username, email, full_name, team_id,
                 is_admin, is_super_admin, is_team_lead, is_display_user, is_active`,
      [
        team_id ?? null,
        flags?.is_admin ?? null,
        flags?.is_super_admin ?? null,
        flags?.is_team_lead ?? null,
        flags?.is_display_user ?? null,
        is_active ?? null,
        full_name ?? null,
        id,
      ]
    )
    const updated = result.rows[0]
    if (!updated) {
      throw createError({ statusCode: 404, message: 'User not found' })
    }

    // Extra teams (migration 027): Supervisors and Team Leads only. A kiosk is one
    // screen at one site and a Super Admin has every team, so a role change to
    // either clears them; a new home team is never also an extra one.
    const holds = canHoldExtraTeams(updated)
    if (!holds && Array.isArray(extra_team_ids) && extra_team_ids.length) {
      throw createError({ statusCode: 400, message: 'Only Supervisors and Team Leads can work in more than one team' })
    }
    const current = (await extraTeamsByUser(client, [updated.id]))[updated.id]?.map((t) => t.id) ?? []
    const wanted = !holds ? [] : extra_team_ids !== undefined ? extra_team_ids : current
    const change = await setExtraTeams(client, updated.id, updated.team_id, wanted)
    await logTeamAccessChanges(client, actor, updated, change)

    return { ...updated, extra_teams: (await extraTeamsByUser(client, [updated.id]))[updated.id] ?? [] }
  })
})
