# Display Role Implementation Plan
## Secure TV Display Access

**Goal**: Create a dedicated "display" role that can only view today's schedule, with no write access or access to other pages.

---

## Current State

- Display mode is public (no authentication)
- Anyone can access `/display` without login
- Database policies allow unauthenticated users to view today's schedule

---

## Proposed Solution: Display User Role

### Benefits

1. **Security**: Can track and revoke access
2. **Control**: Can assign display users to specific teams
3. **Audit**: Can see who accessed display mode
4. **Flexibility**: Can have multiple display users for different TVs/locations

### Implementation

1. **Add `is_display_user` column** to `user_profiles`
2. **Create display user policies** that:
   - Only allow SELECT (read-only)
   - Only show today's schedule
   - Require authentication
3. **Update middleware** to redirect display users to `/display` only
4. **Remove public display policies**

---

## Steps

### Step 1: Run SQL Migration
Run `add-display-role.sql` to:
- Add `is_display_user` column
- Create helper function
- Remove public policies
- Create authenticated display user policies

### Step 2: Create Display User Account

**Option A: Via Settings Page (Super Admin)**
- Super admin creates user with `is_display_user = true`
- Assign to team (optional - NULL = all teams)

**Option B: Via SQL**
```sql
-- After creating auth user in Supabase Dashboard
INSERT INTO user_profiles (id, username, email, is_display_user, is_active, team_id)
VALUES (
  'auth-user-uuid-here',
  'display-tv-1',
  'display@yourcompany.com',
  true,
  true,
  NULL  -- NULL = all teams, or specific team_id
);
```

### Step 3: Update Middleware

Update `middleware/auth.global.ts` to:
- Check if user is display user
- If display user, redirect to `/display` (can't access other pages)
- Remove `/display` from public routes

### Step 4: Update Settings Page

Add UI in settings page (super admin only) to:
- Create display users
- See list of display users
- Revoke display access

---

## Security Features

✅ **Read-only access** - Display users can only SELECT, never INSERT/UPDATE/DELETE  
✅ **Today only** - Can only see today's schedule  
✅ **Team isolation** - Can be assigned to specific team (optional)  
✅ **Route restriction** - Middleware prevents access to other pages  
✅ **Revocable** - Can disable display user account  

---

## Usage

1. **Create display user** (super admin)
2. **Login on TV** with display user credentials
3. **TV stays on `/display`** - middleware prevents navigation
4. **Auto-refresh** - Display mode refreshes every 2 minutes
5. **No interaction** - Display users can't edit anything

---

## Questions

1. **One display user per TV, or shared?**
   - Recommendation: One per TV (better tracking)

2. **Team-specific displays?**
   - If TV shows only one team's schedule, assign `team_id`
   - If TV shows all teams, leave `team_id = NULL`

3. **Password management?**
   - Use simple passwords (TVs are physical security)
   - Or use QR code/pin for quick login

---

## Next Steps

1. Review this plan
2. Run `add-display-role.sql`
3. Create first display user
4. Update middleware
5. Test on TV

