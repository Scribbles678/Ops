# Multi-Tenant Implementation Plan
## Team-Based Scheduling with Username Authentication

## Requirements
- **6 departments** (teams)
- **2-3 users per team** (12-18 total users)
- **Team isolation**: Each team sees only their own data
- **Username-based login** (no email required)
- **Simple setup** (avoid extra security complexity)

---

## Architecture

### Database Structure

```
teams (new table)
├── id (UUID)
├── name (text) - "Department 1", "Department 2", etc.
├── created_at
└── updated_at

users (Supabase auth.users + custom profile)
├── id (UUID) - from auth.users
├── username (text) - unique username
├── team_id (UUID) - links to teams
├── full_name (text) - optional
└── created_at

All existing tables need:
├── team_id (UUID) - links to teams table
└── RLS policies filter by team_id
```

### Data Isolation
- Each team has isolated:
  - Employees
  - Job functions
  - Training records
  - Schedules
  - Shifts
  - Business rules
  - Everything!

---

## Authentication Approach

### Option A: Username with Placeholder Email (RECOMMENDED)

**How It Works:**
- User enters: `username` (e.g., "john.doe")
- We convert to: `username@internal.local` (placeholder email)
- Password: User sets their own
- Store actual username in user metadata

**Pros:**
- ✅ Works with Supabase Auth (requires email field)
- ✅ Users don't need real email
- ✅ Simple username/password
- ✅ No email verification needed
- ✅ Easy to implement

**Cons:**
- ⚠️ Uses placeholder email (but hidden from users)

**Implementation:**
```typescript
// Login
const username = "john.doe"
const email = `${username}@internal.local`
await supabase.auth.signInWithPassword({
  email: email,
  password: password
})

// Store username in metadata
await supabase.auth.updateUser({
  data: { username: username }
})
```

---

### Option B: Custom Username Field (More Complex)

**How It Works:**
- Create custom `user_profiles` table
- Link to Supabase auth.users
- Use username for login lookup
- More complex but cleaner

**Pros:**
- ✅ No placeholder emails
- ✅ Cleaner data model

**Cons:**
- ❌ More complex implementation
- ❌ Need custom login flow
- ❌ More security considerations

---

## Recommended: Option A (Placeholder Email)

**Why:**
- Simplest to implement
- Works with existing Supabase Auth
- Users never see the email
- Secure and simple

---

## Implementation Steps

### Step 1: Create Teams Table

```sql
CREATE TABLE teams (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert 6 departments
INSERT INTO teams (name) VALUES
  ('Department 1'),
  ('Department 2'),
  ('Department 3'),
  ('Department 4'),
  ('Department 5'),
  ('Department 6');
```

### Step 2: Create User Profiles Table

```sql
CREATE TABLE user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT NOT NULL UNIQUE,
  team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  full_name TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Users can only see their own profile
CREATE POLICY "Users can view own profile" 
ON user_profiles FOR SELECT 
USING (auth.uid() = id);

-- Users can update own profile
CREATE POLICY "Users can update own profile" 
ON user_profiles FOR UPDATE 
USING (auth.uid() = id);
```

### Step 3: Add team_id to All Tables

```sql
-- Add team_id to all existing tables
ALTER TABLE employees ADD COLUMN team_id UUID REFERENCES teams(id);
ALTER TABLE job_functions ADD COLUMN team_id UUID REFERENCES teams(id);
ALTER TABLE shifts ADD COLUMN team_id UUID REFERENCES teams(id);
ALTER TABLE schedule_assignments ADD COLUMN team_id UUID REFERENCES teams(id);
ALTER TABLE daily_targets ADD COLUMN team_id UUID REFERENCES teams(id);
ALTER TABLE employee_training ADD COLUMN team_id UUID REFERENCES teams(id);
ALTER TABLE pto_days ADD COLUMN team_id UUID REFERENCES teams(id);
ALTER TABLE shift_swaps ADD COLUMN team_id UUID REFERENCES teams(id);
ALTER TABLE business_rules ADD COLUMN team_id UUID REFERENCES teams(id);
ALTER TABLE preferred_assignments ADD COLUMN team_id UUID REFERENCES teams(id);

-- Add indexes
CREATE INDEX idx_employees_team ON employees(team_id);
CREATE INDEX idx_job_functions_team ON job_functions(team_id);
-- ... etc for all tables
```

### Step 4: Update RLS Policies

