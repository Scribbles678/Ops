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

  // Writes keep the server's own sentence ("Max Kangas already has time off on …")
  // in `error` so the page can show it; e.message is only "[POST] /api/pto: 409".
  const createPTO = async (ptoData: any) => {
    loading.value = true
    error.value = null
    try {
      return await $fetch<any>('/api/pto', { method: 'POST', body: ptoData })
    } catch (e: any) {
      error.value = e.data?.message || e.message
      return null
    } finally {
      loading.value = false
    }
  }

  /** Change a row in place, keeping its link to the request that created it. */
  const updatePTO = async (id: string, fields: { pto_type: string; start_time: string | null; end_time: string | null }) => {
    loading.value = true
    error.value = null
    try {
      return await $fetch<any>(`/api/pto/${id}`, { method: 'PUT', body: fields })
    } catch (e: any) {
      error.value = e.data?.message || e.message
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
      // Immediately remove from local state so UI updates even if re-fetch is cached
      ptoRecords.value = ptoRecords.value.filter(r => r.id !== id)
      return true
    } catch (e: any) {
      error.value = e.data?.message || e.message
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
    updatePTO,
    deletePTO,
  }
}
