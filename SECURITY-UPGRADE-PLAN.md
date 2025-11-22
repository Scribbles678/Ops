# Security Upgrade Plan
## Operations Scheduling Tool

**Status**: Planning Phase - Awaiting Approval  
**Approach**: Methodical, one issue at a time  
**Goal**: Address all security concerns before production deployment

---

## Upgrade Strategy

We'll address security issues in priority order, testing after each change to ensure the application continues to function correctly. Each upgrade will be:
1. **Planned** - Detailed approach documented
2. **Approved** - You review and approve before implementation
3. **Implemented** - Code changes made
4. **Tested** - Verified to work correctly
5. **Documented** - Changes recorded

---

## Priority Order

### Phase 1: Critical Authentication & Access Control (HIGH PRIORITY)

These issues must be fixed before any production use.

#### 🔴 Issue 4.1: Weak Authentication System
**Current State:**
- Single shared password (`operations2024` or from env var)
- Password check happens client-side in `pages/login.vue`
- Password exposed in JavaScript bundle
- No individual user accounts
- Cookie-based session with no security flags

**Proposed Solution:**
**Option A: Supabase Auth (Recommended)**
- Use Supabase's built-in authentication system
- Individual user accounts with email/password
- Password hashing handled by Supabase
- Session management via Supabase
- Can add MFA later if needed
- Supports SSO/OAuth if needed in future

**Option B: Server-Side Password Check**
- Move password validation to Nuxt server route
- Password never exposed to client
- Still single shared password (less ideal)
- Better than current, but not as secure as Option A

**Recommendation**: **Option A (Supabase Auth)** - Most secure, scalable, and future-proof

**Files to Modify:**
- `pages/login.vue` - Replace with Supabase Auth UI
- `composables/useAuth.ts` - Use Supabase Auth methods
- `middleware/auth.global.ts` - Check Supabase session
- `plugins/supabase.client.ts` - Ensure auth is configured
- `nuxt.config.ts` - Remove `appPassword` from public config

**Database Changes:**
- Enable Supabase Auth in Supabase dashboard
- May need to create `auth.users` table (auto-created by Supabase)

**Estimated Time**: 4-6 hours

---

#### 🔴 Issue 4.2: Public Database Access
**Current State:**
- All RLS policies use `USING (true)` - allows anyone
- No authentication checks in policies
- Anyone with Supabase URL/anon key can read/write all data

**Proposed Solution:**
- Update all RLS policies to require authentication
- Use `auth.uid()` to check if user is authenticated
- Create role-based policies (admin vs. regular user)
- Keep read-only access for display mode (or use separate anon key)

**Policy Structure:**
```sql
-- Example new policy
CREATE POLICY "Authenticated users can read employees" 
ON employees FOR SELECT 
USING (auth.uid() IS NOT NULL);

-- Admin-only policies for write operations
CREATE POLICY "Admins can modify employees" 
ON employees FOR ALL 
USING (
  auth.uid() IS NOT NULL 
  AND EXISTS (
    SELECT 1 FROM user_roles 
    WHERE user_id = auth.uid() 
    AND role = 'admin'
  )
);
```

**Files to Modify:**
- `supabase-schema.sql` - Update all RLS policies
- Create new SQL migration file for policy updates
- May need to create `user_roles` table for role management

**Considerations:**
- Display mode needs read access - either:
  - Separate read-only anon key
  - Service role key (server-side only)
  - Or authenticated display user account

**Estimated Time**: 3-4 hours

---

#### 🔴 Issue 4.3: Client-Side Credential Exposure
**Current State:**
- `APP_PASSWORD` in `nuxt.config.ts` public config
- Exposed in client-side JavaScript bundle
- Supabase URL and anon key also public (this is normal, but needs RLS protection)

