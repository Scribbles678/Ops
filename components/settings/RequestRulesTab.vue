<template>
  <div class="grid gap-6 lg:grid-cols-[minmax(0,3fr)_minmax(0,2fr)]">
    <!-- ===== Request rules ===== -->
    <section class="rounded-lg bg-white p-6 shadow" aria-labelledby="rules-title">
      <h2 id="rules-title" class="text-lg font-semibold text-gray-900">
        Request rules<span v-if="teamName" class="font-normal text-gray-500"> — {{ teamName }}</span>
      </h2>
      <p class="mb-4 mt-1 text-sm text-gray-500">
        Requests from the kiosk and the PTO calendar are approved or rejected the moment they're submitted, by these limits.
      </p>

      <p v-if="state === 'loading'" class="text-sm text-gray-500">Loading the rules…</p>

      <div v-else-if="state === 'error'" role="alert" class="rounded-md border border-red-200 bg-red-50 p-4 text-sm text-red-700">
        <p>Couldn't load this team's rules: {{ loadError }}</p>
        <p class="mt-1">Saving is off until they load, so the real rules can't be overwritten with defaults.</p>
        <button type="button" class="mt-2 font-medium underline" @click="load">Retry</button>
      </div>

      <form v-else novalidate class="space-y-6" @submit.prevent="save">
        <p v-if="neverSaved" class="rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-800">
          These rules have never been saved for this team, so the defaults below are in effect — including a limit of
          <strong>{{ DEFAULT_DAY_HOURS }} hours of time off per day for the whole team</strong>, which auto-rejects the
          second full day off on any date. Check them and press <strong>Save rules</strong>.
        </p>

        <!-- Hours per weekday -->
        <fieldset>
          <legend class="text-sm font-semibold text-gray-900">Time off per day, whole team (hours)</legend>
          <p class="mt-0.5 text-xs text-gray-500">
            Approved requests plus time off entered on the schedule page and call-ins, each counted at the paid hours it removes. 0 means no time off that day.
          </p>
          <div class="mt-2 grid grid-cols-4 gap-2 sm:grid-cols-7">
            <div v-for="d in WEEKDAYS" :key="d.key">
              <label :for="`hours-${d.key}`" class="mb-1 block text-xs font-medium text-gray-500">{{ d.label }}</label>
              <input
                :id="`hours-${d.key}`"
                v-model="hours[d.key]"
                type="number"
                inputmode="decimal"
                min="0"
                step="0.25"
                :aria-invalid="!!hourProblems[d.key]"
                :class="fieldClass(!!hourProblems[d.key])"
              />
            </div>
          </div>
          <ul v-if="hourProblemList.length" class="mt-2 space-y-0.5 text-xs text-red-700">
            <li v-for="p in hourProblemList" :key="p">{{ p }}</li>
          </ul>
        </fieldset>

        <!-- The scalar limits, in three groups -->
        <fieldset v-for="group in GROUPS" :key="group.key">
          <legend class="text-sm font-semibold text-gray-900">{{ group.title }}</legend>
          <div class="mt-2 grid gap-4 sm:grid-cols-2">
            <div v-for="f in fieldsIn(group.key)" :key="f.key">
              <label :for="`rule-${f.key}`" class="mb-1 block text-sm font-medium text-gray-700">{{ f.label }}</label>
              <input
                :id="`rule-${f.key}`"
                v-model="values[f.key]"
                type="number"
                inputmode="numeric"
                min="0"
                step="1"
                :placeholder="f.optional ? 'No limit' : undefined"
                :aria-invalid="!!problems[f.key]"
                :aria-describedby="`rule-${f.key}-hint`"
                :class="fieldClass(!!problems[f.key])"
              />
              <p :id="`rule-${f.key}-hint`" class="mt-1 text-xs" :class="problems[f.key] ? 'text-red-700' : 'text-gray-500'">
                {{ problems[f.key] || f.hint }}
              </p>
            </div>
          </div>
        </fieldset>

        <p v-if="saveError" role="alert" class="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
          Not saved: {{ saveError }}
        </p>

        <div class="flex flex-wrap items-center justify-end gap-3 border-t border-gray-100 pt-4">
          <span v-if="dirty" class="mr-auto text-sm text-amber-700">Unsaved changes</span>
          <button
            v-if="dirty"
            type="button"
            :disabled="saving"
            class="rounded-md border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 disabled:opacity-50"
            @click="undo"
          >Undo changes</button>
          <button
            type="submit"
            :disabled="saving || !dirty || hasProblems"
            :title="hasProblems ? 'Fix the boxes marked in red first' : !dirty ? 'Nothing has changed' : undefined"
            class="rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
          >{{ saving ? 'Saving…' : 'Save rules' }}</button>
        </div>
      </form>
    </section>

    <!-- ===== Blocked dates ===== -->
    <section class="rounded-lg bg-white p-6 shadow" aria-labelledby="blocked-title">
      <h2 id="blocked-title" class="text-lg font-semibold text-gray-900">Blocked dates</h2>
      <p class="mb-3 mt-1 text-sm text-gray-500">
        Time-off, leave-early, arrive-late and leave-on-time requests for these dates are rejected automatically. Shift changes aren't affected.
      </p>

      <div class="mb-4 flex flex-wrap gap-2">
        <button type="button" class="rounded-md border border-gray-300 px-3 py-1.5 text-sm hover:bg-gray-50" @click="openSingle">+ Add date</button>
        <button type="button" class="rounded-md border border-gray-300 px-3 py-1.5 text-sm hover:bg-gray-50" @click="openPeriod('quarter')">+ Quarter-end block</button>
        <button type="button" class="rounded-md border border-gray-300 px-3 py-1.5 text-sm hover:bg-gray-50" @click="openPeriod('month')">+ Month-end block</button>
      </div>

      <p v-if="blockedLoadError" role="alert" class="text-sm text-red-700">
        Couldn't load the blocked dates: {{ blockedLoadError }}
        <button type="button" class="ml-1 font-medium underline" @click="loadBlocked">Retry</button>
      </p>
      <template v-else>
        <h3 class="mb-1 text-xs font-semibold uppercase tracking-wide text-gray-500">Upcoming ({{ upcoming.length }})</h3>
        <p v-if="!upcoming.length" class="text-sm italic text-gray-500">No upcoming blocked dates.</p>
        <ul v-else class="divide-y divide-gray-100 rounded-md border border-gray-200">
          <li v-for="bd in upcoming" :key="bd.id" class="flex items-center gap-3 px-3 py-2 text-sm">
            <span class="w-36 shrink-0 text-gray-900">{{ longDate(dayOf(bd)) }}</span>
            <span class="min-w-0 flex-1 truncate text-gray-600" :title="bd.reason || undefined">{{ bd.reason || '—' }}</span>
            <button type="button" class="text-xs text-red-600 hover:text-red-800" @click="removing = bd">Remove</button>
          </li>
        </ul>

        <div v-if="past.length" class="mt-4">
          <button type="button" class="text-sm text-gray-600 underline hover:text-gray-800" :aria-expanded="showPast" @click="showPast = !showPast">
            {{ showPast ? 'Hide' : 'Show' }} {{ past.length }} past date{{ past.length === 1 ? '' : 's' }}
          </button>
          <ul v-if="showPast" class="mt-2 divide-y divide-gray-100 rounded-md border border-gray-200 bg-gray-50">
            <li v-for="bd in past" :key="bd.id" class="flex items-center gap-3 px-3 py-2 text-sm text-gray-500">
              <span class="w-36 shrink-0">{{ longDate(dayOf(bd)) }}</span>
              <span class="min-w-0 flex-1 truncate" :title="bd.reason || undefined">{{ bd.reason || '—' }}</span>
              <button type="button" class="text-xs text-red-600 hover:text-red-800" @click="removing = bd">Remove</button>
            </li>
          </ul>
        </div>
      </template>
    </section>

    <!-- Add one date -->
    <UiModal v-if="showSingle" title="Block a date" size="sm" :busy="adding" @close="showSingle = false">
      <form id="single-date-form" class="space-y-3" @submit.prevent="addSingle">
        <div>
          <label for="single-date" class="mb-1 block text-sm font-medium text-gray-700">Date</label>
          <input id="single-date" v-model="single.date" type="date" class="w-full rounded-md border border-gray-300 px-3 py-2" />
          <p v-if="single.date && blockedDays.has(single.date)" class="mt-1 text-xs text-amber-700">
            Already blocked ({{ blockedDays.get(single.date) || 'no reason' }}).
          </p>
        </div>
        <div>
          <label for="single-reason" class="mb-1 block text-sm font-medium text-gray-700">Reason (optional)</label>
          <input id="single-reason" v-model="single.reason" type="text" placeholder="e.g. Year-end close" class="w-full rounded-md border border-gray-300 px-3 py-2" />
        </div>
        <p v-if="addError" role="alert" class="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">{{ addError }}</p>
      </form>
      <template #footer>
        <button type="button" :disabled="adding" class="rounded-lg border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50" @click="showSingle = false">Cancel</button>
        <button
          type="submit"
          form="single-date-form"
          :disabled="adding || !single.date || blockedDays.has(single.date)"
          class="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
        >{{ adding ? 'Adding…' : 'Block date' }}</button>
      </template>
    </UiModal>

    <!-- Quarter-end / month-end blocks -->
    <UiModal v-if="periodMode" :title="periodMode === 'quarter' ? 'Block quarter-end days' : 'Block month-end days'" :busy="adding" @close="periodMode = null">
      <form id="period-form" class="space-y-3" @submit.prevent="addPeriod">
        <p class="text-sm text-gray-500">
          Blocks the last business days (Mon–Fri) of each {{ periodMode === 'quarter' ? 'quarter' : 'month' }} you tick. Holidays aren't skipped.
        </p>
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label for="period-year" class="mb-1 block text-sm font-medium text-gray-700">Year</label>
            <input id="period-year" v-model.number="period.year" type="number" min="2000" max="2100" class="w-full rounded-md border border-gray-300 px-3 py-2" />
          </div>
          <div>
            <label for="period-days" class="mb-1 block text-sm font-medium text-gray-700">Business days</label>
            <input id="period-days" v-model.number="period.days" type="number" min="1" max="20" class="w-full rounded-md border border-gray-300 px-3 py-2" />
          </div>
        </div>
        <fieldset v-if="periodMode === 'quarter'">
          <legend class="mb-1 text-sm font-medium text-gray-700">Quarters</legend>
          <div class="flex flex-wrap gap-3">
            <label v-for="q in [1, 2, 3, 4]" :key="q" class="flex items-center gap-1.5 text-sm">
              <input v-model="period.quarters" type="checkbox" :value="q" class="h-4 w-4" /> Q{{ q }}
            </label>
          </div>
        </fieldset>
        <fieldset v-else>
          <legend class="mb-1 text-sm font-medium text-gray-700">Months</legend>
          <div class="grid grid-cols-4 gap-1.5">
            <label v-for="m in 12" :key="m" class="flex items-center gap-1 text-sm">
              <input v-model="period.months" type="checkbox" :value="m" class="h-4 w-4" /> {{ MONTHS[m - 1] }}
            </label>
          </div>
          <div class="mt-2 flex gap-3 text-xs">
            <button type="button" class="text-blue-600 hover:text-blue-800" @click="period.months = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]">All</button>
            <button type="button" class="text-gray-500 hover:text-gray-700" @click="period.months = []">None</button>
          </div>
        </fieldset>
        <div>
          <label for="period-reason" class="mb-1 block text-sm font-medium text-gray-700">Reason (optional)</label>
          <input id="period-reason" v-model="period.reason" type="text" class="w-full rounded-md border border-gray-300 px-3 py-2" />
        </div>
        <div v-if="periodDates.length" class="max-h-44 overflow-y-auto rounded-md border border-gray-200 bg-gray-50 p-2">
          <p class="mb-1 text-xs font-medium text-gray-600">
            {{ newPeriodDates.length }} new date{{ newPeriodDates.length === 1 ? '' : 's' }}<template v-if="periodDates.length > newPeriodDates.length">
              · {{ periodDates.length - newPeriodDates.length }} already blocked (they keep their reason)</template>
          </p>
          <ul class="space-y-0.5 text-xs">
            <li v-for="d in periodDates" :key="d" :class="blockedDays.has(d) ? 'text-gray-400' : 'text-gray-700'">
              {{ longDate(d) }}<span v-if="blockedDays.has(d)"> — already blocked</span>
            </li>
          </ul>
        </div>
        <p v-if="addError" role="alert" class="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">{{ addError }}</p>
      </form>
      <template #footer>
        <button type="button" :disabled="adding" class="rounded-lg border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50" @click="periodMode = null">Cancel</button>
        <button
          type="submit"
          form="period-form"
          :disabled="adding || !newPeriodDates.length"
          class="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
        >{{ adding ? 'Adding…' : newPeriodDates.length ? `Block ${newPeriodDates.length} date${newPeriodDates.length === 1 ? '' : 's'}` : 'Nothing new to block' }}</button>
      </template>
    </UiModal>

    <!-- Remove one -->
    <UiConfirmDialog
      v-if="removing"
      title="Remove this blocked date?"
      :message="`${longDate(dayOf(removing))}${removing.reason ? ` (${removing.reason})` : ''} will take requests again.`"
      confirm-label="Remove"
      busy-label="Removing…"
      danger
      :busy="removeBusy"
      :error="removeError"
      @confirm="confirmRemove"
      @cancel="removing = null; removeError = ''"
    />
  </div>
