export const useSchedule = () => {
  const { $supabase } = useNuxtApp()
  
  const scheduleAssignments = ref([])
  const shifts = ref([])
  const dailyTargets = ref([])
  const loading = ref(false)
  const error = ref(null)

  const fetchShifts = async () => {
    loading.value = true
    error.value = null
    
    try {
      const { data, error: fetchError } = await $supabase
        .from('shifts')
        .select('*')
        .eq('is_active', true)
        .order('start_time', { ascending: true })
      
      if (fetchError) throw fetchError
      
      shifts.value = data
      return data
    } catch (e) {
      error.value = e.message
      console.error('Error fetching shifts:', e)
      return []
    } finally {
      loading.value = false
    }
  }

  const createShift = async (shiftData) => {
    loading.value = true
    error.value = null
    
    try {
      const { data, error: createError } = await $supabase
        .from('shifts')
        .insert([shiftData])
        .select()
      
      if (createError) throw createError
      
      await fetchShifts()
      return data[0]
    } catch (e) {
      error.value = e.message
      console.error('Error creating shift:', e)
      return null
    } finally {
      loading.value = false
    }
  }

  const updateShift = async (id, shiftData) => {
    loading.value = true
    error.value = null
    
    try {
      const { data, error: updateError } = await $supabase
        .from('shifts')
        .update(shiftData)
        .eq('id', id)
        .select()
      
      if (updateError) throw updateError
      
      await fetchShifts()
      return data[0]
    } catch (e) {
      error.value = e.message
      console.error('Error updating shift:', e)
      return null
    } finally {
      loading.value = false
    }
  }

  const deleteShift = async (id) => {
    loading.value = true
    error.value = null
    
    try {
      const { error: deleteError } = await $supabase
        .from('shifts')
        .delete()
        .eq('id', id)
      
      if (deleteError) throw deleteError
      
      await fetchShifts()
      return true
    } catch (e) {
      error.value = e.message
      console.error('Error deleting shift:', e)
      return false
    } finally {
      loading.value = false
    }
  }

  const fetchScheduleForDate = async (date) => {
    loading.value = true
    error.value = null
    
    try {
      const { data, error: fetchError } = await $supabase
        .from('schedule_assignments')
        .select(`
          *,
          employee:employees(*),
          job_function:job_functions(*),
          shift:shifts(*)
        `)
        .eq('schedule_date', date)
        .order('start_time', { ascending: true })
      
      if (fetchError) throw fetchError
      
      scheduleAssignments.value = data
      return data
    } catch (e) {
      error.value = e.message
      console.error('Error fetching schedule:', e)
      return []
    } finally {
      loading.value = false
    }
  }

  const createAssignment = async (assignmentData) => {
    loading.value = true
    error.value = null
    
    try {
      const { data, error: createError } = await $supabase
        .from('schedule_assignments')
        .insert([assignmentData])
        .select()
      
      if (createError) throw createError
      
      return data[0]
    } catch (e) {
      error.value = e.message
      console.error('Error creating assignment:', e)
      return null
    } finally {
      loading.value = false
    }
  }

  const updateAssignment = async (id, assignmentData) => {
    loading.value = true
    error.value = null
    
    try {
      const { data, error: updateError } = await $supabase
        .from('schedule_assignments')
        .update(assignmentData)
        .eq('id', id)
        .select()
      
      if (updateError) throw updateError
      
      return data[0]
    } catch (e) {
      error.value = e.message
      console.error('Error updating assignment:', e)
      return null
    } finally {
      loading.value = false
    }
  }

  const deleteAssignment = async (id) => {
    loading.value = true
    error.value = null
    
    try {
      const { error: deleteError } = await $supabase
        .from('schedule_assignments')
        .delete()
        .eq('id', id)
      
      if (deleteError) throw deleteError
      
      return true
    } catch (e) {
      error.value = e.message
      console.error('Error deleting assignment:', e)
      return false
    } finally {
      loading.value = false
    }
  }

  const copySchedule = async (fromDate, toDate) => {
    loading.value = true
    error.value = null
    
    try {
      // Fetch source schedule assignments
      // Note: Only job function assignments are copied from schedule_assignments table.
      // PTO records (pto_days table) and shift swaps (shift_swaps table) are NOT copied,
      // as they are date-specific and stored in separate tables.
      const { data: sourceData, error: fetchError } = await $supabase
        .from('schedule_assignments')
        .select('*')
        .eq('schedule_date', fromDate)
      
      if (fetchError) throw fetchError
      
      if (!sourceData || sourceData.length === 0) {
        return true // No assignments to copy
      }
      
      // Create new assignments with new date
      // Only copying actual job function assignments, not PTO or shift swap data
      const newAssignments = sourceData
        .filter(assignment => {
          // Ensure we have required fields
          return assignment.employee_id && 
                 assignment.job_function_id && 
                 assignment.shift_id &&
                 assignment.start_time &&
                 assignment.end_time
        })
        .map(assignment => ({
          employee_id: assignment.employee_id,
          job_function_id: assignment.job_function_id,
          shift_id: assignment.shift_id,
          schedule_date: toDate,
          assignment_order: assignment.assignment_order,
          start_time: assignment.start_time,
          end_time: assignment.end_time
        }))
      
      if (newAssignments.length > 0) {
        const { error: insertError } = await $supabase
          .from('schedule_assignments')
          .insert(newAssignments)
        
        if (insertError) throw insertError
      }
      
      return true
    } catch (e) {
      error.value = e.message
      console.error('Error copying schedule:', e)
      return false
    } finally {
      loading.value = false
    }
  }

  const fetchDailyTargets = async (date) => {
    try {
      const { data, error: fetchError } = await $supabase
        .from('daily_targets')
        .select('*, job_function:job_functions(*)')
        .eq('schedule_date', date)
      
      if (fetchError) throw fetchError
      
      dailyTargets.value = data
      return data
    } catch (e) {
      console.error('Error fetching daily targets:', e)
      return []
    }
  }

  const upsertDailyTarget = async (targetData) => {
    loading.value = true
    error.value = null
    
    try {
      const { data, error: upsertError } = await $supabase
        .from('daily_targets')
        .upsert(targetData)
        .select()
      
      if (upsertError) throw upsertError
      
      return data[0]
    } catch (e) {
      error.value = e.message
      console.error('Error upserting daily target:', e)
      return null
    } finally {
      loading.value = false
    }
  }

  // Cleanup functions
  const runCleanup = async () => {
    loading.value = true
    error.value = null
    
    try {
      const { data, error: cleanupError } = await $supabase
        .rpc('cleanup_old_schedules_with_logging')
      
      if (cleanupError) throw cleanupError
      
      return data[0]
    } catch (e) {
      error.value = e.message
      console.error('Error running cleanup:', e)
      return null
    } finally {
      loading.value = false
    }
  }

  const getCleanupStats = async () => {
    try {
      const { data, error: statsError } = await $supabase
        .rpc('get_cleanup_stats')
      
      if (statsError) throw statsError
      
      return data[0]
    } catch (e) {
      console.error('Error getting cleanup stats:', e)
      return null
    }
  }

  const getCleanupLog = async (limit = 10) => {
    try {
      const { data, error: logError } = await $supabase
        .from('cleanup_log')
        .select('*')
        .order('cleanup_date', { ascending: false })
        .limit(limit)
      
      if (logError) throw logError
      
      return data
    } catch (e) {
      console.error('Error getting cleanup log:', e)
      return []
    }
  }

  const getCleanupStatus = async () => {
    try {
      const { data, error: statusError } = await $supabase
        .from('cleanup_status')
        .select('*')
      
      if (statusError) throw statusError
      
      return data
    } catch (e) {
      console.error('Error getting cleanup status:', e)
      return []
    }
  }

  // Fetch old schedules for export (older than 7 days)
  const fetchOldSchedulesForExport = async () => {
    try {
      const cutoffDate = new Date()
      cutoffDate.setDate(cutoffDate.getDate() - 7)
      const cutoffDateString = cutoffDate.toISOString().split('T')[0] // YYYY-MM-DD
      
      const { data, error: fetchError } = await $supabase
        .from('schedule_assignments')
        .select(`
          *,
          employee:employees(first_name, last_name),
          job_function:job_functions(name),
          shift:shifts(name)
        `)
        .lt('schedule_date', cutoffDateString)
        .order('schedule_date', { ascending: true })
        .order('start_time', { ascending: true })
      
      if (fetchError) throw fetchError
      
      return data || []
    } catch (e) {
      console.error('Error fetching old schedules for export:', e)
      return []
    }
  }

  return {
    scheduleAssignments,
    shifts,
    dailyTargets,
    loading,
    error,
    fetchShifts,
    createShift,
    updateShift,
    deleteShift,
    fetchScheduleForDate,
    createAssignment,
    updateAssignment,
    deleteAssignment,
    copySchedule,
    fetchDailyTargets,
    upsertDailyTarget,
    runCleanup,
    getCleanupStats,
    getCleanupLog,
    getCleanupStatus,
    fetchOldSchedulesForExport
  }
}

