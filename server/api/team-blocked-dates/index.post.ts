import { query } from '../../utils/db'
import { requireSupervisor, getWriteTeamId } from '../../utils/authorize'

/** Most dates one add may carry: a year of month-end blocks is ~60. */
const MAX_DATES_PER_ADD = 400

/** A real calendar date. Date.parse alone rolls Feb 31 over to Mar 3, which Postgres then refuses. */
const isCalendarDate = (ymd: string): boolean => {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(ymd)) return false
  const [y, m, d] = ymd.split('-').map(Number) as [number, number, number]
  const dt = new Date(Date.UTC(y, m - 1, d))
  return dt.getUTCFullYear() === y && dt.getUTCMonth() === m - 1 && dt.getUTCDate() === d
}

/**
 * Add one or more blocked dates for the current team.
 * Body: { dates: string[] (YYYY-MM-DD), reason?: string }
 * Returns { inserted, count, skipped }: `skipped` are dates that were already
 * blocked. They keep the reason they had — adding a month-end block over the
 * quarter-end days used to relabel them silently ("Quarter-end close" became
 * "Month-end close"). To change a reason, remove the date and add it again.
 */
export default defineEventHandler(async (event) => {
  const user = requireSupervisor(event)
  const teamId = getWriteTeamId(user)
  const body = await readBody(event)
  const { dates, reason } = body ?? {}

  const list: string[] = Array.isArray(dates) ? dates : (typeof dates === 'string' ? [dates] : [])
  const cleaned = [...new Set(
    list
      .map((d) => String(d).slice(0, 10))
      .filter(isCalendarDate)
  )]

  if (cleaned.length === 0) {
    throw createError({ statusCode: 400, message: 'At least one valid date (YYYY-MM-DD) is required' })
  }
  if (cleaned.length > MAX_DATES_PER_ADD) {
    throw createError({ statusCode: 400, message: `Add at most ${MAX_DATES_PER_ADD} dates at a time` })
  }

  const result = await query(
    `INSERT INTO team_blocked_dates (team_id, blocked_date, reason)
     SELECT $1, d, $3 FROM unnest($2::date[]) AS d
     ON CONFLICT (team_id, blocked_date) DO NOTHING
     RETURNING id, team_id, blocked_date, reason, created_at, blocked_date::text AS day`,
    [teamId, cleaned, typeof reason === 'string' && reason.trim() ? reason.trim() : null]
  )
  const added = new Set(result.rows.map((r: any) => r.day))
  const skipped = cleaned.filter((d) => !added.has(d))

  return { inserted: result.rows, count: result.rows.length, skipped }
})
