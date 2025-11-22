# Issue 4.1: Detailed Implementation Plan
## Supabase Authentication (Matching TradeFI Pattern)

**Status**: Ready to Implement  
**Pattern**: Using `@nuxtjs/supabase` module (same as TradeFI)  
**Approach**: Match TradeFI's implementation exactly

---

## Key Differences from Current Setup

**TradeFI Uses:**
- `@nuxtjs/supabase` Nuxt module
- `useSupabaseClient()` composable (provided by module)
- `useSupabaseUser()` composable (provided by module)
- `serverSupabaseUser()` for server-side (provided by module)
- Automatic auth state management

**Current Scheduling App Uses:**
- Custom plugin (`plugins/supabase.client.ts`)
- Manual client creation
- Custom auth composable

**Decision**: Install `@nuxtjs/supabase` module to match TradeFI pattern

---

## Implementation Steps

### Step 1: Install @nuxtjs/supabase Module

```bash
npm install @nuxtjs/supabase
```

**Files Modified:**
- `package.json` - Adds dependency

---

### Step 2: Update nuxt.config.ts

**Current:**
```typescript
modules: ['@nuxtjs/tailwindcss'],
runtimeConfig: {
  public: {
    supabaseUrl: process.env.SUPABASE_URL || '',
    supabaseAnonKey: process.env.SUPABASE_ANON_KEY || '',
    appPassword: process.env.APP_PASSWORD || 'operations2024'
  }
}
```

**New (matching TradeFI):**
```typescript
modules: [
  '@nuxtjs/tailwindcss',
  '@nuxtjs/supabase'
],
supabase: {
  redirect: false, // We'll handle redirects manually
  redirectOptions: {
    login: '/login',
    exclude: ['/login', '/display'] // Display mode might not need auth
  },
  url: process.env.SUPABASE_URL,
  key: process.env.SUPABASE_ANON_KEY,
},
runtimeConfig: {
  public: {
    supabaseUrl: process.env.SUPABASE_URL,
    supabaseKey: process.env.SUPABASE_ANON_KEY,
    // Remove appPassword - no longer needed
  }
}
```

**Files Modified:**
- `nuxt.config.ts`

---

### Step 3: Update Login Page

**Current:** `pages/login.vue` - Single password field, client-side check

**New (matching TradeFI pattern):**
- Email + Password fields
- Login and Sign Up toggle
- Use `useSupabaseClient()` from module
- Use `supabase.auth.signInWithPassword()`
- Use `supabase.auth.signUp()` for registration
- Error handling with user-friendly messages

**Key Code Pattern (from TradeFI):**
```typescript
const supabase = useSupabaseClient()

// Login
const { data, error } = await supabase.auth.signInWithPassword({
  email: email.value,
  password: password.value
})

// Sign Up
const { data, error } = await supabase.auth.signUp({
  email: email.value,
  password: password.value
})
```

**Files Modified:**
- `pages/login.vue` - Complete rewrite to match TradeFI pattern

**Questions:**
- Do you want sign-up enabled, or admin-only user creation?
- Should display mode require auth or be public?

---

### Step 4: Update Auth Middleware

**Current:** `middleware/auth.global.ts` - Checks cookie

**New (matching TradeFI):**
```typescript
export default defineNuxtRouteMiddleware((to) => {
  const user = useSupabaseUser()

  // Public routes that don't require authentication
  const publicRoutes = ['/login']
  const isPublicRoute = publicRoutes.includes(to.path)

  // If user is logged in and trying to access login, redirect to home
  if (user.value && isPublicRoute) {
    return navigateTo('/')
  }

  // If user is not logged in and trying to access protected route, redirect to login
  if (!user.value && !isPublicRoute) {
    return navigateTo('/login')
  }
})
```

**Files Modified:**
- `middleware/auth.global.ts`

**Considerations:**
- Display mode (`/display`) - Should it be public or require auth?
- If public, add to `publicRoutes` array

---

### Step 5: Update/Remove Auth Composable

**Current:** `composables/useAuth.ts` - Custom cookie-based auth

**Options:**
1. **Remove entirely** - Use `useSupabaseUser()` and `useSupabaseClient()` directly
2. **Keep as wrapper** - Wrap Supabase auth methods for convenience