</template>

<script setup lang="ts">
import {
  WEEKDAYS,
  DEFAULT_DAY_HOURS,
  RULE_DEFAULTS,
  ruleProblem,
  weekdayHoursProblem,
  type RuleKey,
  type WeekdayKey,
} from '~/utils/requestRuleSettings'
import { getTZISODate } from '~/utils/localDate'

defineProps<{ teamName: string | null }>()

const { user } = useAuth()
const toast = useToast()
const registry = useSaveRegistry()
const { fetchSettings, saveRules, settings, saving, error: settingsError } = useTeamSettings()

// ---- The form --------------------------------------------------------------------
type ScalarKey = Exclude<RuleKey, 'max_pto_hours_by_dow'>
const GROUPS = [
  { key: 'day', title: 'Whole team, per day' },
  { key: 'week', title: 'Each employee, per week (Mon–Sun)' },
  { key: 'notice', title: 'Notice' },
] as const
const FIELDS: { key: ScalarKey; group: (typeof GROUPS)[number]['key']; label: string; hint: string; optional?: boolean }[] = [
  { key: 'max_shift_swaps_per_day', group: 'day', label: 'Shift changes', hint: 'Shift changes approved per day across the team.' },
  { key: 'max_leave_on_time_per_day', group: 'day', label: 'Leave-on-time requests', hint: 'Blank means no limit.', optional: true },
  { key: 'max_shift_change_per_employee_per_week', group: 'week', label: 'Shift changes', hint: 'Shift changes one employee can have approved in a week.' },
  { key: 'max_leave_early_per_employee_per_week', group: 'week', label: 'Leave-early requests', hint: 'Blank means no limit.', optional: true },
  { key: 'max_leave_on_time_per_employee_per_week', group: 'week', label: 'Leave-on-time requests', hint: '"Leave on time" = decline overtime.' },
  { key: 'min_business_days_notice', group: 'notice', label: 'Advance notice (business days)', hint: "Full working days needed between asking and the day. Weekends don't count: with 1, a Friday request for Monday is rejected." },
]
const fieldsIn = (group: string) => FIELDS.filter((f) => f.group === group)

