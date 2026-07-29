/**
 * Schedule Engine V2 — shared types.
 *
 * V2 models the day as 96 fifteen-minute slots rather than 24 hourly buckets.
 * That is the whole point of the rewrite: coverage cliffs caused by a shift
 * breaking together are 15-minute events, and an hourly model cannot represent
 * them, let alone fill them.
 */

/** Minutes per slot. The schedule grid already renders at this granularity. */
export const SLOT_MINUTES = 15
/** 24h / 15min. Overnight shifts wrap via modulo. */
export const SLOTS_PER_DAY = 96

/** Minimum length the DB will accept (migration 017 lowered this from 30). */
export const MIN_ASSIGNMENT_MINUTES = 15
/** Below this, a block is considered "short" and pays a cost penalty. */
export const PREFERRED_MIN_MINUTES = 30

export interface EngineEmployee {
  id: string
  name: string
  shiftId: string | null
  /** 1 = free to be assigned in this slot. Length SLOTS_PER_DAY. */
  free: Uint8Array
  /** Job function ids this employee may work (Meter parents already resolved). */
  trained: Set<string>
  /** Total slots they are on the clock, for idle reporting. */
  onClockSlots: number
}

export interface EngineFunction {
  id: string
  name: string
  /** Required headcount per slot. Length SLOTS_PER_DAY. */
  demand: Int16Array
  /** Assigned headcount per slot. Length SLOTS_PER_DAY. */
  covered: Int16Array
  /** Per-slot ceiling; null = unlimited. */
  maxHeadcount: number | null
  /** Preferred sink for surplus labour. */
  isOverflow: boolean
  /** Functions excluded from targets are not gap-reported. */
  excludeFromTargets: boolean
  /** trainedSupply / totalDemand — lower means harder to staff. */
  scarcity: number
}

export interface EngineAssignment {
  employeeId: string
  functionId: string
  /** Inclusive start slot, exclusive end slot. */
  startSlot: number
  endSlot: number
  /** Why this assignment exists — the explainability layer. */
  reason: AssignmentReason
}

export type AssignmentReason =
  | 'required-pin'
  | 'coverage'
  | 'cliff-patch'
  | 'surplus-under-target'
  | 'surplus-overflow'
  | 'surplus-continuation'

/** Why a slot could not be covered. Answers "why is this cell empty?". */
export type GapCause =
  | 'no-one-trained-on-shift'
  | 'all-trained-busy'
  | 'capped'
  | 'no-availability'

export interface EngineGap {
  functionId: string
  functionName: string
  /** "HH:MM" of the slot start, for display. */
  time: string
  startSlot: number
  endSlot: number
  shortfall: number
  cause: GapCause
  detail: string
}

export interface FeasibilityIssue {
  functionName: string
  time: string
  required: number
  trainedAvailable: number
  detail: string
}

export interface EngineResult {
  assignments: EngineAssignment[]
  gaps: EngineGap[]
  overTarget: { functionName: string; time: string; surplus: number }[]
  /** Produced BEFORE any assignment, so impossible targets are named up front. */
  feasibility: FeasibilityIssue[]
  warnings: string[]
  stats: {
    slotsAvailable: number
    slotsAssigned: number
    idleSlots: number
    employeesWithNoWork: number
    functionsPerPerson: Record<number, number>
    shortBlocks: number
  }
}

/** Tunable weights. One place where every trade-off lives. */
export interface EngineWeights {
  /** Reward per unmet slot closed. */
  unmet: number
  /** Cost of introducing a function the employee isn't already on. */
  newFunction: number
  /** Cost per distinct function beyond the comfortable count, squared. */
  functionCount: number
  /** Comfortable number of distinct functions per person per day. */
  comfortableFunctions: number
  /** Cost per minute a block falls short of PREFERRED_MIN_MINUTES. */
  shortBlock: number
  /** Reward for extending an adjacent block of the same function. */
  adjacent: number
  /** Reward for a preferred assignment. */
  preferred: number
  /** Reward scaled by how scarce the function's trained supply is. */
  scarce: number
  /**
   * Cost per slot consumed that was ALREADY covered. Without this the engine
   * happily spends a whole shift on a function that only needed the first hour,
   * burning labour that a later, tighter hour then can't get.
   */
  waste: number
  /**
   * Cost proportional to how many functions the employee could otherwise do.
   * Spends specialists first and keeps multi-skilled people free for whichever
   * hole appears next — the single biggest lever in a tight day.
   */
  flexibility: number
}

export const DEFAULT_WEIGHTS: EngineWeights = {
  unmet: 100,
  newFunction: 60,
  functionCount: 40,
  comfortableFunctions: 2,
  shortBlock: 4,
  adjacent: 80,
  preferred: 25,
  scarce: 30,
  waste: 25,
  flexibility: 3,
}
