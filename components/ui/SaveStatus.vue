<!--
  What happened to one inline edit (driven by useBoxSave / useTrainingSaves /
  useSaveStatus). Renders nothing when idle, so a page full of untouched rows stays
  quiet (Team Setup used to show a grey "No Changes" badge on every employee).

  On failure the reason is shown as text, not only in a tooltip, and the
  announcement names what failed ("Training for Smith, Mark: …"), so a screen
  reader hears which of many rows it was. Retry appears only when sending again
  could help; Undo (put back the last saved value) whenever the parent handles it.
-->
<template>
  <span class="inline-flex min-h-[1.25rem] flex-wrap items-center gap-x-1 gap-y-0.5 text-xs" aria-live="polite">
    <template v-if="state === 'saving'">
      <svg class="h-3 w-3 animate-spin text-gray-500" fill="none" viewBox="0 0 24 24" aria-hidden="true">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
      </svg>
      <span class="text-gray-600"><span v-if="label" class="sr-only">{{ label }}: </span>Saving…</span>
    </template>
    <template v-else-if="state === 'saved'">
      <svg class="h-3.5 w-3.5 text-emerald-600" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
        <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
      </svg>
      <span class="text-emerald-700"><span v-if="label" class="sr-only">{{ label }}: </span>Saved</span>
    </template>
    <template v-else-if="state === 'error'">
      <span class="text-red-700"><span v-if="label" class="sr-only">{{ label }}: </span>{{ message || "Couldn't save" }}</span>
      <button
        v-if="retryable"
        type="button"
        class="rounded px-1 font-medium text-red-700 underline hover:bg-red-50"
        @click="emit('retry')"
      >Retry</button>
      <button
        v-if="undoable"
        type="button"
        class="rounded px-1 font-medium text-gray-700 underline hover:bg-gray-100"
        @click="emit('undo')"
      >Undo</button>
    </template>
  </span>
</template>

<script setup lang="ts">
import type { SaveState } from '~/composables/useSaveStatus'

withDefaults(defineProps<{
  state: SaveState
  message?: string
  /** Names what this status is about, for screen readers: "Training for Smith, Mark". */
  label?: string
  retryable?: boolean
  undoable?: boolean
}>(), { retryable: true, undoable: false })
const emit = defineEmits<{ retry: []; undo: [] }>()
</script>
