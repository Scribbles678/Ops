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
      businessRules.value = data ? sortRules(data) : []
      return businessRules.value
    } catch (e: any) {
      error.value = e.message
      console.error('Error fetching business rules:', e)
      return []
    } finally {
      loading.value = false
    }
  }

  const sortRules = (rules: any[]) => {
    return [...rules].sort((a, b) => {
      if (a.job_function_name !== b.job_function_name) {
        return a.job_function_name.localeCompare(b.job_function_name)
      }
      if ((a.priority || 0) !== (b.priority || 0)) {
        return (a.priority || 0) - (b.priority || 0)
      }
      return a.time_slot_start.localeCompare(b.time_slot_start)
    })
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
    fan_out_enabled?: boolean
    fan_out_prefix?: string | null
  }) => {
    try {
      loading.value = true
      error.value = null
      const { data, error: err } = await $supabase
        .from('business_rules')
        .insert([rule])
        .select()
      
      if (err) throw err
      if (data && data[0]) {
        businessRules.value = sortRules([...businessRules.value, data[0]])
        return data[0]
      }
      return null
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
    fan_out_enabled: boolean
    fan_out_prefix: string | null
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
      if (data && data[0]) {
        const updatedRule = data[0]
        businessRules.value = sortRules(businessRules.value.map(rule => rule.id === id ? updatedRule : rule))
        return updatedRule
      }
      return null
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
      businessRules.value = businessRules.value.filter(rule => rule.id !== id)
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

