/**
 * Schedule Builder V2 (Beta) — composable wrapper.
 *
 * Fetches the same inputs V1 does, runs the pure slot engine in
 * utils/scheduleEngineV2/, and returns V1's EXACT output contract so the existing
 * review modal and the transactional apply path are reused unchanged.
 *
 * V1 is not touched. Switching engines is a matter of which composable the page
 * calls, and reverting is removing a button.
 */
import { prepare } from '~/utils/scheduleEngineV2/prepare'
import { runEngine } from '~/utils/scheduleEngineV2/engine'
import { slotToTime } from '~/utils/scheduleEngineV2/slots'
import type { EngineResult } from '~/utils/scheduleEngineV2/types'

export interface V2ScheduleAssignment {
  employee_id: string
  employee_name: string
  job_function: string
  start_time: string
  end_time: string
  /** The shift actually worked that day — the swapped one where a swap exists. */
  shift_id?: string | null
}

export const useScheduleBuilderV2 = () => {
  const { fetchEmployees, getAllEmployeeTraining } = useEmployees()
  const { jobFunctions, fetchJobFunctions } = useJobFunctions()
  // `error` carries the server's real failure message; replaceScheduleForDate only
  // returns null, so without this a DB rejection surfaces as "Failed to save".
  const { fetchShifts, replaceScheduleForDate, error: scheduleError } = useSchedule()
  const { fetchPreferredAssignments, getPreferredAssignmentsMap } = usePreferredAssignments()
  const { fetchTargets: fetchStaffingTargets } = useStaffingTargets()

  /** Last engine result, so the UI can show V2-only diagnostics. */
  const lastResult = ref<EngineResult | null>(null)

  const generateV2Schedule = async (scheduleDate: string = '') => {
    const warnings: string[] = []
    const errors: string[] = []

    try {
      const [employeesData, jobFunctionsData, shiftsData, targetsData] = await Promise.all([
        fetchEmployees(),
        fetchJobFunctions(),
        fetchShifts(),
        fetchStaffingTargets(),
      ])
      await fetchPreferredAssignments()

      const employees = Array.isArray(employeesData) ? employeesData : []
      const jobFunctionsList = Array.isArray(jobFunctionsData) ? jobFunctionsData : []
      const shifts = Array.isArray(shiftsData) ? shiftsData : []
      const staffingTargets = Array.isArray(targetsData) ? targetsData : []

      const activeEmployees = employees.filter((e: any) => e && e.is_active !== false)
      if (!activeEmployees.length) errors.push('No active employees found.')
      if (!shifts.filter((s: any) => s && s.is_active !== false).length) errors.push('No active shifts found.')
      if (!jobFunctionsList.length) errors.push('No job functions configured.')
      if (!staffingTargets.length) {
        errors.push('No staffing targets configured. Please set up staffing targets in the admin page.')
      }
      if (errors.length) {
        return { schedule: [], warnings, actions: [], errors, gaps: [], overTarget: [], feasibility: [], stats: null }
      }

      let training: Record<string, string[]> = {}
      try {
        training = (await getAllEmployeeTraining(activeEmployees.map((e: any) => e.id))) || {}
      } catch (e: any) {
        errors.push(`Error loading employee training: ${e?.message || 'Unknown error'}`)
        return { schedule: [], warnings, actions: [], errors, gaps: [], overTarget: [], feasibility: [], stats: null }
      }

      // Shift swaps for the date. A swap replaces the employee's shift for that
      // day only, and the builder must both SCHEDULE against it and STAMP it —
      // the display groups swapped people by the swapped shift, so an assignment
      // carrying the original shift is dropped from the board.
      const swappedShiftByEmployee: Record<string, string | null> = {}
      if (scheduleDate) {
        try {
          const swaps = await $fetch<any[]>(`/api/shift-swaps/${scheduleDate}`)
          if (Array.isArray(swaps)) {
            for (const sw of swaps) {
              if (sw?.employee_id && sw?.swapped_shift_id) {
                swappedShiftByEmployee[sw.employee_id] = sw.swapped_shift_id
              }
            }
          }
        } catch (e: any) {
          warnings.push(`Could not load shift swaps: ${e?.message || 'Unknown error'}`)
        }
      }

      let ptoByEmployee: Record<string, any> = {}
      if (scheduleDate) {
        try {
          const ptoDays = await $fetch<any[]>(`/api/pto/${scheduleDate}`)
          if (Array.isArray(ptoDays)) {
            for (const p of ptoDays) if (p?.employee_id) ptoByEmployee[p.employee_id] = p
          }
        } catch (e: any) {
          warnings.push(`Could not load PTO data: ${e?.message || 'Unknown error'}`)
        }
      }

      const actions: string[] = []

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
      warnings.push(...prepared.warnings)
      actions.push(...prepared.actions)

      const result = runEngine({
        employees: prepared.employees,
        functions: prepared.functions,
        preferred: prepared.preferred,
        requiredPins: prepared.requiredPins,
      })
      lastResult.value = result
      warnings.push(...result.warnings)
      actions.push(...result.actions)

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

      if (!schedule.length) errors.push('No schedule assignments could be created.')

      // Map to V1's gap/overTarget shape so the review modal renders unchanged.
      //
      // Split the list first. On a normal day ~90% of gap rows are windows where
      // a whole shift is on break or lunch, or hours past the last shift — real,
      // but unfixable by any schedule. Showing 42 undifferentiated rows buries
      // the two or three a supervisor could actually act on.
      const structural = result.gaps.filter((g) => g.cause === 'no-one-trained-on-shift')
      const actionable = result.gaps.filter((g) => g.cause !== 'no-one-trained-on-shift')

      const gaps = actionable.map((g) => ({
        job_function_name: g.functionName,
        hour: g.time,
        shortfall: g.shortfall,
        cause: g.cause,
        detail: g.detail,
      }))
      const overTarget = result.overTarget.map((o) => ({
        job_function_name: o.functionName,
        hour: o.time,
        surplus: o.surplus,
      }))

      // Summarise the structural ones rather than listing every window.
      // Plain language on purpose. This line is read by supervisors at sites that
      // did not build the app, so "headcount-hours" and "shortfalls" are out.
      const structuralHours = Math.round((structural.reduce((s, g) => s + g.shortfall, 0) / 4) * 10) / 10
      const structuralSummary = structural.length
        ? [
            `About ${structuralHours} hours of your targets could not be covered by anyone — the people were on break or at lunch, or the hours fall outside every shift. Rebuilding will not change this; staggering a break or trimming a target will.`,
          ]
        : []

      return {
        schedule,
        warnings,
        actions,
        errors,
        gaps,
        overTarget,
        structuralSummary,
        structuralCount: structural.length,
        feasibility: result.feasibility,
        stats: result.stats,
      }
    } catch (e: any) {
      errors.push(`Error occurred: ${e?.message || 'Unknown error'}`)
      return { schedule: [], warnings, actions: [], errors, gaps: [], overTarget: [], feasibility: [], stats: null }
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
