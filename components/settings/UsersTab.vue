<template>
  <section class="rounded-lg bg-white p-6 shadow" aria-labelledby="users-title">
    <div class="mb-4 flex flex-wrap items-start justify-between gap-3">
      <div>
        <h2 id="users-title" class="text-lg font-semibold text-gray-900">User accounts</h2>
        <p class="mt-1 text-sm text-gray-500">
          {{ isSuperAdmin ? "Every team's accounts." : `${ownTeamName || 'Your team'}'s accounts.` }}
          People sign in with their email; nothing is emailed to them, so pass on the password you set.
        </p>
      </div>
      <div class="flex flex-wrap gap-2">
        <button
          type="button"
          class="rounded-md border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50"
          @click="showLog = true"
        >Change log</button>
        <button
          type="button"
          class="rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500"
          @click="openCreate"
        >+ Create user</button>
      </div>
    </div>

    <div class="mb-3 flex flex-wrap items-center gap-3">
      <input
        v-model="search"
        type="search"
        placeholder="Search name or email"
        aria-label="Search accounts by name or email"
        class="w-full rounded-md border border-gray-300 px-3 py-2 text-sm sm:w-72"
      />
      <select v-if="isSuperAdmin" v-model="teamFilter" aria-label="Show one team" class="rounded-md border border-gray-300 px-3 py-2 text-sm">
        <option value="">All teams</option>
        <option v-for="t in teams" :key="t.id" :value="t.id">{{ t.name }}</option>
      </select>
      <span v-if="state === 'ready'" class="text-sm text-gray-500">Showing {{ shown.length }} of {{ users.length }}</span>
    </div>

    <p v-if="state === 'loading'" class="py-6 text-sm text-gray-500">Loading accounts…</p>
    <div v-else-if="state === 'error'" role="alert" class="rounded-md border border-red-200 bg-red-50 p-4 text-sm text-red-700">
      Couldn't load the accounts: {{ loadError }}
      <button type="button" class="ml-1 font-medium underline" @click="emit('retry')">Retry</button>
    </div>
    <p v-else-if="!shown.length" class="py-6 text-sm italic text-gray-500">No accounts match.</p>

    <div v-else class="relative overflow-x-auto">
      <table class="min-w-full divide-y divide-gray-200 text-sm">
        <thead class="bg-gray-50 text-left text-xs font-medium uppercase tracking-wider text-gray-500">
          <tr>
            <th scope="col" class="px-4 py-3">Name</th>
            <th v-if="isSuperAdmin" scope="col" class="px-4 py-3">Team</th>
            <th scope="col" class="px-4 py-3">Role</th>
            <th scope="col" class="px-4 py-3">Status</th>
            <th scope="col" class="px-4 py-3">Last signed in</th>
            <th scope="col" class="px-4 py-3"><span class="sr-only">Actions</span></th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-100 bg-white">
          <tr v-for="u in shown" :key="u.id" :class="u.is_active ? '' : 'bg-gray-50 text-gray-500'">
            <td class="px-4 py-3">
              <div class="font-medium" :class="u.is_active ? 'text-gray-900' : 'text-gray-500'">
                {{ u.full_name || '—' }}<span v-if="u.id === user?.id" class="ml-1 text-xs font-normal text-gray-500">(you)</span>
              </div>
              <div class="text-xs text-gray-500">{{ u.email || u.username }}</div>
              <div v-if="!isSuperAdmin && otherTeamsOf(u).length" class="text-xs text-gray-500">Also works in {{ otherTeamsOf(u).join(', ') }}</div>
            </td>
            <td v-if="isSuperAdmin" class="px-4 py-3">
              <div class="flex flex-wrap gap-1">
                <span class="inline-flex rounded-full px-2 text-xs font-semibold leading-5" :class="u.team?.name ? 'bg-indigo-100 text-indigo-800' : 'bg-gray-100 text-gray-800'">
                  {{ u.team?.name || 'No team' }}
                </span>
                <!-- Extra teams (migration 027): outlined, so the home team stands out. -->
                <span
                  v-for="t in u.extra_teams || []"
                  :key="t.id"
                  class="inline-flex rounded-full border border-indigo-200 px-2 text-xs leading-5 text-indigo-700"
                  :title="`Also works in ${t.name}`"
                >+ {{ t.name }}</span>
              </div>
            </td>
            <td class="whitespace-nowrap px-4 py-3">
              <span class="inline-flex rounded-full px-2 text-xs font-semibold leading-5" :class="roleBadgeClass(roleOf(u))">{{ roleLabel(roleOf(u)) }}</span>
            </td>
            <td class="whitespace-nowrap px-4 py-3">
              <span
                class="inline-flex rounded-full px-2 text-xs font-semibold leading-5"
                :class="u.is_active ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'"
              >{{ u.is_active ? 'Active' : 'Inactive' }}</span>
            </td>
            <td class="whitespace-nowrap px-4 py-3 text-gray-600">{{ lastSignIn(u) }}</td>
            <td class="whitespace-nowrap px-4 py-3 text-right">
              <div v-if="canManageAccount(u)" class="flex justify-end gap-3">
                <button type="button" class="text-blue-600 hover:text-blue-900" @click="openEdit(u)">Edit</button>
                <!-- Your own password is changed in My account, which asks for the current one. -->
                <button v-if="u.id !== user?.id" type="button" class="text-indigo-600 hover:text-indigo-900" @click="openReset(u)">Reset password</button>
                <button
                  v-if="u.id !== user?.id"
                  type="button"
                  class="text-gray-600 hover:text-gray-900"
                  @click="openToggle(u)"
                >{{ u.is_active ? 'Deactivate' : 'Activate' }}</button>
              </div>
              <span v-else class="text-xs text-gray-400">{{
                u.is_super_admin ? 'Managed by a Super Admin' : 'Works in other teams too — managed by a Super Admin'
              }}</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Create -->
    <UiModal v-if="showCreate" title="Create a user" :busy="createBusy" @close="showCreate = false">
      <form id="create-user-form" class="space-y-3" @submit.prevent="submitCreate">
        <div>
          <label for="new-user-email" class="mb-1 block text-sm font-medium text-gray-700">Email (they sign in with this)</label>
          <input id="new-user-email" v-model="createForm.email" type="email" autocomplete="off" placeholder="name@example.com" class="w-full rounded-md border border-gray-300 px-3 py-2" />
        </div>
        <div>
          <label for="new-user-password" class="mb-1 block text-sm font-medium text-gray-700">Password</label>
          <input id="new-user-password" v-model="createForm.password" type="password" autocomplete="new-password" class="w-full rounded-md border border-gray-300 px-3 py-2" />
          <p class="mt-1 text-xs text-gray-500">At least {{ MIN_PASSWORD_LENGTH }} characters. They can change it in Settings.</p>
        </div>
        <div>
          <label for="new-user-name" class="mb-1 block text-sm font-medium text-gray-700">Full name</label>
          <input id="new-user-name" v-model="createForm.full_name" type="text" class="w-full rounded-md border border-gray-300 px-3 py-2" />
        </div>
        <div>
          <label for="new-user-team" class="mb-1 block text-sm font-medium text-gray-700">{{ isSuperAdmin ? 'Home team' : 'Team' }}</label>
          <select v-if="isSuperAdmin" id="new-user-team" v-model="createForm.team_id" class="w-full rounded-md border border-gray-300 px-3 py-2">
            <option value="" disabled>Pick a team…</option>
            <option v-for="t in teams" :key="t.id" :value="t.id">{{ t.name }}</option>
          </select>
          <p v-else id="new-user-team" class="rounded-md border border-gray-200 bg-gray-50 px-3 py-2 text-sm text-gray-900">{{ ownTeamName || 'Your team' }}</p>
        </div>
        <div>
          <label for="new-user-role" class="mb-1 block text-sm font-medium text-gray-700">Role</label>
          <select id="new-user-role" v-model="createForm.role" class="w-full rounded-md border border-gray-300 px-3 py-2">
            <option value="" disabled>Pick a role…</option>
            <option v-for="r in assignableRoles" :key="r.key" :value="r.key">{{ r.label }}</option>
          </select>
          <p class="mt-1 text-xs text-gray-500">{{ roleDescription(createForm.role) || 'An account holds exactly one role.' }}</p>
        </div>
        <SettingsExtraTeamsField
          v-if="isSuperAdmin && multiTeamRole(createForm.role) && createForm.team_id"
          v-model="createForm.extra_team_ids"
          :teams="teams"
          :home-team-id="createForm.team_id"
        />
        <p v-if="createError" role="alert" class="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">{{ createError }}</p>
      </form>
      <template #footer>
        <button type="button" :disabled="createBusy" class="rounded-lg border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50" @click="showCreate = false">Cancel</button>
        <button
          type="submit"
          form="create-user-form"
          :disabled="createBusy || !!createBlocker"
          :title="createBlocker || undefined"
          class="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
        >{{ createBusy ? 'Creating…' : 'Create user' }}</button>
      </template>
    </UiModal>

    <!-- Edit -->
    <UiModal v-if="editing" :title="`Edit ${editing.email || editing.username}`" :busy="editBusy" @close="editing = null">
      <form id="edit-user-form" class="space-y-3" @submit.prevent="submitEdit">
        <div>
          <label for="edit-user-name" class="mb-1 block text-sm font-medium text-gray-700">Full name</label>
          <input id="edit-user-name" v-model="editForm.full_name" type="text" class="w-full rounded-md border border-gray-300 px-3 py-2" />
        </div>
        <div>
          <label for="edit-user-team" class="mb-1 block text-sm font-medium text-gray-700">{{ isSuperAdmin ? 'Home team' : 'Team' }}</label>
          <select v-if="isSuperAdmin" id="edit-user-team" v-model="editForm.team_id" class="w-full rounded-md border border-gray-300 px-3 py-2">
            <option v-for="t in teams" :key="t.id" :value="t.id">{{ t.name }}</option>
          </select>
          <p v-else id="edit-user-team" class="rounded-md border border-gray-200 bg-gray-50 px-3 py-2 text-sm text-gray-900">{{ editing.team?.name || 'Your team' }}</p>
        </div>
        <div>
          <label for="edit-user-role" class="mb-1 block text-sm font-medium text-gray-700">Role</label>
          <select
            id="edit-user-role"
            v-model="editForm.role"
            :disabled="editingSelf"
            class="w-full rounded-md border border-gray-300 px-3 py-2 disabled:bg-gray-50 disabled:text-gray-500"
          >
            <option v-for="r in assignableRoles" :key="r.key" :value="r.key">{{ r.label }}</option>
          </select>
          <p class="mt-1 text-xs text-gray-500">
            {{ editingSelf ? "You can't change your own role or deactivate yourself — ask another administrator." : roleDescription(editForm.role) }}
          </p>
        </div>
        <SettingsExtraTeamsField
          v-if="isSuperAdmin && multiTeamRole(editForm.role)"
          v-model="editForm.extra_team_ids"
          :teams="teams"
          :home-team-id="editForm.team_id"
        />
        <label class="flex items-center gap-2 text-sm text-gray-700">
          <input v-model="editForm.is_active" type="checkbox" :disabled="editingSelf" class="h-4 w-4" />
          Active (can sign in)
        </label>
        <p v-if="editError" role="alert" class="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">{{ editError }}</p>
      </form>
      <template #footer>
        <button type="button" :disabled="editBusy" class="rounded-lg border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50" @click="editing = null">Cancel</button>
        <button
          type="submit"
          form="edit-user-form"
          :disabled="editBusy || !editForm.role"
          class="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
        >{{ editBusy ? 'Saving…' : 'Save changes' }}</button>
      </template>
    </UiModal>

    <!-- Reset password -->
    <UiModal v-if="resetting" :title="`New password for ${resetting.email || resetting.username}`" :busy="resetBusy" @close="resetting = null">
      <form id="reset-password-form" class="space-y-3" @submit.prevent="submitReset">
        <p class="rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-900">
          <template v-if="resetting.is_display_user">
            The wall display signs out at once and asks for the kiosk sign-in again — enter the new password there.
          </template>
          <template v-else>
            They're signed out at once on every device and sign in again with this password. Any reset link
            already emailed to them stops working.
          </template>
        </p>
        <div>
          <label for="reset-password" class="mb-1 block text-sm font-medium text-gray-700">New password</label>
          <input id="reset-password" v-model="resetForm.password" type="password" autocomplete="new-password" class="w-full rounded-md border border-gray-300 px-3 py-2" />
          <p class="mt-1 text-xs" :class="resetForm.password && resetForm.password.length < MIN_PASSWORD_LENGTH ? 'text-amber-700' : 'text-gray-500'">
            At least {{ MIN_PASSWORD_LENGTH }} characters.
          </p>
        </div>
        <div>
          <label for="reset-confirm" class="mb-1 block text-sm font-medium text-gray-700">Type it again</label>
          <input id="reset-confirm" v-model="resetForm.confirm" type="password" autocomplete="new-password" class="w-full rounded-md border border-gray-300 px-3 py-2" />
          <p v-if="resetForm.confirm && resetForm.confirm !== resetForm.password" class="mt-1 text-xs text-amber-700">Doesn't match yet.</p>
        </div>
        <p v-if="resetError" role="alert" class="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">{{ resetError }}</p>
      </form>
      <template #footer>
        <button type="button" :disabled="resetBusy" class="rounded-lg border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50" @click="resetting = null">Cancel</button>
        <button
          type="submit"
          form="reset-password-form"
          :disabled="resetBusy || !!resetBlocker"
          :title="resetBlocker || undefined"
          class="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
        >{{ resetBusy ? 'Setting…' : 'Set password' }}</button>
      </template>
    </UiModal>

    <!-- Who reset or changed whose password (migration 026); this team's accounts. -->
    <AuditChangeLogModal
      v-if="showLog"
      title="Account changes"
      :subtitle="`Password resets and changes on ${ownTeamName || 'this team'}'s accounts.`"
      :entity="['account']"
      @close="showLog = false"
    />

    <!-- Activate / deactivate -->
    <UiConfirmDialog
      v-if="toggling"
      :title="toggling.is_active ? `Deactivate ${toggling.email}?` : `Activate ${toggling.email}?`"
      :message="toggling.is_active
        ? 'They are signed out at once and can\'t sign in until the account is activated again. Nothing they did is lost.'
        : 'They can sign in again with their current password.'"
      :confirm-label="toggling.is_active ? 'Deactivate' : 'Activate'"
      :busy-label="toggling.is_active ? 'Deactivating…' : 'Activating…'"
      :danger="toggling.is_active"
      :busy="toggleBusy"
      :error="toggleError"
      @confirm="submitToggle"
      @cancel="toggling = null"
    />
  </section>
