<!--
  What happened to one inline edit. Driven by useSaveStatus(); renders nothing when
  idle, so a page full of untouched rows stays quiet (Team Setup used to show a grey
  "No Changes" badge on every employee).
-->
<template>
  <span class="inline-flex min-h-[1.25rem] items-center gap-1 whitespace-nowrap text-xs" aria-live="polite">
    <template v-if="state === 'saving'">
      <svg class="h-3 w-3 animate-spin text-gray-500" fill="none" viewBox="0 0 24 24" aria-hidden="true">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
      </svg>
      <span class="text-gray-600">Saving…</span>
    </template>
    <template v-else-if="state === 'saved'">
      <svg class="h-3.5 w-3.5 text-emerald-600" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
        <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
      </svg>
      <span class="text-emerald-700">Saved</span>
    </template>
    <template v-else-if="state === 'error'">
      <span class="text-red-700" :title="message">{{ shortMessage }}</span>
      <button
        type="button"
        class="rounded px-1 font-medium text-red-700 underline hover:bg-red-50"
        @click="emit('retry')"
      >Retry</button>
    </template>
  </span>
</template>

<script setup lang="ts">
import type { SaveState } from '~/composables/useSaveStatus'

const props = defineProps<{ state: SaveState; message?: string }>()
const emit = defineEmits<{ retry: [] }>()

// The full reason goes in the tooltip; the row only has room for the gist.
const shortMessage = computed(() => (props.message && props.message.length <= 40 ? props.message : "Couldn't save"))
</script>
