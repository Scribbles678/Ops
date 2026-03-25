export const useStaffingTargets = () => {
  const targets = ref<any[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  const targetsByFunction = computed(() => {
    const map: Record<string, any[]> = {}
    for (const t of targets.value) {
      const key = t.job_function_id
      if (!map[key]) map[key] = []
      map[key].push(t)
    }
    return map
  })

  const fetchTargets = async () => {
    loading.value = true
    error.value = null
    try {
      targets.value = await $fetch<any[]>('/api/staffing-targets')
      return targets.value
    } catch (e: any) {
      error.value = e.message
      return []
    } finally {
      loading.value = false
    }
  }

  const saveTargets = async (items: { job_function_id: string; hour_start: string; headcount: number }[]) => {
    loading.value = true
    error.value = null
    try {
      const result = await $fetch('/api/staffing-targets', { method: 'POST', body: { items } })
      await fetchTargets()
      return result
    } catch (e: any) {
      error.value = e.message
      return null
    } finally {
      loading.value = false
    }
  }

  const deleteTarget = async (id: string) => {
    loading.value = true
    error.value = null
    try {
      await $fetch(`/api/staffing-targets/${id}`, { method: 'DELETE' })
      await fetchTargets()
      return true
    } catch (e: any) {
      error.value = e.message
      return false
    } finally {
      loading.value = false
    }
  }

  return {
    targets,
    targetsByFunction,
    loading,
    error,
    fetchTargets,
    saveTargets,
    deleteTarget,
  }
}
