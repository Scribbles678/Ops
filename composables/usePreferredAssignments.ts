export const usePreferredAssignments = () => {
  const preferredAssignments = ref<any[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  const fetchPreferredAssignments = async () => {
    loading.value = true
    error.value = null
    try {
      preferredAssignments.value = await $fetch<any[]>('/api/preferred-assignments')
      return preferredAssignments.value
    } catch (e: any) {
      error.value = e.message
      return []
    } finally {
      loading.value = false
    }
  }

  const createPreferredAssignment = async (data: any) => {
    loading.value = true
    error.value = null
    try {
      const result = await $fetch('/api/preferred-assignments', { method: 'POST', body: data })
      await fetchPreferredAssignments()
      return result
    } catch (e: any) {
      error.value = e.message
      return null
    } finally {
      loading.value = false
    }
  }

  const updatePreferredAssignment = async (id: string, data: any) => {
    loading.value = true
    error.value = null
    try {
      const result = await $fetch(`/api/preferred-assignments/${id}`, { method: 'PUT', body: data })
      await fetchPreferredAssignments()
      return result
    } catch (e: any) {
      error.value = e.message
      return null
    } finally {
      loading.value = false
    }
  }

  const deletePreferredAssignment = async (id: string) => {
    loading.value = true
    error.value = null
    try {
      await $fetch(`/api/preferred-assignments/${id}`, { method: 'DELETE' })
      await fetchPreferredAssignments()
      return true
    } catch (e: any) {
      error.value = e.message
      return false
    } finally {
      loading.value = false
    }
  }

  const isPreferredAssignment = (employeeId: string, jobFunctionId: string) =>
    preferredAssignments.value.some(
      (pa) => pa.employee_id === employeeId && pa.job_function_id === jobFunctionId
    )

  const isRequiredAssignment = (employeeId: string, jobFunctionId: string) =>
    preferredAssignments.value.some(
      (pa) => pa.employee_id === employeeId && pa.job_function_id === jobFunctionId && pa.is_required
    )

  const getAssignmentPriority = (employeeId: string, jobFunctionId: string) => {
    const pa = preferredAssignments.value.find(
      (p) => p.employee_id === employeeId && p.job_function_id === jobFunctionId
    )
    return pa?.priority ?? 0
  }

  const getPreferredAssignmentsMap = () => {
    const map: Record<string, Record<string, any>> = {}
    for (const pa of preferredAssignments.value) {
      if (!map[pa.employee_id]) map[pa.employee_id] = {}
      map[pa.employee_id][pa.job_function_id] = pa
    }
    return map
  }

  return {
    preferredAssignments,
    loading,
    error,
    fetchPreferredAssignments,
    createPreferredAssignment,
    updatePreferredAssignment,
    deletePreferredAssignment,
    isPreferredAssignment,
    isRequiredAssignment,
    getAssignmentPriority,
    getPreferredAssignmentsMap,
  }
}
