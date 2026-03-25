<template>
  <div class="min-h-screen bg-gray-50 py-8">
    <div class="max-w-4xl mx-auto px-4">
      <div class="flex flex-wrap items-center justify-between gap-4 mb-8">
        <div>
          <h1 class="text-3xl font-bold text-gray-900">Day staffing designer</h1>
          <p class="text-gray-600 mt-1 text-sm">
            Beta: edit whole-day target hours per job function. Saves a <strong>draft</strong> until you publish to live business rules.
          </p>
        </div>
        <div class="flex flex-wrap gap-2">
          <NuxtLink to="/admin/business-rules" class="btn-secondary text-sm">Business rules (classic)</NuxtLink>
          <NuxtLink to="/" class="btn-secondary text-sm">Home</NuxtLink>
        </div>
      </div>

      <div v-if="isSuperAdmin" class="card p-4 mb-6">
        <label class="block text-sm font-medium text-gray-700 mb-2">Team scope (super admin)</label>
        <select
          v-model="selectedTeamId"
          class="w-full max-w-md border border-gray-300 rounded-lg px-3 py-2 text-sm"
        >
          <option value="">Global rules (team_id null)</option>
          <option v-for="t in teams" :key="t.id" :value="t.id">{{ t.name }}</option>
        </select>
        <p class="text-xs text-gray-500 mt-2">
          Drafts and live rules are matched to this team. Pick the team whose business rules you normally edit.
        </p>
      </div>

      <div v-if="listLoading" class="text-center py-12 text-gray-600">Loading…</div>
      <div v-else class="card p-4">
        <h2 class="text-lg font-semibold text-gray-900 mb-4">Job functions</h2>
        <ul class="divide-y divide-gray-200">
          <li
            v-for="jf in sortedJobFunctions"
            :key="jf.id"
            class="py-3 flex flex-wrap items-center justify-between gap-2"
          >
            <span class="font-medium text-gray-800">{{ jf.name }}</span>
            <div class="flex items-center gap-2">
              <span
                v-if="draftSet.has(jf.name)"
                class="text-xs px-2 py-0.5 rounded-full bg-amber-100 text-amber-800"
              >
                Draft saved
              </span>
              <NuxtLink
                :to="editorLink(jf.name)"
                class="text-sm px-3 py-1.5 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
              >
                Edit day profile
              </NuxtLink>
            </div>
          </li>
        </ul>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const route = useRoute()
const { jobFunctions, fetchJobFunctions } = useJobFunctions()
const { isSuperAdmin, fetchAllTeams } = useTeam()
const { fetchDraftList } = useStaffingDrafts()

const teams = ref<any[]>([])
const selectedTeamId = ref('')
const listLoading = ref(true)
const draftSet = ref<Set<string>>(new Set())

const teamScopeParam = computed(() => {
  if (!isSuperAdmin.value) return undefined
  return selectedTeamId.value || undefined
})

const sortedJobFunctions = computed(() =>
  [...(jobFunctions.value || [])]
    .filter((jf) => jf.is_active !== false)
    .sort((a, b) => (a.name || '').localeCompare(b.name || ''))
)

const editorLink = (name: string) => {
  const enc = encodeURIComponent(name)
  const q = teamScopeParam.value ? `?team_id=${encodeURIComponent(teamScopeParam.value)}` : ''
  return `/admin/staffing-designer/${enc}${q}`
}

const reloadDraftList = async () => {
  listLoading.value = true
  try {
    const tid = isSuperAdmin.value ? selectedTeamId.value || null : null
    const { rows } = await fetchDraftList(tid || undefined)
    draftSet.value = new Set(rows.map((r) => r.job_function_name))
  } catch {
    draftSet.value = new Set()
  } finally {
    listLoading.value = false
  }
}

watch(selectedTeamId, () => {
  reloadDraftList()
})

onMounted(async () => {
  await fetchJobFunctions()
  if (isSuperAdmin.value) {
    try {
      teams.value = await fetchAllTeams()
    } catch {
      teams.value = []
    }
    const q = route.query.team_id
    if (typeof q === 'string' && q) {
      selectedTeamId.value = q
    }
  }
  await reloadDraftList()
})
</script>
