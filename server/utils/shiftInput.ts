/**
 * Shared input rules for creating and editing a shift (server/api/shifts/*).
 *
 * The Team Setup form sends '' for a cleared time box. Postgres rejects '' for a
 * time column, so a break could never be removed and the form got "Server Error".
 * Blank now means "no time". The database's CHECK constraints are the real rules;
 * the messages below say them in words.
 */
const TIME = /^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/

/** '' / null / undefined → null; "HH:MM[:SS]" → itself; anything else → 400. */
export function timeOrNull(value: unknown, label: string): string | null {
  if (value == null || value === '') return null
  const s = String(value).trim()
  if (!TIME.test(s)) throw createError({ statusCode: 400, message: `${label} isn't a valid time` })
  return s
}

/**
 * A shift ends after it starts, on the same day. No site runs overnight shifts, and
 * the editor, the schedule grid and the builder all assume a same-day shift: an
 * overnight one (22:00–06:30) couldn't be shown in the editor and lost its hours on
 * save. The database still allows one (setup.sql: end <> start), so this is the rule.
 */
export function checkShiftTimes(start: string, end: string): void {
  if (end.slice(0, 5) <= start.slice(0, 5)) {
    throw createError({ statusCode: 400, message: "A shift must end after it starts — overnight shifts aren't supported." })
  }
}

/** Break 1, Break 2 and Lunch each need both halves or neither, ending after they start. */
export function checkPair(start: string | null, end: string | null, label: string): void {
  if ((start == null) !== (end == null)) {
    throw createError({ statusCode: 400, message: `${label} needs both a start and an end time (or neither).` })
  }
  if (start != null && end != null && end.slice(0, 5) <= start.slice(0, 5)) {
    throw createError({ statusCode: 400, message: `${label} must end after it starts.` })
  }
}

const CHECK_MESSAGES: Record<string, string> = {
  check_shift_time_range: "A shift must end after it starts — overnight shifts aren't supported.",
  check_shift_break_times: 'Break 1 needs both a start and an end time, and must end after it starts.',
  check_shift_break_2_times: 'Break 2 needs both a start and an end time, and must end after it starts.',
  check_shift_lunch_times: 'Lunch needs both a start and an end time, and must end after it starts.',
}

/** Turn a CHECK violation into a 400 the form can show; rethrow anything else. */
export function rethrowShiftError(e: any): never {
  if (e?.code === '23514' && CHECK_MESSAGES[e.constraint]) {
    throw createError({ statusCode: 400, message: CHECK_MESSAGES[e.constraint] })
  }
  if (e?.code === '22007' || e?.code === '22008') {
    throw createError({ statusCode: 400, message: 'One of the times is not a valid time.' })
  }
  throw e
}
