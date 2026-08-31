/**
 * How a PTO record should be READ and DISPLAYED.
 *
 * The storage conventions are not self-describing, so anything reading
 * start_time/end_time literally gets two of the four types wrong:
 *
 *   partial      start_time .. end_time          (both set)
 *   leave_early  start_time = when they LEAVE,   end_time is NULL
 *   arrive_late  start_time = '00:00:00',        end_time = when they ARRIVE
 *   full_day     both NULL
 *   call_in      both NULL (unplanned)
 *
 * Read literally, leave_early renders as "4:02 PM – " and arrive_late as
 * "12:00 AM – 9:38 AM". This module is the single place that knows better; the
 * PTO calendar, the display board and anything future should use it rather than
 * keeping their own copy.
 */

export const MINUTES_IN_DAY = 1440

/** "HH:MM[:SS]" -> minutes past midnight, or null. */
export const ptoTimeToMinutes = (t: string | null | undefined): number | null => {
  if (!t) return null
  const parts = String(t).split(':')
  const h = Number(parts[0])
  const m = Number(parts[1] ?? 0)
  if (Number.isNaN(h) || Number.isNaN(m)) return null
  return h * 60 + m
}

/** Minutes past midnight -> "9:38 AM". */
export const formatTimeOfDay = (minutes: number): string => {
  const wrapped = ((minutes % MINUTES_IN_DAY) + MINUTES_IN_DAY) % MINUTES_IN_DAY
  const h = Math.floor(wrapped / 60)
  const m = wrapped % 60
  const ampm = h >= 12 ? 'PM' : 'AM'
  const hr = h % 12 === 0 ? 12 : h % 12
  return `${hr}:${String(m).padStart(2, '0')} ${ampm}`
}

export interface PtoDescription {
  /** Short board label: OFF / LEAVES / ARRIVES. */
  label: string
  /** Human time text appropriate to the type. */
  timeText: string
  /** The absence window, in minutes past midnight. */
  startMin: number
  endMin: number
  /** True when the person is out for the entire day. */
  allDay: boolean
}

/**
 * Interpret a pto_days row. Returns null if it can't be made sense of, so callers
 * can skip rather than render something misleading.
 */
export function describePto(pto: any): PtoDescription | null {
  if (!pto) return null
  const type = pto.pto_type ?? null
  const start = ptoTimeToMinutes(pto.start_time)
  const end = ptoTimeToMinutes(pto.end_time)

  if (type === 'full_day' || type === 'call_in' || (start == null && end == null)) {
    return {
      label: type === 'call_in' ? 'CALL-IN' : 'OFF',
      timeText: 'All day',
      startMin: 0,
      endMin: MINUTES_IN_DAY,
      allDay: true,
    }
  }

  if (type === 'leave_early') {
    if (start == null) return null
    return {
      label: 'LEAVES',
      timeText: formatTimeOfDay(start),
      startMin: start,
      endMin: MINUTES_IN_DAY,
      allDay: false,
    }
  }

  if (type === 'arrive_late') {
    // The arrival time lives in end_time; start_time is a placeholder '00:00:00'.
    if (end == null) return null
    return {
      label: 'ARRIVES',
      timeText: formatTimeOfDay(end),
      startMin: 0,
      endMin: end,
      allDay: false,
    }
  }

  // partial, or an untyped legacy row that carries both times
  if (start != null && end != null && end > start) {
    return {
      label: 'OFF',
      timeText: `${formatTimeOfDay(start)} – ${formatTimeOfDay(end)}`,
      startMin: start,
      endMin: end,
      allDay: false,
    }
  }

  // A single time with no type is ambiguous — treat it as leaving at that time,
  // which matches how leave_early is stored.
  if (start != null && end == null) {
    return {
      label: 'LEAVES',
      timeText: formatTimeOfDay(start),
      startMin: start,
      endMin: MINUTES_IN_DAY,
      allDay: false,
    }
  }

  return null
}

/**
 * Human label for a pto_days.pto_type / request kind: "Full Day", "Call-In", ...
 *
 * Lives here rather than in a component because the PTO calendar kept its own
 * copy of this map and it drifted — `call_in` was missing, so a called-in
 * employee rendered as the raw string "call_in" on the board.
 *
 * The fallback title-cases anything unrecognised, so a type added by a future
 * migration reads as words rather than a database enum.
 */
export function ptoTypeLabel(type: string | null | undefined): string {
  const labels: Record<string, string> = {
    full_day: 'Full Day',
    partial: 'Partial Day',
    leave_early: 'Leave Early',
    arrive_late: 'Arrive Late',
    call_in: 'Call-In',
  }
  if (!type) return 'PTO'
  return labels[type] ?? type.replace(/_/g, ' ').replace(/\b\w/g, (ch) => ch.toUpperCase())
}

/** Longer phrasing for tables: "leaves 4:02 PM", "8:00 AM – 10:00 AM". */
export function ptoTimeLabel(pto: any): string {
  const d = describePto(pto)
  if (!d) return ''
  if (d.allDay) return ''
  if (d.label === 'LEAVES') return `leaves ${d.timeText}`
  if (d.label === 'ARRIVES') return `arrives ${d.timeText}`
  return d.timeText
}

/**
 * Subtract absence windows from an assignment, returning the parts actually
 * worked. An assignment overlapping PTO must be TRIMMED, not dropped — dropping
 * it hides real working time from the board.
 */
export function subtractPto(
  assignStart: number,
  assignEnd: number,
  windows: { startMin: number; endMin: number }[]
): { start: number; end: number }[] {
  let pieces = [{ start: assignStart, end: assignEnd }]
  for (const w of windows) {
    const next: { start: number; end: number }[] = []
    for (const p of pieces) {
      if (w.endMin <= p.start || w.startMin >= p.end) { next.push(p); continue }
      if (w.startMin > p.start) next.push({ start: p.start, end: w.startMin })
      if (w.endMin < p.end) next.push({ start: w.endMin, end: p.end })
    }
    pieces = next
  }
  return pieces.filter((p) => p.end > p.start)
}
