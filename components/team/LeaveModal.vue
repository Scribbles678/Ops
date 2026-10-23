<!--
  Leave of absence for one person — opened from Team Setup → Employees (the Leave
  button, or "Set a leave instead" in the Edit window).

  Lists their leaves (running / upcoming first, past ones folded away) and sets or
  changes one: first day, last day or "return date not known yet", an optional note.
  Under the dates it shows, before Save, what saving will do (POST /api/leaves/preview):
  the time off it cancels and the days they're already on the schedule.

  Supervisors and up change leaves (the server refuses anyone else). A Team Lead sees
  the same window read-only.
-->
<template>
  <UiModal :title="`Leave of absence — ${name}`" size="lg" :busy="busy" @close="emit('close')">
    <p v-if="!canEdit" class="mb-3 rounded-md border border-gray-200 bg-gray-50 px-3 py-2 text-sm text-gray-700">
      View only. A Supervisor sets and changes leaves.
    </p>

    <p v-if="loading" class="text-sm text-gray-500">Loading…</p>
    <div v-else-if="loadError" role="alert" class="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
      Couldn't load {{ first }}'s leaves: {{ loadError }}
      <button type="button" class="ml-1 font-medium underline" @click="load">Retry</button>
    </div>

    <!-- The list -->
    <div v-else-if="!form" class="space-y-3 text-sm">
      <p class="text-gray-500">
        While a leave covers a day, {{ first }} is off all day: left out of the schedule builder, shown as on leave on the
        schedule page, and requests for those days are refused. When it ends they're back with nothing to switch on.
      </p>
      <p v-if="!live.length" class="italic text-gray-500">No leave running or coming up.</p>
      <ul v-else class="divide-y divide-gray-100 rounded-md border border-gray-200">
        <li v-for="l in live" :key="l.id" class="px-3 py-2" :data-leave-id="l.id">
          <div class="flex flex-wrap items-center justify-between gap-2">
            <div>
              <span
                class="mr-2 rounded px-1.5 py-0.5 text-[11px] font-semibold"
                :class="leaveState(l, today) === 'current' ? 'bg-violet-100 text-violet-800' : 'bg-gray-100 text-gray-700'"
              >{{ leaveState(l, today) === 'current' ? 'On leave now' : 'Coming up' }}</span>
              <span class="font-medium text-gray-900">{{ longSpan(l) }}</span>
            </div>
            <div v-if="canEdit && removing !== l.id" class="flex gap-1.5">
              <button type="button" class="rounded border border-gray-300 px-2.5 py-1 text-xs hover:bg-gray-50" @click="openForm(l)">Change</button>
              <button type="button" class="rounded border border-red-200 px-2.5 py-1 text-xs text-red-700 hover:bg-red-50" @click="removing = l.id; removeError = ''">Remove</button>
            </div>
          </div>
          <p v-if="l.notes" class="mt-1 whitespace-pre-line text-xs text-gray-600">{{ l.notes }}</p>
          <!-- Remove asks right here: a second window over this one would be one too many. -->
          <div v-if="removing === l.id" class="mt-2 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-800">
            <p>
              Remove this leave? Use this for a leave entered by mistake — to end a real one early, use Change and set its
              last day, so the record stays. Time off cancelled when it was saved doesn't come back.
            </p>
            <p v-if="removeError" role="alert" class="mt-1 font-medium">{{ removeError }}</p>
            <div class="mt-2 flex gap-2">
              <button type="button" :disabled="busy" class="rounded bg-red-600 px-2.5 py-1 font-medium text-white hover:bg-red-700 disabled:opacity-50" @click="remove(l)">
                {{ busy ? 'Removing…' : 'Remove leave' }}
              </button>
              <button type="button" :disabled="busy" class="rounded border border-gray-300 bg-white px-2.5 py-1 text-gray-700 hover:bg-gray-50" @click="removing = null">Keep it</button>
            </div>
          </div>
        </li>
      </ul>

      <div v-if="past.length">
        <button type="button" class="text-xs text-gray-600 underline hover:text-gray-800" :aria-expanded="showPast" @click="showPast = !showPast">
          {{ showPast ? 'Hide' : 'Show' }} {{ past.length }} past leave{{ past.length === 1 ? '' : 's' }}
        </button>
        <ul v-if="showPast" class="mt-2 divide-y divide-gray-100 rounded-md border border-gray-200 bg-gray-50">
          <li v-for="l in past" :key="l.id" class="px-3 py-2 text-gray-600">
            <div class="flex flex-wrap items-center justify-between gap-2">
              <span>{{ longSpan(l) }}</span>
              <button v-if="canEdit" type="button" class="text-xs text-gray-500 underline hover:text-gray-700" @click="openForm(l)">Change</button>
            </div>
            <p v-if="l.notes" class="mt-0.5 whitespace-pre-line text-xs text-gray-500">{{ l.notes }}</p>
          </li>
        </ul>
      </div>
    </div>

    <!-- Set or change one -->
    <form v-else :id="`${uid}-form`" class="space-y-3 text-sm" novalidate @submit.prevent="save">
      <div class="grid gap-3 sm:grid-cols-2">
        <div>
          <label :for="`${uid}-start`" class="mb-1 block font-medium text-gray-700">First day off</label>
          <input :id="`${uid}-start`" v-model="form.start_date" type="date" data-autofocus class="w-full rounded-md border border-gray-300 px-3 py-2" />
        </div>
        <div>
          <label :for="`${uid}-end`" class="mb-1 block font-medium text-gray-700">Last day off</label>
          <input
            :id="`${uid}-end`"
            v-model="form.end_date"
            type="date"
            :min="form.start_date || undefined"
            :disabled="form.openEnded"
            class="w-full rounded-md border border-gray-300 px-3 py-2 disabled:bg-gray-100 disabled:text-gray-400"
          />
        </div>
      </div>
      <label class="flex items-center gap-2 text-gray-700">
        <input v-model="form.openEnded" type="checkbox" class="h-4 w-4" />
        Return date not known yet
      </label>
      <p v-if="form.openEnded" class="text-xs text-gray-500">
        {{ first }} stays on leave until someone sets the last day here.
      </p>
      <div>
        <label :for="`${uid}-notes`" class="mb-1 block font-medium text-gray-700">Note (optional)</label>
        <textarea
          :id="`${uid}-notes`"
          v-model="form.notes"
          rows="2"
          :maxlength="MAX_NOTES"
          :aria-describedby="`${uid}-notes-help`"
          class="w-full rounded-md border border-gray-300 px-3 py-2"
        ></textarea>
        <p :id="`${uid}-notes-help`" class="mt-0.5 text-xs text-gray-500">
          Seen by Team Leads and Supervisors here and on Employee Overview — never on the kiosk, the display board or the PTO calendar.
        </p>
      </div>

      <!-- What saving will do -->
      <div v-if="datesReady" class="rounded-md border px-3 py-2" :class="check.problem ? 'border-red-200 bg-red-50 text-red-800' : 'border-amber-200 bg-amber-50 text-amber-900'">
        <p v-if="check.loading">Checking what this leave affects…</p>
        <p v-else-if="check.error">Couldn't check what this leave affects ({{ check.error }}). You can still save; the server checks again.</p>
        <template v-else>
          <p v-if="check.problem" class="font-medium">{{ check.problem }}</p>
          <template v-else>
            <template v-if="check.cancels.length">
              <p class="font-medium">Saving cancels {{ first }}'s time off on {{ check.cancels.length === 1 ? 'this day' : 'these days' }}:</p>
              <ul class="mt-1 list-disc space-y-0.5 pl-5">
                <li v-for="c in check.cancels" :key="c">{{ c }}</li>
              </ul>
              <p class="mt-1 text-xs">The leave covers those days instead. Days before today are left as recorded.</p>
            </template>
            <p v-if="check.scheduled.length" :class="check.cancels.length ? 'mt-2' : ''">
              {{ first }} is already on the schedule on {{ check.scheduled.length }} day{{ check.scheduled.length === 1 ? '' : 's' }} of this leave
              ({{ dayList(check.scheduled) }}). Those assignments stay until you clear or rebuild those days; the schedule page
              shows {{ first }} as on leave.
            </p>
            <p v-if="!check.cancels.length && !check.scheduled.length">Nothing else is booked for {{ first }} on these days.</p>
          </template>
        </template>
      </div>
      <p v-else class="text-xs text-gray-500">Pick the first and last day off, or tick “Return date not known yet”.</p>

      <p v-if="formError" role="alert" class="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-red-700">{{ formError }}</p>
    </form>

    <template #footer>
      <template v-if="!form">
        <button type="button" :disabled="busy" class="rounded-lg border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50" @click="emit('close')">Close</button>
        <button
          v-if="canEdit && !loading && !loadError"
          type="button"
          :disabled="busy"
          class="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
          @click="openForm(null)"
        >+ Set a leave</button>
      </template>
      <template v-else>
        <button type="button" :disabled="busy" class="rounded-lg border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50" @click="form = null">Back</button>
        <button
          type="submit"
          :form="`${uid}-form`"
          :disabled="!canSave"
          class="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
        >{{ busy ? 'Saving…' : saveLabel }}</button>
      </template>
    </template>
  </UiModal>
