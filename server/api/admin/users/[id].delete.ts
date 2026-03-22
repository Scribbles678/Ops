import { query } from '../../../utils/db'
import { requireSuperAdmin } from '../../../utils/authorize'

export default defineEventHandler(async (event) => {
  requireSuperAdmin(event)
  const id = getRouterParam(event, 'id')
  await query('DELETE FROM user_profiles WHERE id = $1', [id])
  return { success: true }
})
