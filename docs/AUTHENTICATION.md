# Authentication System Documentation

Complete guide to the authentication system, security features, and configuration options.

---

## Table of Contents

1. [Overview](#overview)
2. [Current Implementation](#current-implementation)
3. [Security Features](#security-features)
4. [Alternative Options](#alternative-options)
5. [Medical/Regulated Environment Considerations](#medicalregulated-environment-considerations)
6. [Configuration & Management](#configuration--management)

---

## Overview

The Operations Scheduling Tool uses **Supabase Authentication** with the `@nuxtjs/supabase` module for secure, production-grade authentication.

### Key Features

- ✅ Individual user accounts (email/password)
- ✅ Password hashing handled by Supabase
- ✅ Secure session management (JWT tokens)
- ✅ Multi-tenant support with roles
- ✅ Automatic secure cookies
- ✅ Built-in rate limiting
- ✅ Session auto-refresh

---

## Current Implementation

### Architecture

The application uses **Supabase Auth** with the `@nuxtjs/supabase` module:

```
User → Login Form → Supabase Auth API → Supabase Database (auth.users)
                                      ↓
                              JWT Token Returned
                                      ↓
                              Stored in Secure Cookie
                                      ↓
                              Used for All Requests
```

### How It Works

1. **User Management**
   - Users stored in Supabase's `auth.users` table (managed by Supabase)
   - Each user has: email, password (hashed), user ID (UUID)
   - Password hashing handled automatically by Supabase

2. **Login Flow**
   ```typescript
   // Client-side (pages/login.vue)
   const { data, error } = await supabase.auth.signInWithPassword({
     email: email.value,
     password: password.value
   })
   
   // Supabase returns JWT token automatically
   // Token stored in secure cookie by Supabase client
   ```

3. **Session Management**
   - Supabase handles session automatically
   - JWT token stored in secure cookie
   - Token includes user ID, email, expiration
   - Auto-refreshes when needed

4. **Access Control**
   ```typescript
   // Check if user is authenticated
   const { data: { user } } = await supabase.auth.getUser()
   
   // Use in RLS policies
   // auth.uid() returns the current user's ID
   ```

### Email-Based Login

The application uses **email addresses** for authentication:

- Users enter their **email address** (e.g., "john.doe@company.com")
- Password: User sets their own (minimum 6 characters)
- Email is validated on the client side before submission
- Email is stored in both `auth.users` and `user_profiles.email` for easy lookup

**Implementation:**
```typescript
// Login (pages/login.vue)
const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
if (!emailRegex.test(email.value)) {
  error.value = 'Please enter a valid email address'
  return
}

const { data, error } = await supabase.auth.signInWithPassword({
  email: email.value.trim().toLowerCase(),
  password: password.value
})
```

**Note**: While the system stores a `username` field in `user_profiles` (derived from the email's local part), users must log in with their full email address.

---

## Security Features

### ✅ Implemented Security

1. **Password Security**
   - Passwords hashed by Supabase (bcrypt)
   - Never exposed in client code
   - No default passwords

2. **Session Security**
   - Secure cookies (HTTPS only)
   - SameSite protection (CSRF protection)
   - Automatic token refresh
   - HttpOnly handling by Supabase

3. **Rate Limiting**
   - Supabase Auth: 30 login attempts per 5 min/IP
   - Built-in brute force protection
   - Automatic account lockout

4. **Multi-Factor Authentication**
   - Supported by Supabase (can be enabled)
   - Optional for enhanced security

### Security Comparison: Module vs Custom

**Why `@nuxtjs/supabase` Module is More Secure:**

| Security Feature | Custom Plugin | @nuxtjs/supabase Module |
|-----------------|---------------|------------------------|
| **HttpOnly Flag** | ⚠️ Must set manually | ✅ Automatic |
| **Secure Flag** | ⚠️ Must set manually | ✅ Automatic |
| **SameSite** | ⚠️ Must set manually | ✅ Automatic |
| **Token Refresh** | ⚠️ Must implement | ✅ Automatic |
| **SSR Handling** | ⚠️ Must implement | ✅ Automatic |
| **Rate Limiting** | ⚠️ Must implement | ✅ Built-in (Supabase Auth) |
| **Security Updates** | ⚠️ You maintain | ✅ Nuxt team maintains |

**Benefits:**
- ✅ Automatic secure cookie configuration
- ✅ Less code = fewer security holes
- ✅ Security updates from Nuxt team
- ✅ Battle-tested by thousands of apps

---

## Alternative Options

### Option 1: SSO/SAML Integration (Best for Enterprise) ⭐

**How It Works:**
- Users authenticate with existing corporate credentials
- No separate accounts to manage
- Single sign-on experience
- Integrates with Active Directory, Okta, Azure AD, etc.

**Supabase Support:**
- ✅ Supports SAML SSO
- ✅ Supports OAuth providers (Microsoft, Google, etc.)
- ✅ Enterprise-ready

**Pros:**
- ✅ Uses existing corporate identity
- ✅ No password management needed
- ✅ Centralized user management
- ✅ Better for compliance/auditing
- ✅ Users already familiar with login
- ✅ Automatic user provisioning/deprovisioning

**Cons:**
- ⚠️ Requires SSO provider setup
- ⚠️ More complex initial setup
- ⚠️ May require IT department involvement

**Best For:**
- Large organizations with existing SSO
- Companies with IT department
- Compliance/audit requirements
- Multiple users

---

### Option 2: Microsoft/Google OAuth (Good for Medical Companies)

**How It Works:**
- Users sign in with Microsoft 365 or Google Workspace
- Uses existing corporate email accounts
- No separate passwords

**Supabase Support:**
- ✅ Built-in OAuth support
- ✅ Microsoft Azure AD
- ✅ Google Workspace
- ✅ Easy to configure

**Pros:**
- ✅ Uses corporate email accounts
- ✅ No password management
- ✅ Familiar login experience
- ✅ Easier than full SSO
- ✅ Automatic user creation

**Cons:**
- ⚠️ Requires OAuth app registration
- ⚠️ Users must have Microsoft/Google accounts
- ⚠️ Less control than SSO

**Best For:**
- Companies using Microsoft 365 or Google Workspace
- Medium-sized teams
- Want OAuth but not full SSO

---

### Option 3: Magic Links (Email-Based, No Password)

**How It Works:**
- User enters email
- Receives magic link via email
- Clicks link to sign in
- No password needed

**Supabase Support:**
- ✅ Built-in magic link support
- ✅ Passwordless authentication

**Pros:**
- ✅ No passwords to remember
- ✅ More secure than shared password
- ✅ Individual user accounts
- ✅ Email verification built-in

**Cons:**
- ⚠️ Requires email access
- ⚠️ Users must check email each time (or use "remember me")
- ⚠️ Email delivery issues possible

**Best For:**
- Users with reliable email access
- Want passwordless but not SSO
- Individual accounts needed

---

### Option 4: IP Whitelisting + Simple Password (Simple)

**How It Works:**
- Restrict access to company IP addresses
- Simple shared password (or individual passwords)
- Only accessible from company network

**Implementation:**
- Netlify IP restrictions (if on paid plan)
- Or Supabase IP allowlist
- Simple password auth

**Pros:**
- ✅ Very simple
- ✅ No user management
- ✅ Network-based security
- ✅ Low maintenance

**Cons:**
- ❌ Less secure (shared password)
- ❌ Doesn't track individual users
- ❌ Can't revoke individual access
- ❌ No audit trail per user

**Best For:**
- Small teams
- Internal-only access
- Low security requirements
- Quick setup

---

## Medical/Regulated Environment Considerations

### Recommendations by Scenario

#### Scenario A: Large Medical Company with IT Department
**Recommendation**: **SSO/SAML Integration**
- Best for compliance
- Uses existing corporate identity
- Centralized management
- Professional solution

#### Scenario B: Small Team, Microsoft/Google Users
**Recommendation**: **Microsoft/Google OAuth**
- Easy setup
- Uses corporate emails
- No password management
- Good balance of security and simplicity

#### Scenario C: Internal Network Only, Small Team
**Recommendation**: **IP Whitelisting + Simple Auth**
- Simplest solution
- Network-based security
- Low maintenance
- Good for small teams

#### Scenario D: Need Individual Accounts, No SSO
**Recommendation**: **Magic Links or Email/Password**
- Individual user tracking
- Better than shared password
- Works with any email

### Questions to Determine Best Approach

1. **How many users?**
   - < 10: Simple password or OAuth
   - 10-50: OAuth or SSO
   - 50+: SSO recommended

2. **Do users have corporate email?**
   - Yes: OAuth or SSO
   - No: Magic links or email/password

3. **Does company have SSO/Active Directory?**
   - Yes: SSO/SAML
   - No: OAuth or simple auth

4. **IT department involvement?**
   - Available: SSO
   - Not available: OAuth or simple

5. **Compliance requirements?**
   - Strict: SSO with audit logging
   - Moderate: OAuth
   - Low: Simple auth

6. **Need individual user tracking?**
   - Yes: SSO, OAuth, or email-based
   - No: Simple password OK

---

## Configuration & Management

### Initial Setup

1. **Enable Supabase Auth**
   - Go to Supabase Dashboard → Authentication → Providers
   - Enable Email provider
   - Configure email settings:
     - **Email confirmations**: OFF (for development) or ON (for production)

2. **Create Initial User(s)**

   **Option A: Via Sign-Up Page**
   - Visit `/login`
   - Click "Sign Up"
   - Create account with email/password

   **Option B: Via Supabase Dashboard**
   - Go to Authentication → Users
   - Click "Add User"
   - Create user manually

   **Option C: Via Admin Interface**
   - Super Admin creates users via User Management
   - Assigns email address, password, team, and role (username is auto-derived from email)

### User Management

#### Creating Users (Super Admin Only)

1. Navigate to **User Management** (Settings page or `/admin/users` page - Super Admin only)
2. Click **"+ Create User"**
3. Fill in:
   - **Email address** (required, used for login)
   - **Password** (min 6 characters)
   - **Full Name** (optional)
   - **Team** (select from dropdown)
   - **Role** (Super Admin, Admin, User, Display User)
4. Click **"Create User"**
5. Username is automatically derived from email (part before '@')

**Note**: Only Super Admins can create users. Admin role can view team users but cannot create new accounts.

#### Password Reset

**For Users:**
- Users can change their own password via Settings page
- Requires current password verification

**For Super Admins:**
- Super Admins can reset passwords for any user
- Done via User Management interface (Settings page or `/admin/users` page)
- Requires Super Admin privileges (server-side API restriction)

**Note**: Admin role cannot reset passwords - this requires Super Admin access.

### Environment Variables

Make sure your `.env` file has:
```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key  # For admin features (server-side only)
```

**Important**: The service role key should NEVER be exposed to the client. It's only used server-side in admin API routes.

### Display Mode Access

- `/display` is configured as a public route (no auth required by default)
- This allows TV displays to show schedules without login
- If you want to require auth for display mode, update middleware configuration

### Sign-Up Configuration

- Sign-up can be enabled or disabled
- If enabled: Users can self-register
- If disabled: Admin-only user creation
- Configure in Supabase Dashboard → Authentication → Settings

---

## Security Best Practices

### ✅ Implemented

1. **Individual Accounts**: Each user has their own credentials
2. **Password Hashing**: Handled by Supabase (bcrypt)
3. **Secure Sessions**: HTTPS-only cookies with SameSite protection
4. **Rate Limiting**: Built-in protection against brute force
5. **No Default Passwords**: All passwords must be set explicitly

### Recommendations

1. **Password Policy**
   - Enforce strong passwords (12+ characters)
   - Consider password complexity requirements
   - Regular password rotation (if policy requires)

2. **Multi-Factor Authentication**
   - Enable MFA for sensitive accounts
   - Use TOTP apps (Google Authenticator, Authy)

3. **Session Management**
   - Regular session timeouts
   - Logout on inactivity
   - Secure session invalidation

4. **Audit Logging**
   - Track login attempts
   - Monitor failed authentications
   - Log password changes

---

## Troubleshooting

### "Invalid login credentials"

**Possible Causes:**
- Incorrect email address or password
- User account is inactive
- User profile doesn't exist

**Solutions:**
- Verify credentials
- Check user is active in User Management
- Verify user profile exists in database

### "Account not found"

**Possible Causes:**
- User profile wasn't created
- Email address mismatch between auth account and user profile

**Solutions:**
- Create user profile via User Management
- Verify email address matches between auth.users and user_profiles tables

### "Account is inactive"

**Possible Causes:**
- User was deactivated by admin

**Solutions:**
- Reactivate user via User Management
- Contact admin to restore access

### Session Expires Too Quickly

**Possible Causes:**
- Supabase session timeout settings
- Browser cookie settings

**Solutions:**
- Check Supabase Auth settings
- Verify browser allows cookies
- Session auto-refreshes, but may require re-login

---

## Next Steps

- Review [ROLES.md](./ROLES.md) for role-based access control
- See [SECURITY.md](./SECURITY.md) for comprehensive security documentation
- Check [MULTI-TENANT.md](./MULTI-TENANT.md) for team isolation setup

---

**Last Updated**: January 2025

