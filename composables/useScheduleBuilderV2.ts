/**
 * The Automated Schedule Builder — composable wrapper.
 *
 * Fetches the team's inputs, runs the pure engine in utils/scheduleEngineV2/
 * (prepare() then runEngine()), and returns the schedule plus what the review
 * modal shows. applyV2Schedule() writes it through the transactional replace.
 *
 * The "V2" in these names is history: an hourly V1 engine was deleted in Aug
 * 2026, and a second "period" engine was tried in Sep 2026 and removed.
 */
import { prepare } from '~/utils/scheduleEngineV2/prepare'
import { runEngine } from '~/utils/scheduleEngineV2/engine'
import { slotToTime } from '~/utils/scheduleEngineV2/slots'
import type { EngineAction, EngineGap, EngineResult, GapCause } from '~/utils/scheduleEngineV2/types'

export interface V2ScheduleAssignment {
  employee_id: string
  employee_name: string
  job_function: string
  start_time: string
  end_time: string
  /** The shift actually worked that day — the swapped one where a swap exists. */
  shift_id?: string | null
}

/** One "Still short" row: a job, why it went short, and when. */
export interface ShortRow {
  functionName: string
  cause: GapCause
  /** Headcount-hours short, every 15 minutes added up. */
  hours: number
  /** "08:00–08:45", or "16:30–18:00 (2 people)" where more than one person was missing. */
  windows: string[]
}

/**
 * Everything the build-result window shows, shaped here so the page only renders.
 * An empty `schedule` means nothing was built, and `fixes` then says why.
 */
export interface BuildOutcome {
  schedule: V2ScheduleAssignment[]
  /** Things a person must fix, each with where to fix it. */
  fixes: EngineAction[]
  /** Informational leftovers. Rare. */
  notes: string[]
  /** People scheduled, off all day, and scheduled but given no work. */
  people: number
  offAllDay: number
  noWork: number
  /** Gaps a person can act on (priority, training, a cap), one row per job and reason. */
  short: ShortRow[]
  /** Headcount-hours no schedule could cover — more work than people on shift — and when. */
  unavoidable: { hours: number; windows: string[] }
  /** Headcount-hours over target per job, most first. */
  extra: { functionName: string; hours: number }[]
}

const notBuilt = (fixes: EngineAction[]): BuildOutcome => ({
  schedule: [],
  fixes,
  notes: [],
  people: 0,
  offAllDay: 0,
  noWork: 0,
  short: [],
  unavoidable: { hours: 0, windows: [] },
  extra: [],
})

/** "employees", "employees and shifts", "employees, shifts and time off". */
const listOf = (items: string[]): string =>
  items.length < 2 ? items.join('') : `${items.slice(0, -1).join(', ')} and ${items[items.length - 1]}`

/** Merge overlapping or touching gaps into "HH:MM–HH:MM" windows, earliest first. */
const mergedWindows = (gaps: EngineGap[]): string[] => {
  const spans = gaps.map((g) => [g.startSlot, g.endSlot] as [number, number]).sort((a, b) => a[0] - b[0])
  const merged: [number, number][] = []
  for (const [start, end] of spans) {
    const last = merged[merged.length - 1]
    if (last && start <= last[1]) last[1] = Math.max(last[1], end)
    else merged.push([start, end])
  }
  return merged.map(([start, end]) => `${slotToTime(start)}–${slotToTime(end)}`)
}