</template>

<script setup lang="ts">
import { ROLES, roleOf, roleLabel, roleBadgeClass, type Role } from '~/utils/roles'

const props = defineProps<{
  users: any[]
  teams: any[]
  state: 'loading' | 'ready' | 'error'
  loadError: string
}>()
const emit = defineEmits<{ changed: []; retry: [] }>()

/** Same minimum as the server (admin/users/create.ts, reset-password.ts). */
const MIN_PASSWORD_LENGTH = 8

const { user, myTeams } = useAuth()
const toast = useToast()
const isSuperAdmin = computed(() => !!user.value?.is_super_admin)
const ownTeamName = computed(() => props.teams.find((t) => t.id === user.value?.team_id)?.name ?? null)
const errorText = (err: any, fallback: string) => err?.data?.message || err?.message || fallback

// A supervisor manages their own team's accounts, other than Super Admins, and can't
// make anyone one. The server enforces the same (assertAccountManageable).
const assignableRoles = computed(() => (isSuperAdmin.value ? ROLES : ROLES.filter((r) => r.key !== 'super_admin')))
const roleDescription = (role: Role | '') => ROLES.find((r) => r.key === role)?.description ?? ''
// An account with extra teams is changed by a Super Admin, or a supervisor who works
// in every one of its teams — the same rule as the server (assertAccountManageable).
const myTeamIds = computed(() => new Set(myTeams.value.map((t) => t.id)))
const teamIdsOf = (u: any): string[] => [u.team_id, ...(u.extra_teams ?? []).map((t: any) => t.id)].filter(Boolean)
const canManageAccount = (u: any) =>
  isSuperAdmin.value || (!u.is_super_admin && teamIdsOf(u).every((id) => myTeamIds.value.has(id)))
