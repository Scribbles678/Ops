<!--
  A confirmation for anything that can't be undone, on the shared window shell
  (UiModal). Replaces the browser's confirm(), which could only say "Are you sure?" —
  it couldn't list what a delete would erase, offer a safer alternative, or say why
  it failed.

  The parent mounts it with v-if and closes it. Focus starts on Cancel, so Enter never
  destroys anything by accident; Escape and the backdrop cancel (not while busy).
-->
<template>
  <UiModal :title="title" :busy="busy" close-on-backdrop layer="top" @close="emit('cancel')">
    <p v-if="message" class="text-sm text-gray-700">{{ message }}</p>

    <p v-if="loading" class="mt-3 text-sm text-gray-500">Checking what this affects…</p>
    <ul v-else-if="items?.length" class="mt-3 list-disc space-y-1 pl-5 text-sm text-gray-700">
      <li v-for="(line, i) in items" :key="i">{{ line }}</li>
    </ul>
    <slot />

    <p v-if="error" role="alert" class="mt-3 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
      {{ error }}
    </p>

    <template #footer>
      <button
        type="button"
        data-autofocus
        :disabled="busy"
        class="rounded-lg border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 disabled:opacity-50"
        @click="emit('cancel')"
      >Cancel</button>
      <button
        v-if="secondaryLabel"
        type="button"
        :disabled="busy || loading || secondaryDisabled"
        :title="secondaryDisabledReason"
        class="rounded-lg border border-blue-300 bg-blue-50 px-4 py-2 text-sm font-medium text-blue-700 hover:bg-blue-100 disabled:opacity-50"
        @click="emit('secondary')"
      >{{ secondaryLabel }}</button>
      <button
        v-if="confirmLabel"
        type="button"
        :disabled="busy || loading || confirmDisabled"
        class="rounded-lg px-4 py-2 text-sm font-medium text-white disabled:opacity-50"
        :class="danger ? 'bg-red-600 hover:bg-red-700' : 'bg-blue-600 hover:bg-blue-700'"
        @click="emit('confirm')"
      >{{ busy ? busyLabel || 'Working…' : confirmLabel }}</button>
    </template>
  </UiModal>
</template>

<script setup lang="ts">
defineProps<{
  title: string
  message?: string
  /** One line per consequence, shown as a list. */
  items?: string[]
  /** True while the consequences are still being looked up. */
  loading?: boolean
  confirmLabel?: string
  busyLabel?: string
  danger?: boolean
  confirmDisabled?: boolean
  secondaryLabel?: string
  secondaryDisabled?: boolean
  secondaryDisabledReason?: string
  busy?: boolean
  error?: string
}>()
const emit = defineEmits<{ confirm: []; secondary: []; cancel: [] }>()
</script>
