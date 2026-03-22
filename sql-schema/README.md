# SQL Schema Documentation

This folder contains documentation of the current database schema, RLS policies, functions, and triggers.

## Structure

Each table has its own file where you can paste the current CREATE TABLE statement and any related definitions.

## Files

### Table Definitions
- `business_rules.sql`
- `cleanup_log.sql`
- `cleanup_status.sql`
- `daily_targets.sql`
- `daily_targets_archive.sql`
- `employee_training.sql`
- `employees.sql`
- `job_functions.sql`
- `preferred_assignments.sql`
- `pto_days.sql`
- `schedule_assignments.sql`
- `schedule_assignments_archive.sql`
- `shift_swaps.sql`
- `shifts.sql`
- `target_hours.sql`
- `teams.sql`
- `user_profiles.sql`

### Other Files
- `rls-policies.sql` - All Row Level Security policies
- `functions.sql` - Custom database functions
- `triggers.sql` - Database triggers

## How to Use

1. For each table file, paste your current CREATE TABLE statement
2. Include any indexes, constraints, or related definitions
3. Update `rls-policies.sql` with all RLS policies
4. Update `functions.sql` with all custom functions
5. Update `triggers.sql` with all triggers

These files are for **documentation only** - they show the current state of your database.

---

**Last Updated**: January 2025

