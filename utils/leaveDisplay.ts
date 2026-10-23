/**
 * How a leave of absence (migration 028, server/utils/leave.ts) reads — on Team
 * Setup, the schedule page, Employee Overview and in the change log. One copy, so
 * the badge beside a name and the sentence in the log say the same dates.
 */

export interface LeaveDates {
  /** YYYY-MM-DD, the first day off. */
  start_date: string
  /** YYYY-MM-DD, the last day off; null while the return date isn't known. */
  end_date: string | null
}

/** "Nov 2" (or "Nov 2, 2027") from a YYYY-MM-DD. */
export const leaveDay = (ymd: string, withYear = false): string => {
  const [y, m, d] = ymd.split('-').map(Number)
  if (!y || !m || !d) return ymd
  return new Date(y, m - 1, d).toLocaleDateString('en-US', { month: 'short', day: 'numeric', ...(withYear ? { year: 'numeric' } : {}) })
}

/** "Nov 2 – Dec 15", "Nov 2" for one day, or "from Nov 2 (return date not set)". */
export const leaveSpan = (l: LeaveDates): string =>
  l.end_date
    ? l.start_date === l.end_date
      ? leaveDay(l.start_date)
      : `${leaveDay(l.start_date)} – ${leaveDay(l.end_date)}`
    : `from ${leaveDay(l.start_date)} (return date not set)`

export type LeaveState = 'current' | 'upcoming' | 'past'

/** Where a leave stands on `today` (YYYY-MM-DD at the site). */
export const leaveState = (l: LeaveDates, today: string): LeaveState =>
  l.start_date > today ? 'upcoming' : l.end_date !== null && l.end_date < today ? 'past' : 'current'

/** The badge beside a name: "On leave through Dec 15", "On leave, return date not set", "Leave from Nov 2". */
export const leaveBadge = (l: LeaveDates, today: string): string => {
  const state = leaveState(l, today)
  if (state === 'upcoming') return `Leave from ${leaveDay(l.start_date)}`
  if (state === 'past') return `Leave ended ${leaveDay(l.end_date!)}`
  return l.end_date ? `On leave through ${leaveDay(l.end_date)}` : 'On leave, return date not set'
}

/**
 * The leave to show for someone on `today`: the one running now, else the next one
 * to start. null if neither.
 */
export const leaveToShow = <T extends LeaveDates>(leaves: T[], today: string): T | null => {
  const live = leaves.filter((l) => leaveState(l, today) !== 'past').sort((a, b) => a.start_date.localeCompare(b.start_date))
  return live.find((l) => leaveState(l, today) === 'current') ?? live[0] ?? null
}
