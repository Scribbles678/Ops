export const useEmployees = () => {
  const employees = ref<any[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)
  // Active-only unless told otherwise, and remembered: a save refreshes the same
  // list it came from. (It always refetched active-only, so on a page listing
  // inactive people too, saving anyone made the inactive ones disappear.)
  let activeOnlyList = true
  // Only the newest request's answer lands. Two quick saves each refetch the list,
  // and the older reply can arrive last — it used to overwrite the newer one.
  let fetchSeq = 0

  const fetchEmployees = async (activeOnly?: boolean) => {
    if (typeof activeOnly === 'boolean') activeOnlyList = activeOnly
    const mine = ++fetchSeq
    loading.value = true
    error.value = null
    try {
      const rows = await $fetch<any[]>('/api/employees', {
        params: activeOnlyList ? { active: 'true' } : {},
      })
      if (mine === fetchSeq) employees.value = rows
      return employees.value
    } catch (e: any) {
      if (mine === fetchSeq) error.value = e.data?.message ?? e.message
      return []
    } finally {
      if (mine === fetchSeq) loading.value = false
    }
  }

  const createEmployee = async (employeeData: any) => {
    loading.value = true
    error.value = null
    try {
      const data = await $fetch('/api/employees', { method: 'POST', body: employeeData })
      await fetchEmployees()
      return data
    } catch (e: any) {
      error.value = e.data?.message ?? e.message
      return null
    } finally {
      loading.value = false
    }
  }

  /**
   * `refetch: false` patches just this employee from the server's reply instead of
   * reloading everyone — for one-field saves like the shift dropdown.
   */
  const updateEmployee = async (id: string, employeeData: any, opts?: { refetch?: boolean }) => {
    loading.value = true
    error.value = null
    try {
      const data = await $fetch<any>(`/api/employees/${id}`, { method: 'PUT', body: employeeData })
      if (opts?.refetch === false) {
        employees.value = employees.value.map((e: any) => (e.id === id ? { ...e, ...data } : e))
      } else {
        await fetchEmployees()
      }
      return data
    } catch (e: any) {
      error.value = e.data?.message ?? e.message
      return null
    } finally {
      loading.value = false
    }
  }

  const deleteEmployee = async (id: string) => {
    loading.value = true
    error.value = null
    try {
      await $fetch(`/api/employees/${id}`, { method: 'DELETE' })
      await fetchEmployees()
      return true
    } catch (e: any) {
      error.value = e.data?.message ?? e.message
      return false
    } finally {
      loading.value = false
    }
  }

  const getEmployeeTraining = async (employeeId: string) => {
    try {
      return await $fetch<any[]>(`/api/employees/${employeeId}/training`)
    } catch {
      return []
    }
  }

  /**
   * employee_id → trained job_function_ids. `strict` throws on failure (Team Setup:
   * a failed load must not look like "trained on nothing" — one tick would then
   * have erased all of that person's training). Otherwise a failure returns {}.
   */
  const getAllEmployeeTraining = async (opts?: { strict?: boolean } | string[]) => {
    const strict = !Array.isArray(opts) && !!opts?.strict
    try {
      const rows = await $fetch<{ employee_id: string; job_function_id: string }[]>('/api/employees/training')
      const out: Record<string, string[]> = {}
      rows.forEach((r) => {
        if (!out[r.employee_id]) out[r.employee_id] = []
        out[r.employee_id].push(r.job_function_id)
      })
      return out
    } catch (e) {
      if (strict) throw e
      return {}
    }
  }

  const updateEmployeeTraining = async (employeeId: string, jobFunctionIds: string[]) => {
    loading.value = true
    error.value = null
    try {
      await $fetch('/api/employees/training', {
        method: 'POST',
        body: { employee_id: employeeId, job_function_ids: jobFunctionIds },
      })
      return true
    } catch (e: any) {
      error.value = e.message
      return false
    } finally {
      loading.value = false
    }
  }

  return {
    employees,
    loading,
    error,
    fetchEmployees,
    createEmployee,
    updateEmployee,
    deleteEmployee,
    getEmployeeTraining,
    getAllEmployeeTraining,
    updateEmployeeTraining,
  }
}
