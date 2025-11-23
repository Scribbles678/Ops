# Team Isolation Implementation Summary

## Overview
This document outlines the changes needed to ensure complete team-based data isolation across the application.

## Current Status

### ✅ Already Implemented
- **Database Schema**: All tables have `team_id` columns
- **RLS Policies**: All tables have RLS policies that filter by `team_id`
- **Composables with Team Filtering**:
  - `useEmployees.ts` - Employees ✅
  - `useSchedule.ts` - Shifts ✅, Schedule Assignments ✅
  - `useJobFunctions.ts` - Job Functions ✅

### ❌ Needs Implementation
1. **`usePTO.ts`** - PTO days not filtered by team
2. **`useShiftSwaps.ts`** - Shift swaps not filtered by team
3. **`useBusinessRules.ts`** - Business rules not filtered by team
4. **`usePreferredAssignments.ts`** - Preferred assignments not filtered by team
5. **`useEmployees.ts`** - Training functions not filtered by team
6. **`useSchedule.ts`** - Daily targets not filtered by team, copySchedule and fetchOldSchedulesForExport not filtered

## Implementation Details

### Pattern to Follow
All composables should:
1. Import `useTeam()` to get `getCurrentTeamId()` and `isSuperAdmin`
2. Filter queries by `team_id` unless user is super admin
3. Automatically set `team_id` when creating records (unless super admin specifies it)
4. Use the pattern:
   ```typescript
   const teamId = isSuperAdmin.value ? null : await getCurrentTeamId()
   if (teamId) {
     query = query.eq('team_id', teamId)
   }
   ```

### Special Cases
- **Employee Training**: Filter by employee's team_id (since training is linked to employees)
- **Schedule Assignments**: Already filtered, but need to ensure team_id is set on create
- **Daily Targets**: Need to filter by team_id

## Files to Update

1. `composables/usePTO.ts`
2. `composables/useShiftSwaps.ts`
3. `composables/useBusinessRules.ts`
4. `composables/usePreferredAssignments.ts`
5. `composables/useEmployees.ts` (training functions)
6. `composables/useSchedule.ts` (daily targets, copySchedule, fetchOldSchedulesForExport)

