export const useEmployees = () => {
  const { $supabase } = useNuxtApp()
  
  const employees = ref([])
  const loading = ref(false)
  const error = ref(null)

  const fetchEmployees = async (activeOnly = true) => {
    loading.value = true
    error.value = null
    
    try {
      let query = $supabase
        .from('employees')
        .select('*')
        .order('last_name', { ascending: true })
      
      if (activeOnly) {
        query = query.eq('is_active', true)
      }
      
      const { data, error: fetchError } = await query
      
      if (fetchError) throw fetchError
      
      employees.value = data
      return data
    } catch (e) {
      error.value = e.message
      console.error('Error fetching employees:', e)
      return []
    } finally {
      loading.value = false
    }
  }

  const createEmployee = async (employeeData) => {
    loading.value = true
    error.value = null
    
    try {
      const { data, error: createError } = await $supabase
        .from('employees')
        .insert([employeeData])
        .select()
      
      if (createError) throw createError
      
      await fetchEmployees()
      return data[0]
    } catch (e) {
      error.value = e.message
      console.error('Error creating employee:', e)
      return null
    } finally {
      loading.value = false
    }
  }

  const updateEmployee = async (id, employeeData) => {
    loading.value = true
    error.value = null
    
    try {
      const { data, error: updateError } = await $supabase
        .from('employees')
        .update(employeeData)
        .eq('id', id)
        .select()
      
      if (updateError) throw updateError
      
      await fetchEmployees()
      return data[0]
    } catch (e) {
      error.value = e.message
      console.error('Error updating employee:', e)
      return null
    } finally {
      loading.value = false
    }
  }

  const deleteEmployee = async (id) => {
    loading.value = true
    error.value = null
    
    try {
      const { error: deleteError } = await $supabase
        .from('employees')
        .delete()
        .eq('id', id)
      
      if (deleteError) throw deleteError
      
      await fetchEmployees()
      return true
    } catch (e) {
      error.value = e.message
      console.error('Error deleting employee:', e)
      return false
    } finally {
      loading.value = false
    }
  }

  const getEmployeeTraining = async (employeeId) => {
    try {
      const { data, error: fetchError } = await $supabase
        .from('employee_training')
        .select('job_function_id')
        .eq('employee_id', employeeId)
      
      if (fetchError) throw fetchError
      
      return data.map(t => t.job_function_id)
    } catch (e) {
      console.error('Error fetching employee training:', e)
      return []
    }
  }

  const getAllEmployeeTraining = async (employeeIds) => {
    try {
      const { data, error: fetchError } = await $supabase
        .from('employee_training')
        .select('employee_id, job_function_id')
        .in('employee_id', employeeIds)
      
      if (fetchError) throw fetchError
      
      // Group by employee_id
      const trainingMap = {}
      data.forEach(t => {
        if (!trainingMap[t.employee_id]) {
          trainingMap[t.employee_id] = []
        }
        trainingMap[t.employee_id].push(t.job_function_id)
      })
      
      return trainingMap
    } catch (e) {
      console.error('Error fetching all employee training:', e)
      return {}
    }
  }

  const updateEmployeeTraining = async (employeeId, jobFunctionIds) => {
    loading.value = true
    error.value = null
    
    try {
      // Delete existing training records
      await $supabase
        .from('employee_training')
        .delete()
        .eq('employee_id', employeeId)
      
      // Insert new training records
      if (jobFunctionIds.length > 0) {
        const trainingRecords = jobFunctionIds.map(jfId => ({
          employee_id: employeeId,
          job_function_id: jfId
        }))
        
        const { error: insertError } = await $supabase
          .from('employee_training')
          .insert(trainingRecords)
        
        if (insertError) throw insertError
      }
      
      return true
    } catch (e) {
      error.value = e.message
      console.error('Error updating employee training:', e)
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
    updateEmployeeTraining
  }
}

