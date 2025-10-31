export const useBusinessRules = () => {
  const { $supabase } = useNuxtApp()

  const businessRules = ref<any[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  const fetchBusinessRules = async () => {
    try {
      loading.value = true
      error.value = null
      const { data, error: err } = await $supabase
        .from('business_rules')
        .select('*')
        .eq('is_active', true)
        .order('job_function_name', { ascending: true })
        .order('priority', { ascending: true })
        .order('time_slot_start', { ascending: true })
      
      if (err) throw err
      businessRules.value = data || []
      return businessRules.value
    } catch (e: any) {
      error.value = e.message
      console.error('Error fetching business rules:', e)
      return []
    } finally {
      loading.value = false
    }
  }

  const createBusinessRule = async (rule: {
    job_function_name: string
    time_slot_start: string
    time_slot_end: string
    min_staff: number
    max_staff?: number | null
    block_size_minutes: number
    priority?: number
    is_active?: boolean
    notes?: string | null
  }) => {
    try {
      loading.value = true
      error.value = null
      const { data, error: err } = await $supabase
        .from('business_rules')
        .insert([rule])
        .select()
      
      if (err) throw err
      await fetchBusinessRules() // Refresh list
      return data?.[0]
    } catch (e: any) {
      error.value = e.message
      console.error('Error creating business rule:', e)
      return null
    } finally {
      loading.value = false
    }
  }

  const updateBusinessRule = async (id: string, updates: Partial<{
    job_function_name: string
    time_slot_start: string
    time_slot_end: string
    min_staff: number
    max_staff: number | null
    block_size_minutes: number
    priority: number
    is_active: boolean
    notes: string | null
  }>) => {
    try {
      loading.value = true
      error.value = null
      const { data, error: err } = await $supabase
        .from('business_rules')
        .update(updates)
        .eq('id', id)
        .select()
      
      if (err) throw err
      await fetchBusinessRules() // Refresh list
      return data?.[0]
    } catch (e: any) {
      error.value = e.message
      console.error('Error updating business rule:', e)
      return null
    } finally {
      loading.value = false
    }
  }

  const deleteBusinessRule = async (id: string) => {
    try {
      loading.value = true
      error.value = null
      const { error: err } = await $supabase
        .from('business_rules')
        .delete()
        .eq('id', id)
      
      if (err) throw err
      await fetchBusinessRules() // Refresh list
      return true
    } catch (e: any) {
      error.value = e.message
      console.error('Error deleting business rule:', e)
      return false
    } finally {
      loading.value = false
    }
  }

  // Group rules by job function for easier consumption
  const rulesByJobFunction = computed(() => {
    const grouped: Record<string, any[]> = {}
    businessRules.value.forEach(rule => {
      if (!grouped[rule.job_function_name]) {
        grouped[rule.job_function_name] = []
      }
      grouped[rule.job_function_name].push(rule)
    })
    return grouped
  })

  return {
    businessRules,
    rulesByJobFunction,
    loading,
    error,
    fetchBusinessRules,
    createBusinessRule,
    updateBusinessRule,
    deleteBusinessRule
  }
}