/** The account's teams other than the one being worked in now, by name. */
const otherTeamsOf = (u: any): string[] =>
  [u.team, ...(u.extra_teams ?? [])].filter((t: any) => t?.id && t.id !== user.value?.team_id).map((t: any) => t.name)
/** Roles that may work in more than one team (server/utils/teamMembership.ts). */
const multiTeamRole = (role: Role | '') => role === 'supervisor' || role === 'team_lead'

const showLog = ref(false)

// ---- The list ---------------------------------------------------------------------
const search = ref('')
const teamFilter = ref('')
const nameOf = (u: any): string => u.full_name || u.email || u.username || ''
const shown = computed(() => {
  const q = search.value.trim().toLowerCase()
  return [...props.users]
    .filter((u) => !teamFilter.value || u.team_id === teamFilter.value)
    .filter((u) => !q || [u.full_name, u.email, u.username].some((s) => s && String(s).toLowerCase().includes(q)))
    .sort((a, b) => (a.team?.name ?? '').localeCompare(b.team?.name ?? '') || nameOf(a).localeCompare(nameOf(b)))
})
const lastSignIn = (u: any) =>
  u.last_login ? new Date(u.last_login).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) : 'Never'

// ---- Create -------------------------------------------------------------------------
const showCreate = ref(false)
const createBusy = ref(false)
const createError = ref('')
const createForm = ref<{ email: string; password: string; full_name: string; team_id: string; role: Role | ''; extra_team_ids: string[] }>({
  email: '', password: '', full_name: '', team_id: '', role: '', extra_team_ids: [],
})
const createBlocker = computed(() => {
  const f = createForm.value
  if (!f.email.trim()) return 'Enter their email'
  if (f.password.length < MIN_PASSWORD_LENGTH) return `The password needs at least ${MIN_PASSWORD_LENGTH} characters`
  if (!f.team_id) return 'Pick a team'
  if (!f.role) return 'Pick a role'
  return null
})
const openCreate = () => {
  // A supervisor adds accounts to their own team only; a Super Admin starts on theirs.
  createForm.value = { email: '', password: '', full_name: '', team_id: user.value?.team_id ?? '', role: '', extra_team_ids: [] }
  createError.value = ''
  showCreate.value = true
}
const submitCreate = async () => {
  if (createBlocker.value) return
  createBusy.value = true
  createError.value = ''
  const email = createForm.value.email.trim().toLowerCase()
  try {
    await $fetch('/api/admin/users/create', {
      method: 'POST',
      body: {
        email,
        password: createForm.value.password,
        full_name: createForm.value.full_name.trim() || null,
        team_id: createForm.value.team_id,
        role: createForm.value.role,
        // Super Admin only, for Supervisors and Team Leads (the server checks both).
        extra_team_ids: isSuperAdmin.value && multiTeamRole(createForm.value.role)
          ? createForm.value.extra_team_ids.filter((id) => id !== createForm.value.team_id)
          : undefined,
      },
    })
    showCreate.value = false
    toast.success(`Created ${email}. Give them the password you set — it isn't emailed.`)
    emit('changed')
  } catch (err: any) {
    createError.value = errorText(err, 'The account was not created.')
  } finally {
    createBusy.value = false
  }
}

