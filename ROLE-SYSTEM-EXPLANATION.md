# Role System Explanation

## Current System (Binary)

Currently, the system has **TWO roles**:

1. **Regular User** (`is_super_admin = false`)
   - Can only see/manage data from their own team
   - Cannot create users or teams
   - Cannot manage other users
   - Team-isolated access

2. **Super Admin** (`is_super_admin = true`)
   - Can see/manage ALL teams' data
   - Can create users and teams
   - Can manage all users (edit, activate/deactivate, reset passwords)
   - Can assign users to teams
   - Bypasses all team isolation

---

## Option 1: Keep Current System (User + Super Admin)

**Pros:**
- ✅ Simple - only two roles to manage
- ✅ Clear separation of power
- ✅ Already implemented and working
- ✅ Easy to understand: "Can you manage users? Yes = Super Admin, No = User"

**Cons:**
- ⚠️ All-or-nothing: Either you can manage everything or nothing
- ⚠️ No middle ground for team managers who need to manage their team but not others

**Best For:**
- Small organizations (< 50 users)
- Clear hierarchy (one person/group manages everything)
- Simple permission model

---

## Option 2: Three-Tier System (User + Admin + Super Admin)

**Roles:**
1. **User** - Team-isolated, can only manage schedules/data for their team
2. **Admin** - Can manage users in their own team, but not create teams or manage other teams
3. **Super Admin** - Can manage everything (all teams, all users, create teams)

**Pros:**
- ✅ More granular permissions
- ✅ Team managers can manage their team without full system access
- ✅ Better for larger organizations
- ✅ More scalable as you grow

**Cons:**
- ⚠️ More complex to implement
- ⚠️ More roles to manage and explain
- ⚠️ Need to define what "Admin" can/cannot do

**Implementation:**
- Add `is_admin` boolean field to `user_profiles`
- Update RLS policies to allow admins to:
  - View/manage users in their own team
  - View/manage data in their own team
  - But NOT create teams or manage other teams' users

**Best For:**
- Larger organizations (> 20 users)
- Multiple departments with their own managers
- Need for delegation without full access

---

## Option 3: Two-Tier System (User + Admin) - Remove Super Admin

**Roles:**
1. **User** - Team-isolated access
2. **Admin** - Can manage everything (all teams, all users, create teams)

**Pros:**
- ✅ Simpler than three-tier
- ✅ Still allows delegation
- ✅ One less role to manage

**Cons:**
- ⚠️ No distinction between "system admin" and "team admin"
- ⚠️ If you need team-specific admins later, you'd need to add it back

**Best For:**
- Small to medium organizations
- You don't need team-specific admins
- You want to keep it simple but still have admin capabilities

---

## Recommendation

**For your use case (6 departments, 2-3 users per team):**

I recommend **Option 1 (Current System: User + Super Admin)** because:

1. **Small scale** - With only 12-18 total users, you don't need complex role hierarchies
2. **Simple management** - One person (you) managing everything is simpler
3. **Already working** - The system is implemented and functional
4. **Easy to understand** - Clear who can do what

**However, if you want team managers to manage their own teams:**

Then **Option 2 (User + Admin + Super Admin)** makes sense:
- Team managers get "Admin" role for their team
- You keep "Super Admin" for system-wide management
- Regular users stay as "User"

---

## What Would Need to Change?

### If switching to Option 2 (User + Admin + Super Admin):

1. **Database:**
   ```sql
   ALTER TABLE user_profiles ADD COLUMN is_admin BOOLEAN DEFAULT false;
   ```

2. **RLS Policies:**
   - Admins can view/manage users in their own team
   - Admins can view/manage data in their own team
   - Only Super Admins can create teams or manage other teams

3. **UI:**
   - Add "Admin" checkbox in user creation/edit
   - Show "Admin" badge in user list
   - Update permission checks throughout the app

### If switching to Option 3 (User + Admin):

1. **Database:**
   - Rename `is_super_admin` to `is_admin`
   - Update all references

2. **Code:**
   - Replace all `is_super_admin` checks with `is_admin`
   - Update UI labels from "Super Admin" to "Admin"

---

## Questions to Consider

1. **Do you need team managers?** 
   - If yes → Option 2 (three-tier)
   - If no → Option 1 (current) or Option 3 (two-tier)

2. **Will you delegate user management?**
   - If yes → Option 2 (three-tier) or Option 3 (two-tier)
   - If no → Option 1 (current)

3. **How many people need admin access?**
   - 1-2 people → Option 1 or Option 3
   - 3+ people → Option 2

4. **Do you want team-specific admins?**
   - If yes → Option 2 (three-tier)
   - If no → Option 1 or Option 3

