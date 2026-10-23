<!--
  The one window shell for forms and confirmations (Team Setup's add / edit windows,
  UiConfirmDialog). Mount it with v-if; it emits `close` and the parent decides.

  - role="dialog", aria-modal, labelled by its title
  - focus moves in on open: an element marked [data-autofocus], else the first field
  - Tab stays inside while open; Escape closes the top window wherever focus is
    (not while `busy`), and focus comes back inside when it stops being busy
  - focus goes back to whatever opened it when it closes
  - the backdrop does NOT close a form (typing would be lost); pass
    close-on-backdrop for windows with nothing to lose
-->
<template>
  <div
    class="fixed inset-0 flex items-center justify-center bg-black/50 p-4"
    :class="layer === 'top' ? 'z-[60]' : 'z-50'"
    @click.self="closeOnBackdrop && !busy && emit('close')"
  >
    <div
      ref="panel"
      role="dialog"
      aria-modal="true"
      :aria-labelledby="titleId"
      class="flex max-h-full w-full flex-col rounded-xl bg-white shadow-2xl"
      :class="size === 'lg' ? 'max-w-lg' : size === 'sm' ? 'max-w-sm' : 'max-w-md'"
      @keydown="onKeydown"
    >
      <h3 :id="titleId" class="px-5 pb-2 pt-5 text-lg font-semibold text-gray-900">{{ title }}</h3>
      <div class="min-h-0 overflow-y-auto px-5 pb-4">
        <slot />
      </div>
      <div v-if="$slots.footer" class="flex flex-wrap items-center justify-end gap-2 border-t border-gray-200 px-5 py-3">
        <slot name="footer" />
      </div>
    </div>
  </div>
</template>

<script lang="ts">
/** Open windows, innermost last. Escape closes only the top one. */
const openWindows: symbol[] = []
</script>

<script setup lang="ts">
const props = withDefaults(defineProps<{
  title: string
  busy?: boolean
  size?: 'sm' | 'md' | 'lg'
  closeOnBackdrop?: boolean
  /** 'top' sits above other windows (a confirm opened from a form). */
  layer?: 'normal' | 'top'
}>(), { busy: false, size: 'md', closeOnBackdrop: false, layer: 'normal' })
const emit = defineEmits<{ close: [] }>()

const titleId = useId()
const panel = ref<HTMLElement | null>(null)
let opener: HTMLElement | null = null

const FOCUSABLE = 'a[href], button:not([disabled]), input:not([disabled]):not([type="hidden"]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'
const focusables = () => [...(panel.value?.querySelectorAll<HTMLElement>(FOCUSABLE) ?? [])].filter((el) => el.offsetParent !== null)

const me = Symbol('window')

onMounted(() => {
  opener = document.activeElement as HTMLElement | null
  openWindows.push(me)
  document.addEventListener('keydown', onDocumentKeydown)
  nextTick(() => {
    const target = panel.value?.querySelector<HTMLElement>('[data-autofocus]') ?? focusables().find((el) => el.matches('input, select, textarea')) ?? focusables()[0]
    target?.focus()
  })
})
onBeforeUnmount(() => {
  openWindows.splice(openWindows.indexOf(me), 1)
  document.removeEventListener('keydown', onDocumentKeydown)
  if (opener && document.contains(opener)) opener.focus()
})

// Escape is heard on the document, not the panel: a Save button disabled while
// busy drops focus to <body>, and after a failed save Escape then did nothing.
const onDocumentKeydown = (e: KeyboardEvent) => {
  if (e.key !== 'Escape' || openWindows[openWindows.length - 1] !== me) return
  e.preventDefault()
  if (!props.busy) emit('close')
}
// ...and once it isn't busy any more, focus comes back inside, so Tab and Enter work.
watch(() => props.busy, (busy) => {
  if (!busy && panel.value && !panel.value.contains(document.activeElement)) {
    nextTick(() => (focusables().find((el) => el.matches('input, select, textarea')) ?? focusables()[0])?.focus())
  }
})

const onKeydown = (e: KeyboardEvent) => {
  if (e.key !== 'Tab') return
  const els = focusables()
  if (!els.length) return
  const first = els[0]!
  const last = els[els.length - 1]!
  if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus() }
  else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus() }
}
</script>
