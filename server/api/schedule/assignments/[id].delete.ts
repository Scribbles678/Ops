import { query } from '../../../utils/db'
import { requireAuth } from '../../../utils/authorize'

export default defineEventHandler(async (event) => {
  requireAuth(event)
  const id = getRouterParam(event, 'id')
  await query('DELETE FROM schedule_assignments WHERE id = $1', [id])
  return { success: true }
})