</template>

<script setup lang="ts">
import { getTZISODate } from '~/utils/localDate'
import { canManageTeam } from '~/utils/roles'
import { leaveDay, leaveState, type LeaveDates } from '~/utils/leaveDisplay'

interface Leave extends LeaveDates {
  id: string
  employee_id: string
  notes: string | null
}

const props = defineProps<{
  employee: { id: string; first_name: string; last_name: string }
  /** Open straight on "Set a leave" (from the Edit window's "Set a leave instead"). */
  startWithForm?: boolean
}>()
const emit = defineEmits<{
  close: []
  /** A leave was saved, changed or removed: the list's badges are out of date. */
  changed: [message: string]
}>()

const MAX_NOTES = 500
const uid = useId()
const { user } = useAuth()
const canEdit = computed(() => canManageTeam(user.value))
const today = computed(() => getTZISODate(user.value?.team_timezone || Intl.DateTimeFormat().resolvedOptions().timeZone))
const first = computed(() => props.employee.first_name)
const name = computed(() => `${props.employee.last_name}, ${props.employee.first_name}`)
const reasonOf = (e: any): string => e?.data?.message || e?.statusMessage || e?.message || 'unknown error'

/** "Mon, Nov 2, 2026 – Tue, Dec 15, 2026" — the window has room for the weekday and year. */
const longDay = (ymd: string) => {
  const [y, m, d] = ymd.split('-').map(Number)
  return new Date(y!, m! - 1, d!).toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric', year: 'numeric' })
}
const longSpan = (l: LeaveDates) =>
  l.end_date
    ? l.end_date === l.start_date ? longDay(l.start_date) : `${longDay(l.start_date)} – ${longDay(l.end_date)}`
    : `From ${longDay(l.start_date)} · return date not set`
