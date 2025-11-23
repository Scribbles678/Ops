# Issue 4.4: No Server-Side Input Validation - Analysis

**Status**: Analysis Phase  
**Risk Level**: 🟡 MEDIUM  
**Priority**: Medium

---

## Current State Assessment

### ✅ What We Have

#### 1. Client-Side Validation
- **File**: `utils/validationRules.ts`
- **Validates**:
  - Assignment duration (minimum 30 minutes)
  - Employee training requirements
  - Time conflicts (no overlapping assignments)
  - Meter job function special handling

#### 2. Database Constraints (Basic)
- **Foreign Keys**: Enforce referential integrity
  - `employee_id` → `employees(id)`
  - `job_function_id` → `job_functions(id)`
  - `shift_id` → `shifts(id)`
  - `team_id` → `teams(id)`

- **NOT NULL Constraints**: Required fields
  - Most primary fields are NOT NULL

- **UNIQUE Constraints**: Prevent duplicates
  - `daily_targets`: `(schedule_date, job_function_id)`
  - `preferred_assignments`: `(employee_id, job_function_id)`
  - `user_profiles`: `username`, `email`

#### 3. Type Safety
- **TypeScript**: Provides compile-time type checking
- **Database Types**: PostgreSQL enforces data types

---

## ❌ What's Missing

### 1. No CHECK Constraints
**Problem**: No validation of data ranges or formats at database level

**Examples of Missing Validations**:
- ❌ Assignment duration (should be > 0, end_time > start_time)
- ❌ Time ranges (start_time < end_time)
- ❌ Staff counts (min_staff >= 0, max_staff >= min_staff)
- ❌ Email format validation
- ❌ Date ranges (schedule_date not in past beyond retention)
- ❌ Priority values (reasonable ranges)
- ❌ Block size (positive values)

### 2. No Database Triggers for Business Rules
**Problem**: Complex validation rules only enforced client-side

**Examples**:
- ❌ Employee must be trained in job function (before assignment)
- ❌ No overlapping assignments for same employee
- ❌ PTO dates must be valid (start <= end)
- ❌ Shift swap dates must be in future
- ❌ Business rule time slots must be valid (start < end)

### 3. No Input Sanitization
**Problem**: User-generated content not sanitized

**Examples**:
- ❌ Text fields (names, notes) could contain XSS
- ❌ No length limits enforced at database level
- ❌ No HTML/strip tag validation

### 4. No Server-Side Validation Functions
**Problem**: All validation happens client-side, can be bypassed

**Examples**:
- ❌ User creation validation (email format, password strength)
- ❌ Team assignment validation
- ❌ Schedule assignment validation

---

## Risk Assessment

### Current Vulnerabilities

1. **Data Corruption**
   - Client-side validation can be bypassed
   - Malicious users could insert invalid data
   - Could break application logic

2. **SQL Injection** (Mitigated)
   - Supabase uses parameterized queries
   - Low risk, but additional validation helps

3. **XSS Attacks** (Potential)
   - User-generated text not sanitized
   - Could inject malicious scripts in notes/names

4. **Business Rule Violations**
   - Invalid schedules could be created
   - Data integrity issues

---

## Proposed Solution

### Phase 1: Database-Level Constraints (Recommended First)

Add CHECK constraints to enforce basic data rules:

**Tables to Update**:
1. `schedule_assignments` - Time validation, duration checks
2. `employees` - Name length, active status
3. `job_functions` - Name length, color format
4. `business_rules` - Time slot validation, staff count validation
5. `pto_days` - Date range validation
6. `shift_swaps` - Date validation
7. `daily_targets` - Target units validation
8. `user_profiles` - Email format, username length

### Phase 2: Database Triggers (For Complex Rules)

Add triggers for business logic validation:

**Triggers Needed**:
1. **Assignment Validation Trigger**
   - Check employee training before insert/update
   - Check for time conflicts
   - Validate duration

2. **Business Rule Validation Trigger**
   - Validate time slot ranges
   - Validate staff counts
   - Validate priority values

3. **PTO Validation Trigger**
   - Validate date ranges
   - Check for conflicts

### Phase 3: Input Sanitization (Optional)

Add sanitization for user-generated content:
- Strip HTML tags from text fields
- Enforce length limits
- Validate email formats

---

## Implementation Plan

### Step 1: Add CHECK Constraints

Create SQL migration with CHECK constraints for:
- Time validations (start < end)
- Duration validations (minimum values)
- Range validations (positive numbers, reasonable limits)
- Format validations (email, time format)

### Step 2: Add Validation Triggers

Create triggers that:
- Enforce business rules
- Prevent invalid data insertion
- Provide clear error messages

### Step 3: Add Length Limits

Add VARCHAR length limits where appropriate:
- Employee names
- Job function names
- Notes fields
- Usernames

### Step 4: Test & Verify

- Test with invalid data (should be rejected)
- Test with valid data (should work)
- Verify error messages are clear

---

## Files to Create/Modify

1. **New SQL File**: `sql-schema/add-server-side-validation.sql`
   - CHECK constraints
   - Validation triggers
   - Length limits

2. **Update**: Existing schema files (if needed)
   - Add constraints to existing tables

---

## Estimated Impact

### Benefits
- ✅ Data integrity enforced at database level
- ✅ Cannot bypass validation (even with direct DB access)
- ✅ Clear error messages for invalid data
- ✅ Prevents data corruption

### Considerations
- ⚠️ May need to update existing invalid data first
- ⚠️ Some constraints may need to be added gradually
- ⚠️ Need to test thoroughly to avoid breaking existing functionality

---

## Questions to Answer

1. **Should we validate existing data first?**
   - Check for any invalid data in current database
   - Clean up before adding constraints

2. **How strict should validation be?**
   - Strict (reject invalid data) vs. Lenient (warn but allow)
   - Recommendation: Strict for new data, lenient for existing

3. **What about backward compatibility?**
   - Existing data may not meet new constraints
   - May need migration path

---

## Next Steps

1. **Review this analysis**
2. **Decide on validation strictness**
3. **Approve implementation approach**
4. **Create SQL migration file**
5. **Test on development database first**

---

**Ready to proceed?** Let me know if you want to:
- Start with CHECK constraints (simpler, safer)
- Add triggers for complex rules
- Or both

