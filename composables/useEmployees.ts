export const useEmployees = () => {
  const supabase = useSupabaseClient()
  const { getCurrentTeamId, isSuperAdmin } = useTeam()
  
  const employees = ref([])
  const loading = ref(false)
  const error = ref(null)

  const fetchEmployees = async (activeOnly = true) => {
    loading.value = true
    error.value = null
    
    try {
      // Get team_id filter (null for super admins = see all)
      const teamId = isSuperAdmin.value ? null : await getCurrentTeamId()
      
      let query = supabase
        .from('employees')
        .select('*')
      
      // Filter by team_id if not super admin
      if (teamId) {
        query = query.eq('team_id', teamId)
      }
      
      query = query.order('last_name', { ascending: true })
      
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
      // Get team_id for new employee
      const teamId = isSuperAdmin.value ? employeeData.team_id : await getCurrentTeamId()
      if (!teamId && !isSuperAdmin.value) {
        throw new Error('Unable to determine team. Please contact administrator.')
      }
      
      const { data, error: createError } = await supabase
        .from('employees')
        .insert([{ ...employeeData, team_id: teamId }])
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
      const { data, error: updateError } = await supabase
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
      const { error: deleteError } = await supabase
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
      const { data, error: fetchError } = await supabase
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
      if (!employeeIds || employeeIds.length === 0) return {}

      const batchSize = 1000
      let from = 0
      let hasMore = true
      let allRows: Array<{ employee_id: string; job_function_id: string }> = []

      while (hasMore) {
        const { data, error: fetchError } = await supabase
          .from('employee_training')
          .select('employee_id, job_function_id')
          .in('employee_id', employeeIds)
          .order('employee_id', { ascending: true })
          .range(from, from + batchSize - 1)

        if (fetchError) throw fetchError

        if (!data || data.length === 0) {
          hasMore = false
        } else {
          allRows = allRows.concat(data)
          hasMore = data.length === batchSize
          from += batchSize
        }
      }

      const trainingMap: Record<string, string[]> = {}
      allRows.forEach(row => {
        if (!trainingMap[row.employee_id]) {
          trainingMap[row.employee_id] = []
        }
        trainingMap[row.employee_id].push(row.job_function_id)
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
      // Clean the array (remove duplicates, nulls, and invalid IDs)
      const cleanJobFunctionIds = Array.from(new Set(jobFunctionIds.filter(id => id && id !== 'meter-group')))
      
      // Try stored procedure first, fallback to direct approach if it fails
      let useDirectMethod = false
      
      try {
        const { data, error: rpcError } = await supabase.rpc('update_employee_training', {
          p_employee_id: employeeId,
          p_job_function_ids: cleanJobFunctionIds
        })
        
        if (rpcError) {
          console.error('RPC error, falling back to direct method:', rpcError)
          useDirectMethod = true
        } else if (data === null || data === false) {
          console.error('Stored procedure returned false/null, falling back to direct method')
          useDirectMethod = true
        }
      } catch (rpcException) {
        console.error('RPC exception, falling back to direct method:', rpcException)
        useDirectMethod = true
      }
      
      // Fallback to direct method if RPC failed
      if (useDirectMethod) {
        // Delete all existing training records
        const { error: deleteError } = await supabase
          .from('employee_training')
          .delete()
          .eq('employee_id', employeeId)
        
        if (deleteError) {
          console.error('Delete error:', deleteError)
          throw deleteError
        }
        
        // Insert new training records
        if (cleanJobFunctionIds.length > 0) {
          const trainingRecords = cleanJobFunctionIds.map(jfId => ({
            employee_id: employeeId,
            job_function_id: jfId
          }))
          
          const { error: insertError } = await supabase
            .from('employee_training')
            .insert(trainingRecords)
        
          if (insertError) {
            console.error('Insert error:', insertError)
            throw insertError
          }
        }
      }
      
      // Verify the save by fetching back (with retry for eventual consistency)
      let verificationPassed = false
      let retryCount = 0
      const maxRetries = 3
      
      while (!verificationPassed && retryCount < maxRetries) {
        if (retryCount > 0) {
          await new Promise(resolve => setTimeout(resolve, 200 * retryCount))
        }
        
        const { data: verifyData, error: verifyError } = await supabase
          .from('employee_training')
          .select('job_function_id')
          .eq('employee_id', employeeId)
        
        if (verifyError) {
          console.error('Verify error:', verifyError)
          throw verifyError
        }
        
        const insertedIds = verifyData.map(r => r.job_function_id)
        const expectedSet = new Set(cleanJobFunctionIds)
        const actualSet = new Set(insertedIds)
        
        verificationPassed = expectedSet.size === actualSet.size && 
          Array.from(expectedSet).every(id => actualSet.has(id))
        
        if (verificationPassed) {
          break
        }
        retryCount++
      }
      
      if (!verificationPassed) {
        throw new Error(`Training verification failed after ${maxRetries} attempts. Expected ${cleanJobFunctionIds.length} records.`)
      }
      
      return true
    } catch (e) {
      error.value = e.message
      console.error('Error updating employee training:', e)
      throw e
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

