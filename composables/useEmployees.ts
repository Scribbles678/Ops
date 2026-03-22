export const useEmployees = () => {
  const employees = ref<any[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  const fetchEmployees = async (activeOnly = true) => {
    loading.value = true
    error.value = null
    try {
      employees.value = await $fetch<any[]>('/api/employees', {
        params: activeOnly ? { active: 'true' } : {},
      })
      return employees.value
    } catch (e: any) {
      error.value = e.message
      return []
    } finally {
      loading.value = false
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
      error.value = e.message
      return null
    } finally {
      loading.value = false
    }
  }

  const updateEmployee = async (id: string, employeeData: any) => {
    loading.value = true
    error.value = null
    try {
      const data = await $fetch(`/api/employees/${id}`, { method: 'PUT', body: employeeData })
      await fetchEmployees()
      return data
    } catch (e: any) {
      error.value = e.message
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
      error.value = e.message
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

  const getAllEmployeeTraining = async (_employeeIds?: string[]) => {
    try {
      const rows = await $fetch<{ employee_id: string; job_function_id: string }[]>('/api/employees/training')
      const out: Record<string, string[]> = {}
      rows.forEach((r) => {
        if (!out[r.employee_id]) out[r.employee_id] = []
        out[r.employee_id].push(r.job_function_id)
      })
      return out
    } catch {
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
