export const useSchedule = () => {
  const scheduleAssignments = ref<any[]>([])
  const shifts = ref<any[]>([])
  const dailyTargets = ref<any[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  // Whether this instance's shift list includes inactive shifts. Team Setup asks for
  // them (so a deactivated shift can be switched back on); every other page gets
  // active only. Remembered so a save refreshes the same list it came from.
  let includeInactiveShifts = false
  // Only the newest request's answer lands. Two quick saves each refetch the list,
  // and the older reply can arrive last — it used to overwrite the newer one.
  let shiftsSeq = 0

  const fetchShifts = async (opts?: { includeInactive?: boolean }) => {
    if (typeof opts?.includeInactive === 'boolean') includeInactiveShifts = opts.includeInactive
    const mine = ++shiftsSeq
    loading.value = true
    error.value = null
    try {
      const rows = await $fetch<any[]>('/api/shifts', {
        params: includeInactiveShifts ? { include_inactive: 'true' } : {},
      })
      if (mine === shiftsSeq) shifts.value = rows
      return shifts.value
    } catch (e: any) {
      if (mine === shiftsSeq) error.value = e.data?.message ?? e.message
      return []
    } finally {
      if (mine === shiftsSeq) loading.value = false
    }
  }

  const createShift = async (shiftData: any) => {
    loading.value = true
    error.value = null
    try {
      const data = await $fetch('/api/shifts', { method: 'POST', body: shiftData })
      await fetchShifts()
      return data
    } catch (e: any) {
      error.value = e.data?.message ?? e.message
      return null
    } finally {
      loading.value = false
    }
  }

  const updateShift = async (id: string, shiftData: any) => {
    loading.value = true
    error.value = null
    try {
      const data = await $fetch(`/api/shifts/${id}`, { method: 'PUT', body: shiftData })
      await fetchShifts()
      return data
    } catch (e: any) {
      error.value = e.data?.message ?? e.message
      return null
    } finally {
      loading.value = false
    }
  }

  const deleteShift = async (id: string) => {
    loading.value = true
    error.value = null
    try {
      await $fetch(`/api/shifts/${id}`, { method: 'DELETE' })
      await fetchShifts()
      return true
    } catch (e: any) {
      error.value = e.data?.message ?? e.message
      return false
    } finally {
      loading.value = false
    }
  }

  const fetchScheduleForDate = async (date: string) => {
    loading.value = true
    error.value = null
    try {
      scheduleAssignments.value = await $fetch<any[]>(`/api/schedule/${date}`)
      return scheduleAssignments.value
    } catch (e: any) {
      error.value = e.message
      return []
    } finally {
      loading.value = false
    }
  }

  const createAssignmentsBatch = async (assignments: any[]) => {
    try {
      const result = await $fetch('/api/schedule/assignments-batch', {
        method: 'POST',
        body: { assignments },
      })
      return result
    } catch (e: any) {
      const msg = e?.data?.message ?? e?.data?.data?.message ?? e?.message ?? 'Failed to create assignments batch'
      error.value = msg
      return null
    }
  }

  const createAssignment = async (assignmentData: any) => {
    loading.value = true
    error.value = null
    try {
      return await $fetch('/api/schedule/assignments', { method: 'POST', body: assignmentData })
    } catch (e: any) {
      error.value = e.message
      return null
    } finally {
      loading.value = false
    }
  }

  const updateAssignment = async (id: string, assignmentData: any) => {
    loading.value = true
    error.value = null
    try {
      return await $fetch(`/api/schedule/assignments/${id}`, { method: 'PUT', body: assignmentData })
    } catch (e: any) {
      error.value = e.message
      return null
    } finally {
      loading.value = false
    }
  }

  const deleteAssignment = async (id: string) => {
    loading.value = true
    error.value = null
    try {
      await $fetch(`/api/schedule/assignments/${id}`, { method: 'DELETE' })
      return true
    } catch (e: any) {
      error.value = e.message
      return false
    } finally {
      loading.value = false
    }
  }

  const clearAssignmentsForDate = async (date: string) => {
    try {
      await $fetch(`/api/schedule/${date}`, { method: 'DELETE' })
      return true
    } catch {
      return false
    }
  }

  const replaceScheduleForDate = async (date: string, assignments: any[]) => {
    try {
      const result = await $fetch('/api/schedule/replace', {
        method: 'POST',
        body: { date, assignments },
      })
      return result
    } catch (e: any) {
      const msg = e?.data?.message ?? e?.data?.data?.message ?? e?.message ?? 'Failed to replace schedule'
      error.value = msg
      return null
    }
  }

  /** What POST /api/schedule/copy reports back. Counts are assignments. */
  interface ScheduleCopyResult {
    success: boolean
    /** The source day had nothing to copy; nothing was changed. */
    source_empty: boolean
    copied: number
    /** Assignments already on the target day that were cleared first. */
    replaced: number
    /** Left off because the person is off that day. */
    excluded: number
    /** Trimmed around a partial absence. */
    adjusted: number
    /** Skipped because the person is no longer active. */
    inactive: number
    /** People with a shift swap on the target day, left off by name. */
    swapped: string[]
  }

  const copySchedule = async (fromDate: string, toDate: string): Promise<ScheduleCopyResult | null> => {
    loading.value = true
    error.value = null
    try {
      return await $fetch<ScheduleCopyResult>('/api/schedule/copy', {
        method: 'POST',
        body: { from_date: fromDate, to_date: toDate },
      })
    } catch (e: any) {
      // Keep the server's own message — it names the row and the rule that
      // rejected it. The generic fetch message is just the status code.
      error.value = e?.data?.message ?? e?.data?.data?.message ?? e?.message ?? 'Failed to copy schedule'
      return null
    } finally {
      loading.value = false
    }
  }

  const fetchDailyTargets = async (date: string) => {
    try {
      dailyTargets.value = await $fetch<any[]>(`/api/daily-targets/${date}`)
      return dailyTargets.value
    } catch (e: any) {
      console.error('Error fetching daily targets:', e)
      return []
    }
  }

  const upsertDailyTarget = async (targetData: any) => {
    loading.value = true
    error.value = null
    try {
      return await $fetch('/api/daily-targets', { method: 'POST', body: targetData })
    } catch (e: any) {
      error.value = e.message
      return null
    } finally {
      loading.value = false
    }
  }

  /**
   * Rows for a historical schedule export, across a date range.
   * Spans live assignments and the archive, so ranges that straddle both are whole.
   */
  const fetchScheduleExport = async (dateFrom: string, dateTo: string) => {
    return await $fetch<any[]>('/api/schedule/export', {
      params: { date_from: dateFrom, date_to: dateTo },
    })
  }

  /**
   * job_function_id → saved target hours. A job with no row isn't in the map.
   * `strict` throws on failure (Team Setup, so a failed load isn't mistaken for
   * "nothing set" and saved over); otherwise a failure returns {}.
   */
  const fetchTargetHours = async (opts?: { strict?: boolean }) => {
    try {
      const rows = await $fetch<{ job_function_id: string; target_hours: number }[]>('/api/target-hours')
      const out: Record<string, number> = {}
      rows.forEach((r) => { out[r.job_function_id] = Number(r.target_hours) })
      return out
    } catch (e) {
      if (opts?.strict) throw e
      return {}
    }
  }

  const saveTargetHours = async (items: Array<{ job_function_id: string; target_hours: number }>) => {
    try {
      await $fetch('/api/target-hours', { method: 'POST', body: { items } })
      return true
    } catch {
      return false
    }
  }

  return {
    scheduleAssignments,
    shifts,
    dailyTargets,
    loading,
    error,
    fetchShifts,
    createShift,
    updateShift,
    deleteShift,
    fetchScheduleForDate,
    createAssignment,
    createAssignmentsBatch,
    updateAssignment,
    deleteAssignment,
    clearAssignmentsForDate,
    replaceScheduleForDate,
    copySchedule,
    fetchDailyTargets,
    upsertDailyTarget,
    fetchScheduleExport,
    fetchTargetHours,
    saveTargetHours,
  }
}
