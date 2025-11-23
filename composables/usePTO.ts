export const usePTO = () => {
  const supabase = useSupabaseClient()
  const { getCurrentTeamId, isSuperAdmin } = useTeam()

  const pto = ref<any[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  const fetchPTOForDate = async (date: string) => {
    try {
      loading.value = true
      error.value = null
      
      // Get team_id filter (null for super admins = see all)
      const teamId = isSuperAdmin.value ? null : await getCurrentTeamId()
      
      let query = supabase
        .from('pto_days')
        .select('*, employee:employees(*)')
        .eq('pto_date', date)
      
      // Filter by team_id if not super admin
      if (teamId) {
        query = query.eq('team_id', teamId)
      }
      
      const { data, error: err } = await query
      if (err) throw err
      pto.value = data || []
      return pto.value
    } catch (e: any) {
      error.value = e.message
      return []
    } finally {
      loading.value = false
    }
  }

  const createPTO = async (record: {
    employee_id: string
    pto_date: string
    start_time?: string | null
    end_time?: string | null
    pto_type?: string | null
    notes?: string | null
    team_id?: string | null
  }) => {
    try {
      loading.value = true
      error.value = null
      
      // Get team_id for new PTO record
      const teamId = isSuperAdmin.value ? record.team_id : await getCurrentTeamId()
      if (!teamId && !isSuperAdmin.value) {
        throw new Error('Unable to determine team. Please contact administrator.')
      }
      
      const { error: err } = await supabase
        .from('pto_days')
        .insert([{ ...record, team_id: teamId }])
      if (err) throw err
      return true
    } catch (e: any) {
      error.value = e.message
      return false
    } finally {
      loading.value = false
    }
  }

  const deletePTO = async (id: string) => {
    try {
      loading.value = true
      error.value = null
      const { error: err } = await supabase.from('pto_days').delete().eq('id', id)
      if (err) throw err
      return true
    } catch (e: any) {
      error.value = e.message
      return false
    } finally {
      loading.value = false
    }
  }

  const ptoByEmployeeId = computed<Record<string, any[]>>(() => {
    const map: Record<string, any[]> = {}
    ;(pto.value || []).forEach((r: any) => {
      const id = r.employee_id
      if (!map[id]) map[id] = []
      map[id].push(r)
    })
    return map
  })

  return {
    pto,
    loading,
    error,
    ptoByEmployeeId,
    fetchPTOForDate,
    createPTO,
    deletePTO
  }
}


