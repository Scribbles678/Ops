/**
 * Training checkboxes, saved one change at a time:
 *   POST /api/employees/:id/training  { add: [ids] } or { remove: [ids] }
 *
 * Per employee:
 *   saved   the set the server last returned (null until the first load succeeds)
 *   queue   changes not yet confirmed, in click order — the boxes show saved + queue
 *   sending true while the head of the queue is out
 *
 * One request per employee at a time; each reply's set becomes the new `saved`, so a
 * training another lead added meanwhile shows up instead of being overwritten. Clicks
 * on other employees never touch this employee. A failure pauses only this
 * employee's queue: the boxes keep showing what was clicked, with Retry (send the
 * rest) and Undo (drop them). Ticking and unticking the same box before it's sent
 * cancels out.
 *
 * What this replaced: every save reloaded everyone's training and cleared everyone's
 * pending clicks, so ticking two people a second apart lost the second tick; and the
 * page sent each person's WHOLE set, so a failed load ("trained on nothing") plus one
 * tick erased all of their training.
 *
 * The store is module-level, so it outlives the Employees tab: switching tabs
 * mid-save loses nothing, and a failure after the tab closed becomes a toast.
 */
import type { SaveState } from './useSaveStatus'
import { describeSaveFailure } from './useBoxSave'

interface Change { op: 'add' | 'remove'; ids: string[] }
interface Row {
  saved: string[] | null
  queue: Change[]
  sending: boolean
  state: SaveState
  message?: string
  retryable: boolean
}

const rows = reactive<Record<string, Row>>({})
const timers = new Map<string, ReturnType<typeof setTimeout>>()
let mounted = 0
let names: (id: string) => string = (id) => id

const SAVED_SHOWN_MS = 2000
const row = (id: string): Row => (rows[id] ??= { saved: null, queue: [], sending: false, state: 'idle', retryable: false })
const sameIds = (a: string[], b: string[]) => a.length === b.length && a.every((x) => b.includes(x))
const apply = (set: string[], c: Change) =>
  c.op === 'add' ? [...new Set([...set, ...c.ids])] : set.filter((x) => !c.ids.includes(x))

export function useTrainingSaves(opts: { nameOf: (employeeId: string) => string }) {
  const registry = useSaveRegistry()
  const toast = useToast()
  names = opts.nameOf
  onMounted(() => { mounted++ })
  onBeforeUnmount(() => { mounted-- })

  const setState = (id: string, state: SaveState, message?: string, retryable = false) => {
    const r = row(id)
    clearTimeout(timers.get(id))
    r.state = state
    r.message = message
    r.retryable = retryable
    if (state === 'saved') {
      timers.set(id, setTimeout(() => { if (rows[id]?.state === 'saved') rows[id]!.state = 'idle' }, SAVED_SHOWN_MS))
    }
    registry.mark(`training:${id}`, state === 'saving' ? 'busy' : state === 'error' ? 'failed' : null)
  }

  const kick = async (id: string) => {
    const r = row(id)
    if (r.sending || r.state === 'error' || !r.queue.length) return
    const change = r.queue[0]!
    r.sending = true
    setState(id, 'saving')
    try {
      const res = await $fetch<{ job_function_ids: string[] }>(`/api/employees/${id}/training`, {
        method: 'POST',
        body: { [change.op]: change.ids },
      })
      r.saved = res.job_function_ids
      r.queue.shift()
      r.sending = false
      if (r.queue.length) return kick(id)
      setState(id, 'saved')
    } catch (e) {
      r.sending = false
      const { message, retryable } = describeSaveFailure(e)
      setState(id, 'error', message, retryable)
      if (mounted <= 0) toast.error(`Couldn't save training for ${names(id)}: ${message}`)
    }
  }

  /**
   * Take the server's training. Employees with changes out or waiting keep theirs:
   * a reload must never undo a click that hasn't been confirmed yet.
   */
  const load = (byEmployee: Record<string, string[]>, employeeIds: string[]) => {
    for (const id of employeeIds) {
      const r = row(id)
      if (r.sending || r.queue.length) continue
      r.saved = [...(byEmployee[id] ?? [])]
    }
  }

  return {
    load,
    /** False until this employee's training has loaded — keep their boxes disabled. */
    loaded: (id: string) => rows[id]?.saved != null,
    /** What the boxes should show: confirmed training plus changes still on their way. */
    want: (id: string): string[] => {
      const r = rows[id]
      if (!r?.saved) return []
      return r.queue.reduce(apply, r.saved)
    },
    /** A click. `ids` is one job, or every id a grouped box stands for (Meter). */
    toggle: (id: string, ids: string[], checked: boolean) => {
      const r = row(id)
      if (r.saved == null) return
      const op = checked ? 'add' : 'remove'
      // Unticking what was just ticked (and not yet sent) cancels out.
      const last = r.queue[r.queue.length - 1]
      const lastIsUnsent = last && !(r.sending && r.queue.length === 1)
      if (lastIsUnsent && last.op !== op && sameIds(last.ids, ids)) {
        r.queue.pop()
        // Nothing left to save (even a failed change, now taken back): all clear.
        if (!r.queue.length && !r.sending) setState(id, 'idle')
        return
      }
      r.queue.push({ op, ids })
      if (r.state !== 'error') kick(id)
    },
    retry: (id: string) => { const r = row(id); if (r.state !== 'error') return; setState(id, 'idle'); kick(id) },
    undo: (id: string) => {
      const r = row(id)
      if (r.sending) return
      r.queue = []
      setState(id, 'idle')
    },
    /** Something is out or waiting for this employee (don't delete / deactivate them now). */
    pending: (id: string) => !!rows[id] && (rows[id]!.sending || rows[id]!.queue.length > 0),
    forget: (id: string) => { if (!rows[id]?.sending) { delete rows[id]; registry.mark(`training:${id}`, null) } },
    stateOf: (id: string): SaveState => rows[id]?.state ?? 'idle',
    messageOf: (id: string) => rows[id]?.message,
    retryableOf: (id: string) => !!rows[id]?.retryable,
  }
}