/** "Mon Nov 2 · Tue Nov 3 and 4 more". */
const dayList = (dates: string[]) => {
  const shown = dates.slice(0, 3).map((d) => longDay(d).replace(/, \d{4}$/, '').replace(',', '')).join(' · ')
  return dates.length > 3 ? `${shown} and ${dates.length - 3} more` : shown
}

// ── The list ──────────────────────────────────────────────────────────────────
const leaves = ref<Leave[]>([])
const loading = ref(true)
const loadError = ref('')
const live = computed(() =>
  leaves.value.filter((l) => leaveState(l, today.value) !== 'past').sort((a, b) => a.start_date.localeCompare(b.start_date))
)
const past = computed(() => leaves.value.filter((l) => leaveState(l, today.value) === 'past'))
const showPast = ref(false)

const load = async () => {
  loading.value = true
  loadError.value = ''
  try {
    leaves.value = await $fetch<Leave[]>('/api/leaves', { params: { employee_id: props.employee.id } })
  } catch (e) {
    loadError.value = reasonOf(e)
  } finally {
    loading.value = false
  }
}

// ── The form ──────────────────────────────────────────────────────────────────
interface Form { id: string | null; start_date: string; end_date: string; openEnded: boolean; notes: string }
const form = ref<Form | null>(null)
const formError = ref('')
const busy = ref(false)

