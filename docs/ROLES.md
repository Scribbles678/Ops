# User Roles & Permissions Documentation

Complete guide to the role system, permissions, and team isolation.

---

## Table of Contents

1. [Role Hierarchy](#role-hierarchy)
2. [Role Definitions](#role-definitions)
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

## Role Definitions

### 1. **Super Admin** 🔑
**Purpose**: Full system administration across all teams

**Key Characteristics:**
- Highest level of access
- Can manage all teams and users
- Can see and modify data across all teams
- Can assign roles to other users
- Can create and manage teams

**Database Flag**: `is_super_admin = true` in `user_profiles`

**Permissions:**
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

**Use Cases:**
- System administrators
- IT department
- Senior management overseeing multiple teams
- Initial setup and configuration

---

### 2. **Admin** 👔
**Purpose**: Team-level administration within a specific team

**Key Characteristics:**
- Can manage users within their own team
- Can see and modify all data for their team
- Can assign users to their team
- Cannot access other teams' data
- Cannot create new teams
- Cannot assign super admin or admin roles

**Database Flag**: `is_admin = true` in `user_profiles`

**Permissions:**
- ✅ **All User permissions** for their own team
- ✅ View users in their own team (via RLS policies)
- ✅ View and manage all data for their own team
- ✅ Change their own team assignment (via Settings page)

**Note**: Admin role can **view** team users through database access, but **cannot create new users or reset passwords** - these operations require Super Admin privileges and use server-side API routes that only allow Super Admin access.

**Restrictions:**
- ❌ Cannot see data from other teams
- ❌ Cannot create new users (requires Super Admin)
- ❌ Cannot reset user passwords (requires Super Admin)
- ❌ Cannot activate/deactivate users (requires Super Admin)
- ❌ Cannot create or delete teams
- ❌ Cannot assign users to teams (requires Super Admin)
- ❌ Cannot grant Admin or Super Admin roles
- ❌ Cannot access User Management section (Super Admin only)
- ❌ Cannot access Team Management section
- ❌ Cannot modify system-wide settings

**Use Cases:**
- Team leads
- Department managers
- Shift supervisors
- Anyone who needs to manage their team's schedule and users

---

### 3. **User** 👤
**Purpose**: Standard user with team-specific access

**Key Characteristics:**
- Can view and edit their team's schedules
- Can manage employees, shifts, and training for their team
- Can create and edit schedules
- Cannot manage users
- Cannot access other teams' data
- Cannot change team assignments

**Database Flag**: `is_admin = false` AND `is_super_admin = false` in `user_profiles`

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

**Use Cases:**
- Regular team members who need to create and manage schedules
- Employees who need to view training records and assignments
- Day-to-day operations staff

---

### 4. **Display User** 📺
**Purpose**: Read-only access for TV displays

**Key Characteristics:**
- **Read-only access** (cannot create, edit, or delete)
- Can only view **today's schedule**
- Restricted to `/display` route only
- Cannot access any other pages
- Can be assigned to specific team (optional)
- Auto-refreshes every 30 seconds

**Database Flag**: `is_display_user = true` in `user_profiles`

**Permissions:**
- ✅ View today's schedule (read-only)
- ✅ Access display mode page
- ✅ Auto-refresh functionality

**Restrictions:**
- ❌ Read-only (no write access)
- ❌ Today's data only
- ❌ Restricted to display mode page
- ❌ Cannot navigate to other pages
- ❌ Cannot create, edit, or delete anything

**Use Cases:**
- TV displays in break rooms
- Public schedule monitors
- Kiosk displays
- Any read-only viewing scenario

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
| **Admin** | Cannot assign roles (Super Admin only) |
| **User** | Cannot assign roles |
| **Display User** | Cannot assign roles |

**Note**: Only Super Admins can create users, assign roles, and manage user accounts through the User Management interface.

### How to Assign Roles

#### Via Settings Page (Super Admin Only)

1. Navigate to **Settings** page (or **User Management** page for Super Admins)
2. Go to **User Management** section (only visible to Super Admins)
3. Click **Create User** or **Edit** existing user
4. Enter user details:
   - **Email address** (required)
   - **Password** (minimum 6 characters)
   - **Full Name** (optional)
   - **Team** (select from dropdown)
5. Select role:
   - ✅ **Super Admin** checkbox
   - ✅ **Admin** checkbox
   - ✅ **Display User** checkbox
   - (If none checked = regular User)
6. Save

**Note**: The username is automatically derived from the email address (part before '@').

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

**Setup:**
- 1 Super Admin (manages everything)
- 2 Admins (one per team)
- Multiple Users per team
- 1 Display User per location (optional)

**Result:**
- Each team only sees their own data
- Admins manage their team independently
- Super Admin can see everything

---

### Use Case 2: Single Team with Multiple Users

**Scenario**: One team, multiple schedulers

**Setup:**
- 1 Super Admin (or Admin)
- Multiple Users
- 1 Display User for TV

**Result:**
- All users see same data (same team)
- Users can collaborate on schedules
- Display shows team schedule

---

### Use Case 3: TV Display Only

**Scenario**: Public TV showing today's schedule

**Setup:**
- 1 Display User account
- Login on TV browser
- Auto-refresh enabled

**Result:**
- TV shows today's schedule
- No login required for viewers
- Can't be edited from TV
- Auto-updates every 30 seconds

---

### Use Case 4: Team-Specific TV Displays

**Scenario**: Each team has their own TV display

**Setup:**
- 1 Display User per team
- Each assigned to their team (`team_id` set)
- Login on respective TV

**Result:**
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

1. **Super Admin** creates user via Settings → User Management page
2. Enter user details:
   - **Email address** (required, used for login)
   - **Password** (minimum 6 characters)
   - **Full Name** (optional)
3. Select role(s):
   - Super Admin (if needed)
   - Admin (if team manager) - Note: Admin can view team data but cannot create users
   - Display User (if TV display)
   - None = Regular User
4. Assign to team (required for Admin/User, optional for Super Admin)
5. Username is automatically derived from email (part before '@')
6. User receives credentials and can login with their email address

### Changing a User's Role

1. **Super Admin** goes to Settings → User Management (or `/admin/users` page)
2. Finds user and clicks **Edit**
3. Updates role checkboxes (Super Admin, Admin, Display User)
4. Can also update team assignment, full name, and active status
5. Saves changes
6. User's permissions update immediately

### Removing Access

1. **Super Admin** goes to Settings → User Management (or `/admin/users` page)
2. Finds user and clicks **Edit**
3. Sets `is_active = false` to deactivate (user cannot login but data is preserved)
4. OR deletes user account (removes from auth and user_profiles)
5. User can no longer login after deactivation or deletion

---

## Troubleshooting

### User Can't See Their Team's Data

**Possible Causes:**
- User not assigned to a team (`team_id = NULL`)
- User's team doesn't have any data
- RLS policy issue

**Solution:**
- Assign user to team in Settings
- Verify team has data
- Check user's `team_id` in database

### User Can See All Teams' Data

**Possible Causes:**
- User is Super Admin
- User's `team_id = NULL` (should only happen for Super Admin)

**Solution:**
- Verify user's role in Settings
- Check `is_super_admin` flag in database

### Display User Can Access Other Pages

**Possible Causes:**
- Middleware not updated
- Display user flag not set correctly

**Solution:**
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

## Next Steps

- See [AUTHENTICATION.md](./AUTHENTICATION.md) for authentication setup
- Review [MULTI-TENANT.md](./MULTI-TENANT.md) for team isolation details
- Check [SECURITY.md](./SECURITY.md) for security best practices

---

**Last Updated**: January 2025

