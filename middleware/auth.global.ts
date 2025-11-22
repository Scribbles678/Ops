export default defineNuxtRouteMiddleware((to) => {
  const user = useSupabaseUser()

  // Public routes that don't require authentication
  const publicRoutes = ['/login', '/display', '/reset-password']
  const isPublicRoute = publicRoutes.includes(to.path)

  // If user is logged in and trying to access login, redirect to home
  if (user.value && isPublicRoute && to.path === '/login') {
    return navigateTo('/')
  }

  // If user is not logged in and trying to access protected route, redirect to login
  if (!user.value && !isPublicRoute) {
    return navigateTo('/login')
  }
})
