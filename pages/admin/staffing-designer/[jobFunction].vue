<template>
  <div class="min-h-screen bg-gray-50 py-8">
    <div class="max-w-3xl mx-auto px-4">
      <div class="mb-6">
        <NuxtLink :to="backHref" class="text-blue-600 hover:text-blue-800 text-sm">← Back to designer</NuxtLink>
        <h1 class="text-2xl md:text-3xl font-bold text-gray-900 mt-2">{{ jobFunctionName }}</h1>
        <p class="text-gray-600 text-sm mt-1">Draft segments → publish replaces classic staffing rules for this function (not fan-out / global max rows).</p>
      </div>

      <div v-if="pageLoading" class="card p-8 text-center text-gray-600">Loading draft…</div>

      <template v-else>
        <div v-if="overlapWarnings.length" class="mb-4 p-3 bg-amber-50 border border-amber-200 rounded-lg text-sm text-amber-900">
          <p class="font-medium">Overlapping segments</p>
          <ul class="list-disc list-inside mt-1">
            <li v-for="(w, i) in overlapWarnings" :key="i">{{ w }}</li>
          </ul>
        </div>

        <!-- Timeline preview -->
        <div class="card p-4 mb-6">
          <h2 class="text-sm font-semibold text-gray-700 mb-2">Day preview (by duration)</h2>
          <div class="flex h-10 rounded-lg overflow-hidden border border-gray-200">
            <div
              v-for="(seg, idx) in segments"
              :key="idx"
              class="min-w-[4px] bg-blue-400 border-r border-white/80 flex items-end justify-center pb-0.5"
              :style="{ flexGrow: Math.max(1, segmentMinutes(seg)) }"
              :title="`${seg.start}–${seg.end}: ${seg.targetHours} target hrs`"
            >
              <span class="text-[10px] text-white font-medium drop-shadow truncate px-0.5">{{ seg.targetHours }}h</span>
            </div>
          </div>
        </div>

        <div class="card p-4 mb-6 space-y-4">
          <div class="flex items-center justify-between">
            <h2 class="text-lg font-semibold text-gray-900">Segments</h2>
            <button type="button" class="text-sm text-blue-600 hover:text-blue-800" @click="addSegment">+ Add segment</button>
          </div>

          <div
            v-for="(seg, idx) in segments"
            :key="idx"
            class="grid grid-cols-1 sm:grid-cols-12 gap-2 items-end border-b border-gray-100 pb-4"
          >
            <div class="sm:col-span-3">
              <label class="text-xs text-gray-500">Start</label>
              <input v-model="seg.start" type="time" class="w-full border rounded-md px-2 py-1.5 text-sm" />
            </div>
            <div class="sm:col-span-3">
              <label class="text-xs text-gray-500">End</label>
              <input v-model="seg.end" type="time" class="w-full border rounded-md px-2 py-1.5 text-sm" />
            </div>
            <div class="sm:col-span-4">
              <label class="text-xs text-gray-500">Target hours</label>
              <input
                v-model.number="seg.targetHours"
                type="number"
                min="0.5"
                step="0.5"
                class="w-full border rounded-md px-2 py-1.5 text-sm"
              />
            </div>
            <div class="sm:col-span-2 flex justify-end">
              <button
                type="button"
                class="text-sm text-red-600 hover:text-red-800 disabled:opacity-40"
                :disabled="segments.length <= 1"
                @click="removeSegment(idx)"
              >
                Remove
              </button>
            </div>
            <p class="sm:col-span-12 text-xs text-gray-500">
              Slot {{ slotLabel(seg) }} → ~{{ impliedHeadcount(seg) }} people (ceil target ÷ slot hours)
            </p>
          </div>
        </div>

        <div class="flex flex-wrap gap-3">
          <button
            type="button"
            class="px-4 py-2 bg-gray-800 text-white rounded-lg hover:bg-gray-900 disabled:opacity-50 text-sm"
            :disabled="saving"
            @click="saveDraft"
          >
            {{ saving ? 'Saving…' : 'Save draft' }}
          </button>
          <button
            type="button"
            class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-50 text-sm"
            :disabled="saving || !canPublish"
            @click="confirmPublish"
          >
            Publish to live rules
          </button>
          <button type="button" class="px-4 py-2 border border-gray-300 rounded-lg text-sm hover:bg-gray-50" @click="reloadFromLive">
            Reset from live rules
          </button>
        </div>

        <p v-if="!canPublish" class="text-xs text-gray-500 mt-3">Publishing requires admin or super admin.</p>
        <p v-if="lastSavedAt" class="text-xs text-gray-500 mt-2">Draft last saved: {{ lastSavedAt }}</p>
        <p v-if="saveError" class="text-sm text-red-600 mt-2">{{ saveError }}</p>
      </template>
    </div>
  </div>
