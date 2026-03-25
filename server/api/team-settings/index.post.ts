import { query } from '../../utils/db'
import { requireAdmin, getTeamFilter } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAdmin(event)
  const teamId = getTeamFilter(user)
  const body = await readBody(event)
  const { setting_key, setting_value } = body

  if (!setting_key || setting_value == null) {
    throw createError({ statusCode: 400, message: 'setting_key and setting_value are required' })
  }

  if (!teamId) {
    throw createError({ statusCode: 400, message: 'Team context required' })
  }

  const result = await query(
    `INSERT INTO team_settings (team_id, setting_key, setting_value)
     VALUES ($1, $2, $3)
     ON CONFLICT (team_id, setting_key)
     DO UPDATE SET setting_value = $3, updated_at = NOW()
     RETURNING *`,
    [teamId, setting_key, String(setting_value)]
  )
  return result.rows[0]
})
