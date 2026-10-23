<!--
  "More teams" in Settings → Users (Create / Edit; Super Admin only): the extra teams
  an account may also work in, besides its home team (migration 027). Supervisors and
  Team Leads only — the parent hides this for other roles, and the server refuses it.
-->
<template>
  <fieldset>
    <legend class="mb-1 text-sm font-medium text-gray-700">More teams</legend>
    <p class="mb-2 text-xs text-gray-500">
      They can switch between their home team and these, one at a time, from the home page.
    </p>
    <div class="flex flex-wrap gap-x-4 gap-y-1.5">
      <label v-for="t in others" :key="t.id" class="flex items-center gap-1.5 text-sm text-gray-700">
        <input type="checkbox" class="h-4 w-4" :value="t.id" :checked="modelValue.includes(t.id)" @change="toggle(t.id)" />
        {{ t.name }}
      </label>
      <span v-if="!others.length" class="text-sm italic text-gray-500">There are no other teams yet.</span>
    </div>
  </fieldset>
</template>

<script setup lang="ts">
const props = defineProps<{ modelValue: string[]; teams: { id: string; name: string }[]; homeTeamId: string }>()
const emit = defineEmits<{ 'update:modelValue': [ids: string[]] }>()

const others = computed(() => props.teams.filter((t) => t.id !== props.homeTeamId))
const toggle = (id: string) =>
  emit('update:modelValue', props.modelValue.includes(id) ? props.modelValue.filter((x) => x !== id) : [...props.modelValue, id])
</script>
