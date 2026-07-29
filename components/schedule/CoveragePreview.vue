<template>
  <div class="bg-white shadow rounded-lg overflow-hidden">
    <!-- Header -->
    <div class="px-5 pt-5 pb-3 flex flex-wrap items-start justify-between gap-3">
      <div>
        <h2 class="text-lg font-semibold text-gray-900">Coverage Preview</h2>
        <p class="text-sm text-gray-500 mt-0.5">
          Staffing targets against the people actually on the clock for
          {{ prettyDate }} — before you build.
        </p>
        <p class="text-xs text-gray-500 mt-1.5 max-w-2xl">
          <span class="font-semibold text-gray-700">Read the top row first.</span>
          It counts every person once, so it's the real check on whether the day is coverable.
          The rows below only ask whether enough <em>trained</em> people exist for that one job —
          they stay grey when training isn't the problem.
        </p>
      </div>
      <div class="flex items-center gap-2">
        <div class="inline-flex rounded-md border border-gray-300 overflow-hidden">
          <button
            v-for="m in modes"
            :key="m.key"
            type="button"
            @click="mode = m.key as 'hour' | 'worst'"
            class="px-3 py-1.5 text-xs font-medium border-r border-gray-200 last:border-r-0"
            :class="mode === m.key ? 'bg-blue-50 text-blue-700' : 'bg-white text-gray-600 hover:bg-gray-50'"
            :title="m.hint"
          >{{ m.label }}</button>
        </div>
        <button
          @click="load"
          :disabled="loading"
          class="px-3 py-1.5 text-xs rounded-md border border-gray-300 text-gray-600 hover:bg-gray-50 disabled:opacity-50"
        >{{ loading ? 'Loading…' : 'Refresh' }}</button>
      </div>
    </div>

    <div v-if="error" class="mx-5 mb-4 bg-red-50 border border-red-200 rounded-md p-3 text-sm text-red-700">
      {{ error }}
    </div>

    <div v-else-if="loading && !data" class="px-5 pb-6 text-sm text-gray-500">Loading coverage…</div>

    <template v-else-if="data">
      <!-- Summary tiles -->
      <div class="px-5 pb-4 grid grid-cols-1 sm:grid-cols-3 gap-2.5">
        <div class="border border-gray-200 rounded-lg p-3">
          <div class="text-[10px] uppercase tracking-wide text-gray-500 font-medium">Target demand</div>
          <div class="text-2xl font-bold text-gray-900 leading-tight">
            {{ data.summary.totalDemandHours.toFixed(0) }}<span class="text-sm font-medium text-gray-500 ml-0.5">h</span>
          </div>
          <div class="text-[11px] text-gray-500">headcount-hours</div>
        </div>
        <div class="border border-gray-200 rounded-lg p-3">
          <div class="text-[10px] uppercase tracking-wide text-gray-500 font-medium">Labour available</div>
          <div class="text-2xl font-bold leading-tight" :class="labourShort ? 'text-red-600' : 'text-gray-900'">
            {{ data.summary.totalLabourHours.toFixed(0) }}<span class="text-sm font-medium text-gray-500 ml-0.5">h</span>
          </div>
          <div class="text-[11px] text-gray-500">{{ data.summary.schedulableEmployees }} schedulable staff</div>
        </div>
        <div class="border border-gray-200 rounded-lg p-3">
          <div class="text-[10px] uppercase tracking-wide text-gray-500 font-medium">Buffer</div>
          <div class="text-2xl font-bold leading-tight" :class="bufferHours < 0 ? 'text-red-600' : 'text-gray-900'">
            {{ bufferHours > 0 ? '+' : '' }}{{ bufferHours.toFixed(0) }}<span class="text-sm font-medium text-gray-500 ml-0.5">h</span>
          </div>
          <div class="text-[11px] text-gray-500">labour minus demand</div>
        </div>
      </div>

      <!-- Grid -->
      <div class="px-5 pb-2 overflow-x-auto">
        <table class="min-w-full border-separate" style="border-spacing: 2px">
          <thead>
            <tr>
              <th class="text-left text-[10px] uppercase tracking-wide text-gray-500 font-medium px-2 py-1 sticky left-0 bg-white z-10">
                Job Function
              </th>
              <th
                v-for="h in data.hours"
                :key="h"
                class="text-center text-[10px] font-semibold text-gray-500 px-1 py-1 min-w-[46px]"
              >{{ hourLabel(h) }}</th>
            </tr>
          </thead>
          <tbody>
            <!-- Totals first: this is the binding constraint -->
            <tr>
              <td class="px-2 py-1 text-xs font-bold text-gray-900 whitespace-nowrap sticky left-0 bg-white z-10 border-b-2 border-gray-300">
                EVERYONE
                <div class="text-[9px] font-normal text-gray-500 leading-tight">spare people, all jobs</div>
              </td>
              <td
                v-for="t in data.totals"
                :key="'tot' + t.hour"
                class="text-center rounded border-b-2 border-gray-300 py-1"
                :class="totalCellClass(activeSlack(t))"
                :title="totalTitle(t)"
              >
                <span class="text-xs font-bold tabular-nums">{{ fmt(activeSlack(t)) }}</span>
              </td>
            </tr>

            <!-- Per-function rows -->
            <tr v-for="fn in data.functions" :key="fn.id">
              <td class="px-2 py-1 text-xs text-gray-800 whitespace-nowrap sticky left-0 bg-white z-10">
                <span class="inline-block w-2 h-2 rounded-sm mr-1.5 align-middle" :style="{ backgroundColor: fn.color }"></span>
                {{ fn.name }}
              </td>
              <!-- Quiet unless training is genuinely the binding constraint. A big
                   "+44" here would be meaningless: the same people appear in every
                   row they're trained for, so plenty-of-cover is not news. -->
              <td
                v-for="c in fn.cells"
                :key="fn.id + c.hour"
                class="text-center rounded py-1"
                :class="functionCellClass(c)"
                :title="cellTitle(fn, c)"
              >
                <span v-if="c.target === 0" class="text-[10px] text-gray-300">·</span>
                <!-- The figure is always shown. Only the COLOUR is held back when
                     training isn't the constraint, so a row of large spare counts
                     can't read as "the day is fine". -->
                <span
                  v-else
                  class="text-xs tabular-nums"
                  :class="isBinding(c) ? 'font-semibold' : 'font-normal'"
                >{{ fmt(activeSlack(c)) }}</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Legend -->
      <div class="px-5 pb-4 space-y-1.5">
        <div class="flex flex-wrap items-center gap-x-4 gap-y-1.5 text-[11px] text-gray-600">
          <span class="font-semibold text-gray-700 w-20">Any row:</span>
          <span class="flex items-center gap-1.5"><span class="w-4 h-4 rounded bg-red-500"></span> not enough people</span>
          <span class="flex items-center gap-1.5"><span class="w-4 h-4 rounded bg-amber-300"></span> exactly enough — no cover for a call-off</span>
          <span class="flex items-center gap-1.5"><span class="w-4 h-4 rounded bg-amber-100 border border-amber-200"></span> only 1 spare</span>
        </div>
        <div class="flex flex-wrap items-center gap-x-4 gap-y-1.5 text-[11px] text-gray-600">
          <span class="font-semibold text-gray-700 w-20">Top row:</span>
          <span class="flex items-center gap-1.5"><span class="w-4 h-4 rounded bg-emerald-200"></span> 1–2 spare</span>
          <span class="flex items-center gap-1.5"><span class="w-4 h-4 rounded bg-emerald-400"></span> comfortable</span>
        </div>
        <div class="flex flex-wrap items-center gap-x-4 gap-y-1.5 text-[11px] text-gray-600">
          <span class="font-semibold text-gray-700 w-20">Job rows:</span>
          <span class="flex items-center gap-1.5"><span class="text-gray-400 tabular-nums">+8</span> spare trained people — plenty, not the constraint</span>
          <span class="flex items-center gap-1.5"><span class="w-4 h-4 rounded bg-gray-50 border border-gray-200"></span> no target this hour</span>
        </div>
        <div class="flex flex-wrap items-center gap-x-4 gap-y-1.5 text-[11px] text-gray-600">
          <span class="font-semibold text-gray-700 w-20">Tip:</span>
          <span>An hour can read fine and still dip while a shift is on break — switch to <b class="text-gray-700">Worst 15 min</b> to see the low point of every hour.</span>
        </div>
      </div>

      <div v-if="data.summary.warnings?.length" class="border-t border-gray-100 px-5 py-3">
        <p v-for="(warn, i) in data.summary.warnings" :key="i" class="text-[11px] text-amber-700">{{ warn }}</p>
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{ date: string }>()

