<!--
  Change log — the read-only audit view. One component, two windows: the PTO
  calendar opens it for request changes across the team; the Employee Overview
  opens it for every kind of change to one person. Supervisor and above only
  (the endpoint refuses anyone else).
-->
<template>
  <div class="fixed inset-0 bg-black/50 flex items-start justify-center z-50 p-4 overflow-y-auto" @click.self="$emit('close')">
    <div class="bg-white rounded-xl shadow-2xl max-w-4xl w-full my-4">
      <div class="p-6">
        <div class="flex justify-between items-start mb-3">
          <div>
            <h2 class="text-xl font-bold text-gray-900">{{ title }}</h2>
            <p class="text-sm text-gray-500 mt-0.5">{{ subtitle }} Read-only — nothing here can be edited or removed.</p>
          </div>
          <button @click="$emit('close')" aria-label="Close" class="text-gray-400 hover:text-gray-600 text-2xl leading-none">&times;</button>
        </div>

        <div class="flex flex-wrap items-center gap-2 mb-3">
          <div class="inline-flex rounded-md border border-gray-300 overflow-hidden">
            <button
              v-for="a in ACTION_FILTERS"
              :key="a.key"
              type="button"
              @click="action = a.key"
              class="px-3 py-1.5 text-xs font-medium border-r border-gray-200 last:border-r-0"
              :class="action === a.key ? 'bg-blue-50 text-blue-700' : 'bg-white text-gray-600 hover:bg-gray-50'"
            >{{ a.label }}</button>
          </div>
          <span v-if="total" class="ml-auto text-xs text-gray-500 tabular-nums">
            {{ offset + 1 }}–{{ Math.min(offset + entries.length, total) }} of {{ total }}
          </span>
        </div>

        <div v-if="error" class="bg-red-50 border border-red-200 rounded-md p-3 text-sm text-red-700">{{ error }}</div>
        <div v-else-if="loading && !entries.length" class="text-sm text-gray-500 py-10 text-center">Loading…</div>
        <div v-else-if="!entries.length" class="text-sm text-gray-500 py-10 text-center border border-gray-200 rounded-lg">
          No changes recorded{{ action ? ' for that filter' : '' }}.
        </div>

        <div v-else class="border border-gray-200 rounded-lg divide-y divide-gray-100" :class="loading ? 'opacity-60' : ''">
          <div v-for="e in entries" :key="e.id" class="px-3 py-2.5 flex items-start gap-3">
            <span class="flex-none mt-0.5 px-2 py-0.5 rounded-full text-[11px] font-semibold" :class="actionClass(e.action)">
              {{ actionLabel(e.action) }}
            </span>
            <div class="min-w-0 flex-1">
              <p class="text-sm text-gray-900">{{ e.summary }}</p>
              <p class="text-xs text-gray-500 mt-0.5">
                <b class="text-gray-700">{{ e.actor_name }}</b> · {{ when(e.created_at) }}
                <span class="text-gray-400"> · {{ entityLabel(e.entity_type) }}</span>
              </p>
            </div>
          </div>
        </div>

        <div v-if="total > limit" class="flex items-center justify-between mt-3 pt-3 border-t border-gray-100 text-xs">
          <button
            type="button"
            @click="offset = Math.max(0, offset - limit)"
            :disabled="offset === 0"
            class="px-3 py-1.5 rounded-md border border-gray-300 text-gray-700 hover:bg-gray-50 disabled:opacity-40 disabled:hover:bg-white"
          >← Newer</button>
          <span class="text-gray-500 tabular-nums">Page {{ Math.floor(offset / limit) + 1 }} of {{ Math.ceil(total / limit) }}</span>
          <button
            type="button"
            @click="offset = offset + limit"
            :disabled="offset + limit >= total"
            class="px-3 py-1.5 rounded-md border border-gray-300 text-gray-700 hover:bg-gray-50 disabled:opacity-40 disabled:hover:bg-white"
          >Older →</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{
  title: string
  subtitle: string
  /** Restrict to these kinds of record; omit for every kind. */
  entity?: string[]
  /** Restrict to one person. */
  employeeId?: string | null
}>()
defineEmits<{ close: [] }>()

const ACTION_FILTERS = [
  { key: '', label: 'All' },
  { key: 'approve', label: 'Approved' },
  { key: 'reject', label: 'Rejected' },
  { key: 'delete', label: 'Deleted' },
  { key: 'add', label: 'Added' },
  { key: 'edit', label: 'Edited' },
]
const action = ref('')
const limit = 15
const offset = ref(0)
const entries = ref<any[]>([])
const total = ref(0)
const loading = ref(false)
const error = ref('')

const load = async () => {
  loading.value = true
  error.value = ''
  try {
    const params: Record<string, string | number> = { limit, offset: offset.value }
    if (props.entity?.length) params.entity = props.entity.join(',')
    if (props.employeeId) params.employee_id = props.employeeId
    if (action.value) params.action = action.value
    const data = await $fetch<{ entries: any[]; total: number }>('/api/audit-log', { params })
    entries.value = data.entries
    total.value = data.total
  } catch (e: any) {
    error.value = e.data?.message || e.message || 'Could not load the change log'
  } finally {
    loading.value = false
  }
}
watch(action, () => { offset.value = 0; load() })
watch(offset, load)
onMounted(load)

const actionLabel = (a: string) => ACTION_FILTERS.find((x) => x.key === a)?.label ?? a
const actionClass = (a: string) => ({
  'bg-green-100 text-green-800': a === 'approve' || a === 'add',
  'bg-red-100 text-red-800': a === 'reject' || a === 'delete',
  'bg-blue-100 text-blue-800': a === 'edit',
})
const ENTITY_LABELS: Record<string, string> = {
  request: 'request',
  pto_day: 'time off',
  attendance_point: 'attendance point',
  performance_note: 'note',
  performance_error: 'error log',
}
const entityLabel = (t: string) => ENTITY_LABELS[t] ?? t
const when = (iso: string) =>
  new Date(iso).toLocaleString('en-US', { month: 'short', day: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit' })
</script>
