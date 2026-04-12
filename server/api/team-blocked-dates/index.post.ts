import { query } from '../../utils/db'
import { requireAdmin, getTeamFilter } from '../../utils/authorize'

/**
 * Add one or more blocked dates for the current team.
 * Body: { dates: string[] (YYYY-MM-DD), reason?: string }
 * Idempotent — existing (team_id, blocked_date) pairs are upserted to update the reason.
 */
export default defineEventHandler(async (event) => {
  const user = requireAdmin(event)
  const teamId = getTeamFilter(user) || user.team_id
  const body = await readBody(event)
  const { dates, reason } = body ?? {}

  if (!teamId) {
    throw createError({ statusCode: 400, message: 'Team context required' })
  }

  const list: string[] = Array.isArray(dates) ? dates : (typeof dates === 'string' ? [dates] : [])
  const cleaned = list
    .map((d) => String(d).slice(0, 10))
    .filter((d) => /^\d{4}-\d{2}-\d{2}$/.test(d))

  if (cleaned.length === 0) {
    throw createError({ statusCode: 400, message: 'At least one valid date (YYYY-MM-DD) is required' })
  }

  const inserted: any[] = []
  for (const d of cleaned) {
    const result = await query(
      `INSERT INTO team_blocked_dates (team_id, blocked_date, reason)
       VALUES ($1, $2, $3)
       ON CONFLICT (team_id, blocked_date)
       DO UPDATE SET reason = EXCLUDED.reason
       RETURNING *`,
      [teamId, d, reason ?? null]
    )
    inserted.push(result.rows[0])
  }

  return { inserted, count: inserted.length }
})