const data = ref<any>(null)
const loading = ref(false)
const error = ref('')

const modes = [
  { key: 'hour', label: 'Hourly', hint: 'Best headcount available at any point in the hour' },
  { key: 'worst', label: 'Worst 15 min', hint: 'The worst 15-minute slot inside each hour — reveals break and lunch cliffs' },
]
const mode = ref<'hour' | 'worst'>('hour')

const activeSlack = (c: any) => (mode.value === 'worst' ? c.worstSlack : c.slack)

const bufferHours = computed(() =>
  data.value ? data.value.summary.totalLabourHours - data.value.summary.totalDemandHours : 0
)
const labourShort = computed(() => bufferHours.value < 0)

const prettyDate = computed(() => {
  if (!props.date) return ''
  const [y, m, d] = props.date.split('-').map(Number)
  if (!y || !m || !d) return props.date
  return new Date(y, m - 1, d).toLocaleDateString('en-US', {
    weekday: 'long', month: 'long', day: 'numeric',
  })
})

const hourLabel = (h: number) => {
  const ampm = h >= 12 ? 'PM' : 'AM'
  const hr = h % 12 === 0 ? 12 : h % 12
  return `${hr}${ampm}`
}

const fmt = (n: number) => (n > 0 ? `+${n}` : String(n))

