<!--
  "Working in": the teams this account may work in, the current one marked; picking
  another switches this browser to it (useAuth().switchTeam — a form POST, so the
  browser asks about unsaved edits first). Renders nothing for an account with one
  team. The home page shows it as buttons, My account and the bar as a dropdown.
-->
<template>
  <div v-if="myTeams.length > 1" class="flex flex-wrap items-center gap-2">
    <span class="text-sm font-medium text-gray-600">{{ label }}</span>

    <div v-if="variant === 'buttons' && myTeams.length <= MAX_BUTTONS" class="flex flex-wrap gap-2" role="group" aria-label="Switch team">
      <button
        v-for="t in myTeams"
        :key="t.id"
        type="button"
        :aria-pressed="t.id === user?.team_id"
        :disabled="switching"
        :class="[
          'rounded-full border px-4 py-1.5 text-sm font-medium transition-colors',
          t.id === user?.team_id
            ? 'border-blue-600 bg-blue-600 text-white'
            : 'border-gray-300 bg-white text-gray-700 hover:border-blue-400 hover:bg-blue-50',
        ]"
        @click="pick(t.id)"
      >
        <span v-if="t.id === user?.team_id" aria-hidden="true">✓ </span>{{ t.name }}
      </button>
    </div>

    <select
      v-else
      :key="resets"
      :value="user?.team_id ?? ''"
      :disabled="switching"
      aria-label="Switch team"
      class="rounded-md border border-gray-300 bg-white px-3 py-1.5 text-sm font-medium text-gray-800"
      @change="pick(($event.target as HTMLSelectElement).value)"
    >
      <option v-for="t in myTeams" :key="t.id" :value="t.id">{{ t.name }}{{ t.home ? ' (home)' : '' }}</option>
    </select>
  </div>
</template>

<script setup lang="ts">
withDefaults(defineProps<{ variant?: 'buttons' | 'select'; label?: string }>(), { variant: 'select', label: 'Working in:' })

/** More teams than this and the buttons become a dropdown. */
const MAX_BUTTONS = 5

const { user, myTeams, switchTeam } = useAuth()
const switching = ref(false)
const resets = ref(0)

const pick = (teamId: string) => {
  if (!teamId || teamId === user.value?.team_id) return
  switching.value = true
  switchTeam(teamId)
  // If the browser's "leave this page?" prompt is cancelled, nothing switched and
  // the page stays: show the current team again and let the control be used.
  setTimeout(() => {
    switching.value = false
    resets.value++
  }, 1500)
}
</script>
