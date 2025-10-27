export const useAuth = () => {
  const authToken = useCookie('auth-token')
  
  const isAuthenticated = computed(() => !!authToken.value)
  
  const login = (token: string) => {
    authToken.value = token
  }
  
  const logout = async () => {
    authToken.value = null
    await navigateTo('/login')
  }
  
  return {
    isAuthenticated,
    login,
    logout
  }
}
