/**
 * Single source of truth for PTO-hour accounting.
 *
 * Both the auto-approval rule (server/api/schedule-requests/index.post.ts) and the
 * availability strip (via /api/pto/availability) run through these helpers. Keep it
 * that way — the two used to compute hours independently and drifted apart, which is
 * what made the "hours left" display disagree with what actually got approved.
 *
 * Hours model: an absence consumes the PAID scheduled hours it removes — the shift
 * span minus the unpaid lunch, clipped to the absence window. Paid 15-minute breaks
 * stay in. For the standard 8.5h-span/30m-lunch shifts a full day is exactly 8.0h,
 * which is what the old hardcoded constant assumed.
 */

/** Minimal shift shape needed to price an absence. */
export interface ShiftInfo {
  start_time: string | null
  end_time: string | null
  lunch_start: string | null
  lunch_end: string | null
}

/** Fallback when an employee has no shift assigned at all. */
const DEFAULT_PAID_MINUTES = 8 * 60

/** "HH:MM[:SS]" -> minutes past midnight. Returns null on anything unparseable. */
export function toMinutes(t: string | null | undefined): number | null {
  if (!t) return null
  const parts = String(t).split(':')
  const h = Number(parts[0])
  const m = Number(parts[1] ?? 0)
  if (Number.isNaN(h) || Number.isNaN(m)) return null
  return h * 60 + m
}

/**
 * Shift bounds as minutes past midnight, with overnight shifts unrolled past 1440
 * so plain numeric comparison works (e.g. 22:00–06:00 becomes 1320–1800).
 */
function shiftBounds(shift: ShiftInfo | null): { start: number; end: number } | null {
  const start = toMinutes(shift?.start_time)
  let end = toMinutes(shift?.end_time)
  if (start === null || end === null) return null
  if (end <= start) end += 24 * 60 // crosses midnight
  return { start, end }
}

/** Overlap in minutes between [aStart,aEnd) and [bStart,bEnd). */
function overlap(aStart: number, aEnd: number, bStart: number, bEnd: number): number {
  return Math.max(0, Math.min(aEnd, bEnd) - Math.max(aStart, bStart))
}

/**
 * Paid minutes of the shift that fall inside [fromMin, toMin) — i.e. the window
 * overlap, less any unpaid lunch inside it.
 */
export function paidMinutesInWindow(
  shift: ShiftInfo | null,
  fromMin: number,
  toMin: number
): number {
  const bounds = shiftBounds(shift)
  if (!bounds) {
    // No usable shift: treat the window itself as paid time, capped at a normal day.
    return Math.min(Math.max(0, toMin - fromMin), DEFAULT_PAID_MINUTES)
  }

  // Unroll the window the same way the shift was, so overnight comparisons line up.
  let from = fromMin
  let to = toMin
  if (bounds.end > 24 * 60) {
    if (from < bounds.start) from += 24 * 60
    if (to <= from) to += 24 * 60
  }

  let minutes = overlap(from, to, bounds.start, bounds.end)

  const lunchStart = toMinutes(shift?.lunch_start)
  const lunchEnd = toMinutes(shift?.lunch_end)
  if (lunchStart !== null && lunchEnd !== null && lunchEnd > lunchStart) {
    let ls = lunchStart
    let le = lunchEnd
    if (bounds.end > 24 * 60 && ls < bounds.start) {
      ls += 24 * 60
      le += 24 * 60
    }
    minutes -= overlap(from, to, ls, le)
  }

  return Math.max(0, minutes)
}

/** Total paid minutes in a full scheduled day for this shift. */
export function paidMinutesFullDay(shift: ShiftInfo | null): number {
  const bounds = shiftBounds(shift)
  if (!bounds) return DEFAULT_PAID_MINUTES
  return paidMinutesInWindow(shift, bounds.start, bounds.end)
}

const round2 = (n: number) => Math.round(n * 100) / 100

/**
 * Hours a schedule_requests row consumes from the team's daily PTO budget.
 *
 *  - pto_full_day  full paid shift
 *  - pto_partial   paid time inside [start_time, end_time]
 *  - leave_early   paid time from start_time (the new end time) to shift end
 *  - arrive_late   paid time from shift start to start_time (the arrival time)
 *  - leave_on_time informational, always 0
 *  - shift_swap    not an absence, always 0
 */
