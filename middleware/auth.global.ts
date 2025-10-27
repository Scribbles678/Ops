export default defineNuxtRouteMiddleware((to, from) => {
  // Check if user is authenticated
  const isAuthenticated = useCookie('auth-token', {
    default: () => null,
    maxAge: 60 * 60 * 24 * 7 // 7 days
  })

  // If not authenticated and not on login page, redirect to login
  if (!isAuthenticated.value && to.path !== '/login') {
    return navigateTo('/login')
  }
})