**Recommendation:** Remove and use Supabase composables directly (matches TradeFI pattern)

**Files Modified:**
- `composables/useAuth.ts` - Delete or rewrite as wrapper

**If keeping as wrapper:**
```typescript
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
```

---

### Step 6: Remove/Update Supabase Plugin

**Current:** `plugins/supabase.client.ts` - Custom client creation

**Options:**
1. **Remove entirely** - Module handles this
2. **Keep for service role client** - If needed for admin operations

**Recommendation:** Remove if not needed, or keep only for service role client (like TradeFI does)

**Files Modified:**
- `plugins/supabase.client.ts` - Delete or update for service role only

**If keeping for service role (like TradeFI):**
```typescript
// Only needed if you need service role client for admin operations
// Otherwise, can be deleted
```

---

### Step 7: Update All Components Using Auth

**Search for:**
- `useAuth()` calls
- `isAuthenticated` checks
- `authToken` references

**Replace with:**
- `useSupabaseUser()` for user state
- `useSupabaseClient()` for Supabase operations
- `computed(() => !!user.value)` for isAuthenticated

**Files to Check:**
- All pages and components
- Any composables that check auth

---

### Step 8: Supabase Dashboard Setup

**Required Steps:**
1. Enable Authentication in Supabase dashboard
2. Configure email provider
3. Set email confirmation (OFF for dev, ON for production)
4. Create initial admin user(s) via dashboard or sign-up

**SQL Migration (if needed):**
- May need to add `user_id` columns to tables (for Issue 4.2)
- For now, just enable auth - RLS policies come in Issue 4.2

---

## File Changes Summary

### Files to Modify:
1. ✅ `package.json` - Add `@nuxtjs/supabase`
2. ✅ `nuxt.config.ts` - Add module, update config
3. ✅ `pages/login.vue` - Rewrite to match TradeFI pattern
4. ✅ `middleware/auth.global.ts` - Use `useSupabaseUser()`
5. ✅ `composables/useAuth.ts` - Delete or rewrite
6. ✅ `plugins/supabase.client.ts` - Delete or keep for service role

### Files to Review:
- All pages/components - Update auth checks
- Display mode - Decide if public or requires auth

### New Files:
- None (using existing Supabase infrastructure)

---

## Testing Checklist

After implementation:
- [ ] Can install `@nuxtjs/supabase` module
- [ ] Login page shows email + password fields
- [ ] Can sign up new user
- [ ] Can sign in existing user
- [ ] Session persists on page reload
- [ ] Logout works correctly
- [ ] Protected routes redirect to login
- [ ] Login page redirects if already authenticated
- [ ] Display mode works (if public) or requires auth (if protected)
- [ ] No console errors
- [ ] Works in development
- [ ] Works in production (Netlify)

---

## Questions to Answer Before Implementation

1. **Sign-up**: Should users be able to self-register, or admin-only?
   - If admin-only, we'll hide sign-up UI and create users via Supabase dashboard

2. **Display Mode**: Should `/display` require authentication?
   - **Option A**: Public (anyone can view) - Add to `publicRoutes`
   - **Option B**: Requires auth (only logged-in users) - Keep protected

3. **User Management**: How will you create initial users?
   - Via sign-up page?
   - Via Supabase dashboard?
   - Via admin interface (future)?

4. **Email Confirmation**: Enable email verification?
   - **Development**: OFF (easier testing)
   - **Production**: ON (more secure)

---

## Implementation Order

1. Install module and update config
2. Update middleware
3. Update login page
4. Remove/update auth composable
5. Remove/update plugin
6. Test thoroughly
7. Update any components using old auth

---

## Ready to Proceed?

Once you answer the questions above, I'll implement exactly matching your TradeFI pattern. The code will be:
- ✅ Using `@nuxtjs/supabase` module
- ✅ Same patterns as TradeFI
- ✅ Same error handling
- ✅ Same user experience

**Please confirm:**
1. Sign-up: Self-register or admin-only?
2. Display mode: Public or requires auth?
3. Email confirmation: ON or OFF for now?

Then I'll start coding! 🚀

