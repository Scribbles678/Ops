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

/**
 * Shortest block the ENGINE will ever produce.
 *
 * Deliberately 30, not 15. The engine *can* work at quarter-hour resolution, and
 * briefly did — but auto-generated 15-minute assignments turned out to create more
 * hand-correction than they saved, so the builder now only ever emits half-hour
 * blocks or longer.
 */
export const ENGINE_MIN_BLOCK_MINUTES = 30

/**
 * Shortest block the DATABASE accepts (migration 017).
 *
 * Deliberately LOWER than the engine floor: a supervisor can still make 15-minute
 * tweaks by hand after a build. Do not "tidy" this up to match the engine — the
 * gap between the two numbers is the feature.
 */
export const DB_MIN_BLOCK_MINUTES = 15

/**
 * Below this a block is "short" and pays a cost penalty. Currently equal to the
 * engine floor, so the penalty is inert; it stays wired up so shorter blocks can
 * be re-enabled by lowering ENGINE_MIN_BLOCK_MINUTES alone.
 */
export const PREFERRED_MIN_MINUTES = 30

export interface EngineEmployee {
  id: string
  /** "Last, First" - for lists and the schedule grid, where it sorts correctly. */
  name: string
  /** "First Last" - for messages that read as a sentence. */
  displayName: string
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
  /**
   * 1 where a shortfall COUNTS; 0 inside any shift's break or lunch window. The
   * floor does not expect a job staffed through a 15-minute break or lunch, so
   * those shortfalls are neither scored, chased nor reported. Demand itself is
   * left intact so placement still spans the window.
   *
   * Per-job "keep covered during breaks / through lunch" flags existed Sep 2026
   * and were removed: on real data they never made the builder cover more (the
   * trained people were simply not on shift then); they only added warnings.
   */
  mustCover: Uint8Array
  /** trainedSupply / totalDemand — lower means harder to staff. */
  scarcity: number
  /**
   * Business priority: 1 = fill first, 5 = drop first (default 3).
   * Leads the fill order; scarcity breaks ties within a priority band.
   */
  priority: number
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
  | 'surplus-under-target'
  | 'surplus-overflow'
  | 'surplus-continuation'

/** Why a slot could not be covered. Answers "why is this cell empty?". */
export type GapCause =
  /** More work was asked for than there were people on the floor. No schedule can fix it. */
  | 'floor-short'
  /** Nobody on the team is trained for the job at all. */
  | 'no-one-trained'
  /** People are trained, but none of them is on the floor at that time. */
  | 'no-one-trained-on-shift'
  | 'all-trained-busy'
  | 'capped'
  | 'no-availability'

/** Where in the app a person goes to fix an action. The review modal links there. */
export type FixPlace = 'rules-and-targets' | 'required-assignments' | 'employees' | 'job-functions' | 'shifts'

/** Something a person must change in the app, and where to change it. */
export interface EngineAction {
  message: string
  fix?: FixPlace
}

export interface EngineGap {
  functionId: string
  functionName: string
  /** "HH:MM" of the slot start, for display. */
  time: string
  startSlot: number
  endSlot: number
  /** The most people short at any moment in the gap. */
  shortfall: number
  /** Headcount-hours short across the whole gap, every 15 minutes added up. */
  hours: number
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
  /** surplus = most people over target at once; hours = headcount-hours over, added up. */
  overTarget: { functionName: string; time: string; surplus: number; hours: number }[]
  /** Produced BEFORE any assignment, so impossible targets are named up front. */
  feasibility: FeasibilityIssue[]
  /**
   * Things a PERSON must go and fix in the app - missing training, an unassigned
   * shift, a stale target cell. Kept separate from `warnings` so the review modal
   * can lead with them instead of burying them among informational notes. Each
   * says where to fix it, so the modal can link straight there.
   */
  actions: EngineAction[]
  /** Informational only. Nothing for anyone to do. */
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
   * Reward per priority step above the lowest. Large enough that a high-priority
   * function outbids a low-priority one for the same person, but not so large it
   * overrides genuine unmet demand.
   */
  priority: number
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
  priority: 45,
}

/** Lowest (worst) priority value; used to convert priority into a reward. */
export const LOWEST_PRIORITY = 5