export function hoursForRequest(
  requestType: string,
  startTime: string | null,
  endTime: string | null,
  shift: ShiftInfo | null
): number {
  const bounds = shiftBounds(shift)

  switch (requestType) {
    case 'pto_full_day':
      return round2(paidMinutesFullDay(shift) / 60)

    case 'pto_partial': {
      const s = toMinutes(startTime)
      const e = toMinutes(endTime)
      if (s === null || e === null || e <= s) return 0
      return round2(paidMinutesInWindow(shift, s, e) / 60)
    }

    case 'leave_early': {
      const s = toMinutes(startTime)
      if (s === null) return 0
      // No shift on file: fall back to the legacy flat 2h rather than guessing.
      if (!bounds) return 2
      return round2(paidMinutesInWindow(shift, s, bounds.end) / 60)
    }

    case 'arrive_late': {
      const arrival = toMinutes(startTime)
      if (arrival === null) return 0
      if (!bounds) return 2
      return round2(paidMinutesInWindow(shift, bounds.start, arrival) / 60)
    }

    default:
      return 0 // leave_on_time, shift_swap
  }
}

/**
 * Hours a pto_days row consumes. These come from two places: materialized by an
 * approved request (deduped by the caller via created_pto_id) or entered by hand /
 * logged as a call-in.
 *
 * A call-in, or an untyped row with no times, is a whole missed day — that is the
 * only sane reading of a bare PTO record, and it is what the schedule builder
 * already assumes when it clips the day.
 */
export function hoursForPtoDay(
  ptoType: string | null,
  startTime: string | null,
  endTime: string | null,
  shift: ShiftInfo | null
): number {
  const bounds = shiftBounds(shift)

  switch (ptoType) {
    case 'full_day':
    case 'call_in':
      return round2(paidMinutesFullDay(shift) / 60)

    case 'partial': {
      const s = toMinutes(startTime)
      const e = toMinutes(endTime)
      if (s === null || e === null || e <= s) return 0
      return round2(paidMinutesInWindow(shift, s, e) / 60)
    }

    case 'leave_early': {
      const s = toMinutes(startTime)
      if (s === null) return 0
      if (!bounds) return 2
      return round2(paidMinutesInWindow(shift, s, bounds.end) / 60)
    }

    case 'arrive_late': {
      // Stored as 00:00 -> arrival time; the arrival is in end_time.
      const arrival = toMinutes(endTime)
      if (arrival === null) return 0
      if (!bounds) return 2
      return round2(paidMinutesInWindow(shift, bounds.start, arrival) / 60)
    }

    default: {
      // Unknown/legacy type. Times present -> price the window; otherwise full day.
      const s = toMinutes(startTime)
      const e = toMinutes(endTime)
      if (s !== null && e !== null && e > s) {
        return round2(paidMinutesInWindow(shift, s, e) / 60)
      }
      return round2(paidMinutesFullDay(shift) / 60)
    }
  }
}

/** Request types that draw down the daily PTO-hours budget. */
export const HOUR_CONSUMING_TYPES = ['pto_full_day', 'pto_partial', 'leave_early', 'arrive_late']

const DOW_KEYS = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat']

/**
 * Team-wide PTO-hours cap for a given date.
 *
 * Primary source is the per-weekday JSON setting `max_pto_hours_by_dow`; any weekday
 * missing from it falls back to the legacy scalar `max_pto_hours_per_day`.
 */
export function ptoCapForDate(settings: Record<string, string>, dateStr: string): number {
  const legacy = (() => {
    const v = parseInt(settings['max_pto_hours_per_day'] ?? '', 10)
    return isNaN(v) ? 8 : v
  })()

  const [y, m, d] = dateStr.split('-').map(Number)
  if (!y || !m || !d) return legacy
  const dowName = DOW_KEYS[new Date(y, m - 1, d).getDay()]

  try {
    const raw = settings['max_pto_hours_by_dow']
    if (raw) {
      const map = JSON.parse(raw)
      const v = Number(map?.[dowName])
      if (!isNaN(v) && map?.[dowName] != null) return v
    }
  } catch {
    /* malformed JSON — fall back */
  }
  return legacy
}

const pad = (n: number) => String(n).padStart(2, '0')

/** Local-timezone YYYY-MM-DD. Never use toISOString() for this — it shifts the date. */
export function fmtDate(d: Date): string {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
}

/**
 * Full working days (Mon–Fri) strictly between two dates. A Friday request for
 * Monday therefore gives 0 business days' notice.
 */
export function countBusinessDaysBetween(from: Date, to: Date): number {
  let count = 0
  const d = new Date(from.getFullYear(), from.getMonth(), from.getDate())
  d.setDate(d.getDate() + 1) // strictly after `from`
  const end = new Date(to.getFullYear(), to.getMonth(), to.getDate())
  while (d < end) {
    const dow = d.getDay()
    if (dow !== 0 && dow !== 6) count++
    d.setDate(d.getDate() + 1)
  }
  return count
}
