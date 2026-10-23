<!--
  "Working in Memphis DC" across the top of every page, for an account that works in
  more than one team (migration 027) — so nobody edits Site B's schedule thinking it
  is Memphis. Not on the home page (its own switcher is right there), the sign-in
  pages or the wall display.

  Also, after a switch (the server redirects back with ?team_switched=1): tells this
  browser's other tabs to reload into the new team, and tidies the address. A failed
  switch comes back as ?team_switch_failed=<reason> and is shown as a toast.
-->
<template>
  <div
    v-if="shown"
    class="border-b border-blue-100 bg-blue-50 px-4 py-1.5 text-sm text-blue-900"
    role="region"
    aria-label="Current team"
  >
    <div class="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-2">
      <span>Working in <strong>{{ teamName }}</strong></span>
      <TeamSwitcher variant="select" label="Switch team:" />
    </div>
  </div>
</template>

<script setup lang="ts">
import { announceAuthChange } from '~/composables/useAuth'
import { roleOf } from '~/utils/roles'

const HIDDEN_ON = ['/', '/login', '/display', '/reset-password']

const { user, myTeams } = useAuth()
const route = useRoute()
const router = useRouter()
const toast = useToast()

const teamName = computed(() => myTeams.value.find((t) => t.id === user.value?.team_id)?.name ?? '')
const shown = computed(() =>
  !!user.value && roleOf(user.value) !== 'kiosk' && myTeams.value.length > 1 && !HIDDEN_ON.includes(route.path)
)

watch(
  () => [user.value?.id, route.query.team_switched, route.query.team_switch_failed] as const,
  ([id, switched, failed]) => {
    if (!id || (switched === undefined && failed === undefined)) return
    if (switched !== undefined) announceAuthChange({ id, team_id: user.value?.team_id ?? null })
    if (failed !== undefined) toast.error(`Couldn't switch team: ${String(failed)}`)
    const { team_switched: _s, team_switch_failed: _f, ...rest } = route.query
    router.replace({ query: rest })
  },
  { immediate: true }
)
</script>
