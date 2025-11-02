import { ref } from 'vue'
import { useNuxtApp } from '#app'

export const usePreferredAssignments = () => {
  const { $supabase } = useNuxtApp()
  const preferredAssignments = ref<any[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  // Fetch all preferred assignments
  const fetchPreferredAssignments = async () => {
    loading.value = true
    error.value = null
    try {
      const { data, error: fetchError } = await $supabase
        .from('preferred_assignments')
        .select(`
          *,
          employee:employees(id, first_name, last_name),
          job_function:job_functions(id, name)
        `)
        .order('priority', { ascending: false })
        .order('created_at', { ascending: true })

      if (fetchError) throw fetchError
      preferredAssignments.value = data || []
    } catch (e: any) {
      error.value = e.message
      console.error('Error fetching preferred assignments:', e.message)
    } finally {
      loading.value = false
    }
  }

  // Get preferred assignments for a specific employee
  const getPreferredAssignmentsForEmployee = (employeeId: string) => {
    return preferredAssignments.value.filter(pa => pa.employee_id === employeeId)
  }

  // Get preferred assignments for a specific job function
  const getPreferredAssignmentsForJobFunction = (jobFunctionId: string) => {
    return preferredAssignments.value.filter(pa => pa.job_function_id === jobFunctionId)
  }

  // Get preferred assignment mapping (employee_id -> job_function_id -> preferred assignment)
  const getPreferredAssignmentsMap = () => {
    const map: Record<string, Record<string, any>> = {}
    preferredAssignments.value.forEach(pa => {
      if (!map[pa.employee_id]) {
        map[pa.employee_id] = {}
      }
      map[pa.employee_id][pa.job_function_id] = pa
    })
    return map
  }

  // Check if an employee has a preferred/required assignment for a job function
  const isPreferredAssignment = (employeeId: string, jobFunctionId: string) => {
    return preferredAssignments.value.some(
      pa => pa.employee_id === employeeId && pa.job_function_id === jobFunctionId
    )
  }

  // Check if an assignment is required (not just preferred)
  const isRequiredAssignment = (employeeId: string, jobFunctionId: string) => {
    const pa = preferredAssignments.value.find(
      p => p.employee_id === employeeId && p.job_function_id === jobFunctionId
    )
    return pa?.is_required === true
  }

  // Get priority for an assignment (higher = should be assigned first)
  const getAssignmentPriority = (employeeId: string, jobFunctionId: string) => {
    const pa = preferredAssignments.value.find(
      p => p.employee_id === employeeId && p.job_function_id === jobFunctionId
    )
    return pa?.priority || 0
  }

  // Create a preferred assignment
  const createPreferredAssignment = async (assignmentData: {
    employee_id: string
    job_function_id: string
    is_required?: boolean
    priority?: number
    notes?: string
  }) => {
    try {
      const { data, error: insertError } = await $supabase
        .from('preferred_assignments')
        .insert(assignmentData)
        .select()

      if (insertError) throw insertError
      await fetchPreferredAssignments() // Refresh list
      return data[0]
    } catch (e: any) {
      error.value = e.message
      console.error('Error creating preferred assignment:', e.message)
      throw e
    }
  }

  // Update a preferred assignment
  const updatePreferredAssignment = async (id: string, updates: {
    is_required?: boolean
    priority?: number
    notes?: string
  }) => {
    try {
      const { data, error: updateError } = await $supabase
        .from('preferred_assignments')
        .update(updates)
        .eq('id', id)
        .select()

      if (updateError) throw updateError
      await fetchPreferredAssignments() // Refresh list
      return data[0]
    } catch (e: any) {
      error.value = e.message
      console.error('Error updating preferred assignment:', e.message)
      throw e
    }
  }

  // Delete a preferred assignment
  const deletePreferredAssignment = async (id: string) => {
    try {
      const { error: deleteError } = await $supabase
        .from('preferred_assignments')
        .delete()
        .eq('id', id)

      if (deleteError) throw deleteError
      await fetchPreferredAssignments() // Refresh list
    } catch (e: any) {
      error.value = e.message
      console.error('Error deleting preferred assignment:', e.message)
      throw e
    }
  }

  return {
    preferredAssignments,
    loading,
    error,
    fetchPreferredAssignments,
    getPreferredAssignmentsForEmployee,
    getPreferredAssignmentsForJobFunction,
    getPreferredAssignmentsMap,
    isPreferredAssignment,
    isRequiredAssignment,
    getAssignmentPriority,
    createPreferredAssignment,
    updatePreferredAssignment,
    deletePreferredAssignment
  }
}

