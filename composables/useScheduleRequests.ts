export interface ScheduleRequest {
  id: string
  employee_id: string
  team_id: string | null
  request_type: 'leave_early' | 'pto_full_day' | 'pto_partial' | 'shift_swap'
  status: 'pending' | 'approved' | 'rejected'
  request_date: string
  start_time: string | null
  end_time: string | null
  original_shift_id: string | null
  requested_shift_id: string | null
  approval_rule_results: Record<string, boolean> | null
  approved_by: string | null
  admin_override: boolean
  rejection_reason: string | null
  created_pto_id: string | null
  created_swap_id: string | null
  notes: string | null
  submitted_by: string | null
  created_at: string
  updated_at: string
  employee_name?: string
}

export interface SubmitResult {
  request: ScheduleRequest
  ruleResults: Record<string, boolean>
  status: 'approved' | 'rejected'
}

export interface RequestFilters {
  status?: string
  date_from?: string
  date_to?: string
  employee_id?: string
}

export const useScheduleRequests = () => {
  const requests = ref<ScheduleRequest[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  const fetchRequests = async (filters: RequestFilters = {}) => {
    loading.value = true
    error.value = null
    try {
      const params = new URLSearchParams()
      if (filters.status) params.set('status', filters.status)
      if (filters.date_from) params.set('date_from', filters.date_from)
      if (filters.date_to) params.set('date_to', filters.date_to)
      if (filters.employee_id) params.set('employee_id', filters.employee_id)

      const qs = params.toString()
      const url = '/api/schedule-requests' + (qs ? `?${qs}` : '')
      requests.value = await $fetch<ScheduleRequest[]>(url)
      return requests.value
    } catch (e: any) {
      error.value = e.data?.message || e.message
      return []
    } finally {
      loading.value = false
    }
  }

  const submitRequest = async (data: {
    employee_id: string
    request_type: string
    request_date: string
    start_time?: string | null
    end_time?: string | null
    original_shift_id?: string | null
    requested_shift_id?: string | null
    notes?: string | null
  }): Promise<SubmitResult> => {
    loading.value = true
    error.value = null
    try {
      const result = await $fetch<SubmitResult>('/api/schedule-requests', {
        method: 'POST',
        body: data,
      })
      return result
    } catch (e: any) {
      error.value = e.data?.message || e.message
      throw e
    } finally {
      loading.value = false
    }
  }

  const overrideRequest = async (id: string, data: { status: string; rejection_reason?: string }) => {
    loading.value = true
    error.value = null
    try {
      const result = await $fetch<ScheduleRequest>(`/api/schedule-requests/${id}`, {
        method: 'PUT',
        body: data,
      })
      return result
    } catch (e: any) {
      error.value = e.data?.message || e.message
      throw e
    } finally {
      loading.value = false
    }
  }

  const cancelRequest = async (id: string) => {
    loading.value = true
    error.value = null
    try {
      await $fetch(`/api/schedule-requests/${id}`, { method: 'DELETE' })
    } catch (e: any) {
      error.value = e.data?.message || e.message
      throw e
    } finally {
      loading.value = false
    }
  }

  return {
    requests,
    loading,
    error,
    fetchRequests,
    submitRequest,
    overrideRequest,
    cancelRequest,
  }
}
