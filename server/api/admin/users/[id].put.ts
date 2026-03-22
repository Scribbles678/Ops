import { query } from '../../../utils/db'
import { requireSuperAdmin } from '../../../utils/authorize'

export default defineEventHandler(async (event) => {
  requireSuperAdmin(event)
  const id = getRouterParam(event, 'id')
  const body = await readBody(event)
  const { team_id, is_admin, is_super_admin, is_display_user, is_active, full_name } = body

  const result = await query(
    `UPDATE user_profiles
     SET team_id        = COALESCE($1, team_id),
         is_admin       = COALESCE($2, is_admin),
         is_super_admin = COALESCE($3, is_super_admin),
         is_display_user = COALESCE($4, is_display_user),
         is_active      = COALESCE($5, is_active),
         full_name      = COALESCE($6, full_name),
         updated_at     = NOW()
     WHERE id = $7
     RETURNING id, username, email, full_name, team_id, is_admin, is_super_admin, is_display_user, is_active`,
    [team_id ?? null, is_admin ?? null, is_super_admin ?? null, is_display_user ?? null, is_active ?? null, full_name ?? null, id]
  )

  if (result.rows.length === 0) {
    throw createError({ statusCode: 404, message: 'User not found' })
  }
  return result.rows[0]
})