const state = ref<'loading' | 'ready' | 'error'>('loading')
const loadError = ref('')
const neverSaved = ref(false)
// A type="number" box hands back a number (or '' when empty), so values are compared as text.
type Box = string | number
const hours = ref<Record<WeekdayKey, Box>>(Object.fromEntries(WEEKDAYS.map((d) => [d.key, ''])) as Record<WeekdayKey, Box>)
const values = ref<Record<ScalarKey, Box>>(Object.fromEntries(FIELDS.map((f) => [f.key, ''])) as Record<ScalarKey, Box>)
const savedSnapshot = ref('')
const asText = (o: Record<string, Box>) => Object.fromEntries(Object.entries(o).map(([k, v]) => [k, String(v ?? '').trim()]))
const snapshot = () => JSON.stringify({ hours: asText(hours.value), values: asText(values.value) })

/**
 * The form from the stored settings, showing exactly what the rule engine applies:
 * a rule never saved shows its default, and a blank weekday shows the fallback the
 * cap reader uses (ptoCapForDate). A value stored before Oct 2026 that's no longer
 * allowed (a "-1") is shown as it is, marked red, so it can be fixed.
 */
const fillForm = (stored: Record<string, string>) => {
  const legacy = parseInt(stored.max_pto_hours_per_day ?? '', 10)
  const fallback = String(Number.isNaN(legacy) ? DEFAULT_DAY_HOURS : legacy)
  let byDay: Record<string, unknown> = {}
  try { byDay = stored.max_pto_hours_by_dow ? JSON.parse(stored.max_pto_hours_by_dow) : {} } catch { byDay = {} }
  hours.value = Object.fromEntries(
    WEEKDAYS.map((d) => {
      const v = byDay[d.key]
      return [d.key, v == null || String(v).trim() === '' ? fallback : String(v)]
    })
  ) as Record<WeekdayKey, Box>
  values.value = Object.fromEntries(
    FIELDS.map((f) => {
      const v = stored[f.key]
      if (v != null) return [f.key, String(v)]
      return [f.key, f.optional ? '' : String(RULE_DEFAULTS[f.key as keyof typeof RULE_DEFAULTS])]
    })
  ) as Record<ScalarKey, Box>
  savedSnapshot.value = snapshot()
}

