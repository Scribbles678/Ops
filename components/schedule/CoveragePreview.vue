<template>
  <div class="bg-white shadow rounded-lg overflow-hidden">
    <!-- Header -->
    <div class="px-5 pt-5 pb-1 flex flex-wrap items-start justify-between gap-3">
      <div>
        <h2 class="text-lg font-semibold text-gray-900">Training &amp; Coverage Preview</h2>
        <p class="text-sm text-gray-500 mt-0.5">
          {{ prettyDate }} — before you build.
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

    <div v-if="error" class="mx-5 my-4 bg-red-50 border border-red-200 rounded-md p-3 text-sm text-red-700">
      {{ error }}
    </div>

    <div v-else-if="loading && !data" class="px-5 pb-6 pt-3 text-sm text-gray-500">Loading coverage…</div>

    <template v-else-if="data">
      <!-- TRAINING band: spare *trained* people. Every job, every hour, colour and
           number — the same person appears in every row they are trained for, so
           these rows answer "is training the limit here", not "how many people". -->
      <div class="px-5 pt-4">
        <div class="flex items-baseline gap-2 mb-1.5">
          <span class="text-[11px] font-bold uppercase tracking-wider text-gray-900">Training</span>
        </div>
        <div class="overflow-x-auto">
          <table class="border-separate" style="border-spacing: 2px">
            <thead>
              <tr>
                <th class="text-left px-2 py-1 min-w-[140px]"></th>
                <th
                  v-for="h in data.hours"
                  :key="'th' + h"
                  class="text-center text-[10px] font-semibold text-gray-500 px-1 py-1 min-w-[46px]"
                >{{ hourLabel(h) }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="fn in data.functions" :key="fn.id">
                <td class="px-2 py-1 text-xs text-gray-800 whitespace-nowrap min-w-[140px]">
                  <span class="inline-block w-2 h-2 rounded-sm mr-1.5 align-middle" :style="{ backgroundColor: fn.color }"></span>
                  {{ fn.name }}
                </td>
                <td
                  v-for="c in fn.cells"
                  :key="fn.id + c.hour"
                  class="text-center rounded py-1 text-xs tabular-nums"
                  :class="c.target === 0 ? 'bg-gray-50 text-gray-300' : heatClass(activeSlack(c)) + ' font-semibold'"
                  :title="cellTitle(fn, c)"
                >{{ c.target === 0 ? '·' : fmt(activeSlack(c)) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- The ramp, shown as the ramp. Capped at 16+ deliberately — see heatClass. -->
      <div class="px-5 pt-3 pb-4 flex flex-wrap items-center gap-x-1 gap-y-2 text-[11px] text-gray-500">
        <span class="mr-1.5">spare people</span>
        <span
          v-for="step in RAMP_LEGEND"
          :key="step.label"
          class="inline-flex items-center justify-center min-w-[34px] h-5 rounded font-semibold tabular-nums"
          :class="step.cls"
        >{{ step.label }}</span>
        <span class="ml-1.5 mr-4">deeper bench →</span>
        <span class="inline-flex items-center justify-center min-w-[34px] h-5 rounded bg-gray-50 text-gray-300">·</span>
        <span class="ml-1.5">no target this hour</span>
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

/** Below this many spare trained people, training is the thing running out. */
const TIGHT_MARGIN = 2

/**
 * Heatmap step for "spare people". One ramp serves both bands because both count
 * the same thing.
 *
 * Capped at 16+ on purpose. Measured on real data, 46% of cells sit above that and
 * the range runs to +44 — a linear ramp would spend nearly all its colour on the
 * difference between +18 and +44, which nobody acts on, and flatten 0–7 where every
 * decision actually lives.
 */
const heatClass = (slack: number): string => {
  if (slack <= -3) return 'bg-red-600 text-white'
  if (slack < 0) return 'bg-red-400 text-red-950'
  if (slack === 0) return 'bg-amber-300 text-amber-950'
  if (slack === 1) return 'bg-amber-100 text-amber-900'
  if (slack <= 3) return 'bg-emerald-50 text-emerald-700'
  if (slack <= 7) return 'bg-emerald-100 text-emerald-800'
  if (slack <= 15) return 'bg-emerald-200 text-emerald-900'
  return 'bg-emerald-400 text-emerald-950'
}

const RAMP_LEGEND = [
  { label: '<-2', cls: 'bg-red-600 text-white' },
  { label: '-1', cls: 'bg-red-400 text-red-950' },
  { label: '0', cls: 'bg-amber-300 text-amber-950' },
  { label: '1', cls: 'bg-amber-100 text-amber-900' },
  { label: '2-3', cls: 'bg-emerald-50 text-emerald-700' },
  { label: '4-7', cls: 'bg-emerald-100 text-emerald-800' },
  { label: '8-15', cls: 'bg-emerald-200 text-emerald-900' },
  { label: '16+', cls: 'bg-emerald-400 text-emerald-950' },
]

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

// Tooltips carry the real figures behind every cell, including the quiet ones.
const cellTitle = (fn: any, c: any) => {
  if (c.target === 0) return `${fn.name} at ${hourLabel(c.hour)} — no target set for this hour`
  const base =
    `${fn.name} at ${hourLabel(c.hour)}\n` +
    `Needs ${c.target}. ${c.trainedFree} trained ${c.trainedFree === 1 ? 'person is' : 'people are'} free.\n` +
    (activeSlack(c) < TIGHT_MARGIN
      ? 'Training is the limit here.'
      : 'Plenty of trained cover — not the constraint.')
  return c.dip
    ? `${base}\nDips to ${c.worstTrainedFree} free for part of the hour (break or lunch).`
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