// ---- Edit ---------------------------------------------------------------------------
const editing = ref<any>(null)
const editBusy = ref(false)
const editError = ref('')
const editForm = ref<{ full_name: string; team_id: string; role: Role | ''; is_active: boolean; extra_team_ids: string[] }>({
  full_name: '', team_id: '', role: '', is_active: true, extra_team_ids: [],
})
const editingSelf = computed(() => !!editing.value && editing.value.id === user.value?.id)
const openEdit = (u: any) => {
  editForm.value = {
    full_name: u.full_name || '',
    team_id: u.team_id || '',
    // A legacy multi-flag row shows as its stronger role; saving normalises it.
    role: roleOf(u) ?? '',
    is_active: u.is_active !== false,
    extra_team_ids: (u.extra_teams ?? []).map((t: any) => t.id),
  }
  editError.value = ''
  editing.value = u
}
const submitEdit = async () => {
  if (!editing.value) return
  editBusy.value = true
  editError.value = ''
  try {
    await $fetch(`/api/admin/users/${editing.value.id}`, {
      method: 'PUT',
      body: {
        full_name: editForm.value.full_name.trim() || null,
        // Only a Super Admin moves accounts between teams.
        team_id: isSuperAdmin.value ? editForm.value.team_id || null : undefined,
        role: editingSelf.value ? undefined : editForm.value.role || undefined,
        is_active: editingSelf.value ? undefined : editForm.value.is_active,
        // A Super Admin sets them; another role clears them on the server.
        extra_team_ids: isSuperAdmin.value
          ? multiTeamRole(editForm.value.role) ? editForm.value.extra_team_ids.filter((id) => id !== editForm.value.team_id) : []
          : undefined,
      },
    })
    toast.success(`Saved ${editing.value.email || editing.value.username}.`)
    editing.value = null
    emit('changed')
  } catch (err: any) {
    editError.value = errorText(err, 'The changes were not saved.')
  } finally {
    editBusy.value = false
  }
}

