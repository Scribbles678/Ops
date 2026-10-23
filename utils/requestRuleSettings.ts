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

/**
 * Saturday and Sunday count only at a site that works them (open_weekend_days).
 * Monday to Friday always do. A closed day is skipped in a multi-day request and a
 * request for it alone is refused — the sites are Mon–Fri, and a weekend day in a
 * two-week stretch used to be charged a full shift against the Sat/Sun limits.
 */
export const WEEKEND_KEYS = ['sat', 'sun'] as const
export type WeekendKey = (typeof WEEKEND_KEYS)[number]

/** The weekend days a team works, from its setting: '' (none — the default), 'sat', 'sun' or 'sat,sun'. */
export function openWeekendDays(raw: unknown): WeekendKey[] {
  const parts = (Array.isArray(raw) ? raw : String(raw ?? '').split(',')).map((p) => String(p).trim())
  return WEEKEND_KEYS.filter((k) => parts.includes(k))
}

/** 'mon' … 'sun' for a YYYY-MM-DD. */
export function weekdayOf(ymd: string): WeekdayKey {
  const [y = 0, m = 1, d = 1] = ymd.split('-').map(Number)
  return (['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'] as const)[new Date(y, m - 1, d).getDay()]!
}

/** Does the site work on `ymd`, given the weekend days it works? */
export function isWorkingDay(ymd: string, open: readonly WeekendKey[]): boolean {
  const day = weekdayOf(ymd)
  return day === 'sat' || day === 'sun' ? open.includes(day) : true
}

/** Why a request for a day the site doesn't work is refused. */
export const closedDayMessage = (ymd: string): string => {
  const name = WEEKDAYS.find((d) => d.key === weekdayOf(ymd))?.name ?? 'That day'
  return `${name}s aren't working days at this site, so there's no time off or schedule change to ask for.`
}

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

/**
 * Whether a day of someone's leave of absence (employee_leaves) uses up the daily
 * time-off limit, priced like a full day off. Off unless a supervisor turns it on,
 * so teams' limits behave as they did before leaves existed (server/utils/ptoUsage.ts).
 */
export const countsLeaveInLimit = (raw: unknown): boolean => String(raw ?? '').trim() === 'true'

type RuleKind = 'count' | 'optionalCount' | 'notice' | 'hoursByWeekday' | 'weekendDays' | 'onOff'

export const REQUEST_RULES = {
  max_pto_hours_by_dow: { kind: 'hoursByWeekday', label: 'Max time-off hours per day' },
  open_weekend_days: { kind: 'weekendDays', label: 'Weekend days the site works' },
  count_leave_in_pto_limit: { kind: 'onOff', label: 'Count leave of absence toward the daily limit' },
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

/**
 * The whole value for `key`: a sentence saying what's wrong, or null when it's fine.
 * The hours check needs the weekend days the site works: a closed day has no limit
 * to fill in (without `openWeekend`, all seven are checked).
 */
export function ruleProblem(key: RuleKey, value: unknown, openWeekend: readonly WeekendKey[] = WEEKEND_KEYS): string | null {
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
        if ((d.key === 'sat' || d.key === 'sun') && !openWeekend.includes(d.key)) continue
        const problem = weekdayHoursProblem(d.key, (map as Record<string, unknown>)[d.key])
        if (problem) return problem
      }
      return null
    }
    case 'weekendDays': {
      const parts = (Array.isArray(value) ? value : String(value ?? '').split(',')).map((p) => String(p).trim()).filter(Boolean)
      return parts.every((p) => (WEEKEND_KEYS as readonly string[]).includes(p))
        ? null
        : `${label}: Saturday, Sunday, both or neither.`
    }
    case 'onOff':
      return value === true || value === false || value === 'true' || value === 'false' ? null : `${label}: on or off.`
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
    // Every day that has a valid number: all the open ones (ruleProblem checked them),
    // and a closed weekend day only if it still carries one, ready for reopening.
    const kept = WEEKDAYS.filter((d) => !blank(map[d.key]) && weekdayHoursProblem(d.key, map[d.key]) === null)
    return JSON.stringify(Object.fromEntries(kept.map((d) => [d.key, Number(String(map[d.key]).trim())])))
  }
  if (kind === 'weekendDays') return openWeekendDays(value).join(',')
  if (kind === 'onOff') return String(value).trim() === 'true' ? 'true' : 'false'
  if (kind === 'optionalCount' && blank(value)) return ''
  return String(Number(String(value).trim()))
}
