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

  return {
    jobFunctions,
    loading,
    error,
    fetchJobFunctions,
    createJobFunction,
    updateJobFunction,
    deleteJobFunction
  }
}

