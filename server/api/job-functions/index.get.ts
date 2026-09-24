import { query } from '../../utils/db'
import { requireAuth, getTeamFilter } from '../../utils/authorize'

/**
 * Active job functions, for every page that schedules against them. Team Setup
 * passes ?include_inactive=true so a deactivated job stays listed there and can be
 * switched back on — without it, unticking "Active" made a job vanish for good.
 */
export default defineEventHandler(async (event) => {
  const user = requireAuth(event)
  const teamId = getTeamFilter(user)
  const includeInactive = getQuery(event).include_inactive === 'true'

  const conditions: string[] = []
  const params: unknown[] = []
  if (!includeInactive) conditions.push('is_active = true')
  if (teamId) {
    params.push(teamId)
    conditions.push(`team_id = $${params.length}`)
  }

  let sql = 'SELECT * FROM job_functions'
  if (conditions.length) sql += ` WHERE ${conditions.join(' AND ')}`
  sql += ' ORDER BY sort_order, name'

  const result = await query(sql, params)
  return result.rows
})
