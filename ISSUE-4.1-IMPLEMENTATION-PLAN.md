# Issue 4.1 Implementation Plan
## Supabase Authentication Implementation

**Status**: Planning - Awaiting review of existing implementation  
**Goal**: Replace client-side password check with Supabase Auth

---

## Current State Analysis

**Files to Modify:**
1. `pages/login.vue` - Replace password check with Supabase Auth
2. `composables/useAuth.ts` - Use Supabase Auth methods
3. `middleware/auth.global.ts` - Check Supabase session
4. `plugins/supabase.client.ts` - Configure auth persistence (if needed)
5. `nuxt.config.ts` - Remove `appPassword` from public config

**Current Supabase Setup:**
- Client initialized in `plugins/supabase.client.ts`
- Using `@supabase/supabase-js` v2.76.1
- Basic client creation (no auth persistence configured yet)

---

## Implementation Steps

### Step 1: Configure Supabase Client for Auth Persistence

**File**: `plugins/supabase.client.ts`

**Changes Needed:**
- Add auth persistence configuration
- Handle SSR properly (Nuxt 3)
- Ensure session persists across page reloads

**Considerations:**
- Need to see your other project's pattern for this
- May need to configure `auth.storage` for SSR
- May need to handle cookie-based storage

---

### Step 2: Update Login Page

**File**: `pages/login.vue`

**Current Implementation:**
- Single password field
- Client-side password check
- Sets cookie on success

**New Implementation:**
- Email + Password fields (or just password if using magic links)
- Call `supabase.auth.signInWithPassword()`
- Handle errors properly
- Redirect on success

**Questions:**
- Do you want email + password, or just email (magic link)?
- What error messages do you prefer?
- Any specific UI patterns from your other project?

---

### Step 3: Update Auth Composable

**File**: `composables/useAuth.ts`

**Current Implementation:**
- Simple cookie-based check
- `isAuthenticated` computed
- `login()` and `logout()` methods

**New Implementation:**
- Use `supabase.auth.getUser()` for auth state
- Use `supabase.auth.getSession()` for session check
- `login()` → `supabase.auth.signInWithPassword()`
- `logout()` → `supabase.auth.signOut()`
- Reactive user state

**Pattern to Match:**
- Will follow your other project's pattern

---

### Step 4: Update Auth Middleware

**File**: `middleware/auth.global.ts`

**Current Implementation:**
- Checks cookie value
- Redirects to `/login` if not authenticated

**New Implementation:**
- Check Supabase session
- Use `supabase.auth.getSession()`
- Handle async properly in middleware
- Redirect to `/login` if no session

**Considerations:**
- Nuxt middleware needs to handle async Supabase calls
- May need to use `await` properly

---

### Step 5: Remove Password from Config

**File**: `nuxt.config.ts`

**Changes:**
- Remove `appPassword` from `runtimeConfig.public`
- Keep only Supabase URL and anon key

---

### Step 6: Update All Auth Checks

**Files to Review:**
- Any components that check `isAuthenticated`
- Any pages that need auth
- Display mode (may need special handling)

**Considerations:**
- Display mode might need read-only access
- May need to handle unauthenticated display mode differently

---

## Supabase Dashboard Setup

**Required Steps:**
1. Enable Authentication in Supabase dashboard
2. Configure email provider (if using email/password)
3. Create initial admin user(s)
4. Configure auth settings (password requirements, etc.)

**Questions:**
- Do you want email verification required?
- Password requirements?
- Any specific auth providers (Google, etc.)?

---

## Testing Checklist

After implementation:
- [ ] Can log in with valid credentials
- [ ] Cannot log in with invalid credentials
- [ ] Session persists on page reload
- [ ] Logout works correctly
- [ ] Protected routes redirect to login
- [ ] Login page redirects if already authenticated
- [ ] Display mode works (if it should work without auth)
- [ ] No console errors
- [ ] Works in production (Netlify)

---

## Questions for Your Existing Implementation

Please share your other project's:
1. **Supabase client setup** - How is auth persistence configured?
2. **Login page** - What does the UI/flow look like?
3. **Auth composable** - How do you check auth state?
4. **Middleware** - How do you handle auth checks?
5. **Error handling** - How do you display auth errors?
6. **User management** - How do you create/manage users?

---

## Next Steps

1. **Review your existing implementation** - Share the relevant files
2. **Refine this plan** - Match your patterns and preferences
3. **Get approval** - You review the final plan
4. **Implement** - Code the changes
5. **Test** - Verify everything works
6. **Document** - Update documentation

---

**Ready to see your existing implementation!** Please share the relevant files from your other project, and I'll match the patterns exactly.

