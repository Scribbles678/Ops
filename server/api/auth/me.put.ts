import { query } from '../../utils/db'
import { requireAuth } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const body = await readBody(event)
  const { team_id } = body ?? {}

  await query(
    `UPDATE user_profiles SET team_id = $1, updated_at = NOW() WHERE id = $2`,
    [team_id ?? null, user.id]
  )
  return { ok: true }
})
