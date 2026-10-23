<template>
  <section class="rounded-lg bg-white p-6 shadow" aria-labelledby="teams-title">
    <div class="mb-4 flex flex-wrap items-start justify-between gap-3">
      <div>
        <h2 id="teams-title" class="text-lg font-semibold text-gray-900">Teams</h2>
        <p class="mt-1 text-sm text-gray-500">
          Each site is a team, with its own people, schedules and rules. Its time zone decides "today" for its requests and its display board.
        </p>
      </div>
      <button
        type="button"
        class="rounded-md bg-green-600 px-4 py-2 text-sm font-medium text-white hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500"
        @click="openCreate"
      >+ Create team</button>
    </div>

    <div class="relative overflow-x-auto">
      <table class="min-w-full divide-y divide-gray-200 text-sm">
        <thead class="bg-gray-50 text-left text-xs font-medium uppercase tracking-wider text-gray-500">
          <tr>
            <th scope="col" class="px-4 py-3">Team</th>
            <th scope="col" class="px-4 py-3">Time zone</th>
            <th scope="col" class="px-4 py-3">Accounts</th>
            <th scope="col" class="px-4 py-3"><span class="sr-only">Actions</span></th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-100 bg-white">
          <tr v-for="team in teams" :key="team.id">
            <td class="whitespace-nowrap px-4 py-3 font-medium text-gray-900">
              {{ team.name }}<span v-if="team.id === user?.team_id" class="ml-1 text-xs font-normal text-gray-500">(working in now)</span><span
                v-if="team.id === user?.home_team_id && team.id !== user?.team_id"
                class="ml-1 text-xs font-normal text-gray-500"
              >(your home team)</span>
            </td>
            <td class="whitespace-nowrap px-4 py-3">
              <select
                :key="`${team.id}-${team.timezone}-${zoneResets}`"
                :value="team.timezone"
                :aria-label="`Time zone for ${team.name}`"
                :disabled="zoneSaving === team.id"
                class="rounded-md border border-gray-300 px-2 py-1"
                @change="pickZone(team, ($event.target as HTMLSelectElement).value)"
              >
                <option v-for="z in zoneOptions(team.timezone)" :key="z.value" :value="z.value">{{ z.label }}</option>
                <option :value="OTHER_ZONE">Other…</option>
              </select>
            </td>
            <td class="whitespace-nowrap px-4 py-3 text-gray-600">
              {{ accountsIn(team.id) }}<span v-if="alsoIn(team.id)" class="text-gray-400"> (+{{ alsoIn(team.id) }} from other teams)</span>
            </td>
            <td class="whitespace-nowrap px-4 py-3 text-right">
              <div class="flex justify-end gap-3">
                <button type="button" class="text-blue-600 hover:text-blue-900" @click="openRename(team)">Rename</button>
                <button type="button" class="text-red-600 hover:text-red-900" @click="openDelete(team)">Delete</button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Create -->
    <UiModal v-if="showCreate" title="Create a team" :busy="createBusy" @close="showCreate = false">
      <form id="create-team-form" class="space-y-3" @submit.prevent="submitCreate">
        <div>
          <label for="new-team-name" class="mb-1 block text-sm font-medium text-gray-700">Team name</label>
          <input id="new-team-name" v-model="createForm.name" type="text" :maxlength="MAX_NAME" placeholder="e.g. Memphis DC" class="w-full rounded-md border border-gray-300 px-3 py-2" />
        </div>
        <div>
          <label for="new-team-zone" class="mb-1 block text-sm font-medium text-gray-700">Time zone</label>
          <select id="new-team-zone" v-model="createForm.timezone" class="w-full rounded-md border border-gray-300 px-3 py-2">
            <option v-for="z in TIME_ZONES" :key="z.value" :value="z.value">{{ z.label }}</option>
          </select>
          <p class="mt-1 text-xs text-gray-500">Where the site is.</p>
        </div>
        <p v-if="createError" role="alert" class="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">{{ createError }}</p>
      </form>
      <template #footer>
        <button type="button" :disabled="createBusy" class="rounded-lg border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50" @click="showCreate = false">Cancel</button>
        <button
          type="submit"
          form="create-team-form"
          :disabled="createBusy || !createForm.name.trim()"
          class="rounded-lg bg-green-600 px-4 py-2 text-sm font-medium text-white hover:bg-green-700 disabled:opacity-50"
        >{{ createBusy ? 'Creating…' : 'Create team' }}</button>
      </template>
    </UiModal>

    <!-- Rename -->
    <UiModal v-if="renaming" :title="`Rename ${renaming.name}`" size="sm" :busy="renameBusy" @close="renaming = null">
      <form id="rename-team-form" class="space-y-3" @submit.prevent="submitRename">
        <label for="rename-team" class="block text-sm font-medium text-gray-700">New name</label>
        <input id="rename-team" v-model="renameValue" type="text" :maxlength="MAX_NAME" class="w-full rounded-md border border-gray-300 px-3 py-2" />
        <p v-if="renameError" role="alert" class="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">{{ renameError }}</p>
      </form>
      <template #footer>
        <button type="button" :disabled="renameBusy" class="rounded-lg border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50" @click="renaming = null">Cancel</button>
        <button
          type="submit"
          form="rename-team-form"
          :disabled="renameBusy || !renameValue.trim() || renameValue.trim() === renaming.name"
          class="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
        >{{ renameBusy ? 'Saving…' : 'Rename' }}</button>
      </template>
    </UiModal>

    <!-- A time zone that isn't in the list -->
    <UiModal v-if="otherZone" :title="`Time zone for ${otherZone.team.name}`" size="sm" :busy="zoneSaving === otherZone.team.id" @close="cancelOtherZone">
      <form id="other-zone-form" class="space-y-2" @submit.prevent="saveZone(otherZone.team, otherZone.value.trim())">
        <label for="other-zone" class="block text-sm font-medium text-gray-700">IANA time zone name</label>
        <input id="other-zone" v-model="otherZone.value" type="text" placeholder="e.g. Europe/Dublin" class="w-full rounded-md border border-gray-300 px-3 py-2" />
        <p class="text-xs text-gray-500">As in the tz database: Region/City, for example America/Indiana/Indianapolis.</p>
        <p v-if="zoneError" role="alert" class="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">{{ zoneError }}</p>
      </form>
      <template #footer>
        <button type="button" class="rounded-lg border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50" @click="cancelOtherZone">Cancel</button>
        <button
          type="submit"
          form="other-zone-form"
          :disabled="!otherZone.value.trim() || zoneSaving === otherZone.team.id"
          class="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
        >Use this zone</button>
      </template>
    </UiModal>

    <!-- Delete: only an empty team; typing its name guards the click -->
    <UiConfirmDialog
      v-if="deleting"
      :title="`Delete ${deleting.name}?`"
      message="Only an empty team can be deleted — one with no accounts, employees, shifts, job functions, schedules, requests or time off."
      confirm-label="Delete team"
      busy-label="Deleting…"
      danger
      :confirm-disabled="deleteTyped.trim() !== deleting.name"
      :busy="deleteBusy"
      :error="deleteError"
      @confirm="submitDelete"
      @cancel="deleting = null"
    >
      <label for="delete-team-name" class="mt-3 block text-sm text-gray-700">Type <strong>{{ deleting.name }}</strong> to confirm</label>
      <input id="delete-team-name" v-model="deleteTyped" type="text" autocomplete="off" class="mt-1 w-full rounded-md border border-gray-300 px-3 py-2" />
    </UiConfirmDialog>
  </section>
