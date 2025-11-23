// Rate limiting middleware for API routes
// Protects against API abuse and DoS attacks

interface RateLimitStore {
  [key: string]: {
    count: number
    resetTime: number
  }
}

// In-memory store (for serverless, consider using a shared cache in production)
const rateLimitStore: RateLimitStore = {}

// Rate limit configuration
const RATE_LIMIT_CONFIG = {
  // General API routes: 100 requests per minute per IP
  default: {
    maxRequests: 100,
    windowMs: 60 * 1000 // 1 minute
  },
  // Admin routes: 50 requests per minute per IP (more restrictive)
  admin: {
    maxRequests: 50,
    windowMs: 60 * 1000 // 1 minute
  },
  // User creation: 5 requests per hour per IP (very restrictive)
  userCreation: {
    maxRequests: 5,
    windowMs: 60 * 60 * 1000 // 1 hour
  },
  // Password reset: 3 requests per hour per IP (very restrictive)
  passwordReset: {
    maxRequests: 3,
    windowMs: 60 * 60 * 1000 // 1 hour
  }
}

export default defineEventHandler(async (event) => {
  // Only apply rate limiting to API routes
  if (!event.path.startsWith('/api/')) {
    return // Skip rate limiting for non-API routes
  }

  // Get client IP address
  const clientIP = getClientIP(event) || 'unknown'
  
  // Determine which rate limit to apply based on route
  let config = RATE_LIMIT_CONFIG.default
  
  if (event.path.includes('/admin/users/create')) {
    config = RATE_LIMIT_CONFIG.userCreation
  } else if (event.path.includes('/admin/users/reset-password')) {
    config = RATE_LIMIT_CONFIG.passwordReset
  } else if (event.path.includes('/admin/')) {
    config = RATE_LIMIT_CONFIG.admin
  }

  // Create a unique key for this IP and route type
  const key = `${clientIP}:${event.path.split('/')[2] || 'default'}` // Use route prefix as part of key
  
  const now = Date.now()
  const record = rateLimitStore[key]

  // Check if record exists and is still valid
  if (record && now < record.resetTime) {
    // Increment count
    record.count++
    
    // Check if limit exceeded
    if (record.count > config.maxRequests) {
      // Rate limit exceeded
      throw createError({
        statusCode: 429,
        statusMessage: 'Too Many Requests',
        message: `Rate limit exceeded. Maximum ${config.maxRequests} requests per ${config.windowMs / 1000} seconds. Please try again later.`
      })
    }
  } else {
    // Create new record or reset expired one
    rateLimitStore[key] = {
      count: 1,
      resetTime: now + config.windowMs
    }
  }

  // Clean up old entries periodically (every 5 minutes)
  // This prevents memory leaks in long-running instances
  if (Math.random() < 0.01) { // 1% chance to run cleanup
    const cutoff = now - (5 * 60 * 1000) // 5 minutes ago
    Object.keys(rateLimitStore).forEach(k => {
      if (rateLimitStore[k].resetTime < cutoff) {
        delete rateLimitStore[k]
      }
    })
  }

  // Add rate limit headers to response
  const currentRecord = rateLimitStore[key]
  if (currentRecord) {
    setHeader(event, 'X-RateLimit-Limit', config.maxRequests.toString())
    setHeader(event, 'X-RateLimit-Remaining', Math.max(0, config.maxRequests - currentRecord.count).toString())
    setHeader(event, 'X-RateLimit-Reset', new Date(currentRecord.resetTime).toISOString())
  }
})

