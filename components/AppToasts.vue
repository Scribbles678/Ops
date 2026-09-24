<!--
  The one place toasts appear (see composables/useToast.ts). Mounted once, in app.vue.
  Successes sit in a polite live region, so a screen reader mentions them without
  interrupting; each error is its own role="alert", which is announced at once.
-->
<template>
  <div class="fixed bottom-4 right-4 z-[70] flex w-[min(24rem,calc(100vw-2rem))] flex-col gap-2 pointer-events-none">
    <div role="status" aria-live="polite" class="flex flex-col gap-2">
      <div
        v-for="t in successes"
        :key="t.id"
        class="pointer-events-auto flex items-start gap-2 rounded-lg border border-emerald-200 bg-white px-3 py-2.5 text-sm text-gray-800 shadow-lg"
      >
        <svg class="mt-0.5 h-4 w-4 flex-shrink-0 text-emerald-600" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
          <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
        </svg>
        <span class="flex-1">{{ t.message }}</span>
      </div>
    </div>
    <div
      v-for="t in errors"
      :key="t.id"
      role="alert"
      class="pointer-events-auto flex items-start gap-2 rounded-lg border border-red-200 bg-red-50 px-3 py-2.5 text-sm text-red-800 shadow-lg"
    >
      <span class="flex-1">{{ t.message }}</span>
      <button
        type="button"
        class="-mr-1 -mt-0.5 rounded px-1.5 text-lg leading-none text-red-700 hover:bg-red-100"
        aria-label="Dismiss"
        @click="dismiss(t.id)"
      >&times;</button>
    </div>
  </div>
</template>

<script setup lang="ts">
const { toasts, dismiss } = useToast()
const successes = computed(() => toasts.value.filter((t) => t.kind === 'success'))
const errors = computed(() => toasts.value.filter((t) => t.kind === 'error'))
</script>
