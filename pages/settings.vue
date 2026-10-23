<template>
  <div class="min-h-screen bg-gray-50">
    <div class="mx-auto max-w-6xl px-4 py-6 md:py-8">
      <!-- Header -->
      <div class="mb-5 flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1 class="text-2xl md:text-3xl font-semibold text-gray-800">Settings</h1>
          <p class="mt-1 text-sm text-gray-600">{{ subtitle }}</p>
        </div>
        <NuxtLink to="/" class="btn-secondary">← Back to Home</NuxtLink>
      </div>

      <!-- Tabs (only when there is more than one) -->
      <div v-if="tabs.length > 1" class="mb-5 border-b border-gray-200">
        <nav class="-mb-px flex flex-wrap gap-2 md:gap-4" aria-label="Settings sections">
          <button
            v-for="t in tabs"
            :key="t.key"
            type="button"
            :aria-current="activeTab === t.key ? 'page' : undefined"
            :class="[
              'py-2 md:py-3 px-1 border-b-2 font-medium text-sm transition',
              activeTab === t.key
                ? 'border-blue-500 text-blue-600'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
            ]"
            @click="activeTab = t.key"
          >
            {{ t.label }}
          </button>
        </nav>
      </div>

      <SettingsAccountTab v-if="visited.account" v-show="activeTab === 'account'" :team-name="teamName" />
      <SettingsRequestRulesTab v-if="visited.rules" v-show="activeTab === 'rules'" :team-name="teamName" />
      <SettingsUsersTab
        v-if="visited.users"
        v-show="activeTab === 'users'"
        :users="users"
        :teams="teams"
        :state="usersState"
        :load-error="usersError"
        @changed="loadUsers"
        @retry="loadUsers"
      />
      <SettingsTeamsTab v-if="visited.teams" v-show="activeTab === 'teams'" :teams="teams" :users="users" @changed="reloadAdmin" />
    </div>
  </div>
</template>

<script setup lang="ts">
import { canLead, canManageTeam } from '~/utils/roles'

/**
 * Settings, in tabs (Oct 2026), each addressable as ?tab=:
 *   account — everyone: who you are, your password (and the team switcher)
 *   rules   — Team Lead and up: the team's Request Rules and Blocked Dates — only
 *             Supervisors and up change them; a Team Lead sees them locked
 *   users   — Supervisor and up: the team's accounts (every team's, for a Super Admin)
 *   teams   — Super Admin: create, rename, time zones, delete
 * Until then it was one narrow column: a Super Admin's page ran 2,800px and the user
 * table was wider than its card, hiding every Edit / Reset / Deactivate button.
 *
 * A tab mounts the first time it's opened and then stays mounted (v-show), so
 * switching tabs never drops a half-edited form. Leaving the page with unsaved
 * Request Rules asks first (useLeaveGuard; RequestRulesTab marks the registry).
 * The global middleware has already loaded the signed-in user.
 */
type SettingsTab = 'account' | 'rules' | 'users' | 'teams'

const route = useRoute()
const router = useRouter()
const { user, sessionEnded } = useAuth()
const toast = useToast()
useLeaveGuard('Your Request Rules changes are not saved. Leave without saving?')

const isSuperAdmin = computed(() => !!user.value?.is_super_admin)
const tabs = computed(() => [
  { key: 'account' as const, label: 'My account' },
  ...(canLead(user.value) ? [{ key: 'rules' as const, label: 'Request rules' }] : []),
  ...(canManageTeam(user.value) ? [{ key: 'users' as const, label: 'Users' }] : []),
  ...(isSuperAdmin.value ? [{ key: 'teams' as const, label: 'Teams' }] : []),
])

const tabFromRoute = (): SettingsTab => {
  // The user list used to be linked as /settings#user-management.
  const t = route.hash === '#user-management' ? 'users' : String(route.query.tab ?? '')
  return tabs.value.some((x) => x.key === t) ? (t as SettingsTab) : 'account'
}
const activeTab = ref<SettingsTab>(tabFromRoute())
const visited = reactive<Record<SettingsTab, boolean>>({ account: false, rules: false, users: false, teams: false })
visited[activeTab.value] = true
// An old #user-management link, or a ?tab= this account can't open: show the
// address of what's actually on screen, so a copied link is the right one.
if (route.hash || (route.query.tab && route.query.tab !== activeTab.value)) {
  router.replace({ query: { ...route.query, tab: activeTab.value }, hash: '' })
}
watch(activeTab, (tab) => {
  visited[tab] = true
  if (route.query.tab !== tab) router.replace({ query: { ...route.query, tab }, hash: '' })
})
watch(() => route.query.tab, () => { activeTab.value = tabFromRoute() })

// Teams: everyone needs their own team's name; /api/teams gives a Super Admin all of them.
const teams = ref<any[]>([])
const teamName = computed<string | null>(() => teams.value.find((t) => t.id === user.value?.team_id)?.name ?? null)
const loadTeams = async () => {
  try {
    teams.value = await $fetch<any[]>('/api/teams')
  } catch (err: any) {
    if (err?.statusCode !== 401) toast.error(`Couldn't load the teams: ${err.data?.message || err.message}`)
  }
}

// One user list, shared by the Users tab and the Teams tab's account counts.
const users = ref<any[]>([])
const usersState = ref<'loading' | 'ready' | 'error'>('loading')
const usersError = ref('')
const loadUsers = async () => {
  if (!canManageTeam(user.value)) return
  try {
    users.value = await $fetch<any[]>('/api/admin/users')
    usersState.value = 'ready'
  } catch (err: any) {
    if (err?.statusCode === 401) return
    // After the first load, keep the list on screen and say so instead.
    if (usersState.value === 'ready') toast.error(`Couldn't refresh the user list: ${err.data?.message || err.message}`)
    else {
      usersError.value = err.data?.message || err.message || 'unknown error'
      usersState.value = 'error'
    }
  }
}
const reloadAdmin = () => Promise.all([loadTeams(), loadUsers()])

const subtitle = computed(() => {
  const team = teamName.value ?? 'your team'
  if (isSuperAdmin.value) return `Your account, ${team}'s request rules and user accounts, and every team`
  if (canManageTeam(user.value)) return `Your account, and ${team}'s request rules and user accounts`
  if (canLead(user.value)) return `Your account, and ${team}'s request rules (view only)`
  return 'Your account and password'
})

onMounted(reloadAdmin)
// Signed back in over this page (a password reset signs people out mid-work): what
// failed to load while signed out — the team name, the user list — loads now.
watch(sessionEnded, (ended, was) => { if (was && !ended) reloadAdmin() })
</script>
