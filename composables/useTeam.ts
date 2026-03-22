/**
 * Team management composable
 * Reads team data from the authenticated user (JWT) via useAuth().
 * Super admin status is determined by the server-side JWT payload.
 */
export const useTeam = () => {
  const { user, fetchCurrentUser } = useAuth()

  const currentTeam = ref<any>(null)
  const loading = ref(false)

  const isSuperAdmin = computed(() => user.value?.is_super_admin ?? false)

  const checkIsSuperAdmin = async () => {
    await fetchCurrentUser()
  }

  const fetchCurrentTeam = async () => {
    if (!user.value?.team_id) {
      currentTeam.value = null
      return null
    }
    loading.value = true
    try {
      const teams = await $fetch<any[]>('/api/teams')
      currentTeam.value = teams.find((t) => t.id === user.value?.team_id) ?? null
      return currentTeam.value
    } catch {
      currentTeam.value = null
      return null
    } finally {
      loading.value = false
    }
  }

  const fetchAllTeams = async (): Promise<any[]> => {
    if (!isSuperAdmin.value) throw new Error('Only super admins can view all teams')
    return $fetch<any[]>('/api/teams')
  }

  const createTeam = async (name: string) => {
    if (!isSuperAdmin.value) throw new Error('Only super admins can create teams')
    return $fetch('/api/teams', { method: 'POST', body: { name } })
  }

  const updateTeam = async (teamId: string, updates: { name?: string }) => {
    if (!isSuperAdmin.value) throw new Error('Only super admins can update teams')
    return $fetch(`/api/teams/${teamId}`, { method: 'PUT', body: updates })
  }

  const deleteTeam = async (teamId: string) => {
    if (!isSuperAdmin.value) throw new Error('Only super admins can delete teams')
    return $fetch(`/api/teams/${teamId}`, { method: 'DELETE' })
  }

  return {
    currentTeam,
    isSuperAdmin,
    checkIsSuperAdmin,
    loading,
    fetchCurrentTeam,
    fetchAllTeams,
    createTeam,
    updateTeam,
    deleteTeam,
  }
}
