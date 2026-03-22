import { query } from '../../../utils/db'
import { requireSuperAdmin } from '../../../utils/authorize'

export default defineEventHandler(async (event) => {
  requireSuperAdmin(event)

  const result = await query(`SELECT * FROM cleanup_old_schedules_with_logging()`)
  return result.rows[0]
})
