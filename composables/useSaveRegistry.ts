/**
 * Every inline save on a page registers here while a request is out ('busy') or
 * after one failed and hasn't been retried or undone ('failed'). Leaving the page —
 * the router, a refresh, closing the tab — then warns instead of quietly dropping it.
 *
 * Keys are namespaced by the saver ("training:<employee id>", "box:target-hours:<id>").
 * useBoxSave and useTrainingSaves keep this up to date; pages only read it, through
 * useLeaveGuard().
 */
import { onBeforeRouteLeave } from 'vue-router'

export type RegistryState = 'busy' | 'failed'

export const useSaveRegistry = () => {
  const entries = useState<Record<string, RegistryState>>('save-registry', () => ({}))

  const mark = (key: string, state: RegistryState | null) => {
    const next = { ...entries.value }
    if (state) next[key] = state
    else delete next[key]
    entries.value = next
  }

  const isBusy = computed(() => Object.values(entries.value).includes('busy'))
  /** A save still out, or one that failed and is waiting for Retry / Undo. */
  const hasUnsaved = computed(() => Object.keys(entries.value).length > 0)

  /** Resolves true once nothing is in flight, false if `ms` passes first. */
  const whenIdle = (ms = 5000) =>
    new Promise<boolean>((resolve) => {
      const started = Date.now()
      const tick = () => {
        if (!isBusy.value) return resolve(true)
        if (Date.now() - started >= ms) return resolve(false)
        setTimeout(tick, 100)
      }
      tick()
    })

  return { mark, isBusy, hasUnsaved, whenIdle }
}

/**
 * For a page with inline saves (Team Setup): leaving waits briefly for saves in
 * flight, then asks if anything is still unsaved. Refresh / close warns too.
 * Switching tabs within the page needs no guard — the savers outlive the tab.
 */
export const useLeaveGuard = (message = "Some changes haven't saved yet. Leave anyway?") => {
  const registry = useSaveRegistry()

  onBeforeRouteLeave(async () => {
    if (registry.isBusy.value) await registry.whenIdle(5000)
    if (!registry.hasUnsaved.value) return true
    return window.confirm(message)
  })

  const onBeforeUnload = (e: BeforeUnloadEvent) => {
    if (!registry.hasUnsaved.value) return
    e.preventDefault()
    e.returnValue = message
  }
  onMounted(() => window.addEventListener('beforeunload', onBeforeUnload))
  onBeforeUnmount(() => window.removeEventListener('beforeunload', onBeforeUnload))

  return registry
}