**Proposed Solution:**
- Remove `APP_PASSWORD` entirely (replaced by Supabase Auth)
- Keep Supabase URL/anon key public (they're meant to be public)
- Ensure RLS policies protect data (addressed in Issue 4.2)
- Move any sensitive operations to server routes if needed

**Files to Modify:**
- `nuxt.config.ts` - Remove `appPassword` from public config
- `pages/login.vue` - No longer needs password from config

**Estimated Time**: 30 minutes (mostly cleanup)

---

### Phase 2: Session & Input Security (MEDIUM PRIORITY)

#### 🟡 Issue 4.7: Session Security
**Current State:**
- Cookie set with `useCookie()` - no security flags
- No HttpOnly, Secure, or SameSite attributes
- Vulnerable to XSS attacks

**Proposed Solution:**
- Configure cookie with security flags:
  - `httpOnly: true` - Prevents JavaScript access
  - `secure: true` - HTTPS only (if in production)
  - `sameSite: 'strict'` - CSRF protection
- If using Supabase Auth, they handle this automatically

**Files to Modify:**
- `composables/useAuth.ts` - Update cookie configuration
- Or rely on Supabase Auth session handling

**Estimated Time**: 1 hour

---

#### 🟡 Issue 4.4: No Server-Side Input Validation
**Current State:**
- Validation only in `utils/validationRules.ts` (client-side)
- No server-side validation
- Relies on database constraints

**Proposed Solution:**
- Add database-level constraints and triggers
- Create Supabase Edge Functions for critical operations (optional)
- Add input sanitization for user-generated content
- Validate data types and ranges at database level

**Files to Modify:**
- `supabase-schema.sql` - Add CHECK constraints
- Create validation functions in database
- Optionally: Create Edge Functions for complex validations

**Estimated Time**: 2-3 hours

---

### Phase 3: Monitoring & Compliance (MEDIUM PRIORITY)

#### 🟡 Issue 4.5: No Audit Logging
**Current State:**
- No tracking of who made changes
- No timestamp of modifications
- Cannot trace security incidents

**Proposed Solution:**
- Create `audit_log` table
- Add database triggers to log all INSERT/UPDATE/DELETE operations
- Include: user_id, table_name, action, old_data, new_data, timestamp
- Create UI to view audit logs (admin only)

**Database Changes:**
```sql
CREATE TABLE audit_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id),
  table_name TEXT NOT NULL,
  action TEXT NOT NULL, -- 'INSERT', 'UPDATE', 'DELETE'
  old_data JSONB,
  new_data JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

**Files to Modify:**
- Create new SQL file for audit logging setup
- Add triggers to all tables
- Create composable for viewing audit logs
- Add admin page to view audit logs

**Estimated Time**: 4-5 hours

---

#### 🟡 Issue 4.6: No Rate Limiting
**Current State:**
- No protection against brute force attacks
- No API rate limiting
- Login attempts not throttled

**Proposed Solution:**
- Implement rate limiting at Supabase level (if available)
- Add client-side rate limiting for login attempts
- Consider Netlify rate limiting (if on paid plan)
- Store failed login attempts in database with timestamps

**Files to Modify:**
- `pages/login.vue` - Add rate limiting logic
- Create database table for tracking login attempts
- Or use Supabase Auth rate limiting (built-in)

**Estimated Time**: 2-3 hours

---

### Phase 4: Cleanup & Best Practices (LOW PRIORITY)

#### 🟢 Issue 4.9: Default Password
**Current State:**
- Hardcoded default `operations2024` in code
- Fallback if env var not set

**Proposed Solution:**
- Remove default password entirely
- Require explicit configuration
- Or better: Use Supabase Auth (no password needed)

**Files to Modify:**
- `pages/login.vue` - Remove default
- `nuxt.config.ts` - Remove default

**Estimated Time**: 15 minutes

---

## Implementation Order

### Recommended Sequence:

1. **Issue 4.1: Authentication** (Supabase Auth)
   - Foundation for everything else
   - Enables user-based access control

2. **Issue 4.2: Database Access Control**
   - Requires authentication to be in place first
   - Protects all data

3. **Issue 4.3: Credential Exposure**
   - Quick cleanup after auth is fixed
   - Removes exposed password

4. **Issue 4.7: Session Security**
   - Enhance session handling
   - Works with Supabase Auth

5. **Issue 4.4: Server-Side Validation**
   - Add database constraints
   - Improve data integrity

6. **Issue 4.5: Audit Logging**
   - Track all changes
   - Important for compliance

7. **Issue 4.6: Rate Limiting**
   - Protect against attacks
   - May be handled by Supabase Auth

8. **Issue 4.9: Default Password**
   - Final cleanup
   - Remove hardcoded values

---

## Testing Strategy

After each upgrade:
1. **Unit Testing**: Test the specific feature changed
2. **Integration Testing**: Verify it works with existing features
3. **Security Testing**: Verify the security issue is resolved
4. **Regression Testing**: Ensure nothing else broke

**Test Checklist for Each Upgrade:**
- [ ] Feature works as expected
- [ ] Security issue is resolved
- [ ] No new errors in console
- [ ] Existing features still work
- [ ] Database operations succeed
- [ ] Authentication flows work
- [ ] Display mode works (if applicable)

---

## Rollback Plan

For each upgrade:
1. **Git Commit**: Commit before starting
2. **Branch**: Create feature branch (optional but recommended)
3. **Test**: Verify changes work
4. **Document**: Update documentation
5. **Merge**: Merge to main after approval

**If Issues Arise:**
- Revert to previous commit
- Document what went wrong
- Adjust approach and retry

---

## Questions for Decision

Before we start, please confirm:

1. **Authentication Approach**: 
   - [ ] Option A: Supabase Auth (recommended)
   - [ ] Option B: Server-side password check
   - [ ] Other: _______________

2. **User Management**:
   - How will users be created? (Admin creates them? Self-registration? Email invites?)
   - What roles do you need? (Admin, User, Display-only?)

3. **Display Mode Access**:
   - Should display mode require authentication?
   - Or use separate read-only access?

4. **Timeline**:
   - How quickly do you need these fixes?
   - Can we do one at a time, or need them all quickly?

5. **Testing Environment**:
   - Do you have a staging/test Supabase project?
   - Or should we test on production database?

---

## Next Steps

1. **Review this plan** - Does the approach make sense?
2. **Answer questions above** - So we can proceed correctly
3. **Approve Issue 4.1** - Start with authentication
4. **Begin implementation** - I'll code after your approval

---

**Ready to proceed?** Let me know which issue you'd like to tackle first, and I'll provide detailed implementation steps before coding.

