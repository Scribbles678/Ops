/**
 * Calendar-date helpers, shared by every page that needs "today" as YYYY-MM-DD.
 *
 * `new Date().toISOString().slice(0, 10)` is the wrong tool for this: it names the
 * UTC date, which from 7pm Central is already tomorrow. The Create Schedule page
 * used it for "today", "tomorrow" and the picker minimum, so an evening copy read
 * the wrong source day and every default landed one day late. The schedule page
 * and the display board each carried a correct copy of these helpers; this file
 * is that copy, made the only one.
 */

/** A Date -> YYYY-MM-DD in the browser's local calendar. */
export const toLocalISO = (d: Date): string => {
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

/** Today's YYYY-MM-DD in a named IANA timezone (en-CA formats as YYYY-MM-DD). */
export const getTZISODate = (tz: string, now: Date = new Date()): string => {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: tz,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(now)
}

/** A new Date `n` calendar days from `d` (negative to go back). */
export const addDays = (d: Date, n: number): Date => {
  const out = new Date(d)
  out.setDate(out.getDate() + n)
  return out
}