</template>

<script setup lang="ts">
import { normalizeDbTime, type StaffingSegment } from '~/composables/useStaffingDrafts'

const route = useRoute()
const { user, fetchCurrentUser } = useAuth()
const {
  fetchDraftPayload,
  saveDraft: putDraft,
  publishDraft,
  liveRulesToSegments,
  slotDurationHours,
  overlapWarnings: computeOverlapWarnings,
} = useStaffingDrafts()

const jobFunctionName = computed(() => {
  const raw = route.params.jobFunction as string
  try {
    return decodeURIComponent(raw)
  } catch {
    return raw
  }
})

const teamIdQuery = computed(() => {
  const t = route.query.team_id
  return typeof t === 'string' && t ? t : undefined
})

const backHref = computed(() => {
  const q = teamIdQuery.value ? `?team_id=${encodeURIComponent(teamIdQuery.value)}` : ''
  return `/admin/staffing-designer${q}`
})

const pageLoading = ref(true)
const saving = ref(false)
const saveError = ref('')
const segments = ref<StaffingSegment[]>([{ start: '08:00', end: '17:00', targetHours: 8 }])
const lastSavedAt = ref('')
const liveRulesSnapshot = ref<any[]>([])

const canPublish = computed(
  () => !!(user.value?.is_admin || user.value?.is_super_admin)
)

const overlapWarnings = computed(() => computeOverlapWarnings(segments.value))

const segmentMinutes = (seg: StaffingSegment) => {
  const h = slotDurationHours(seg.start, seg.end)
  return Math.max(1, Math.round(h * 60))
}

const slotLabel = (seg: StaffingSegment) => {
  const h = slotDurationHours(seg.start, seg.end)
  if (h <= 0) return 'invalid'
  return `${h % 1 === 0 ? h : h.toFixed(2)} h slot`
}

const impliedHeadcount = (seg: StaffingSegment) => {
  const h = slotDurationHours(seg.start, seg.end)
  if (h <= 0) return '—'
  return Math.max(1, Math.ceil(seg.targetHours / h))
}

const load = async () => {
  pageLoading.value = true
  saveError.value = ''
  await fetchCurrentUser()
  try {
    const payload = await fetchDraftPayload(jobFunctionName.value, teamIdQuery.value)
    liveRulesSnapshot.value = payload.liveRules || []
    const draftSegs = payload.draft?.segments
    if (Array.isArray(draftSegs) && draftSegs.length > 0) {
      segments.value = draftSegs.map((s: any) => ({
        start: normalizeDbTime(s.start),
        end: normalizeDbTime(s.end),
        targetHours: Number(s.targetHours) || 0.5,
      }))
    } else {
      segments.value = liveRulesToSegments(payload.liveRules || [])
    }
    if (payload.draft?.updated_at) {
      lastSavedAt.value = new Date(payload.draft.updated_at).toLocaleString()
    } else {
      lastSavedAt.value = ''
    }
  } catch {
    segments.value = [{ start: '08:00', end: '17:00', targetHours: 8 }]
  } finally {
    pageLoading.value = false
  }
}

const addSegment = () => {
  const last = segments.value[segments.value.length - 1]
  segments.value.push({ start: last?.end || '12:00', end: '17:00', targetHours: 4 })
}

const removeSegment = (idx: number) => {
  if (segments.value.length <= 1) return
  segments.value.splice(idx, 1)
}

const saveDraft = async () => {
  saving.value = true
  saveError.value = ''
  try {
    await putDraft(jobFunctionName.value, segments.value, teamIdQuery.value)
    lastSavedAt.value = new Date().toLocaleString()
  } catch (e: any) {
    saveError.value = e?.data?.message || e?.message || 'Save failed'
  } finally {
    saving.value = false
  }
}

const reloadFromLive = () => {
  segments.value = liveRulesToSegments(liveRulesSnapshot.value)
  saveError.value = ''
}

const confirmPublish = async () => {
  if (!canPublish.value) return
  if (
    !confirm(
      `Publish draft for "${jobFunctionName.value}" to live business rules?\n\nThis replaces existing staffing rows for this function (not fan-out / global max).`
    )
  ) {
    return
  }
  saving.value = true
  saveError.value = ''
  try {
    await saveDraft()
    await publishDraft(jobFunctionName.value, teamIdQuery.value)
    alert('Published. You can verify on the classic Business Rules page.')
    await load()
  } catch (e: any) {
    saveError.value = e?.data?.message || e?.message || 'Publish failed'
  } finally {
    saving.value = false
  }
}

watch(
  () => [route.params.jobFunction, route.query.team_id],
  () => {
    load()
  }
)

onMounted(() => {
  load()
})
</script>
