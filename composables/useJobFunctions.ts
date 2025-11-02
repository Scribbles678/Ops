export const useJobFunctions = () => {
  const { $supabase } = useNuxtApp()
  
  const jobFunctions = ref([])
  const loading = ref(false)
  const error = ref(null)

  const fetchJobFunctions = async (activeOnly = true) => {
    loading.value = true
    error.value = null
    
    try {
      let query = $supabase
        .from('job_functions')
        .select('*')
        .order('sort_order', { ascending: true })
      
      if (activeOnly) {
        query = query.eq('is_active', true)
      }
      
      const { data, error: fetchError } = await query
      
      if (fetchError) throw fetchError
      
      jobFunctions.value = data
      return data
    } catch (e) {
      error.value = e.message
      console.error('Error fetching job functions:', e)
      return []
    } finally {
      loading.value = false
    }
  }

  const createJobFunction = async (jobFunctionData) => {
    loading.value = true
    error.value = null
    
    try {
      const { data, error: createError } = await $supabase
        .from('job_functions')
        .insert([jobFunctionData])
        .select()
      
      if (createError) throw createError
      
      await fetchJobFunctions()
      return data[0]
    } catch (e) {
      error.value = e.message
      console.error('Error creating job function:', e)
      return null
    } finally {
      loading.value = false
    }
  }

  const updateJobFunction = async (id, jobFunctionData) => {
    loading.value = true
    error.value = null
    
    try {
      const { data, error: updateError } = await $supabase
        .from('job_functions')
        .update(jobFunctionData)
        .eq('id', id)
        .select()
      
      if (updateError) throw updateError
      
      await fetchJobFunctions()
      return data[0]
    } catch (e) {
      error.value = e.message
      console.error('Error updating job function:', e)
      return null
    } finally {
      loading.value = false
    }
  }

  const deleteJobFunction = async (id) => {
    loading.value = true
    error.value = null
    
    try {
      const { error: deleteError } = await $supabase
        .from('job_functions')
        .delete()
        .eq('id', id)
      
      if (deleteError) throw deleteError
      
      await fetchJobFunctions()
      return true
    } catch (e) {
      error.value = e.message
      console.error('Error deleting job function:', e)
      return false
    } finally {
      loading.value = false
    }
  }

  // Helper functions for meter management
  const isMeterJobFunction = (jobFunctionName) => {
    return jobFunctionName && jobFunctionName.startsWith('Meter ')
  }

  const getMeterNumber = (jobFunctionName) => {
    if (!isMeterJobFunction(jobFunctionName)) return null
    const match = jobFunctionName.match(/Meter (\d+)/)
    return match ? parseInt(match[1]) : null
  }

  const getGroupedJobFunctions = () => {
    if (!jobFunctions.value) return []
    
    const grouped = []
    const meters = []
    
    jobFunctions.value.forEach(jf => {
      if (isMeterJobFunction(jf.name)) {
        // Individual meter entries (Meter 1, Meter 2, etc.)
        meters.push(jf)
      } else if (jf.name === 'Meter') {
        // Skip standalone "Meter" entry - we'll create a grouped one instead
        // This prevents duplicate "Meter" entries in the UI
      } else {
        // All other non-meter job functions
        grouped.push(jf)
      }
    })
    
    // Add a single "Meter" entry representing all meters (only if we have individual meters)
    if (meters.length > 0) {
      grouped.push({
        id: 'meter-group',
        name: 'Meter',
        color_code: meters[0].color_code,
        productivity_rate: meters[0].productivity_rate,
        unit_of_measure: meters[0].unit_of_measure,
        is_active: meters[0].is_active,
        sort_order: meters[0].sort_order,
        isGroup: true,
        individualMeters: meters
      })
    }
    
    return grouped.sort((a, b) => a.sort_order - b.sort_order)
  }

  const getAllMeterJobFunctions = () => {
    if (!jobFunctions.value) return []
    return jobFunctions.value.filter(jf => isMeterJobFunction(jf.name))
  }

  const getMeterJobFunctionByNumber = (meterNumber) => {
    if (!jobFunctions.value) return null
    return jobFunctions.value.find(jf => jf.name === `Meter ${meterNumber}`)
  }

  return {
    jobFunctions,
    loading,
    error,
    fetchJobFunctions,
    createJobFunction,
    updateJobFunction,
    deleteJobFunction,
    // Meter helper functions
    isMeterJobFunction,
    getMeterNumber,
    getGroupedJobFunctions,
    getAllMeterJobFunctions,
    getMeterJobFunctionByNumber
  }
}

