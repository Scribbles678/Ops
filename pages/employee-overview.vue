<template>
  <div class="min-h-screen bg-gray-50">
    <div class="container mx-auto px-4 py-6 md:py-8">
      <!-- Header -->
      <div class="flex items-start justify-between mb-5 gap-4">
        <div>
          <h1 class="text-2xl md:text-3xl font-semibold text-gray-800">Employee Overview</h1>
          <p class="text-sm text-gray-500 mt-1">
            Scheduled work, skills and attendance drawn from schedule history.
          </p>
        </div>
        <NuxtLink to="/" class="btn-secondary flex-none">
          ← Back to Home
        </NuxtLink>
      </div>

      <EmployeeOverview v-model:employee-id="employeeId" v-model:period="period" />
    </div>
  </div>
</template>

<script setup lang="ts">
import { OVERVIEW_PERIODS, type OverviewPeriod } from '~/components/employee/Overview.vue'

// The chosen employee and period live in the URL (?employee=…&period=…), so an
// overview can be bookmarked or linked to — the training matrix's per-row
// "Overview" button lands here preselected — and Back/Forward step through
// what was viewed rather than leaving the page.
const route = useRoute()
const router = useRouter()

const periodFromQuery = (): OverviewPeriod => {
  const p = String(route.query.period ?? '')
  return OVERVIEW_PERIODS.some((x) => x.key === p) ? (p as OverviewPeriod) : 'all'
}

const employeeId = ref(String(route.query.employee ?? ''))
const period = ref<OverviewPeriod>(periodFromQuery())

watch([employeeId, period], ([emp, per]) => {
  const query: Record<string, string> = {}
  if (emp) query.employee = emp
  if (per !== 'all') query.period = per
  const current = { employee: route.query.employee, period: route.query.period }
  if (current.employee !== (query.employee ?? undefined) || current.period !== (query.period ?? undefined)) {
    router.replace({ query })
  }
})

watch(() => route.query, () => {
  const emp = String(route.query.employee ?? '')
  if (emp !== employeeId.value) employeeId.value = emp
  const per = periodFromQuery()
  if (per !== period.value) period.value = per
})
</script>
