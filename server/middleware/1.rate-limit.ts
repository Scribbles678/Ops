// Rate limiting middleware for API routes
// Protects against API abuse and DoS attacks
//
// Named "1." so it runs before auth.ts (Nitro runs server middleware in filename
// order): a flood is throttled before auth.ts looks the caller up in the database.

import type { H3Event } from 'h3'

/**
 * The address to count against. X-Real-IP is set by the ingress (nginx overwrites
 * whatever the browser sent). X-Forwarded-For is only trustworthy at its END — the
 * hop the ingress appended — because a browser can put anything at its start; the
 * first entry used to be taken, which let a caller pick their own bucket.
 */
function getClientIP(event: H3Event): string | undefined {
  const xRealIp = getRequestHeader(event, 'x-real-ip')
  if (xRealIp) return xRealIp.trim()
  const xForwardedFor = getRequestHeader(event, 'x-forwarded-for')
  if (xForwardedFor) return xForwardedFor.split(',').pop()!.trim()
  return event.node?.req?.socket?.remoteAddress
}

interface RateLimitStore {
  [key: string]: {
    count: number
    resetTime: number
  }
}

// In-memory store (for serverless, consider using a shared cache in production)
const rateLimitStore: RateLimitStore = {}

// Rate limit configuration. Remember a whole site often reaches the app from ONE
// address (its network's egress), so these are per site as much as per person.
const RATE_LIMIT_CONFIG = {
  // General API routes: 200 requests per minute per IP, counted separately for each
  // area (/api/employees, /api/schedule, …)
  default: {
    maxRequests: 200,
    windowMs: 60 * 1000 // 1 minute
  },
  // Admin routes: 100 requests per minute per IP (settings page loads teams + users)
  admin: {
    maxRequests: 100,
    windowMs: 60 * 1000 // 1 minute
  },
  // Sign-in attempts: slows password guessing without getting in the way of a
  // shift's worth of people signing in from one site.
  login: {
    maxRequests: 30,
    windowMs: 60 * 1000 // 1 minute
  },
  // User creation (super admin only). Was 5 an hour, which stopped onboarding a
  // new site after its fifth account.
  userCreation: {
    maxRequests: 60,
    windowMs: 60 * 60 * 1000 // 1 hour
  },
  // A super admin resetting someone's password — an admin chore, not a public door.
  adminPasswordReset: {
    maxRequests: 60,
    windowMs: 60 * 60 * 1000 // 1 hour
  },
  // Public "forgot password" / reset-link use: 10 per hour per IP (per site network).
  passwordReset: {
    maxRequests: 10,
    windowMs: 60 * 60 * 1000 // 1 hour
  },
  // Kiosk "check my requests" by UPI: a soft gate, so keep guessing slow.
  // 20 a minute is plenty for real use (a typo or two) and too slow to walk
  // through employee numbers.
  upiLookup: {
    maxRequests: 20,
    windowMs: 60 * 1000 // 1 minute
  }
}
type LimitName = keyof typeof RATE_LIMIT_CONFIG

export default defineEventHandler(async (event) => {
  // Only apply rate limiting to API routes
  if (!event.path.startsWith('/api/')) {
    return // Skip rate limiting for non-API routes
  }

  // Get client IP address
  const clientIP = getClientIP(event) || 'unknown'

  // Determine which rate limit to apply based on route
  let limit: LimitName = 'default'
  if (event.path.includes('/admin/users/create')) {
    limit = 'userCreation'
  } else if (event.path.includes('/admin/users/reset-password')) {
    limit = 'adminPasswordReset'
  } else if (event.path.includes('/auth/forgot-password') || event.path.includes('/auth/reset-password')) {
    limit = 'passwordReset'
  } else if (event.path.startsWith('/api/auth/login')) {
    limit = 'login'
  } else if (event.path.includes('/admin/')) {
    limit = 'admin'
  } else if (event.path.includes('/schedule-requests/lookup')) {
    limit = 'upiLookup'
  }
  const config = RATE_LIMIT_CONFIG[limit]

  // Every limit keeps its own count. They used to share one per path segment, so
  // loading the user list used up the "create user" allowance, and a few sign-ins
  // used up "forgot password". The two broad limits are still counted per area.
  const area = limit === 'default' || limit === 'admin' ? `:${event.path.split('/')[2] || 'default'}` : ''
  const key = `${clientIP}:${limit}${area}`

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