const load = async () => {
  state.value = 'loading'
  await fetchSettings()
  if (settingsError.value) {
    loadError.value = settingsError.value
    state.value = 'error'
    return
  }
  neverSaved.value = !settings.value.max_pto_hours_by_dow && !settings.value.max_pto_hours_per_day
  fillForm(settings.value)
  state.value = 'ready'
}

const hourProblems = computed(() =>
  Object.fromEntries(WEEKDAYS.map((d) => [d.key, weekdayHoursProblem(d.key, hours.value[d.key])])) as Record<WeekdayKey, string | null>
)
const hourProblemList = computed(() => Object.values(hourProblems.value).filter((p): p is string => !!p))
const problems = computed(() =>
  Object.fromEntries(FIELDS.map((f) => [f.key, ruleProblem(f.key, values.value[f.key])])) as Record<ScalarKey, string | null>
)
const hasProblems = computed(() => hourProblemList.value.length > 0 || Object.values(problems.value).some(Boolean))
const dirty = computed(() => state.value === 'ready' && snapshot() !== savedSnapshot.value)

const fieldClass = (bad: boolean) => [
  'w-full rounded-md border px-2 py-2 shadow-sm focus:outline-none focus:ring-2',
  bad ? 'border-red-400 bg-red-50 focus:ring-red-400' : 'border-gray-300 focus:border-blue-500 focus:ring-blue-500',
]

