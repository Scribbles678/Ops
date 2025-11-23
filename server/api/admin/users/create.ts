import { createClient } from '@supabase/supabase-js'

export default defineEventHandler(async (event) => {
  // Only allow POST requests
  if (event.method !== 'POST') {
    throw createError({
      statusCode: 405,
      message: 'Method not allowed'
    })
  }

  const config = useRuntimeConfig()
  const body = await readBody(event)

  // Validate required fields
  const { email, password, full_name, team_id, is_super_admin } = body

  if (!email || !password) {
    throw createError({
      statusCode: 400,
      message: 'Email and password are required'
    })
  }

  // Validate email format
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
  if (!emailRegex.test(email)) {
    throw createError({
      statusCode: 400,
      message: 'Invalid email format'
    })
  }

  if (password.length < 6) {
    throw createError({
      statusCode: 400,
      message: 'Password must be at least 6 characters'
    })
  }

  // Create service role client (server-side only)
  const supabaseAdmin = createClient(
    config.public.supabaseUrl,
    config.supabaseServiceRoleKey
  )

  try {
    // Check if user is super admin (verify from auth token)
    const authHeader = getHeader(event, 'authorization')
    if (!authHeader) {
      throw createError({
        statusCode: 401,
        message: 'Unauthorized'
      })
    }

    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token)

    if (userError || !user) {
      throw createError({
        statusCode: 401,
        message: 'Invalid authentication'
      })
    }

    // Check if user is super admin
    const { data: profile } = await supabaseAdmin
      .from('user_profiles')
      .select('is_super_admin')
      .eq('id', user.id)
      .single()

    if (!profile?.is_super_admin) {
      throw createError({
        statusCode: 403,
        message: 'Only super admins can create users'
      })
    }

    // Check if email already exists in auth
    const { data: existingAuth } = await supabaseAdmin.auth.admin.listUsers()
    const emailExists = existingAuth?.users?.some(u => u.email?.toLowerCase() === email.trim().toLowerCase())
    
    if (emailExists) {
      throw createError({
        statusCode: 400,
        message: 'Email already exists'
      })
    }

    // Create auth user with the provided email
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email: email.trim().toLowerCase(),
      password: password,
      email_confirm: true, // Auto-confirm (no email verification needed)
      user_metadata: {
        full_name: full_name || null
      }
    })

    if (authError) {
      throw createError({
        statusCode: 400,
        message: authError.message || 'Failed to create user'
      })
    }

    if (!authData.user) {
      throw createError({
        statusCode: 500,
        message: 'Failed to create user account'
      })
    }

    // Create user profile (username is derived from email for display)
    const username = email.split('@')[0] // Use part before @ as username
    const { data: profileData, error: profileError } = await supabaseAdmin
      .from('user_profiles')
      .insert({
        id: authData.user.id,
        username: username.trim().toLowerCase(),
        email: email.trim().toLowerCase(), // Store email for easy lookup
        full_name: full_name || null,
        team_id: team_id || null,
        is_super_admin: is_super_admin || false,
        is_active: true
      })
      .select()
      .single()

    if (profileError) {
      // If profile creation fails, delete the auth user
      await supabaseAdmin.auth.admin.deleteUser(authData.user.id)
      throw createError({
        statusCode: 500,
        message: profileError.message || 'Failed to create user profile'
      })
    }

    return {
      success: true,
      user: profileData
    }
  } catch (error: any) {
    if (error.statusCode) {
      throw error
    }
    throw createError({
      statusCode: 500,
      message: error.message || 'An unexpected error occurred'
    })
  }
})
