# Roles Overview
## Operations Scheduling Tool - User Roles & Permissions Guide

**Last Updated**: January 2025  
**Purpose**: Comprehensive guide to all user roles, their permissions, and use cases

---

## Table of Contents

1. [Role Hierarchy](#role-hierarchy)
2. [Role Descriptions](#role-descriptions)
3. [Permissions Matrix](#permissions-matrix)
4. [Team Isolation Rules](#team-isolation-rules)
5. [Role Assignment](#role-assignment)
6. [Use Cases](#use-cases)
7. [Security Considerations](#security-considerations)

---

## Role Hierarchy

The application uses a **four-tier role system**:

```
Super Admin (Highest)
    ↓
Admin
    ↓
User (Standard)
    ↓
Display User (Read-Only)
```

---

## Role Descriptions

### 1. **Super Admin** 🔑
**Purpose**: Full system administration across all teams

**Key Characteristics**:
- Highest level of access
- Can manage all teams and users
- Can see and modify data across all teams
- Can assign roles to other users
- Can create and manage teams

**Database Flag**: `is_super_admin = true` in `user_profiles`

**Use Cases**:
- System administrators
- IT department
- Senior management overseeing multiple teams
- Initial setup and configuration

**Limitations**:
- None (full access)

---

### 2. **Admin** 👔
**Purpose**: Team-level administration within a specific team

**Key Characteristics**:
- Can manage users within their own team
- Can see and modify all data for their team
- Can assign users to their team
- Cannot access other teams' data
- Cannot create new teams
- Cannot assign super admin or admin roles

**Database Flag**: `is_admin = true` in `user_profiles`

**Use Cases**:
- Team leads
- Department managers
- Shift supervisors
- Anyone who needs to manage their team's schedule and users

**Limitations**:
- Team-bound (can only see their team's data)
- Cannot manage other teams
- Cannot change roles (except assign users to their team)

---

### 3. **User** 👤
**Purpose**: Standard user with team-specific access

**Key Characteristics**:
- Can view and edit their team's schedules
- Can manage employees, shifts, and training for their team
- Can create and edit schedules
- Cannot manage users
- Cannot access other teams' data
- Cannot change team assignments

**Database Flag**: `is_admin = false` AND `is_super_admin = false` in `user_profiles`

**Use Cases**:
- Regular employees who create schedules
- Staff who update training records
- Anyone who needs to view and edit their team's data

**Limitations**:
- Team-bound (can only see their team's data)
- Cannot manage users
- Cannot access admin features

---

### 4. **Display User** 📺
**Purpose**: Read-only access for TV displays

**Key Characteristics**:
- **Read-only access** (cannot create, edit, or delete)
- Can only view **today's schedule**
- Restricted to `/display` route only
- Cannot access any other pages
- Can be assigned to specific team (optional)
- Auto-refreshes every 2 minutes

**Database Flag**: `is_display_user = true` in `user_profiles`

**Use Cases**:
- TV displays in break rooms
- Public schedule monitors
- Kiosk displays
- Any read-only viewing scenario

**Limitations**:
- Read-only (no write access)
- Today's data only
- Restricted to display mode page
- Cannot navigate to other pages

---

## Permissions Matrix

| Feature | Super Admin | Admin | User | Display User |
|---------|------------|-------|------|--------------|
| **View All Teams' Data** | ✅ | ❌ | ❌ | ❌* |
| **View Own Team's Data** | ✅ | ✅ | ✅ | ✅ (today only) |
| **Edit Own Team's Data** | ✅ | ✅ | ✅ | ❌ |
| **Create Schedules** | ✅ | ✅ | ✅ | ❌ |
| **Manage Employees** | ✅ (all) | ✅ (team) | ✅ (team) | ❌ |
| **Manage Job Functions** | ✅ (all) | ✅ (team) | ✅ (team) | ❌ |
| **Manage Shifts** | ✅ (all) | ✅ (team) | ✅ (team) | ❌ |
| **Manage Training** | ✅ (all) | ✅ (team) | ✅ (team) | ❌ |
| **Manage PTO** | ✅ (all) | ✅ (team) | ✅ (team) | ❌ |
| **Create Teams** | ✅ | ❌ | ❌ | ❌ |
| **Manage Users** | ✅ (all) | ✅ (team) | ❌ | ❌ |
| **Assign Roles** | ✅ | ❌ | ❌ | ❌ |
| **Change Team Assignments** | ✅ | ✅ (team) | ❌ | ❌ |
| **Access Settings Page** | ✅ | ✅ | ✅ | ❌ |
| **Access Display Mode** | ✅ | ✅ | ✅ | ✅ (only) |
| **View Historical Data** | ✅ | ✅ | ✅ | ❌ |
| **Export Data** | ✅ | ✅ | ✅ | ❌ |

*Display users can view all teams if `team_id = NULL`, or only their assigned team if `team_id` is set.

---

## Team Isolation Rules

### How Team Isolation Works

1. **Data Filtering**: All queries automatically filter by `team_id`
2. **Database-Level Security**: Row Level Security (RLS) policies enforce team isolation
3. **Automatic Assignment**: New records automatically get the user's `team_id`

### Team Isolation by Role

| Role | Can See | Can Edit |
|------|---------|----------|
| **Super Admin** | All teams | All teams |
| **Admin** | Own team only | Own team only |
| **User** | Own team only | Own team only |
| **Display User** | Own team (or all if `team_id = NULL`) | None (read-only) |

### Examples

**Scenario 1: Regular User**
- Assigned to "Domestic" team
- Can only see Domestic employees, schedules, training
- Cannot see "International" team data
- New records automatically assigned to "Domestic"

**Scenario 2: Super Admin**
- Not assigned to any specific team
- Can see all teams' data
- Can create records for any team (by specifying `team_id`)
- Can manage users across all teams

**Scenario 3: Admin**
- Assigned to "Domestic" team
- Can see and manage all Domestic team data
- Can assign users to Domestic team
- Cannot see "International" team data

---

## Role Assignment

### Who Can Assign Roles?

| Role | Can Assign |
|------|------------|
| **Super Admin** | All roles (Super Admin, Admin, User, Display User) |
| **Admin** | Cannot assign roles (can only assign users to their team) |
| **User** | Cannot assign roles |
| **Display User** | Cannot assign roles |

### How to Assign Roles

#### Via Settings Page (Super Admin Only)

1. Navigate to **Settings** page
2. Go to **User Management** section
3. Click **Create User** or **Edit** existing user
4. Select role:
   - ✅ **Super Admin** checkbox
   - ✅ **Admin** checkbox
   - ✅ **Display User** checkbox
   - (If none checked = regular User)
5. Assign to team (optional for Super Admin)
6. Save

#### Via SQL (Advanced)

```sql
-- Make user a Super Admin
UPDATE user_profiles 
SET is_super_admin = true 
WHERE id = 'user-uuid-here';

-- Make user an Admin
UPDATE user_profiles 
SET is_admin = true 
WHERE id = 'user-uuid-here';

-- Make user a Display User
UPDATE user_profiles 
SET is_display_user = true 
WHERE id = 'user-uuid-here';

-- Remove all roles (make regular User)
UPDATE user_profiles 
SET is_super_admin = false, 
    is_admin = false, 
    is_display_user = false 
WHERE id = 'user-uuid-here';
```

---

## Use Cases

### Use Case 1: Multi-Team Organization

**Scenario**: Company has "Domestic" and "International" teams

**Setup**:
- 1 Super Admin (manages everything)
- 2 Admins (one per team)
- Multiple Users per team
- 1 Display User per location (optional)

**Result**:
- Each team only sees their own data
- Admins manage their team independently
- Super Admin can see everything

---

### Use Case 2: Single Team with Multiple Users

**Scenario**: One team, multiple schedulers

**Setup**:
- 1 Super Admin (or Admin)
- Multiple Users
- 1 Display User for TV

**Result**:
- All users see same data (same team)
- Users can collaborate on schedules
- Display shows team schedule

---

### Use Case 3: TV Display Only

**Scenario**: Public TV showing today's schedule

**Setup**:
- 1 Display User account
- Login on TV browser
- Auto-refresh enabled

**Result**:
- TV shows today's schedule
- No login required for viewers
- Can't be edited from TV
- Auto-updates every 2 minutes

---

### Use Case 4: Team-Specific TV Displays

**Scenario**: Each team has their own TV display

**Setup**:
- 1 Display User per team
- Each assigned to their team (`team_id` set)
- Login on respective TV

**Result**:
- Each TV shows only that team's schedule
- Isolated displays per team
- Can't see other teams' schedules

---

## Security Considerations

### Role Immutability

- **Regular users cannot change their own role**
- Only Super Admins can assign/change roles
- Database triggers prevent role escalation
- Users cannot change their `team_id` (except Super Admin/Admin)

### Team Isolation Security

- **Database-level enforcement**: RLS policies prevent cross-team access
- **Client-side filtering**: Additional layer of security in application code
- **Super Admin override**: Can see all teams (by design)

### Display User Security

- **Read-only**: Cannot modify any data
- **Route restriction**: Middleware prevents access to other pages
- **Today only**: Can only see current day's schedule
- **Revocable**: Can disable display user account

### Best Practices

1. **Minimize Super Admins**: Only assign to trusted personnel
2. **Use Admins for Teams**: Let team leads be Admins, not Super Admins
3. **Separate Display Accounts**: Use different accounts for each TV
4. **Regular Audits**: Review user roles periodically
5. **Team Assignment**: Always assign users to teams (except Super Admin)

---

## Role Management Workflow

### Creating a New User

1. **Super Admin** creates user via Settings page
2. Assign email, password, full name
3. Select role(s):
   - Super Admin (if needed)
   - Admin (if team manager)
   - Display User (if TV display)
   - None = Regular User
4. Assign to team (required for Admin/User, optional for Super Admin)
5. User receives credentials and can login

### Changing a User's Role

1. **Super Admin** goes to Settings → User Management
2. Finds user and clicks **Edit**
3. Updates role checkboxes
4. Saves changes
5. User's permissions update immediately

### Removing Access

1. **Super Admin** goes to Settings → User Management
2. Finds user and clicks **Edit**
3. Sets `is_active = false` OR deletes user
4. User can no longer login

---

## Visual Indicators

### In the Application

- **Role Pills**: Displayed in Settings page and user tables
  - 🔑 **Super Admin** (red/purple)
  - 👔 **Admin** (blue)
  - 👤 **User** (gray)
  - 📺 **Display User** (green)

- **Team Pills**: Show which team user belongs to
  - Displayed next to role in user tables

---

## Troubleshooting

### User Can't See Their Team's Data

**Possible Causes**:
- User not assigned to a team (`team_id = NULL`)
- User's team doesn't have any data
- RLS policy issue

**Solution**:
- Assign user to team in Settings
- Verify team has data
- Check user's `team_id` in database

### User Can See All Teams' Data

**Possible Causes**:
- User is Super Admin
- User's `team_id = NULL` (should only happen for Super Admin)

**Solution**:
- Verify user's role in Settings
- Check `is_super_admin` flag in database

### Display User Can Access Other Pages

**Possible Causes**:
- Middleware not updated
- Display user flag not set correctly

**Solution**:
- Update middleware to restrict display users
- Verify `is_display_user = true` in database

---

## Summary

| Role | Access Level | Team Scope | Write Access | Use Case |
|------|-------------|------------|--------------|----------|
| **Super Admin** | Full | All teams | ✅ Full | System administration |
| **Admin** | Team | Own team | ✅ Full | Team management |
| **User** | Team | Own team | ✅ Full | Regular operations |
| **Display User** | Read-only | Own team (or all) | ❌ None | TV displays |

---

## Questions?

For questions about roles or permissions, contact your Super Admin or refer to:
- `ROLES-DOCUMENTATION.md` - Detailed technical documentation
- Settings page - User Management section
- Database schema - `user_profiles` table

---

**Document Version**: 1.0  
**Last Updated**: January 2025

