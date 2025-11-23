# Issue 4.5: No Audit Logging - Analysis

**Status**: Analysis Phase  
**Risk Level**: 🟡 MEDIUM  
**Priority**: Medium

---

## Current State Assessment

### ❌ What's Missing

**No tracking of data modifications:**
- ❌ No record of who created/updated/deleted records
- ❌ No timestamp of when changes were made
- ❌ No way to trace data modifications
- ❌ Cannot identify who made specific changes
- ❌ No audit trail for compliance or troubleshooting

### Current Situation

**What happens now:**
- Data is created, updated, and deleted
- No record of who made the change
- No record of when the change was made
- No way to rollback or investigate issues
- Cannot answer "Who changed this?" or "When was this changed?"

**Impact:**
- Cannot trace security incidents
- Cannot investigate data corruption
- Cannot comply with audit requirements
- Cannot track user activity
- Difficult to troubleshoot issues

---

## What Audit Logging Should Track

### 1. **Data Modifications**
- **CREATE**: Who created a record and when
- **UPDATE**: Who updated a record, what changed, and when
- **DELETE**: Who deleted a record and when

### 2. **User Actions**
- Login/logout events
- Failed login attempts
- Permission changes
- Role assignments

### 3. **Critical Operations**
- User creation/deletion
- Team creation/deletion
- Password resets
- Bulk operations

---

## Proposed Solution

### Option 1: Database Triggers (Recommended)
**How it works:**
- PostgreSQL triggers automatically log all changes
- No code changes needed in application
- Captures ALL changes (even direct database access)
- Cannot be bypassed

**Pros:**
- ✅ Automatic (no code changes)
- ✅ Comprehensive (captures everything)
- ✅ Cannot be bypassed
- ✅ Works even with direct database access

**Cons:**
- ⚠️ Requires database-level implementation
- ⚠️ May need to handle large log tables

---

### Option 2: Application-Level Logging
**How it works:**
- Add logging calls in composables/functions
- Log before/after each data modification
- Store logs in separate audit table

**Pros:**
- ✅ More control over what's logged
- ✅ Can include business context
- ✅ Easier to customize

**Cons:**
- ⚠️ Requires code changes everywhere
- ⚠️ Can be missed if code is bypassed
- ⚠️ More maintenance

---

### Option 3: Hybrid Approach (Best)
**How it works:**
- Database triggers for automatic logging (all changes)
- Application-level logging for business context (user actions, etc.)

**Pros:**
- ✅ Comprehensive coverage
- ✅ Automatic + contextual
- ✅ Best of both worlds

**Cons:**
- ⚠️ More complex to implement
- ⚠️ More storage needed

---

## Recommended Implementation: Option 1 (Database Triggers)

**Why:**
- Simplest to implement
- Most comprehensive
- Cannot be bypassed
- Works automatically

**What to log:**
1. **Table**: `audit_logs`
2. **Fields**:
   - `id` (UUID, primary key)
   - `table_name` (which table was changed)
   - `record_id` (which record was changed)
   - `action` (INSERT, UPDATE, DELETE)
   - `user_id` (who made the change)
   - `old_data` (JSON of old values - for UPDATE/DELETE)
   - `new_data` (JSON of new values - for INSERT/UPDATE)
   - `changed_fields` (array of field names that changed)
   - `created_at` (when the change was made)
   - `team_id` (for team isolation)

3. **Triggers**: One trigger per table (or generic trigger function)

---

## Implementation Plan

### Step 1: Create Audit Logs Table
- Create `audit_logs` table with all necessary fields
- Add indexes for performance
- Set up RLS policies (team-based access)

### Step 2: Create Generic Audit Trigger Function
- Function that logs changes automatically
- Handles INSERT, UPDATE, DELETE
- Captures old/new data as JSON
- Identifies changed fields

### Step 3: Add Triggers to All Tables
- Add triggers to:
  - `employees`
  - `job_functions`
  - `schedule_assignments`
  - `shifts`
  - `employee_training`
  - `pto_days`
  - `shift_swaps`
  - `business_rules`
  - `preferred_assignments`
  - `daily_targets`
  - `user_profiles`
  - `teams`

### Step 4: Create Audit Log Viewing Interface
- Add audit log viewer to Settings page (super admins only)
- Filter by table, user, date range
- Show before/after values
- Export audit logs

---

## Storage Considerations

### How Much Storage?
**Estimate:**
- Each audit log entry: ~1-2 KB
- 1000 changes/day = ~1-2 MB/day
- 30 days = ~30-60 MB
- 1 year = ~365-730 MB

**Recommendation:**
- Keep audit logs for 90 days (configurable)
- Archive older logs to separate table
- Can export before deletion

---

## Security Considerations

### Who Can View Audit Logs?
- **Super Admins**: Can view all audit logs
- **Admins**: Can view audit logs for their team
- **Users**: Cannot view audit logs

### RLS Policies
- Audit logs filtered by `team_id`
- Super admins can see all
- Regular users cannot access

---

## Benefits

### 1. **Security**
- Track who accessed/modified data
- Identify suspicious activity
- Investigate security incidents

### 2. **Compliance**
- Meet audit requirements
- Track data changes
- Demonstrate accountability

### 3. **Troubleshooting**
- Identify when data was changed
- See what changed
- Rollback if needed

### 4. **Accountability**
- Know who made changes
- Track user activity
- Prevent unauthorized changes

---

## Questions to Answer

1. **How long to keep audit logs?**
   - Recommendation: 90 days (configurable)

2. **What level of detail?**
   - Recommendation: Full before/after for all changes

3. **Who can view audit logs?**
   - Recommendation: Super admins only (or admins for their team)

4. **Should we log SELECT operations?**
   - Recommendation: No (too much data, not critical)

---

## Next Steps

1. **Review this analysis**
2. **Approve implementation approach**
3. **Create audit logs table**
4. **Create trigger function**
5. **Add triggers to all tables**
6. **Create audit log viewer UI**
7. **Test and verify**

---

**Ready to proceed?** Let me know if you want to:
- Start with database triggers (automatic logging)
- Add application-level logging
- Or both (hybrid approach)

