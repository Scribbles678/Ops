import { query } from '../../../utils/db'
import { requireSuperAdmin } from '../../../utils/authorize'
import { flagsForRole, isRole } from '../../../../utils/roles'

export default defineEventHandler(async (event) => {
  requireSuperAdmin(event)
  const id = getRouterParam(event, 'id')
  const body = await readBody(event)
  const { team_id, is_active, full_name, role } = body ?? {}

  // A role change writes all four flags together, so an account can never end
  // up holding two. Omit `role` to leave the flags alone.
  if (role !== undefined && !isRole(role)) {
    throw createError({ statusCode: 400, message: 'Unknown role' })
  }
  const flags = role === undefined ? null : flagsForRole(role)

  const result = await query(
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

  if (result.rows.length === 0) {
    throw createError({ statusCode: 404, message: 'User not found' })
  }
  return result.rows[0]
})
