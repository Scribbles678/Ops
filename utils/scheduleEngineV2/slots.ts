/**
 * Slot arithmetic for Schedule Engine V2.
 *
 * Everything downstream works in integer slot indices, so there is no time-string
 * parsing in the hot path and no "HH:MM" vs "HH:MM:SS" key mismatches — a class
 * of bug the hourly model was prone to.
 */
import { SLOT_MINUTES, SLOTS_PER_DAY } from './types'

/** "HH:MM[:SS]" -> minutes past midnight. Returns null if unparseable. */
export const toMinutes = (t: string | null | undefined): number | null => {
  if (!t) return null
  const parts = String(t).split(':')
  const h = Number(parts[0])
  const m = Number(parts[1] ?? 0)
  if (Number.isNaN(h) || Number.isNaN(m)) return null
  return h * 60 + m
}

/** Minutes past midnight -> "HH:MM". */
export const toTime = (minutes: number): string => {
  const wrapped = ((minutes % 1440) + 1440) % 1440
  const h = Math.floor(wrapped / 60)
  const m = wrapped % 60
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`
}

/** Slot index containing this minute. */
export const slotOf = (minutes: number): number => Math.floor(minutes / SLOT_MINUTES)

/** First slot fully at/after this minute (for exclusive ends). */
export const slotCeil = (minutes: number): number => Math.ceil(minutes / SLOT_MINUTES)

export const slotToMinutes = (slot: number): number => slot * SLOT_MINUTES
export const slotToTime = (slot: number): string => toTime(slotToMinutes(slot))

/**
 * Mark [startMin, endMin) in a slot array. Handles overnight wrap by splitting.
 * Partial slots are marked — a break from 19:00-19:15 occupies exactly one slot,
 * but a 10-minute oddity still consumes its slot rather than silently vanishing.
 */
export const fillSlots = (arr: Uint8Array, startMin: number, endMin: number, value: number): void => {
  if (endMin <= startMin) return
  let s = slotOf(startMin)
  let e = slotCeil(endMin)
  for (let i = s; i < e; i++) arr[((i % SLOTS_PER_DAY) + SLOTS_PER_DAY) % SLOTS_PER_DAY] = value
}

/** Contiguous runs of slots satisfying `pred`, as [start, end) pairs. */
export const runsWhere = (
  length: number,
  pred: (slot: number) => boolean
): { start: number; end: number }[] => {
  const runs: { start: number; end: number }[] = []
  let start = -1
  for (let i = 0; i < length; i++) {
    if (pred(i)) {
      if (start < 0) start = i
    } else if (start >= 0) {
      runs.push({ start, end: i })
      start = -1
    }
  }
  if (start >= 0) runs.push({ start, end: length })
  return runs
}

/** Longest sub-run of [start,end) where the employee is free. */
export const longestFreeRun = (
  free: Uint8Array,
  start: number,
  end: number
): { start: number; end: number } | null => {
  let best: { start: number; end: number } | null = null
  let cur = -1
  for (let i = start; i <= end; i++) {
    const isFree = i < end && free[i] === 1
    if (isFree) {
      if (cur < 0) cur = i
    } else if (cur >= 0) {
      if (!best || i - cur > best.end - best.start) best = { start: cur, end: i }
      cur = -1
    }
  }
  return best
}

export const slotsToMinutesLength = (startSlot: number, endSlot: number): number =>
  (endSlot - startSlot) * SLOT_MINUTES
