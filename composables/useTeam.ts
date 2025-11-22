/**
 * Team management composable
 * Handles team isolation and super admin checks
 */
export const useTeam = () => {
  const supabase = useSupabaseClient()
  const user = useSupabaseUser()
  
  const currentTeam = ref<any>(null)
  const isSuperAdmin = ref(false)
  const loading = ref(false)
  
  /**
   * Get current user's team
   */
  const fetchCurrentTeam = async () => {
    if (!user.value) {
      currentTeam.value = null
      return null
    }
    
    loading.value = true
    try {
      const { data, error } = await supabase
        .from('user_profiles')
        .select('*, teams(*)')
        .eq('id', user.value.id)
        .single()
      
      if (error) throw error
      
      currentTeam.value = data?.teams
      isSuperAdmin.value = data?.is_super_admin || false
      
      return data?.teams
    } catch (error) {
      console.error('Error fetching team:', error)
      return null
    } finally {
      loading.value = false
    }
  }
  
  /**
   * Get current user's team_id
   */
  const getCurrentTeamId = async (): Promise<string | null> => {
    if (!user.value) return null
    
    // If super admin, return null (can access all teams)
    if (isSuperAdmin.value) return null
    
    try {
      const { data, error } = await supabase
        .from('user_profiles')
        .select('team_id')
        .eq('id', user.value.id)
        .single()
      
      if (error) throw error
      
      return data?.team_id || null
    } catch (error) {
      console.error('Error fetching team_id:', error)
      return null
    }
  }
  
  /**
   * Check if current user is super admin
   */
  const checkIsSuperAdmin = async (): Promise<boolean> => {
    if (!user.value) return false
    
    try {
      const { data, error } = await supabase
        .from('user_profiles')
        .select('is_super_admin')
        .eq('id', user.value.id)
        .single()
      
      if (error) throw error
      
      isSuperAdmin.value = data?.is_super_admin || false
      return isSuperAdmin.value
    } catch (error) {
      console.error('Error checking super admin:', error)
      return false
    }
  }
  
  /**
   * Get all teams (super admin only)
   */
  const fetchAllTeams = async () => {
    if (!isSuperAdmin.value) {
      throw new Error('Only super admins can view all teams')
    }
    
    const { data, error } = await supabase
      .from('teams')
      .select('*')
      .order('name')
    
    if (error) throw error
    return data || []
  }
  
  /**
   * Create a new team (super admin only)
   */
  const createTeam = async (name: string) => {
    if (!isSuperAdmin.value) {
      throw new Error('Only super admins can create teams')
    }
    
    const { data, error } = await supabase
      .from('teams')
      .insert([{ name }])
      .select()
      .single()
    
    if (error) throw error
    return data
  }
  
  /**
   * Update team (super admin only)
   */
  const updateTeam = async (teamId: string, updates: { name?: string }) => {
    if (!isSuperAdmin.value) {
      throw new Error('Only super admins can update teams')
    }
    
    const { data, error } = await supabase
      .from('teams')
      .update(updates)
      .eq('id', teamId)
      .select()
      .single()
    
    if (error) throw error
    return data
  }
  
  /**
   * Delete team (super admin only)
   */
  const deleteTeam = async (teamId: string) => {
    if (!isSuperAdmin.value) {
      throw new Error('Only super admins can delete teams')
    }
    
    const { error } = await supabase
      .from('teams')
      .delete()
      .eq('id', teamId)
    
    if (error) throw error
  }
  
  return {
    currentTeam,
    isSuperAdmin,
    loading,
    fetchCurrentTeam,
    getCurrentTeamId,
    checkIsSuperAdmin,
    fetchAllTeams,
    createTeam,
    updateTeam,
    deleteTeam
  }
}

