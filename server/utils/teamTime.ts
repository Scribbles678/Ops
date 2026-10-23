import { getTZISODate } from '../../utils/localDate'

/**
 * A team's own calendar: "today" where the site is, not where the server is.
 *
 * The app pod and the database run on UTC, so a server-side `new Date()` rolled over
 * to tomorrow at 7pm Central (5pm Pacific): evening requests were refused for too
 * little notice and today's date was marked as past. Since Sep 2026 every team has a
 * time zone (teams.timezone, migration 025), and server-side "today" comes from here.
 */
export const DEFAULT_TIMEZONE = 'America/Chicago'

/** True for an IANA zone the runtime knows ("America/New_York"). */
export const isValidTimeZone = (tz: unknown): tz is string => {
  if (typeof tz !== 'string' || !tz) return false
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: tz })
    return true
  } catch {
    return false
  }
}

interface Queryable {
  query: (text: string, params?: unknown[]) => Promise<{ rows: any[] }>
}

export async function teamTimeZone(db: Queryable, teamId: string): Promise<string> {
  const r = await db.query('SELECT timezone FROM teams WHERE id = $1', [teamId])
  const tz = r.rows[0]?.timezone
  return isValidTimeZone(tz) ? tz : DEFAULT_TIMEZONE
}

/** Today's YYYY-MM-DD at the team's site. */
export async function teamToday(db: Queryable, teamId: string): Promise<string> {
  return getTZISODate(await teamTimeZone(db, teamId))
}

/**
 * A YYYY-MM-DD as a Date at local midnight. The day arithmetic in ptoHours reads a
 * Date's local year/month/day, so dates built this way from strings compare
 * correctly whatever zone the server is in.
 */
export const dateOnly = (iso: string): Date => {
  const [y = 0, m = 1, d = 1] = iso.split('-').map(Number)
  return new Date(y, m - 1, d)
}