```sql
-- Example: Employees table
DROP POLICY IF EXISTS "Enable read access for all users" ON employees;
DROP POLICY IF EXISTS "Enable insert for all users" ON employees;
DROP POLICY IF EXISTS "Enable update for all users" ON employees;
DROP POLICY IF EXISTS "Enable delete for all users" ON employees;

-- New policies: Users can only access their team's data
CREATE POLICY "Users can view own team employees" 
ON employees FOR SELECT 
USING (
  team_id IN (
    SELECT team_id FROM user_profiles WHERE id = auth.uid()
  )
);

CREATE POLICY "Users can insert own team employees" 
ON employees FOR INSERT 
WITH CHECK (
  team_id IN (
    SELECT team_id FROM user_profiles WHERE id = auth.uid()
  )
);

-- Similar policies for UPDATE and DELETE
-- Repeat for ALL tables
```

### Step 5: Update Login Page

```typescript
// pages/login.vue
const username = ref('')
const password = ref('')

const handleLogin = async () => {
  // Convert username to placeholder email
  const email = `${username.value}@internal.local`
  
  const { data, error } = await supabase.auth.signInWithPassword({
    email: email,
    password: password.value
  })
  
  if (error) {
    error.value = 'Invalid username or password'
    return
  }
  
  // Redirect to home
  await router.push('/')
}
```

### Step 6: Update Sign-Up Page

```typescript
// pages/login.vue - Sign up flow
const handleSignUp = async () => {
  // Validate username is unique
  const email = `${username.value}@internal.local`
  
  const { data, error } = await supabase.auth.signUp({
    email: email,
    password: password.value,
    options: {
      data: {
        username: username.value,
        team_id: selectedTeamId.value // Admin selects team
      }
    }
  })
  
  // Create user profile
  if (data.user) {
    await supabase.from('user_profiles').insert({
      id: data.user.id,
      username: username.value,
      team_id: selectedTeamId.value
    })
  }
}
```

### Step 7: Create Helper Composable

```typescript
// composables/useTeam.ts
export const useTeam = () => {
  const supabase = useSupabaseClient()
  const user = useSupabaseUser()
  
  const currentTeam = ref(null)
  const loading = ref(false)
  
  const fetchCurrentTeam = async () => {
    if (!user.value) return null
    
    const { data } = await supabase
      .from('user_profiles')
      .select('*, teams(*)')
      .eq('id', user.value.id)
      .single()
    
    currentTeam.value = data?.teams
    return data?.teams
  }
  
  const getCurrentTeamId = async () => {
    if (!user.value) return null
    
    const { data } = await supabase
      .from('user_profiles')
      .select('team_id')
      .eq('id', user.value.id)
      .single()
    
    return data?.team_id
  }
  
  return {
    currentTeam,
    fetchCurrentTeam,
    getCurrentTeamId
  }
}
```

### Step 8: Update All Queries to Filter by Team

```typescript
// composables/useEmployees.ts
export const useEmployees = () => {
  const supabase = useSupabaseClient()
  const { getCurrentTeamId } = useTeam()
  
  const fetchEmployees = async () => {
    const teamId = await getCurrentTeamId()
    if (!teamId) return []
    
    const { data } = await supabase
      .from('employees')
      .select('*')
      .eq('team_id', teamId) // Filter by team
      .order('last_name')
    
    return data || []
  }
  
  // All CRUD operations filter by team_id
}
```

---

## User Flow

### Admin Creates User:
1. Admin goes to user management page
2. Enters: Username, Password, Team selection
3. System creates account with `username@internal.local`
4. User profile created with team_id
5. User receives credentials

### User Logs In:
1. User visits `/login`
2. Enters: Username (e.g., "john.doe"), Password
3. System converts to `john.doe@internal.local`
4. Supabase authenticates
5. User sees only their team's data

---

## Security Benefits

✅ **Team Isolation**: RLS policies ensure data separation
✅ **No Email Required**: Users don't need corporate email
✅ **Simple Username/Password**: Easy for users
✅ **Individual Accounts**: Each user has own credentials
✅ **Audit Trail**: Can track who made changes (by user_id)
✅ **Access Control**: Can revoke individual access

---

## Migration Plan

### For Existing Data:
1. Create teams table
2. Assign existing data to a default team (or create teams for each department)
3. Add team_id columns
4. Update RLS policies
5. Create user accounts for each team

---

## Next Steps

1. **Create database migration** for teams and user_profiles
2. **Update login page** to use username instead of email
3. **Add team_id to all tables**
4. **Update RLS policies** for team isolation
5. **Update all composables** to filter by team
6. **Create admin interface** for user/team management

---

## Questions

1. **Team Names**: What are the 6 department names?
2. **Initial Users**: Who should have access initially?
3. **Admin Access**: Should there be a super-admin who can see all teams?
4. **Data Migration**: Do you have existing data that needs to be assigned to teams?

---

**Ready to implement?** This approach gives you:
- ✅ Simple username/password (no email)
- ✅ Team-based data isolation
- ✅ Secure multi-tenant setup
- ✅ Minimal security complexity