</template>

<script setup lang="ts">
const props = defineProps<{ teams: any[]; users: any[] }>()
const emit = defineEmits<{ changed: [] }>()

/** Same limit as the server (server/utils/teamName.ts). */
const MAX_NAME = 80

const { user } = useAuth()
const toast = useToast()
const errorText = (err: any, fallback: string) => err?.data?.message || err?.message || fallback

// Accounts whose home is this team — what a delete counts — and, apart, those who
// work in it as an extra team (migration 027; a delete just removes their access).
const accountsIn = (teamId: string) => props.users.filter((u) => u.team_id === teamId).length
const alsoIn = (teamId: string) =>
  props.users.filter((u) => u.team_id !== teamId && (u.extra_teams ?? []).some((t: any) => t.id === teamId)).length

// The common US zones first; any other IANA zone through "Other…" (teams.timezone,
// migration 025 — it decides "today" for the team's requests and display board).
const TIME_ZONES = [
  { value: 'America/New_York', label: 'Eastern (New York)' },
  { value: 'America/Chicago', label: 'Central (Chicago)' },
  { value: 'America/Denver', label: 'Mountain (Denver)' },
  { value: 'America/Phoenix', label: 'Arizona (Phoenix)' },
  { value: 'America/Los_Angeles', label: 'Pacific (Los Angeles)' },
  { value: 'America/Anchorage', label: 'Alaska (Anchorage)' },
  { value: 'Pacific/Honolulu', label: 'Hawaii (Honolulu)' },
  { value: 'America/Puerto_Rico', label: 'Atlantic (Puerto Rico)' },
]
const OTHER_ZONE = '__other__'
/** The list, plus a team's own zone if it isn't one of the common ones. */
const zoneOptions = (current?: string | null) =>
  current && !TIME_ZONES.some((z) => z.value === current) ? [...TIME_ZONES, { value: current, label: current }] : TIME_ZONES