const saveError = ref('')
const save = async () => {
  if (!dirty.value || hasProblems.value) return
  saveError.value = ''
  registry.mark(LEAVE_KEY, 'busy')
  try {
    // One request, all or nothing. The server re-checks every value.
    const stored = await saveRules({ max_pto_hours_by_dow: hours.value, ...values.value })
    neverSaved.value = false
    fillForm(stored)
    toast.success('Request rules saved.')
  } catch (err: any) {
    saveError.value = err.data?.message || err.message || 'unknown error'
  } finally {
    registry.mark(LEAVE_KEY, dirty.value ? 'failed' : null)
  }
}
const undo = () => {
  const s = JSON.parse(savedSnapshot.value)
  hours.value = s.hours
  values.value = s.values
  saveError.value = ''
}

// Unsaved edits count as unsaved work for the page's leave guard (pages/settings.vue).
const LEAVE_KEY = 'form:request-rules'
watch(dirty, (d) => { if (!saving.value) registry.mark(LEAVE_KEY, d ? 'failed' : null) })
onBeforeUnmount(() => registry.mark(LEAVE_KEY, null))

// ---- Blocked dates ----------------------------------------------------------------
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
const {
  blockedDates,
  error: blockedError,
  fetchBlockedDates,
  addBlockedDates,
  removeBlockedDate,
  buildQuarterEndDates,
  buildMonthEndDates,
} = useTeamBlockedDates()
const blockedLoadError = ref('')
const loadBlocked = async () => {
  await fetchBlockedDates()
  blockedLoadError.value = blockedError.value ?? ''
}