const openForm = (l: Leave | null) => {
  form.value = l
    ? { id: l.id, start_date: l.start_date, end_date: l.end_date ?? '', openEnded: l.end_date === null, notes: l.notes ?? '' }
    : { id: null, start_date: today.value, end_date: '', openEnded: false, notes: '' }
  formError.value = ''
  removing.value = null
}

const endDate = computed(() => (form.value?.openEnded ? null : form.value?.end_date || null))
/** Enough to ask the server what saving would do. */
const datesReady = computed(() => !!form.value?.start_date && (form.value.openEnded || !!form.value.end_date))

const check = reactive({ loading: false, error: '', problem: null as string | null, cancels: [] as string[], scheduled: [] as string[] })
let checkSeq = 0
let checkTimer: ReturnType<typeof setTimeout> | undefined
const runCheck = async () => {
  const mine = ++checkSeq
  const f = form.value
  if (!f || !datesReady.value) return
  if (endDate.value && endDate.value < f.start_date) {
    Object.assign(check, { loading: false, error: '', problem: 'The last day is before the first day.', cancels: [], scheduled: [] })
    return
  }
  Object.assign(check, { loading: true, error: '', problem: null, cancels: [], scheduled: [] })
  try {
    const r = await $fetch<{ problem: string | null; cancels: string[]; scheduled: string[] }>('/api/leaves/preview', {
      method: 'POST',
      body: { employee_id: props.employee.id, leave_id: f.id, start_date: f.start_date, end_date: endDate.value },
    })
    if (mine !== checkSeq) return
    Object.assign(check, { loading: false, ...r })
  } catch (e: any) {
    if (mine !== checkSeq) return
    // A 400 is about the dates themselves: say it as the problem, not as a failed check.
    if (Number(e?.statusCode ?? e?.status) === 400) Object.assign(check, { loading: false, problem: reasonOf(e) })
    else Object.assign(check, { loading: false, error: reasonOf(e) })
  }
}
watch(() => [form.value?.start_date, endDate.value, form.value?.id], () => {
  clearTimeout(checkTimer)
  checkSeq++
  if (!datesReady.value) return
  check.loading = true
  checkTimer = setTimeout(runCheck, 250)
})
onBeforeUnmount(() => clearTimeout(checkTimer))

const canSave = computed(() => canEdit.value && !busy.value && datesReady.value && !check.loading && !check.problem)
const saveLabel = computed(() =>
  check.cancels.length ? 'Save and cancel the time off' : form.value?.id ? 'Save changes' : 'Save leave'
)

const save = async () => {
  const f = form.value
  if (!f || !canSave.value) return
  busy.value = true
  formError.value = ''
  try {
    const body = { start_date: f.start_date, end_date: endDate.value, notes: f.notes.trim() || null }
    const r = await $fetch<{ leave: Leave; cancelled: string[] }>(f.id ? `/api/leaves/${f.id}` : '/api/leaves', {
      method: f.id ? 'PUT' : 'POST',
      body: f.id ? body : { ...body, employee_id: props.employee.id },
    })
    const what = `${f.id ? 'Changed' : 'Saved'} ${first.value}'s leave: ${longSpan(r.leave)}.`
    const cancelled = r.cancelled.length ? ` Their time off inside it was cancelled (${r.cancelled.length}).` : ''
    emit('changed', what + cancelled)
    form.value = null
    await load()
  } catch (e) {
    formError.value = reasonOf(e)
  } finally {
    busy.value = false
  }
}

// ── Remove ────────────────────────────────────────────────────────────────────
const removing = ref<string | null>(null)
const removeError = ref('')
const remove = async (l: Leave) => {
  busy.value = true
  removeError.value = ''
  try {
    await $fetch(`/api/leaves/${l.id}`, { method: 'DELETE' })
    removing.value = null
    emit('changed', `Removed ${first.value}'s leave (${leaveDay(l.start_date)}${l.end_date ? ` – ${leaveDay(l.end_date)}` : ', no return date'}).`)
    await load()
  } catch (e) {
    removeError.value = reasonOf(e)
  } finally {
    busy.value = false
  }
}

onMounted(async () => {
  await load()
  if (props.startWithForm && canEdit.value && !loadError.value) openForm(null)
})
</script>