// ---- Reset password ---------------------------------------------------------------
const resetting = ref<any>(null)
const resetBusy = ref(false)
const resetError = ref('')
const resetForm = ref({ password: '', confirm: '' })
const resetBlocker = computed(() => {
  if (resetForm.value.password.length < MIN_PASSWORD_LENGTH) return `At least ${MIN_PASSWORD_LENGTH} characters`
  if (resetForm.value.password !== resetForm.value.confirm) return "The two passwords don't match"
  return null
})
const openReset = (u: any) => {
  resetForm.value = { password: '', confirm: '' }
  resetError.value = ''
  resetting.value = u
}
const submitReset = async () => {
  if (!resetting.value || resetBlocker.value) return
  resetBusy.value = true
  resetError.value = ''
  try {
    await $fetch('/api/admin/users/reset-password', {
      method: 'POST',
      body: { user_id: resetting.value.id, new_password: resetForm.value.password },
    })
    toast.success(`New password set for ${resetting.value.email || resetting.value.username}. They were signed out everywhere — give them the new password.`)
    resetting.value = null
  } catch (err: any) {
    resetError.value = errorText(err, 'The password was not changed.')
  } finally {
    resetBusy.value = false
  }
}

// ---- Activate / deactivate ----------------------------------------------------------
const toggling = ref<any>(null)
const toggleBusy = ref(false)
const toggleError = ref('')
const openToggle = (u: any) => {
  toggleError.value = ''
  toggling.value = u
}
const submitToggle = async () => {
  if (!toggling.value) return
  toggleBusy.value = true
  toggleError.value = ''
  const u = toggling.value
  try {
    await $fetch(`/api/admin/users/${u.id}`, { method: 'PUT', body: { is_active: !u.is_active } })
    toast.success(`${u.email} ${u.is_active ? 'deactivated' : 'activated'}.`)
    toggling.value = null
    emit('changed')
  } catch (err: any) {
    toggleError.value = errorText(err, 'Nothing was changed.')
  } finally {
    toggleBusy.value = false
  }
}
</script>
