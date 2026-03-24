export const usePTO = () => {
  const ptoRecords = ref<any[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  /** One array of PTO rows per employee (same shape the schedule UI expects). */
  const ptoByEmployeeId = computed(() => {
    const map: Record<string, any[]> = {}
    for (const record of ptoRecords.value) {
      const id = record.employee_id
      if (!id) continue
      if (!map[id]) map[id] = []
      map[id].push(record)
    }
    return map
  })

  const fetchPTOForDate = async (date: string) => {
    loading.value = true
    error.value = null
    try {
      ptoRecords.value = await $fetch<any[]>(`/api/pto/${date}`)
      return ptoRecords.value
    } catch (e: any) {
      error.value = e.message
      return []
    } finally {
      loading.value = false
    }
  }

  const createPTO = async (ptoData: any) => {
    loading.value = true
    error.value = null
    try {
      return await $fetch('/api/pto', { method: 'POST', body: ptoData })
    } catch (e: any) {
      error.value = e.message
      return null
    } finally {
      loading.value = false
    }
  }

  const deletePTO = async (id: string) => {
    loading.value = true
    error.value = null
    try {
      await $fetch(`/api/pto/${id}`, { method: 'DELETE' })
      return true
    } catch (e: any) {
      error.value = e.message
      return false
    } finally {
      loading.value = false
    }
  }

  return {
    ptoRecords,
    ptoByEmployeeId,
    loading,
    error,
    fetchPTOForDate,
    createPTO,
    deletePTO,
  }
}
