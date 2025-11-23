# Team Isolation Analysis & Implementation Plan

## Current Status

### ✅ **Already Filtering by Team (Composables)**
1. **`useEmployees.ts`** - ✅ Filters employees by `team_id`
2. **`useSchedule.ts`** - ✅ Filters shifts by `team_id`
3. **`useJobFunctions.ts`** - ✅ Filters job functions by `team_id`

### ❌ **NOT Filtering by Team (Composables)**
1. **`usePTO.ts`** - ❌ No team filtering
2. **`useShiftSwaps.ts`** - ❌ No team filtering
3. **`useBusinessRules.ts`** - ❌ No team filtering
4. **`usePreferredAssignments.ts`** - ❌ No team filtering
5. **`useEmployees.ts`** - Training functions (`getEmployeeTraining`, `getAllEmployeeTraining`) - ❌ No team filtering
6. **`useSchedule.ts`** - Schedule assignments and daily targets - ⚠️ Need to verify

### ✅ **Database Schema**
- All tables have `team_id` columns ✅
- RLS policies are set up for all tables ✅
- Policies use `get_user_team_id()` function ✅

### ⚠️ **Potential Issues**
1. **RLS Policies**: The `get_user_team_id()` function needs to be `SECURITY DEFINER` to avoid recursion
2. **Schedule Assignments**: Need to verify if schedule assignments are filtered by team_id
3. **Daily Targets**: Need to verify if daily targets are filtered by team_id
4. **Create Operations**: Need to ensure all create operations set `team_id` automatically

## Implementation Plan

### Phase 1: Fix Composables (Client-Side Filtering)
1. Update `usePTO.ts` to filter by team_id
2. Update `useShiftSwaps.ts` to filter by team_id
3. Update `useBusinessRules.ts` to filter by team_id
4. Update `usePreferredAssignments.ts` to filter by team_id
5. Update `useEmployees.ts` training functions to filter by team_id
6. Verify `useSchedule.ts` filters schedule_assignments and daily_targets by team_id

### Phase 2: Ensure Create Operations Set team_id
1. Update all create functions to automatically set `team_id` from user's team
2. Super admins should be able to specify `team_id` when creating

### Phase 3: Verify RLS Policies
1. Ensure `get_user_team_id()` is `SECURITY DEFINER STABLE`
2. Test that RLS policies are working correctly
3. Verify super admins can see all data

### Phase 4: Testing
1. Test with regular user (should only see their team's data)
2. Test with super admin (should see all data)
3. Test create operations (should auto-set team_id)
4. Test cross-team access (should be blocked)

## Tables That Need Team Isolation

1. ✅ `employees` - Already filtered
2. ✅ `job_functions` - Already filtered
3. ✅ `shifts` - Already filtered
4. ⚠️ `schedule_assignments` - Need to verify
5. ⚠️ `daily_targets` - Need to verify
6. ❌ `employee_training` - Not filtered in composables
7. ❌ `pto_days` - Not filtered
8. ❌ `shift_swaps` - Not filtered
9. ❌ `business_rules` - Not filtered
10. ❌ `preferred_assignments` - Not filtered

