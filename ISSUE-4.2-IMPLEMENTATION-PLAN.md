# Issue 4.2 Implementation Plan
## Public Database Access - Remove Public Policies

**Status**: Ready to implement  
**Goal**: Remove all public access policies and ensure all tables require authentication

---

## Current State

- Old `supabase-schema.sql` has `USING (true)` policies that allow public access
- `multi-tenant-setup.sql` created authenticated, team-based policies
- Both sets of policies may exist, causing confusion
- Display mode (`/display`) currently works without authentication

---

## Implementation Steps

### Step 1: Drop All Old Public Policies

The SQL file `fix-public-database-access-issue-4.2.sql` will:
- Drop all `"Enable read access for all users"` policies
- Drop all `"Enable insert for all users"` policies  
- Drop all `"Enable update for all users"` policies
- Drop all `"Enable delete for all users"` policies

### Step 2: Verify Authenticated Policies Exist

The `multi-tenant-setup.sql` should have already created:
- Super admin policies (can see all)
- Team-based policies (users see only their team)
- All policies require `auth.uid() IS NOT NULL` (implicitly via team_id matching)

### Step 3: Handle Display Mode

**Option A: Keep Display Mode Public (Recommended)**
- Add read-only policies for unauthenticated users
- Only allow viewing today's schedule
- No write access

**Option B: Require Authentication for Display Mode**
- Remove display mode from public routes
- Require login to view display
- Simpler, more secure

**Recommendation**: Option A - Keep it public but read-only for today's data only

---

## Files to Run

1. **`fix-public-database-access-issue-4.2.sql`** - Main migration
   - Drops old public policies
   - Verifies authenticated policies exist
   - Adds display mode public read-only policies

---

## Testing Checklist

After running the migration:

- [ ] Try accessing database without authentication (should fail)
- [ ] Log in as regular user (should see only their team's data)
- [ ] Log in as super admin (should see all data)
- [ ] Test display mode (`/display`) - should work without login
- [ ] Verify all CRUD operations require authentication
- [ ] Check that old public policies are gone

---

## Rollback Plan

If issues occur:
1. The old policies can be recreated from `supabase-schema.sql`
2. Display mode policies can be removed if needed
3. All changes are in SQL - easy to revert

---

## Next Steps

1. Review the SQL file
2. Run it in Supabase SQL Editor
3. Test authentication requirements
4. Verify display mode still works
5. Mark Issue 4.2 as complete