// ---- Time zone ------------------------------------------------------------------------
const zoneSaving = ref<string | null>(null)
const zoneError = ref('')
const zoneResets = ref(0)
const otherZone = ref<{ team: any; value: string } | null>(null)
const pickZone = (team: any, picked: string) => {
  if (picked === OTHER_ZONE) {
    zoneError.value = ''
    otherZone.value = { team, value: zoneOptions().some((z) => z.value === team.timezone) ? '' : team.timezone }
    return
  }
  saveZone(team, picked)
}
const cancelOtherZone = () => {
  otherZone.value = null
  zoneResets.value++ // put the dropdown back on the saved zone
}
const saveZone = async (team: any, zone: string) => {
  if (!zone) return
  zoneSaving.value = team.id
  zoneError.value = ''
  try {
    await $fetch(`/api/teams/${team.id}`, { method: 'PUT', body: { timezone: zone } })
    toast.success(`${team.name} now uses ${zone}.`)
    otherZone.value = null
    emit('changed')
  } catch (err: any) {
    if (otherZone.value) zoneError.value = errorText(err, 'The time zone was not changed.')
    else {
      toast.error(`Couldn't change ${team.name}'s time zone: ${errorText(err, 'unknown error')}`)
      zoneResets.value++
    }
  } finally {
    zoneSaving.value = null
  }
}

// ---- Create -----------------------------------------------------------------------------
const browserZone = Intl.DateTimeFormat().resolvedOptions().timeZone
const showCreate = ref(false)
const createBusy = ref(false)
const createError = ref('')
const createForm = ref({ name: '', timezone: 'America/Chicago' })
const openCreate = () => {
  createForm.value = { name: '', timezone: TIME_ZONES.some((z) => z.value === browserZone) ? browserZone : 'America/Chicago' }
  createError.value = ''
  showCreate.value = true
}
const submitCreate = async () => {
  createBusy.value = true
  createError.value = ''
  try {
    const team = await $fetch<any>('/api/teams', { method: 'POST', body: { name: createForm.value.name.trim(), timezone: createForm.value.timezone } })
    showCreate.value = false
    // Until its Request Rules are saved, a team runs on the defaults, including a
    // team-wide 8 hours of time off a day.
    toast.success(`Team "${team.name}" created. Before its people start, switch to it ("Working in" on the home page) and save its Request rules.`)
    emit('changed')
  } catch (err: any) {
    createError.value = errorText(err, 'The team was not created.')
  } finally {
    createBusy.value = false
  }
}

// ---- Rename -----------------------------------------------------------------------------
const renaming = ref<any>(null)
const renameValue = ref('')
const renameBusy = ref(false)
const renameError = ref('')
const openRename = (team: any) => {
  renameValue.value = team.name
  renameError.value = ''
  renaming.value = team
}
const submitRename = async () => {
  if (!renaming.value) return
  renameBusy.value = true
  renameError.value = ''
  try {
    const team = await $fetch<any>(`/api/teams/${renaming.value.id}`, { method: 'PUT', body: { name: renameValue.value.trim() } })
    toast.success(`Renamed to "${team.name}".`)
    renaming.value = null
    emit('changed')
  } catch (err: any) {
    renameError.value = errorText(err, 'The team was not renamed.')
  } finally {
    renameBusy.value = false
  }
}

// ---- Delete ------------------------------------------------------------------------------
const deleting = ref<any>(null)
const deleteTyped = ref('')
const deleteBusy = ref(false)
const deleteError = ref('')
const openDelete = (team: any) => {
  deleteTyped.value = ''
  deleteError.value = ''
  deleting.value = team
}
const submitDelete = async () => {
  if (!deleting.value) return
  deleteBusy.value = true
  deleteError.value = ''
  try {
    // The server refuses a team that still holds anything, and says what.
    await $fetch(`/api/teams/${deleting.value.id}`, { method: 'DELETE' })
    toast.success(`Deleted the team "${deleting.value.name}".`)
    deleting.value = null
    emit('changed')
  } catch (err: any) {
    deleteError.value = errorText(err, 'The team was not deleted.')
  } finally {
    deleteBusy.value = false
  }
}
</script>
