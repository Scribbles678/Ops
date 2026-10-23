<template>
  <div class="bg-white shadow rounded-lg overflow-hidden">
    <div class="px-5 pt-5 pb-1">
      <h2 class="text-lg font-semibold text-gray-900">Training Matrix</h2>
      <p class="text-sm text-gray-500 mt-0.5">
        How many people trained on each job are on shift each hour, from everyone's regular shift.
      </p>
    </div>

    <div v-if="loadError" class="mx-5 my-4 bg-red-50 border border-red-200 rounded-md p-3 text-sm text-red-700 flex items-center justify-between gap-3">
      <span>{{ loadError }}</span>
      <button type="button" class="font-medium underline hover:text-red-800" @click="load">Retry</button>
    </div>

    <div v-else-if="loading" class="px-5 pb-6 pt-3 text-sm text-gray-500">Loading…</div>

    <div v-else-if="!hours.length" class="px-5 pb-6 pt-3 text-sm text-gray-500">
      No active shifts are set up, so there are no hours to show. Add shifts in Shift Management.
    </div>

    <template v-else>
      <div class="px-5 pt-4 overflow-x-auto">
        <table class="border-separate" style="border-spacing: 2px">
          <thead>
            <tr>
              <th class="text-left px-2 py-1 min-w-[140px]"></th>
              <th class="text-center text-[10px] font-semibold text-gray-500 px-1 py-1" :title="TARGET_MEANING">Target</th>
              <th
                v-for="h in hours"
                :key="'th' + h"
                class="text-center text-[10px] font-semibold text-gray-500 px-1 py-1 min-w-[40px]"
              >{{ hourLabel(h) }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in rows" :key="row.id">
              <td class="px-2 py-1 text-xs text-gray-800 whitespace-nowrap min-w-[140px]">
                <span class="inline-block w-2 h-2 rounded-sm mr-1.5 align-middle" :style="{ backgroundColor: row.color }"></span>
                {{ row.name }}
              </td>
              <td class="px-1">
                <div class="flex items-center gap-1">
                  <!-- type="text", not "number": a number box reports text it can't read
                       as empty, which would clear the target instead of being refused. -->
                  <input
                    :value="typed[row.id] ?? ''"
                    type="text"
                    inputmode="numeric"
                    autocomplete="off"
                    placeholder="–"
                    :aria-label="`Training target for ${row.name}`"
                    :title="TARGET_MEANING"
                    @input="onTargetInput(row.id, $event)"
                    @change="commitTarget(row.id)"
                    class="w-12 px-1 py-0.5 text-xs text-center tabular-nums border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                  <!-- Fixed width, so a status coming and going doesn't shift the grid sideways. -->
                  <div class="w-24">
                    <UiSaveStatus
                      :state="targets.stateOf(row.id)"
                      :message="targets.messageOf(row.id)"
                      :label="`Training target for ${row.name}`"
                      :retryable="targets.retryableOf(row.id)"
                      undoable
                      @retry="targets.retry(row.id)"
                      @undo="undoTarget(row.id)"
                    />
                  </div>
                </div>
              </td>
              <td
                v-for="c in row.cells"
                :key="row.id + '-' + c.hour"
                class="text-center rounded py-1 text-xs tabular-nums whitespace-nowrap"
                :class="cellClass(row, c)"
                :title="cellTitle(row, c)"
                :aria-label="cellTitle(row, c)"
              >{{ c.trained }}<span v-if="shortBy(row, c)" class="ml-0.5 text-[9px] font-medium">−{{ shortBy(row, c) }}</span></td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="px-5 pt-3 pb-4 space-y-2 text-[11px] text-gray-500">
        <div class="flex flex-wrap items-center gap-x-4 gap-y-2">
          <span v-for="k in LEGEND" :key="k.label" class="inline-flex items-center gap-1.5">
            <span class="inline-flex items-center justify-center min-w-[1.5rem] px-1 h-5 rounded tabular-nums" :class="k.cls">{{ k.sample }}<span v-if="k.short" class="ml-0.5 text-[9px] font-medium">−{{ k.short }}</span></span>{{ k.label }}
          </span>
        </div>
        <p><span class="font-medium text-gray-600">Target</span> — {{ TARGET_MEANING }}</p>
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
// Team Setup → Training Matrix: for each job and hour, how many people trained on
// that job are on shift, against a per-job target (job_functions.training_target,
// migration 023). Built from each person's regular shift, so time off, breaks and
// swaps don't come into it; it answers "is our training deep enough", not "can we
// cover Tuesday". Until Sep 2026 this tab was a dated coverage preview (spare
// trained people after time off and breaks for one day); that view was removed.
import { shiftHours } from '~/utils/shiftHours'

const TARGET_MEANING = 'the fewest trained people you want on shift in any hour the job is worked.'

// The same classes cellClass() uses, with a sample number (and shortfall), so each
// swatch looks exactly like the cells it explains.
const CELL = {
  meets: 'bg-emerald-100 text-emerald-900 font-semibold',
  below: 'bg-red-200 text-red-900 font-semibold',
  noTarget: 'bg-slate-100 text-gray-700',
  notWorked: 'bg-gray-50 text-gray-300',
}
const LEGEND = [
  { label: 'Meets target', cls: CELL.meets, sample: 6 },
  { label: 'Below target (−2 = 2 short)', cls: CELL.below, sample: 3, short: 2 },
  { label: 'No target set', cls: CELL.noTarget, sample: 6 },
  { label: 'Job not worked that hour', cls: CELL.notWorked, sample: 6 },
]

interface Cell { hour: number; trained: number; worked: boolean }
interface Row { id: string; name: string; color: string; cells: Cell[] }

const loading = ref(true)
const loadError = ref('')
const hours = ref<number[]>([])
const rows = ref<Row[]>([])

const nameOf = (id: string) => rows.value.find((r) => r.id === id)?.name ?? 'a job'

/**
 * Each Target box, keyed by job function id; null = no target. The box holds what
 * the server confirmed and what is typed, sends one change at a time, and keeps a
 * failure on screen with Retry / Undo — the old handler put the box back to the
 * saved number on any failure, so what was typed vanished behind a banner.
 */
const targets = useBoxSave<number | null>({
  namespace: 'training-target',
  save: async (id, value) => {
    await $fetch(`/api/job-functions/${id}`, { method: 'PUT', body: { training_target: value } })
  },
  label: (id) => `the training target for ${nameOf(id)}`,
})

/**
 * The text in each Target box. Kept apart from the box's draft, which only ever
 * holds a valid target: an entry that isn't one stays on screen, with the reason
 * beside it, instead of being replaced.
 */
const typed = ref<Record<string, string>>({})

const asText = (v: number | null | undefined) => (v == null ? '' : String(v))

const hourLabel = (h: number) => `${h % 12 === 0 ? 12 : h % 12}${h >= 12 ? 'PM' : 'AM'}`

// As server/api/job-functions/[id].put.ts.
const MAX_TARGET = 1000

/** A box's text as a target: null when empty, undefined when it isn't a whole number 0–1000. */
const parseTarget = (text: string): number | null | undefined => {
  const v = text.trim()
  if (v === '') return null
  const n = Number(v)
  return /^\d+$/.test(v) && n <= MAX_TARGET ? n : undefined
}

const onTargetInput = (id: string, e: Event) => {
  typed.value[id] = (e.target as HTMLInputElement).value
}

/** On change (blur / Enter): send it, or say why not. Empty clears the target. */
const commitTarget = (id: string) => {
  const value = parseTarget(typed.value[id] ?? '')
  if (value === undefined) return targets.invalid(id, `A whole number from 0 to ${MAX_TARGET}`)
  targets.setDraft(id, value)
  targets.commit(id)
}

const undoTarget = (id: string) => {
  targets.undo(id)
  typed.value[id] = asText(targets.draftOf(id))
}

/**
 * The target the colours use: what's typed, while it reads as one, so the effect of
 * a number shows before it saves; otherwise the box's value.
 */
const targetOf = (row: Row): number | null => {
  const v = parseTarget(typed.value[row.id] ?? '')
  return v !== undefined ? v : targets.draftOf(row.id) ?? null
}

/** How many people short of the target an hour is; 0 when it isn't (or has none). */
const shortBy = (row: Row, c: Cell): number => {
  if (!c.worked) return 0
  const target = targetOf(row)
  return target != null && c.trained < target ? target - c.trained : 0
}

const cellClass = (row: Row, c: Cell): string => {
  if (!c.worked) return CELL.notWorked
  if (targetOf(row) == null) return CELL.noTarget
  return shortBy(row, c) ? CELL.below : CELL.meets
}

const cellTitle = (row: Row, c: Cell): string => {
  const base = `${row.name} at ${hourLabel(c.hour)}: ${c.trained} trained ${c.trained === 1 ? 'person' : 'people'} on shift.`
  if (!c.worked) return `${base} No staffing target this hour.`
  const target = targetOf(row)
  if (target == null) return base
  const short = shortBy(row, c)
  return short ? `${base} ${short} short of the target of ${target}.` : `${base} Target of ${target} met.`
}

const load = async () => {
  loading.value = true
  loadError.value = ''
  try {
    const [jobFunctions, shifts, employees, training, staffingTargets] = await Promise.all([
      $fetch<any[]>('/api/job-functions'),
      $fetch<any[]>('/api/shifts'),
      $fetch<any[]>('/api/employees', { params: { active: 'true' } }),
      $fetch<{ employee_id: string; job_function_id: string }[]>('/api/employees/training'),
      $fetch<any[]>('/api/staffing-targets'),
    ])

    // The hours each person is on shift. Only active shifts count, as in the
    // Staffing Targets grid, and the hour rule is the same shared one.
    const hoursByShift = new Map(shifts.filter((s) => s.is_active !== false).map((s) => [s.id, new Set(shiftHours(s))]))
    const onShift = new Map<string, Set<number>>()
    for (const e of employees) {
      const set = e.is_active !== false && e.shift_id ? hoursByShift.get(e.shift_id) : undefined
      if (set) onShift.set(e.id, set)
    }
    hours.value = [...new Set([...hoursByShift.values()].flatMap((s) => [...s]))].sort((a, b) => a - b)

    const trainedFor = new Map<string, Set<string>>()
    for (const t of training) {
      if (!trainedFor.has(t.job_function_id)) trainedFor.set(t.job_function_id, new Set())
      trainedFor.get(t.job_function_id)!.add(t.employee_id)
    }

    // An hour a job is worked = it has a staffing target then. A job with no
    // staffing targets at all (TL, coordinator) is taken as worked whenever anyone
    // is on shift, or its target could never be checked.
    const workedHours = new Map<string, Set<number>>()
    for (const t of staffingTargets) {
      if (!((t.headcount ?? 0) > 0)) continue
      if (!workedHours.has(t.job_function_id)) workedHours.set(t.job_function_id, new Set())
      workedHours.get(t.job_function_id)!.add(Number(String(t.hour_start).slice(0, 2)))
    }

    // One row per active job, as in the Staffing Targets grid: the individual
    // "Meter N" jobs are left out, since training on "Meter" covers all of them.
    rows.value = jobFunctions
      .filter((jf) => !/^Meter [0-9]+$/.test(jf.name || ''))
      .map((jf) => {
        const people = [...(trainedFor.get(jf.id) ?? [])].map((id) => onShift.get(id)).filter(Boolean) as Set<number>[]
        const worked = workedHours.get(jf.id)
        return {
          id: jf.id,
          name: jf.name,
          color: jf.color_code,
          cells: hours.value.map((hour) => ({
            hour,
            trained: people.filter((set) => set.has(hour)).length,
            worked: !worked || worked.has(hour),
          })),
        }
      })
    // init() leaves a box alone while it is mid-edit or mid-save (the store outlives
    // this tab), so show whatever the box holds afterwards, not the server's number.
    for (const jf of jobFunctions) targets.init(jf.id, jf.training_target ?? null)
    typed.value = Object.fromEntries(jobFunctions.map((jf) => [jf.id, asText(targets.draftOf(jf.id))]))
  } catch (e: any) {
    loadError.value = `Couldn't load the Training Matrix: ${e.data?.message || e.message || 'unknown error'}`
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>
