import { query } from '../../utils/db'
import { requireAuth } from '../../utils/authorize'

export default defineEventHandler(async (event) => {
  requireAuth(event)
  const id = getRouterParam(event, 'id')

  await query('DELETE FROM job_functions WHERE id = $1', [id])
  return { success: true }
})
