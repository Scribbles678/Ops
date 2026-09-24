/**
 * Which clock hours a shift works. Shared by the Staffing Targets grid (its hour
 * columns and "On shift" row) and Team Setup → Training Matrix, so the two count
 * people on shift the same way.
 *
 * An hour counts when any part of it is worked: a 07:00-14:30 shift covers 7AM
 * through 2PM, because the 2PM column means 14:00-15:00 and half of it is staffed.
 * A shift that ends at or before its start crosses midnight.
 */

// Not exported: utils/validationRules.ts already exports a `timeToMinutes`, and a
// second auto-imported name would change which one other files pick up.
const minutesOf = (t: string | null | undefined): number | null => {
  if (!t) return null
  const parts = String(t).split(':')
  const h = Number(parts[0])
  const m = Number(parts[1] ?? 0)
  if (Number.isNaN(h) || Number.isNaN(m)) return null
  return h * 60 + m
}

/** The hours (0-23) a shift works any part of; empty when its times are missing. */
export const shiftHours = (shift: { start_time?: string | null; end_time?: string | null }): number[] => {
  const start = minutesOf(shift.start_time)
  let end = minutesOf(shift.end_time)
  if (start == null || end == null) return []
  if (end <= start) end += 24 * 60 // crosses midnight
  const hours: number[] = []
  for (let h = Math.floor(start / 60); h <= Math.ceil(end / 60) - 1; h++) hours.push(((h % 24) + 24) % 24)
  return hours
}
