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
        return { schedule: [], warnings, errors, gaps: [], overTarget: [], feasibility: [], stats: null }
      }

      let training: Record<string, string[]> = {}
      try {
        training = (await getAllEmployeeTraining(activeEmployees.map((e: any) => e.id))) || {}
      } catch (e: any) {
        errors.push(`Error loading employee training: ${e?.message || 'Unknown error'}`)
        return { schedule: [], warnings, errors, gaps: [], overTarget: [], feasibility: [], stats: null }
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

      const prepared = prepare({
        employees: activeEmployees,
        jobFunctions: jobFunctionsList,
        shifts,
        training,
        staffingTargets,
        preferredAssignments: getPreferredAssignmentsMap(),
        ptoByEmployee,
      })
      warnings.push(...prepared.warnings)

      const result = runEngine({
        employees: prepared.employees,
        functions: prepared.functions,
        preferred: prepared.preferred,
        requiredPins: prepared.requiredPins,
      })
      lastResult.value = result
      warnings.push(...result.warnings)

      const nameById = new Map(prepared.employees.map((e) => [e.id, e.name]))
      const fnNameById = new Map(prepared.functions.map((f) => [f.id, f.name]))

      const schedule: V2ScheduleAssignment[] = result.assignments.map((a) => ({
        employee_id: a.employeeId,
        employee_name: nameById.get(a.employeeId) || '',
        job_function: fnNameById.get(a.functionId) || '',
        start_time: slotToTime(a.startSlot),
        end_time: slotToTime(a.endSlot),
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
      const structuralHours = Math.round((structural.reduce((s, g) => s + g.shortfall, 0) / 4) * 10) / 10
      const structuralSummary = structural.length
        ? [
            `${structural.length} further shortfalls (${structuralHours} headcount-hours) fall in windows nobody can cover — a whole shift on break or at lunch, or hours after the last shift ends. No schedule can fill these; staggering a break or trimming a target can.`,
          ]
        : []

      return {
        schedule,
        warnings,
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
      return { schedule: [], warnings, errors, gaps: [], overTarget: [], feasibility: [], stats: null }
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
        const shiftId = employeeShiftMap.get(a.employee_id)
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
