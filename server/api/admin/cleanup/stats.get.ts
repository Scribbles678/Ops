import { query } from '../../../utils/db'
import { requireAuth } from '../../../utils/authorize'

export default defineEventHandler(async (event) => {
  requireAuth(event)
  const result = await query(`SELECT * FROM get_cleanup_stats()`)
  return result.rows[0]
})
