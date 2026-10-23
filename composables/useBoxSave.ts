/**
 * Saving ONE value per key that can change again before the last save returns — a
 * number box, a dropdown. Team Setup's single rule for these:
 *
 *   saved      what the server last confirmed
 *   draft      what the control shows (bind it with draftOf / setDraft)
 *   committed  the last value the user FINISHED (commit on change / blur / Enter)
 *   sent       the value in flight, or undefined
 *
 * Only committed values are ever sent — never a half-typed draft. commit(key) sends
 * unless it already equals `sent ?? saved`. While a request is out, only the newest
 * committed value waits to go next (older ones are skipped), so the last value the
 * user finished is what ends up saved, however fast they go.
 * `saved` moves only when the server confirms. A failure keeps what was typed and
 * shows why: Retry resends it (only for errors a resend can fix — network / 5xx),
 * Undo puts back the saved value.
 *
 * The state lives in a store per `namespace`, not in the component, so switching
 * tabs mid-save loses nothing and a failure that lands after the tab closed is raised
 * as a toast instead of vanishing.
 */
import type { SaveState } from './useSaveStatus'

export interface BoxSaveOptions<T> {
  namespace: string
  /** Persist one value. Throw (a $fetch error is fine) on failure. */
  save: (key: string, value: T) => Promise<void>
  /** Names the box in a toast: "Pick target hours". */
  label: (key: string) => string
  equals?: (a: T, b: T) => boolean
}

interface Box<T> {
  saved: T
  draft: T
  committed: T
  sent?: T
  state: SaveState
  message?: string
  retryable: boolean
}

interface Store {
  boxes: Record<string, Box<any>>
  opts: BoxSaveOptions<any>
  mounted: number
  timers: Map<string, ReturnType<typeof setTimeout>>
}
const stores = new Map<string, Store>()

const SAVED_SHOWN_MS = 2000

/** A $fetch error's message and whether sending it again could help. */
export const describeSaveFailure = (e: any): { message: string; retryable: boolean } => {
  const status = Number(e?.statusCode ?? e?.status ?? e?.response?.status ?? 0)
  const message = e?.data?.message || e?.statusMessage || (status ? `Couldn't save (error ${status})` : "Couldn't reach the server")
  return { message, retryable: !status || status >= 500 || status === 408 || status === 429 }
}

export function useBoxSave<T>(opts: BoxSaveOptions<T>) {
  const registry = useSaveRegistry()
  const toast = useToast()
  let store = stores.get(opts.namespace)
  if (!store) {
    store = { boxes: reactive({}) as Record<string, Box<any>>, opts, mounted: 0, timers: new Map() }
    stores.set(opts.namespace, store)
  }
  store.opts = opts // the newest component's callbacks
  const s = store
  const eq = (a: T, b: T) => (opts.equals ? opts.equals(a, b) : a === b)
  const regKey = (key: string) => `box:${opts.namespace}:${key}`

  onMounted(() => { s.mounted++ })
  onBeforeUnmount(() => { s.mounted-- })

  const setState = (key: string, state: SaveState, message?: string, retryable = false) => {
    const b = s.boxes[key]
    if (!b) return
    clearTimeout(s.timers.get(key))
    b.state = state
    b.message = message
    b.retryable = retryable
    if (state === 'saved') {
      s.timers.set(key, setTimeout(() => { if (s.boxes[key]?.state === 'saved') s.boxes[key]!.state = 'idle' }, SAVED_SHOWN_MS))
    }
    registry.mark(regKey(key), state === 'saving' ? 'busy' : state === 'error' ? 'failed' : null)
  }

  /**
   * Take a value from the server. Never overwrites a box mid-edit (typed but not
   * yet confirmed) or mid-save — a refetch landing then would undo the typing.
   */
  const init = (key: string, value: T) => {
    const b = s.boxes[key]
    if (b && (b.sent !== undefined || !eq(b.draft, b.saved) || !eq(b.committed, b.saved) || b.state === 'error')) return
    s.boxes[key] = { saved: value, draft: value, committed: value, sent: undefined, state: b?.state === 'saved' ? 'saved' : 'idle', retryable: false }
  }

  const send = async (key: string) => {
    const b = s.boxes[key]
    if (!b || b.sent !== undefined) return
    const value = b.committed
    if (eq(value, b.saved)) { setState(key, 'idle'); return }
    b.sent = value
    setState(key, 'saving')
    try {
      await s.opts.save(key, value)
      b.saved = value
      b.sent = undefined
      if (!eq(b.committed, b.saved)) return send(key) // committed again meanwhile: the newest goes next
      setState(key, 'saved')
    } catch (e) {
      b.sent = undefined
      const { message, retryable } = describeSaveFailure(e)
      setState(key, 'error', message, retryable)
      if (s.mounted <= 0) toast.error(`Couldn't save ${s.opts.label(key)}: ${message}`)
    }
  }

  return {
    init,
    has: (key: string) => !!s.boxes[key],
    draftOf: (key: string): T | undefined => s.boxes[key]?.draft,
    savedOf: (key: string): T | undefined => s.boxes[key]?.saved,
    setDraft: (key: string, value: T) => { if (s.boxes[key]) s.boxes[key]!.draft = value },
    /** The user finished this value: send it (call on change / blur / Enter, after validating it). */
    commit: (key: string) => {
      const b = s.boxes[key]
      if (!b) return
      b.committed = b.draft
      if (b.sent !== undefined) return // in flight: this goes when it returns
      return send(key)
    },
    /** Show a problem with what was typed, without sending anything. */
    invalid: (key: string, message: string) => setState(key, 'error', message, false),
    retry: (key: string) => send(key),
    undo: (key: string) => {
      const b = s.boxes[key]
      if (!b || b.sent !== undefined) return
      b.draft = b.saved
      b.committed = b.saved
      setState(key, 'idle')
    },
    stateOf: (key: string): SaveState => s.boxes[key]?.state ?? 'idle',
    messageOf: (key: string) => s.boxes[key]?.message,
    retryableOf: (key: string) => !!s.boxes[key]?.retryable,
  }
}
