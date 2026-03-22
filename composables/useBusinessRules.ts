export const useBusinessRules = () => {
  const businessRules = ref<any[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  const rulesByJobFunction = computed(() => {
    const map: Record<string, any[]> = {}
    for (const rule of businessRules.value) {
      if (!map[rule.job_function_name]) map[rule.job_function_name] = []
      map[rule.job_function_name].push(rule)
    }
    return map
  })

  const fetchBusinessRules = async () => {
    loading.value = true
    error.value = null
    try {
      businessRules.value = await $fetch<any[]>('/api/business-rules')
      return businessRules.value
    } catch (e: any) {
      error.value = e.message
      return []
    } finally {
      loading.value = false
    }
  }

  const createBusinessRule = async (data: any) => {
    loading.value = true
    error.value = null
    try {
      const result = await $fetch('/api/business-rules', { method: 'POST', body: data })
      await fetchBusinessRules()
      return result
    } catch (e: any) {
      error.value = e.message
      return null
    } finally {
      loading.value = false
    }
  }

  const updateBusinessRule = async (id: string, data: any) => {
    loading.value = true
    error.value = null
    try {
      const result = await $fetch(`/api/business-rules/${id}`, { method: 'PUT', body: data })
      await fetchBusinessRules()
      return result
    } catch (e: any) {
      error.value = e.message
      return null
    } finally {
      loading.value = false
    }
  }

  const deleteBusinessRule = async (id: string) => {
    loading.value = true
    error.value = null
    try {
      await $fetch(`/api/business-rules/${id}`, { method: 'DELETE' })
      await fetchBusinessRules()
      return true
    } catch (e: any) {
      error.value = e.message
      return false
    } finally {
      loading.value = false
    }
  }

  const sortRules = (rules: any[]) => {
    return [...rules].sort((a, b) => {
      if (a.job_function_name < b.job_function_name) return -1
      if (a.job_function_name > b.job_function_name) return 1
      if (b.priority !== a.priority) return b.priority - a.priority
      return a.time_slot_start.localeCompare(b.time_slot_start)
    })
  }

  return {
    businessRules,
    rulesByJobFunction,
    loading,
    error,
    fetchBusinessRules,
    createBusinessRule,
    updateBusinessRule,
    deleteBusinessRule,
    sortRules,
  }
}
