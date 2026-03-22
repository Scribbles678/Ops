import { query } from '../../../utils/db'
import { requireAuth } from '../../../utils/authorize'

export default defineEventHandler(async (event) => {
  requireAuth(event)
  const qs = getQuery(event)
  const limit = parseInt(String(qs.limit ?? '10'), 10)

  const result = await query(
    `SELECT * FROM cleanup_log ORDER BY cleanup_date DESC LIMIT $1`,
    [limit]
  )
  return result.rows
})
