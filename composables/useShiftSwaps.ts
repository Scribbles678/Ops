export const useShiftSwaps = () => {
  const shiftSwaps = ref<any[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  const swapByEmployeeId = computed(() => {
    const map: Record<string, any> = {}
    for (const swap of shiftSwaps.value) {
      map[swap.employee_id] = swap
    }
    return map
  })

  const fetchShiftSwapsForDate = async (date: string) => {
    loading.value = true
    error.value = null
    try {
      shiftSwaps.value = await $fetch<any[]>(`/api/shift-swaps/${date}`)
      return shiftSwaps.value
    } catch (e: any) {
      error.value = e.message
      return []
    } finally {
      loading.value = false
    }
  }

  const createShiftSwap = async (swapData: any) => {
    loading.value = true
    error.value = null
    try {
      return await $fetch('/api/shift-swaps', { method: 'POST', body: swapData })
    } catch (e: any) {
      error.value = e.message
      return null
    } finally {
      loading.value = false
    }
  }

  const deleteShiftSwap = async (id: string) => {
    loading.value = true
    error.value = null
    try {
      await $fetch(`/api/shift-swaps/${id}`, { method: 'DELETE' })
      return true
    } catch (e: any) {
      error.value = e.message
      return false
    } finally {
      loading.value = false
    }
  }

  const getSwapForEmployee = (employeeId: string) => swapByEmployeeId.value[employeeId] ?? null

  return {
    shiftSwaps,
    swapByEmployeeId,
    loading,
    error,
    fetchShiftSwapsForDate,
    createShiftSwap,
    deleteShiftSwap,
    getSwapForEmployee,
  }
}
