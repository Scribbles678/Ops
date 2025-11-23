# User Roles Documentation

## Overview

The Operations Scheduling Tool uses a **three-tier role system** to manage access and permissions across teams and departments.

---

## Role Hierarchy

```
Super Admin (Highest)
    ↓
Admin (Middle)
    ↓
User (Base)
```

---

## Role Definitions

### 1. **User** (Base Role)
**Default role for all new accounts**

**Permissions:**
- ✅ View and manage schedules for their own team
- ✅ View and manage employees in their own team
- ✅ View and manage job functions in their own team
- ✅ View and manage training records in their own team
- ✅ View and manage PTO requests in their own team
- ✅ View and manage shift swaps in their own team
- ✅ Change their own password (via Settings page)
- ✅ View their own account information

**Restrictions:**
- ❌ Cannot see data from other teams
- ❌ Cannot create or manage other users
- ❌ Cannot create or manage teams
- ❌ Cannot access User Management or Team Management sections
- ❌ Cannot modify system settings

**Use Case:**
- Regular team members who need to create and manage schedules
- Employees who need to view training records and assignments
- Day-to-day operations staff

---

### 2. **Admin** (Team Manager Role)
**For team managers who need to manage their own team**

**Permissions:**
- ✅ **All User permissions** for their own team
- ✅ Create and manage users within their own team
- ✅ Assign users to their team
- ✅ Activate/deactivate users in their own team
- ✅ Reset passwords for users in their own team
- ✅ View and manage all data for their own team
- ✅ Access User Management section (filtered to their team only)

**Restrictions:**
- ❌ Cannot see data from other teams
- ❌ Cannot create or manage users in other teams
- ❌ Cannot create or delete teams
- ❌ Cannot assign users to other teams
- ❌ Cannot grant Admin or Super Admin roles
- ❌ Cannot access Team Management section
- ❌ Cannot modify system-wide settings

**Use Case:**
- Department managers who need to manage their team's users
- Team leads who need to onboard new team members
- Supervisors who need to reset passwords for their team

---

### 3. **Super Admin** (System Administrator Role)
**For system administrators who manage the entire application**

**Permissions:**
- ✅ **All Admin permissions** for all teams
- ✅ View and manage data from ALL teams
- ✅ Create and manage users across all teams
- ✅ Assign users to any team
- ✅ Create and delete teams
- ✅ Grant Admin and Super Admin roles
- ✅ Activate/deactivate any user
- ✅ Reset passwords for any user
- ✅ Access User Management section (all users)
- ✅ Access Team Management section
- ✅ Modify system-wide settings

**Restrictions:**
- None (full system access)

**Use Case:**
- IT administrators
- Operations managers overseeing multiple departments
- System owners who need full control

---

## Role Assignment

### How Roles Are Assigned

1. **New Users:**
   - Default role: **User**
   - Must be assigned by a Super Admin or Admin (for their team)

2. **Promoting Users:**
   - Only **Super Admins** can grant Admin or Super Admin roles
   - Admins cannot grant Admin or Super Admin roles (even to their own team)

3. **Role Changes:**
   - Only **Super Admins** can change user roles
   - Users cannot change their own role
   - Admins cannot change roles (even within their team)

---

## Team Isolation

### How Team Isolation Works

**Users:**
- Can only see data from their assigned team
- Cannot access other teams' schedules, employees, or data

**Admins:**
- Can see and manage data from their assigned team
- Can manage users in their assigned team
- Cannot see or manage other teams' data

**Super Admins:**
- Can see and manage data from ALL teams
- Can switch between teams when viewing data
- Bypass all team isolation restrictions

---

## Examples

### Example 1: Regular User
**Sarah** is a User in the "Domestic Operations" team:
- ✅ Can create schedules for Domestic Operations
- ✅ Can view Domestic Operations employees
- ❌ Cannot see "International Operations" data
- ❌ Cannot create new users

### Example 2: Team Admin
**John** is an Admin in the "Domestic Operations" team:
- ✅ Can create schedules for Domestic Operations
- ✅ Can create new users and assign them to Domestic Operations
- ✅ Can reset passwords for Domestic Operations users
- ❌ Cannot see "International Operations" data
- ❌ Cannot create new teams

### Example 3: Super Admin
**Mike** is a Super Admin:
- ✅ Can see all teams' data
- ✅ Can create users for any team
- ✅ Can create new teams
- ✅ Can assign users to any team
- ✅ Can grant Admin or Super Admin roles

---

## Security Notes

1. **Role Escalation Prevention:**
   - Users cannot promote themselves
   - Admins cannot grant Admin or Super Admin roles
   - Only Super Admins can change roles

2. **Team Isolation:**
   - Database-level Row Level Security (RLS) enforces team isolation
   - Users cannot bypass restrictions even with direct database access
   - Super Admins explicitly bypass RLS policies

3. **Audit Trail:**
   - All role changes should be logged (future enhancement)
   - User creation and management actions are tracked

---

## Best Practices

1. **Minimize Super Admins:**
   - Only assign Super Admin to 1-2 trusted individuals
   - Use Admin role for team managers instead

2. **Use Admin Role for Delegation:**
   - Grant Admin role to team managers who need to manage their team
   - This reduces the number of Super Admins needed

3. **Regular Review:**
   - Periodically review who has Admin and Super Admin roles
   - Remove roles from users who no longer need them

4. **Team Assignment:**
   - Always assign users to appropriate teams
   - Users without a team cannot access team-specific data

---

## Technical Implementation

### Database Fields
- `is_super_admin` (BOOLEAN) - Super Admin role
- `is_admin` (BOOLEAN) - Admin role
- `team_id` (UUID) - User's assigned team

### Role Checking
- Check `is_super_admin` first (highest privilege)
- Then check `is_admin` (middle privilege)
- Default to User (base privilege)

### RLS Policies
- Users: Filter by `team_id = user's team_id`
- Admins: Filter by `team_id = user's team_id` (but can manage users)
- Super Admins: No filter (see everything)

