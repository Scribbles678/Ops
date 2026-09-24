/**
 * Someone's time on the floor for one day, in 15-minute slots (index = minute / 15):
 * their shift, minus lunch and both breaks, minus every absence — read through
 * describePto, the one place that knows how each kind of time off is stored.
 *
 * The schedule builder carves out exactly this inline in prepare() (its
 * `shiftShape.workable` and `free` arrays). prepare() should call this instead;
 * that move is waiting for the in-progress builder work in prepare.ts to settle.
 * Until then a change to either rule must be made to both.
 */
import { describePto, type PtoDescription } from './ptoDisplay'
import { fillSlots, toMinutes } from './scheduleEngineV2/slots'
import { SLOTS_PER_DAY } from './scheduleEngineV2/types'

export interface WorkableSlots {
  /** The shift minus lunch and breaks, before any time off. 1 = working slot. */
  onShift: Uint8Array
  /** onShift minus absences: the time that can actually be scheduled. All 0 when off all day. */
  free: Uint8Array
}

/** Null when the shift has no usable start/end. */
export function workableSlots(shift: any, ptoRows: any[] = []): WorkableSlots | null {
  const start = toMinutes(shift?.start_time)
  let end = toMinutes(shift?.end_time)
  if (start == null || end == null) return null
  if (end <= start) end += 1440 // crosses midnight

  const onShift = new Uint8Array(SLOTS_PER_DAY)
  fillSlots(onShift, start, end, 1)
  for (const [a, b] of [
    [shift.lunch_start, shift.lunch_end],
    [shift.break_1_start, shift.break_1_end],
    [shift.break_2_start, shift.break_2_end],
  ]) {
    const s = toMinutes(a)
    const t = toMinutes(b)
    if (s != null && t != null && t > s) fillSlots(onShift, s, t, 0)
  }

  const free = Uint8Array.from(onShift)
  const absences = ptoRows
    .map((row) => describePto(row))
    .filter((d): d is PtoDescription => d != null)
  if (absences.some((d) => d.allDay)) free.fill(0)
  else for (const d of absences) fillSlots(free, d.startMin, d.endMin, 0)

  return { onShift, free }
}
