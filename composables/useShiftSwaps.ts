import { ref, computed } from 'vue'

export const useShiftSwaps = () => {
  const supabase = useSupabaseClient()

  const shiftSwaps = ref<any[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  const fetchShiftSwapsForDate = async (date: string) => {
    try {
      loading.value = true
      error.value = null
      const { data, error: err } = await supabase
        .from('shift_swaps')
        .select('*, employee:employees(*), original_shift:shifts!shift_swaps_original_shift_id_fkey(*), swapped_shift:shifts!shift_swaps_swapped_shift_id_fkey(*)')
        .eq('swap_date', date)

      if (err) throw err
      shiftSwaps.value = data || []
      return shiftSwaps.value
    } catch (e: any) {
      error.value = e.message
      console.error('Error fetching shift swaps:', e)
      return []
    } finally {
      loading.value = false
    }
  }

  const createShiftSwap = async (record: {
    employee_id: string
    swap_date: string
    original_shift_id: string
    swapped_shift_id: string
    notes?: string | null
  }) => {
    try {
      loading.value = true
      error.value = null
      const { data, error: err } = await supabase
        .from('shift_swaps')
        .upsert([record], { onConflict: 'employee_id,swap_date' })
        .select()

      if (err) throw err
      
      // Refresh swaps for the date
      await fetchShiftSwapsForDate(record.swap_date)
      return data?.[0]
    } catch (e: any) {
      error.value = e.message
      console.error('Error creating shift swap:', e)
      throw e
    } finally {
      loading.value = false
    }
  }

  const deleteShiftSwap = async (id: string) => {
    try {
      loading.value = true
      error.value = null
      const { error: err } = await supabase
        .from('shift_swaps')
        .delete()
        .eq('id', id)

      if (err) throw err
      return true
    } catch (e: any) {
      error.value = e.message
      console.error('Error deleting shift swap:', e)
      return false
    } finally {
      loading.value = false
    }
  }

  const getSwapForEmployee = (employeeId: string, date: string) => {
    return shiftSwaps.value.find(
      swap => swap.employee_id === employeeId && swap.swap_date === date
    )
  }

  const swapByEmployeeId = computed<Record<string, any>>(() => {
    const map: Record<string, any> = {}
    ;(shiftSwaps.value || []).forEach((swap: any) => {
      map[swap.employee_id] = swap
    })
    return map
  })

  return {
    shiftSwaps,
    loading,
    error,
    swapByEmployeeId,
    fetchShiftSwapsForDate,
    createShiftSwap,
    deleteShiftSwap,
    getSwapForEmployee
  }
}

