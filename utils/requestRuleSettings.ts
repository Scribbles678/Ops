/**
 * The Request Rules a team can set (Settings → Request rules), and what each accepts.
 * ONE definition, used by the form to check a box as it's typed in and by
 * POST /api/team-settings to refuse a bad value — so the two can't disagree.
 *
 * Until Oct 2026 the server stored whatever it was sent. A cleared weekday box was
 * saved as "" and read back as a 0-hour limit, so every time-off request that
 * weekday was auto-rejected while the box just looked empty; "-1 shift changes a
 * day" was stored too, and refused every shift change. The rule engine that reads
 * these is server/utils/requestRules.ts (+ ptoCapForDate in ptoHours.ts).
 */

export const WEEKDAYS = [
  { key: 'mon', label: 'Mon', name: 'Monday' },
  { key: 'tue', label: 'Tue', name: 'Tuesday' },
  { key: 'wed', label: 'Wed', name: 'Wednesday' },
  { key: 'thu', label: 'Thu', name: 'Thursday' },
  { key: 'fri', label: 'Fri', name: 'Friday' },
  { key: 'sat', label: 'Sat', name: 'Saturday' },
  { key: 'sun', label: 'Sun', name: 'Sunday' },
] as const
export type WeekdayKey = (typeof WEEKDAYS)[number]['key']

/** Most requests a count rule may allow; far above any real team, low enough to catch a typo. */
export const MAX_RULE_COUNT = 1000
/** Longest advance notice, in business days: about a working year. */
export const MAX_NOTICE_DAYS = 260
/** Most team-wide time-off hours a day may allow. */
export const MAX_DAY_HOURS = 10000
/** Hours are entered in quarter hours, like Target Hours on Team Setup. */
const QUARTERS_PER_HOUR = 4

/**
 * What applies while a team has never saved a rule. The rule engine and the form
 * both read these, so the form shows exactly what's in effect. The day-hours
 * default is team-wide: a new team auto-rejects the second full day off on a date
 * until its rules are saved.
 */
export const DEFAULT_DAY_HOURS = 8
export const RULE_DEFAULTS = {
  max_shift_swaps_per_day: 3,
  max_shift_change_per_employee_per_week: 1,
  max_leave_on_time_per_employee_per_week: 5,
  min_business_days_notice: 1,
} as const

type RuleKind = 'count' | 'optionalCount' | 'notice' | 'hoursByWeekday'

export const REQUEST_RULES = {
  max_pto_hours_by_dow: { kind: 'hoursByWeekday', label: 'Max time-off hours per day' },
  max_shift_swaps_per_day: { kind: 'count', label: 'Shift changes per day' },
  max_leave_on_time_per_day: { kind: 'optionalCount', label: 'Leave-on-time requests per day' },
  max_shift_change_per_employee_per_week: { kind: 'count', label: 'Shift changes per week per employee' },
  max_leave_early_per_employee_per_week: { kind: 'optionalCount', label: 'Leave-early requests per week per employee' },
  max_leave_on_time_per_employee_per_week: { kind: 'count', label: 'Leave-on-time requests per week per employee' },
  min_business_days_notice: { kind: 'notice', label: 'Advance notice' },
} as const satisfies Record<string, { kind: RuleKind; label: string }>
export type RuleKey = keyof typeof REQUEST_RULES

export const isRuleKey = (key: unknown): key is RuleKey =>
  typeof key === 'string' && Object.prototype.hasOwnProperty.call(REQUEST_RULES, key)

const blank = (v: unknown) => v == null || String(v).trim() === ''
const wholeNumber = (v: unknown): number | null => {
  const s = String(v).trim()
  return /^\d+$/.test(s) ? Number(s) : null
}

/** One weekday's hours box: a sentence saying what's wrong, or null when it's fine. */
export function weekdayHoursProblem(day: WeekdayKey, value: unknown): string | null {
  const name = WEEKDAYS.find((d) => d.key === day)?.name ?? day
  if (blank(value)) return `${name}: enter a number of hours (0 means no time off that day).`
  const s = String(value).trim()
  const n = Number(s)
  if (!/^\d+(\.\d+)?$/.test(s) || n > MAX_DAY_HOURS) {
    return `${name}: enter hours from 0 to ${MAX_DAY_HOURS.toLocaleString('en-US')}.`
  }
  if (Math.round(n * QUARTERS_PER_HOUR) !== n * QUARTERS_PER_HOUR) {
    return `${name}: use quarter hours (for example 7.5 or 7.25).`
  }
  return null
}

/** The whole value for `key`: a sentence saying what's wrong, or null when it's fine. */
export function ruleProblem(key: RuleKey, value: unknown): string | null {
  const { kind, label } = REQUEST_RULES[key]
  switch (kind) {
    case 'count': {
      const n = wholeNumber(value)
      return n == null || n > MAX_RULE_COUNT ? `${label}: enter a whole number from 0 to ${MAX_RULE_COUNT}.` : null
    }
    case 'optionalCount': {
      if (blank(value)) return null
      const n = wholeNumber(value)
      return n == null || n > MAX_RULE_COUNT
        ? `${label}: enter a whole number from 0 to ${MAX_RULE_COUNT}, or leave it blank for no limit.`
        : null
    }
    case 'notice': {
      const n = wholeNumber(value)
      return n == null || n > MAX_NOTICE_DAYS
        ? `${label}: enter a whole number of business days from 0 to ${MAX_NOTICE_DAYS}.`
        : null
    }
    case 'hoursByWeekday': {
      let map: unknown = value
      if (typeof value === 'string') {
        try { map = JSON.parse(value) } catch { map = null }
      }
      if (!map || typeof map !== 'object') return `${label}: enter hours for every day of the week.`
      for (const d of WEEKDAYS) {
        const problem = weekdayHoursProblem(d.key, (map as Record<string, unknown>)[d.key])
        if (problem) return problem
      }
      return null
    }
  }
}

/**
 * The text stored in team_settings.setting_value. Call only once ruleProblem() has
 * returned null. A blank optional limit is stored as '' — the rule engine reads
 * blank as "no limit" (getOptionalSetting in requestRules.ts).
 */
export function ruleStoredValue(key: RuleKey, value: unknown): string {
  const { kind } = REQUEST_RULES[key]
  if (kind === 'hoursByWeekday') {
    const map = (typeof value === 'string' ? JSON.parse(value) : value) as Record<string, unknown>
    return JSON.stringify(Object.fromEntries(WEEKDAYS.map((d) => [d.key, Number(String(map[d.key]).trim())])))
  }
  if (kind === 'optionalCount' && blank(value)) return ''
  return String(Number(String(value).trim()))
}