export const useScheduleBuilderV2 = () => {
  const { fetchEmployees, error: employeesError } = useEmployees()
  const { jobFunctions, fetchJobFunctions, error: jobFunctionsError } = useJobFunctions()
  // `error` carries the server's real failure message; replaceScheduleForDate only
  // returns null, so without this a DB rejection surfaces as "Failed to save".
  const { fetchShifts, replaceScheduleForDate, error: scheduleError } = useSchedule()
  const { fetchPreferredAssignments, getPreferredAssignmentsMap, error: preferredError } = usePreferredAssignments()
  const { fetchTargets: fetchStaffingTargets, error: targetsError } = useStaffingTargets()

  /** Last engine result, so the UI can show V2-only diagnostics. */
  const lastResult = ref<EngineResult | null>(null)

  const generateV2Schedule = async (scheduleDate: string = ''): Promise<BuildOutcome> => {
    try {
      // Training, shift swaps and time off are fetched directly. The shared loaders
      // turn a failed request into an empty list, and an empty list builds the day
      // as if nobody were trained, swapped or off — so a failure must stop the build.
      const notLoaded: string[] = []
      const fetchOrNote = async <T>(url: string, what: string): Promise<T | null> => {
        try {
          return (await $fetch(url)) as T
        } catch {
          notLoaded.push(what)
          return null
        }
      }
      const [employeesData, jobFunctionsData, shiftsData, targetsData, , trainingRows, swaps, ptoDays] =
        await Promise.all([
          fetchEmployees(),
          fetchJobFunctions(),
          fetchShifts(),
          fetchStaffingTargets(),
          fetchPreferredAssignments(),
          fetchOrNote<{ employee_id: string; job_function_id: string }[]>('/api/employees/training', 'training'),
          scheduleDate ? fetchOrNote<any[]>(`/api/shift-swaps/${scheduleDate}`, 'shift swaps') : [],
          scheduleDate ? fetchOrNote<any[]>(`/api/pto/${scheduleDate}`, 'time off') : [],
        ])
      // The same for the shared loaders: they record the failure in their `error`.
      // Unchecked, a failure read as "No active shifts found", or quietly built the
      // day without anybody's required assignments.
      notLoaded.unshift(
        ...[
          employeesError.value && 'employees',
          jobFunctionsError.value && 'job functions',
          scheduleError.value && 'shifts',
          targetsError.value && 'staffing targets',
          preferredError.value && 'required assignments',
        ].filter((what): what is string => !!what)
      )
      if (notLoaded.length) {
        return notBuilt([
          { message: `Couldn't load ${listOf(notLoaded)}, so nothing was built. Try again; if it keeps happening, sign out and back in.` },
        ])
      }

      const employees = Array.isArray(employeesData) ? employeesData : []
      const jobFunctionsList = Array.isArray(jobFunctionsData) ? jobFunctionsData : []
      const shifts = Array.isArray(shiftsData) ? shiftsData : []
      const staffingTargets = Array.isArray(targetsData) ? targetsData : []

      const activeEmployees = employees.filter((e: any) => e && e.is_active !== false)
      const setup: EngineAction[] = []
      if (!activeEmployees.length) setup.push({ message: 'There are no active employees.', fix: 'employees' })
      if (!shifts.some((s: any) => s && s.is_active !== false)) setup.push({ message: 'There are no active shifts.', fix: 'shifts' })
      if (!jobFunctionsList.length) setup.push({ message: 'There are no job functions.', fix: 'job-functions' })
      if (!staffingTargets.length) setup.push({ message: 'No staffing targets are set.', fix: 'rules-and-targets' })
      if (setup.length) return notBuilt(setup)

      const training: Record<string, string[]> = {}
      for (const r of trainingRows ?? []) (training[r.employee_id] ??= []).push(r.job_function_id)

      // Shift swaps for the date. A swap replaces the employee's shift for that
      // day only, and the builder must both SCHEDULE against it and STAMP it —
      // the display groups swapped people by the swapped shift, so an assignment
      // carrying the original shift is dropped from the board.
      const swappedShiftByEmployee: Record<string, string | null> = {}
      for (const sw of swaps ?? []) {
        if (sw?.employee_id && sw?.swapped_shift_id) swappedShiftByEmployee[sw.employee_id] = sw.swapped_shift_id
      }

      // Every absence per person — someone can arrive late AND leave early.
      const ptoByEmployee: Record<string, any[]> = {}
      for (const p of ptoDays ?? []) if (p?.employee_id) (ptoByEmployee[p.employee_id] ??= []).push(p)

      const prepared = prepare({
        employees: activeEmployees,
        jobFunctions: jobFunctionsList,
        shifts,
        training,
        staffingTargets,
        preferredAssignments: getPreferredAssignmentsMap(),
        ptoByEmployee,
        swappedShiftByEmployee,
      })

      const engineInput = {
        employees: prepared.employees,
        functions: prepared.functions,
        preferred: prepared.preferred,
        requiredPins: prepared.requiredPins,
      }
      const result = runEngine(engineInput)
      lastResult.value = result
      const fixes = [...prepared.actions, ...result.actions]

      const nameById = new Map(prepared.employees.map((e) => [e.id, e.name]))
      const shiftById = new Map(prepared.employees.map((e) => [e.id, e.shiftId]))
      const fnNameById = new Map(prepared.functions.map((f) => [f.id, f.name]))

      const schedule: V2ScheduleAssignment[] = result.assignments.map((a) => ({
        employee_id: a.employeeId,
        employee_name: nameById.get(a.employeeId) || '',
        job_function: fnNameById.get(a.functionId) || '',
        start_time: slotToTime(a.startSlot),
        end_time: slotToTime(a.endSlot),
        // The shift the engine actually built against, swap included.
        shift_id: shiftById.get(a.employeeId) || null,
      }))

      if (!schedule.length) {
        return {
          ...notBuilt(fixes.length ? fixes : [{ message: 'Nobody could be placed on this day.' }]),
          offAllDay: prepared.offAllDay,
        }
      }

      // Gaps a person can act on get a row per job and reason. The whole-floor ones
      // (more work asked for than people on shift) become ONE line: on a normal day
      // they are most of the list, and only more people or smaller targets change
      // them, so listing each window buried the few rows anyone could act on.
      const rows = new Map<string, ShortRow>()
      const wholeFloor: EngineGap[] = []
      for (const g of result.gaps) {
        if (g.cause === 'floor-short') { wholeFloor.push(g); continue }
        const key = `${g.functionName}|${g.cause}`
        const row = rows.get(key) ?? { functionName: g.functionName, cause: g.cause, hours: 0, windows: [] }
        row.hours += g.hours
        row.windows.push(g.shortfall > 1 ? `${g.time} (${g.shortfall} people)` : g.time)
        rows.set(key, row)
      }

      // Hours are every 15 minutes added up, not a peak: the old summary added
      // each gap's peak shortfall and read "about 3.8 hours" on a day 17.5 short.
      const extraByFunction = new Map<string, number>()
      for (const o of result.overTarget) {
        extraByFunction.set(o.functionName, (extraByFunction.get(o.functionName) ?? 0) + o.hours)
      }

      return {
        schedule,
        fixes,
        notes: [...prepared.warnings, ...result.warnings],
        people: prepared.employees.length,
        offAllDay: prepared.offAllDay,
        noWork: result.stats.employeesWithNoWork,
        short: [...rows.values()].sort((a, b) => b.hours - a.hours),
        unavoidable: {
          hours: wholeFloor.reduce((sum, g) => sum + g.hours, 0),
          windows: mergedWindows(wholeFloor),
        },
        extra: [...extraByFunction]
          .map(([functionName, hours]) => ({ functionName, hours }))
          .sort((a, b) => b.hours - a.hours),
      }
    } catch (e: any) {
      return notBuilt([{ message: `Something went wrong while building: ${e?.message || 'unknown error'}` }])
    }
  }

  /** Identical write path to V1: name -> id mapping then transactional replace. */
  const applyV2Schedule = async (schedule: V2ScheduleAssignment[], scheduleDate: string) => {
    const [shiftsData, employeesData] = await Promise.all([fetchShifts(), fetchEmployees()])

    const employeeShiftMap = new Map<string, string | null>()
    if (Array.isArray(employeesData)) {
      for (const emp of employeesData) if (emp?.id) employeeShiftMap.set(emp.id, emp.shift_id || null)
    }
    const jfList = jobFunctions.value || []

    const dropped: string[] = []
    const assignments = schedule
      .map((a) => {
        const jf = jfList.find((j: any) => j.name === a.job_function) as any
        if (!jf) { dropped.push(`Unknown job function "${a.job_function}"`); return null }
        // The engine's shift wins: it already resolved any swap for this date.
        const shiftId = a.shift_id || employeeShiftMap.get(a.employee_id)
        const shift = shiftId ? (shiftsData || []).find((s: any) => s.id === shiftId) : null
        if (!shift) { dropped.push(`Employee ${a.employee_id} has no valid shift assigned`); return null }
        return {
          employee_id: a.employee_id,
          job_function_id: jf.id,
          shift_id: shift.id,
          start_time: a.start_time,
          end_time: a.end_time,
          schedule_date: scheduleDate,
        }
      })
      .filter(Boolean) as any[]

    if (dropped.length) {
      const preview = dropped.slice(0, 5).join('\n')
      const extra = dropped.length > 5 ? `\n...and ${dropped.length - 5} more` : ''
      throw new Error(`${dropped.length} assignment(s) could not be applied:\n${preview}${extra}`)
    }

    const result = await replaceScheduleForDate(scheduleDate, assignments)
    if (!result) {
      // Pass the database's actual complaint through — "Assignment 47 of 202
      // failed: <reason>" is diagnosable; "Failed to save schedule" is not.
      throw new Error(
        scheduleError.value
          ? `Could not save: ${scheduleError.value}`
          : `Could not save the schedule (${assignments.length} assignments). The server rejected the write without a reason.`
      )
    }
  }

  return { generateV2Schedule, applyV2Schedule, lastResult }
}
