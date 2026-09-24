/**
 * App-wide, non-blocking notices: the "Saved …" / "Couldn't …" that follows a save
 * made from a window (add / edit forms, a delete). Success notices fade on their
 * own; errors stay until closed. The single host, <AppToasts>, is mounted in app.vue.
 *
 * Inline edits (a checkbox, a dropdown, one number box) don't use this — they show
 * <UiSaveStatus> beside the field instead (see useSaveStatus). Nothing here blocks
 * the page: the old "✅ Success — OK" pop-ups had to be clicked away after every save.
 */
export interface Toast {
  id: number
  kind: 'success' | 'error'
  message: string
}

const SUCCESS_MS = 3000
const MAX_SHOWN = 4
let nextId = 1

export const useToast = () => {
  const toasts = useState<Toast[]>('app-toasts', () => [])

  const dismiss = (id: number) => {
    toasts.value = toasts.value.filter((t) => t.id !== id)
  }

  const push = (kind: Toast['kind'], message: string) => {
    const id = nextId++
    toasts.value = [...toasts.value, { id, kind, message }].slice(-MAX_SHOWN)
    if (kind === 'success') setTimeout(() => dismiss(id), SUCCESS_MS)
    return id
  }

  return {
    toasts,
    success: (message: string) => push('success', message),
    error: (message: string) => push('error', message),
    dismiss,
  }
}