/**
 * The EVERYONE row counts each person once, so its number always means something
 * and always gets a colour. Status colouring, not a categorical palette — and the
 * number is always shown, so meaning never rests on colour alone.
 */
const totalCellClass = (slack: number) => {
  if (slack < -2) return 'bg-red-500 text-white'
  if (slack < 0) return 'bg-red-300 text-red-950'
  if (slack === 0) return 'bg-amber-300 text-amber-950'
  if (slack <= 2) return 'bg-emerald-200 text-emerald-900'
  return 'bg-emerald-400 text-emerald-950'
}

/**
 * A function row only matters when TRAINING is the thing running out. With 2 or
 * more trained people spare it isn't the constraint, so the cell goes quiet and
 * the eye is left free for the cells that are.
 */
const TIGHT_MARGIN = 2
const isBinding = (c: any) => c.target > 0 && activeSlack(c) < TIGHT_MARGIN

const functionCellClass = (c: any) => {
  if (c.target === 0) return 'bg-gray-50'
  const slack = activeSlack(c)
  if (slack < 0) return 'bg-red-400 text-white'
  if (slack === 0) return 'bg-amber-300 text-amber-950'
  if (slack < TIGHT_MARGIN) return 'bg-amber-100 text-amber-900'
  // Plenty of trained cover: the count is still readable, just not shouting.
  return 'bg-gray-50 text-gray-400'
}

// Tooltips always carry the real figures, including for the quiet ✓ cells.
const cellTitle = (fn: any, c: any) => {
  if (c.target === 0) return `${fn.name} at ${hourLabel(c.hour)} — no target set for this hour`
  const base =
    `${fn.name} at ${hourLabel(c.hour)}\n` +
    `Needs ${c.target}. ${c.trainedFree} trained ${c.trainedFree === 1 ? 'person is' : 'people are'} free.\n` +
    (isBinding(c)
      ? 'Training is the limit here.'
      : 'Plenty of trained cover — not the constraint.')
  return c.dip
    ? `${base}\nDips to ${c.worstTrainedFree} free for part of the hour (break or lunch).`
    : base
}

const totalTitle = (t: any) => {
  const base =
    `${hourLabel(t.hour)} — everyone\n` +
    `${t.demand} needed across all jobs. ${t.onClock} on the clock.\n` +
    (t.slack < 0
      ? `Short by ${Math.abs(t.slack)}.`
      : t.slack === 0
        ? 'Exactly enough — no cover for a call-off.'
        : `${t.slack} spare.`)
  return t.dip
    ? `${base}\nDrops to ${t.worstOnClock} for part of the hour (break or lunch).`
    : base
}

const load = async () => {
  if (!props.date) return
  loading.value = true
  error.value = ''
  try {
    data.value = await $fetch<any>('/api/schedule/coverage-preview', { params: { date: props.date } })
  } catch (e: any) {
    error.value = e.data?.message || e.message || 'Could not load coverage preview'
    data.value = null
  } finally {
    loading.value = false
  }
}

watch(() => props.date, load)
onMounted(load)
</script>
