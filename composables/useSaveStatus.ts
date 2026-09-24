/**
 * The status of inline edits, keyed by whatever identifies the thing being saved
 * (an employee id, "shift:<employee id>", a job function id…). Pairs with
 * <UiSaveStatus>: nothing while idle, "Saving…" while the request is out, "Saved"
 * for a moment afterwards, "Couldn't save — Retry" on failure.
 *
 * This is the one timing for every inline save on the page, so a checkbox, a
 * dropdown and a number box all say the same thing the same way.
 */
export type SaveState = 'idle' | 'saving' | 'saved' | 'error'

const SAVED_SHOWN_MS = 2000

export const useSaveStatus = () => {
  const statuses = ref<Record<string, { state: SaveState; message?: string }>>({})
  const timers = new Map<string, ReturnType<typeof setTimeout>>()

  const set = (key: string, state: SaveState, message?: string) => {
    clearTimeout(timers.get(key))
    timers.delete(key)
    statuses.value = { ...statuses.value, [key]: { state, message } }
  }

  const saving = (key: string) => set(key, 'saving')
  const failed = (key: string, message?: string) => set(key, 'error', message)
  const saved = (key: string) => {
    set(key, 'saved')
    timers.set(key, setTimeout(() => {
      timers.delete(key)
      if (statuses.value[key]?.state === 'saved') set(key, 'idle')
    }, SAVED_SHOWN_MS))
  }
  const clear = (key: string) => set(key, 'idle')

  const stateOf = (key: string): SaveState => statuses.value[key]?.state ?? 'idle'
  const messageOf = (key: string): string | undefined => statuses.value[key]?.message

  onBeforeUnmount(() => { for (const t of timers.values()) clearTimeout(t) })

  return { saving, saved, failed, clear, stateOf, messageOf }
}
