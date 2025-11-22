/**
 * Auth composable using Supabase Auth
 * Wraps Supabase auth methods for convenience
 */
export const useAuth = () => {
  const supabase = useSupabaseClient()
  const user = useSupabaseUser()
  
  const isAuthenticated = computed(() => !!user.value)
  
  const login = async (email: string, password: string) => {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password
    })
    if (error) throw error
    return data
  }
  
  const logout = async () => {
    await supabase.auth.signOut()
    await navigateTo('/login')
  }
  
  return {
    user,
    isAuthenticated,
    login,
    logout
  }
}
