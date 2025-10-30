# Database Cleanup Setup Guide

## Overview
This system automatically archives and deletes schedule data older than 1 month to maintain optimal database performance and comply with data retention policies.

## What Gets Cleaned Up
- **Schedule Assignments**: Employee job assignments older than 1 month
- **Daily Targets**: Production targets older than 1 month
- **Retention Period**: 1 month (30 days)
- **Cleanup Frequency**: Weekly (recommended)

## Database Setup

### 1. Run the Cleanup SQL
Execute the `database-cleanup.sql` file in your Supabase SQL Editor to create:
- Archive tables for old data
- Cleanup functions
- Monitoring views
- Logging system

### 2. Verify Setup.
Check that these functions exist in your database:
- `cleanup_old_schedules_with_logging()`
- `get_cleanup_stats()`
- `get_cleanup_log()`
- `cleanup_status` view

## Manual Cleanup

### Using the Admin Interface
1. Go to **Database Cleanup** from the main page
2. View current statistics and data status
3. Click **"Run Cleanup Now"** to manually trigger cleanup
4. Monitor the cleanup log for results

### Using SQL (Advanced)
```sql
-- Run cleanup manually
SELECT * FROM cleanup_old_schedules_with_logging();

-- Check statistics
SELECT * FROM get_cleanup_stats();

-- View cleanup log
SELECT * FROM cleanup_log ORDER BY cleanup_date DESC LIMIT 10;
```

## Automated Weekly Cleanup

### Option 1: Supabase Edge Functions (Recommended)
Create a Supabase Edge Function that runs weekly:

1. **Create Edge Function**:
```typescript
// supabase/functions/weekly-cleanup/index.ts
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

Deno.serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  )

  try {
    const { data, error } = await supabase.rpc('cleanup_old_schedules_with_logging')
    
    if (error) throw error
    
    return new Response(JSON.stringify({
      success: true,
      archived_assignments: data[0].archived_assignments,
      archived_targets: data[0].archived_targets
    }), {
      headers: { 'Content-Type': 'application/json' }
    })
  } catch (error) {
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})
```

2. **Deploy Function**:
```bash
supabase functions deploy weekly-cleanup
```

3. **Set up Cron Job** (using external service like cron-job.org):
- URL: `https://your-project.supabase.co/functions/v1/weekly-cleanup`
- Schedule: Weekly (e.g., Sundays at 2 AM)
- Headers: `Authorization: Bearer YOUR_ANON_KEY`

### Option 2: External Cron Service
Use services like:
- **cron-job.org** (free)
- **EasyCron** (paid)
- **GitHub Actions** (free for public repos)

Set up a weekly webhook to call your cleanup endpoint.

### Option 3: Server Cron Job
If you have a server, add to crontab:
```bash
# Run cleanup every Sunday at 2 AM
0 2 * * 0 curl -X POST "https://your-project.supabase.co/functions/v1/weekly-cleanup" \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```

## Monitoring

### Admin Dashboard
- **Current Records**: Live count of active schedules
- **Archived Records**: Count of archived data
- **Cleanup Status**: Shows what will be cleaned up
- **Cleanup Log**: History of all cleanup operations

### Key Metrics to Watch
- **Database Size**: Monitor growth over time
- **Query Performance**: Ensure queries remain fast
- **Archive Growth**: Track archived data volume
- **Cleanup Success Rate**: Monitor for failures

## Data Recovery

### If You Need Old Data
Archived data is preserved in separate tables:
- `schedule_assignments_archive`
- `daily_targets_archive`

To restore data:
```sql
-- Restore specific date range
INSERT INTO schedule_assignments 
SELECT id, employee_id, job_function_id, shift_id, schedule_date,
       assignment_order, start_time, end_time, created_at, updated_at
FROM schedule_assignments_archive 
WHERE schedule_date BETWEEN '2024-01-01' AND '2024-01-31';
```

## Troubleshooting

### Common Issues
1. **Cleanup Fails**: Check Supabase logs for errors
2. **No Data Archived**: Verify cutoff date calculation
3. **Performance Issues**: Check database indexes
4. **Permission Errors**: Verify RLS policies

### Debug Commands
```sql
-- Check what will be cleaned up
SELECT COUNT(*) FROM schedule_assignments 
WHERE schedule_date < CURRENT_DATE - INTERVAL '1 month';

-- Check archive tables
SELECT COUNT(*) FROM schedule_assignments_archive;

-- View recent cleanup logs
SELECT * FROM cleanup_log ORDER BY cleanup_date DESC LIMIT 5;
```

## Security Notes
- Archive tables have read-only access for most users
- Only admin users can run cleanup functions
- All cleanup operations are logged
- Data is archived before deletion (recoverable)

## Cost Considerations
- **Supabase Storage**: Archived data still counts toward storage limits
- **Edge Functions**: Minimal cost for weekly execution
- **Database Performance**: Cleanup improves query performance
- **Backup Size**: Smaller backups due to data reduction

## Best Practices
1. **Test First**: Run manual cleanup before automating
2. **Monitor Logs**: Check cleanup success regularly
3. **Backup Before**: Ensure you have backups before first cleanup
4. **Gradual Rollout**: Start with longer retention, then reduce
5. **Document Changes**: Keep track of retention policy changes