const dayOf = (bd: { blocked_date: string }) => String(bd.blocked_date).slice(0, 10)
/** "Wed, May 27, 2026" from a YYYY-MM-DD. */
const longDate = (ymd: string) => {
  const [y, m, d] = ymd.split('-').map(Number)
  if (!y || !m || !d) return ymd
  return new Date(y, m - 1, d).toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric', year: 'numeric' })
}
// "Today" at the site, as the display board decides it.
const today = computed(() => getTZISODate(user.value?.team_timezone || Intl.DateTimeFormat().resolvedOptions().timeZone))
const upcoming = computed(() => blockedDates.value.filter((b) => dayOf(b) >= today.value).sort((a, b) => dayOf(a).localeCompare(dayOf(b))))
const past = computed(() => blockedDates.value.filter((b) => dayOf(b) < today.value).sort((a, b) => dayOf(b).localeCompare(dayOf(a))))
const showPast = ref(false)
const blockedDays = computed(() => new Map(blockedDates.value.map((b) => [dayOf(b), b.reason])))

const adding = ref(false)
const addError = ref('')
const runAdd = async (dates: string[], reason: string) => {
  adding.value = true
  addError.value = ''
  try {
    const res = await addBlockedDates(dates, reason.trim() || null)
    const kept = res.skipped?.length ?? 0
    toast.success(
      `Blocked ${res.count} date${res.count === 1 ? '' : 's'}.` +
        (kept ? ` ${kept} ${kept === 1 ? 'was' : 'were'} already blocked and kept ${kept === 1 ? 'its' : 'their'} reason.` : '')
    )
    return true
  } catch (err: any) {
    addError.value = err.data?.message || err.message || 'The dates were not added.'
    return false
  } finally {
    adding.value = false
  }
}

const showSingle = ref(false)
const single = ref({ date: '', reason: '' })
const openSingle = () => {
  single.value = { date: '', reason: '' }
  addError.value = ''
  showSingle.value = true
}
const addSingle = async () => {
  if (!single.value.date || blockedDays.value.has(single.value.date)) return
  if (await runAdd([single.value.date], single.value.reason)) showSingle.value = false
}

const periodMode = ref<'quarter' | 'month' | null>(null)
const period = ref({ year: 0, days: 5, quarters: [] as number[], months: [] as number[], reason: '' })
const openPeriod = (mode: 'quarter' | 'month') => {
  const year = Number(today.value.slice(0, 4))
  period.value = mode === 'quarter'
    ? { year, days: 5, quarters: [1, 2, 3, 4], months: [], reason: 'Quarter-end close' }
    : { year, days: 3, quarters: [], months: [], reason: 'Month-end close' }
  addError.value = ''
  periodMode.value = mode
}
const periodDates = computed<string[]>(() => {
  const p = period.value
  if (!p.year || !p.days) return []
  if (periodMode.value === 'quarter') return p.quarters.length ? buildQuarterEndDates(p.year, p.quarters, p.days) : []
  if (periodMode.value === 'month') return p.months.length ? buildMonthEndDates(p.year, p.months, p.days) : []
  return []
})
const newPeriodDates = computed(() => periodDates.value.filter((d) => !blockedDays.value.has(d)))
const addPeriod = async () => {
  if (!newPeriodDates.value.length) return
  if (await runAdd(newPeriodDates.value, period.value.reason)) periodMode.value = null
}

const removing = ref<any>(null)
const removeBusy = ref(false)
const removeError = ref('')
const confirmRemove = async () => {
  if (!removing.value) return
  removeBusy.value = true
  removeError.value = ''
  const day = longDate(dayOf(removing.value))
  if (await removeBlockedDate(removing.value.id)) {
    toast.success(`${day} takes requests again.`)
    removing.value = null
  } else {
    removeError.value = blockedError.value || 'The date was not removed.'
  }
  removeBusy.value = false
}

onMounted(() => {
  load()
  loadBlocked()
})
</script>
