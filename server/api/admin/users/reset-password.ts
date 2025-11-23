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
  const { user_id, new_password } = body

  if (!user_id || !new_password) {
    throw createError({
      statusCode: 400,
      message: 'User ID and new password are required'
    })
  }

  if (new_password.length < 6) {
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
        message: 'Only super admins can reset passwords'
      })
    }

    // Update the user's password using admin API
    const { data: updateData, error: updateError } = await supabaseAdmin.auth.admin.updateUserById(
      user_id,
      { password: new_password }
    )

    if (updateError) {
      throw createError({
        statusCode: 400,
        message: updateError.message || 'Failed to reset password'
      })
    }

    return {
      success: true,
      message: 'Password reset successfully'
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
