export const useSchedule = () => {
  const scheduleAssignments = ref<any[]>([])
  const shifts = ref<any[]>([])
  const dailyTargets = ref<any[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  const fetchShifts = async () => {
    loading.value = true
    error.value = null
    try {
      shifts.value = await $fetch<any[]>('/api/shifts')
      return shifts.value
    } catch (e: any) {
      error.value = e.message
      return []
    } finally {
      loading.value = false
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
      error.value = e.message
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
      error.value = e.message
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
      error.value = e.message
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
      error.value = e.message
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

  const copySchedule = async (fromDate: string, toDate: string) => {
    loading.value = true
    error.value = null
    try {
      await $fetch('/api/schedule/copy', { method: 'POST', body: { from_date: fromDate, to_date: toDate } })
      return true
    } catch (e: any) {
      error.value = e.message
      return false
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

  const runCleanup = async () => {
    loading.value = true
    error.value = null
    try {
      return await $fetch('/api/admin/cleanup/run', { method: 'POST' })
    } catch (e: any) {
      error.value = e.message
      return null
    } finally {
      loading.value = false
    }
  }

  const getCleanupStats = async () => {
    try {
      return await $fetch('/api/admin/cleanup/stats')
    } catch {
      return null
    }
  }

  const getCleanupLog = async (limit = 10) => {
    try {
      return await $fetch('/api/admin/cleanup/log', { params: { limit } })
    } catch {
      return []
    }
  }

  const getCleanupStatus = async () => {
    try {
      return await $fetch('/api/admin/cleanup/stats')
    } catch {
      return null
    }
  }

  const fetchOldSchedulesForExport = async () => {
    try {
      return await $fetch<any[]>('/api/schedule/export')
    } catch {
      return []
    }
  }

  const fetchTargetHours = async () => {
    try {
      const rows = await $fetch<{ job_function_id: string; target_hours: number }[]>('/api/target-hours')
      const out: Record<string, number> = {}
      rows.forEach((r) => { out[r.job_function_id] = Number(r.target_hours) })
      return out
    } catch {
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
    copySchedule,
    fetchDailyTargets,
    upsertDailyTarget,
    runCleanup,
    getCleanupStats,
    getCleanupLog,
    getCleanupStatus,
    fetchOldSchedulesForExport,
    fetchTargetHours,
    saveTargetHours,
  }
}
