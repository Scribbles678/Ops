<template>
  <div class="grid gap-6 md:grid-cols-2">
    <!-- Who you are -->
    <section class="rounded-lg bg-white p-6 shadow" aria-labelledby="account-info-title">
      <h2 id="account-info-title" class="mb-4 text-lg font-semibold text-gray-900">Your account</h2>
      <dl class="space-y-4 text-sm">
        <div>
          <dt class="font-medium text-gray-500">Name</dt>
          <dd class="mt-1 text-gray-900">{{ user?.full_name || '—' }}</dd>
        </div>
        <div>
          <dt class="font-medium text-gray-500">Email (you sign in with this)</dt>
          <dd class="mt-1 text-gray-900">{{ user?.email }}</dd>
        </div>
        <div>
          <dt class="font-medium text-gray-500">Team</dt>
          <!-- More than one team (or a Super Admin): switch here, as on the home page.
               It changes this browser only; the home team is where sign-in starts. -->
          <dd v-if="myTeams.length > 1" class="mt-1 space-y-1">
            <TeamSwitcher variant="select" />
            <p class="text-xs text-gray-500">
              Home team: {{ homeTeamName || '—' }}. Switching changes this browser only; signing in starts at your home team.
            </p>
          </dd>
          <dd v-else class="mt-1">
            <span
              class="inline-flex rounded-full px-2 text-xs font-semibold leading-5"
              :class="teamName ? 'bg-indigo-100 text-indigo-800' : 'bg-gray-100 text-gray-800'"
            >{{ teamName || 'No team' }}</span>
          </dd>
        </div>
        <div>
          <dt class="font-medium text-gray-500">Role</dt>
          <dd class="mt-1">
            <span class="inline-flex rounded-full px-2 text-xs font-semibold leading-5" :class="roleBadgeClass(role)">
              {{ roleLabel(role) }}
            </span>
            <p v-if="role" class="mt-1 text-xs text-gray-500">{{ roleDescription }}</p>
            <p v-else class="mt-2 rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-amber-800">
              This account has no role, so it cannot view or change anything yet. Ask your supervisor or a Super Admin to assign one.
            </p>
          </dd>
        </div>
      </dl>
      <!-- Not self-editable on purpose: the change log records this name next to
           everything a person approves or deletes. -->
      <p class="mt-4 text-xs text-gray-500">Your name is what the change log shows, so a supervisor changes it (Settings → Users).</p>
    </section>

    <!-- Password -->
    <section class="rounded-lg bg-white p-6 shadow" aria-labelledby="password-title">
      <h2 id="password-title" class="text-lg font-semibold text-gray-900">Change password</h2>
      <p class="mb-4 mt-1 text-sm text-gray-500">Your other devices are signed out; this one stays signed in.</p>
      <form class="space-y-4" @submit.prevent="changeOwnPassword">
        <div>
          <label for="current-password" class="mb-1 block text-sm font-medium text-gray-700">Current password</label>
          <input
            id="current-password"
            v-model="current"
            type="password"
            autocomplete="current-password"
            :disabled="changing"
            class="w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
        <div>
          <label for="new-password" class="mb-1 block text-sm font-medium text-gray-700">New password</label>
          <input
            id="new-password"
            v-model="next"
            type="password"
            autocomplete="new-password"
            :disabled="changing"
            aria-describedby="new-password-hint"
            class="w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <p id="new-password-hint" class="mt-1 text-xs" :class="next && next.length < MIN_PASSWORD_LENGTH ? 'text-amber-700' : 'text-gray-500'">
            At least {{ MIN_PASSWORD_LENGTH }} characters{{ next && next.length < MIN_PASSWORD_LENGTH ? ` — ${MIN_PASSWORD_LENGTH - next.length} more` : '' }}
          </p>
        </div>
        <div>
          <label for="confirm-password" class="mb-1 block text-sm font-medium text-gray-700">Type the new password again</label>
          <input
            id="confirm-password"
            v-model="confirm"
            type="password"
            autocomplete="new-password"
            :disabled="changing"
            class="w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <p v-if="confirm && confirm !== next" class="mt-1 text-xs text-amber-700">Doesn't match the new password yet.</p>
        </div>

        <p v-if="passwordError" role="alert" class="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">{{ passwordError }}</p>

        <button
          type="submit"
          :disabled="changing || !!passwordBlocker"
          :title="passwordBlocker || undefined"
          class="w-full rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-50"
        >{{ changing ? 'Changing password…' : 'Change password' }}</button>
      </form>
    </section>
  </div>
</template>

<script setup lang="ts">
import { ROLES, roleOf, roleLabel, roleBadgeClass } from '~/utils/roles'

defineProps<{ teamName: string | null }>()

/** Same minimum as the server (auth/change-password, admin reset, create user). */
const MIN_PASSWORD_LENGTH = 8

const { user, myTeams, changePassword } = useAuth()
const homeTeamName = computed(() => myTeams.value.find((t) => t.home)?.name ?? null)
const toast = useToast()

const role = computed(() => roleOf(user.value))
const roleDescription = computed(() => ROLES.find((r) => r.key === role.value)?.description ?? '')

// ---- Password ------------------------------------------------------------------
const current = ref('')
const next = ref('')
const confirm = ref('')
const changing = ref(false)
const passwordError = ref('')

/** Why the button is off, in words (shown as its tooltip); null when it can be pressed. */
const passwordBlocker = computed(() => {
  if (!current.value || !next.value || !confirm.value) return 'Fill in all three boxes'
  if (next.value.length < MIN_PASSWORD_LENGTH) return `The new password needs at least ${MIN_PASSWORD_LENGTH} characters`
  if (next.value !== confirm.value) return "The two new passwords don't match"
  if (next.value === current.value) return 'The new password must be different from the current one'
  return null
})

const changeOwnPassword = async () => {
  if (passwordBlocker.value) return
  passwordError.value = ''
  changing.value = true
  try {
    await changePassword(current.value, next.value)
    current.value = next.value = confirm.value = ''
    toast.success('Password changed. Your other devices were signed out.')
  } catch (err: any) {
    // The server's own words ("Current password is incorrect"), not the raw request text.
    passwordError.value = err.data?.message || err.message || 'The password could not be changed.'
  } finally {
    changing.value = false
  }
}
</script>
