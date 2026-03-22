# Setup Guide

Complete setup and configuration guide for the Operations Scheduling Tool.

---

## Table of Contents

1. [Initial Setup](#initial-setup)
2. [Environment Configuration](#environment-configuration)
3. [First Run & Testing](#first-run--testing)
4. [Database Cleanup Configuration](#database-cleanup-configuration)
5. [Password Management](#password-management)
6. [Deployment](#deployment)
7. [Troubleshooting](#troubleshooting)

---

## Initial Setup

### Step 1: Set Up Supabase Database

1. **Create Supabase Account**
   - Go to [supabase.com](https://supabase.com)
   - Sign up with GitHub/Google
   - Click "New Project"

2. **Create New Project**
   - **Name**: "operations-scheduling" (or your choice)
   - **Database Password**: Create a strong password (save this!)
   - **Region**: Choose closest to you
   - Click "Create new project"
   - Wait ~2 minutes for setup to complete

3. **Run Database Schema**
   - Click **SQL Editor** in the left sidebar
   - Click **"New Query"**
   - You'll need to run the table creation statements for each table
   - Open each file in `sql-schema/` folder (e.g., `teams.sql`, `user_profiles.sql`, `employees.sql`, etc.)
   - Copy the contents of each file and paste into the SQL Editor
   - Run each file in order (start with `teams.sql` and `user_profiles.sql`, then other tables)
   - After all tables are created, run `sql-schema/rls-policies.sql` to set up Row Level Security
   - Click **"Run"** (or press Ctrl+Enter) after each paste
   - You should see "Success. No rows returned"
   
   **Note**: See `sql-schema/README.md` for the complete list of schema files and their purposes.

4. **Verify Setup**
   - Go to **Table Editor** in Supabase dashboard
   - Verify tables were created:
     - `employees`
     - `job_functions`
     - `shifts`
     - `schedule_assignments`
     - `daily_targets`
     - `employee_training`
     - And other tables

---

## Environment Configuration

### Step 2: Get Your Supabase Credentials

1. In Supabase dashboard, click the **gear icon (⚙️)** for "Project Settings"
2. Click **"API"** in the left menu
3. Find and copy these two values:
   - **Project URL**: `https://xxxxx.supabase.co`
   - **anon public key**: Long string starting with `eyJ`

### Step 3: Create Your .env File

1. In the `scheduling-app` folder, create a file named `.env`
2. Add these lines (paste your actual values):

```bash
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

**Important Notes:**
- No quotes around values
- No spaces around the `=` sign
- Never commit `.env` to version control

### Step 4: Install Dependencies

Open your terminal/PowerShell in the `scheduling-app` folder and run:

```bash
npm install
```

This will install all required dependencies.

### Step 5: Start Development Server

```bash
npm run dev
```

The application will be available at `http://localhost:3000`

---

## First Run & Testing

### Test the Application

Try these steps in order:

1. **Add Employees**
   - Go to **Details** → **Employees** tab
   - Sample employees are already there from seed data
   - Add your real employees if needed

2. **Configure Job Functions**
   - Go to **Details** → **Job Functions** tab
   - Sample functions are loaded (RT-Pick, EM9 Packsize, etc.)
   - Edit colors and rates as needed
   - Add your specific job functions

3. **Set Up Training**
   - Click **"Update Training"** from the home page
   - Check boxes to show which employees are trained in which functions
   - Click **"Save Changes"**

4. **Create a Schedule**
   - Click **"Edit Today's Schedule"**
   - Click **"+ Add Assignment"**
   - Select: Employee, Job Function, Shift, Times
   - Click **"Create"**
   - See it appear in the schedule!

5. **Set Daily Targets**
   - In the schedule sidebar, enter target units for each job function
   - Watch the labor hours calculation update in real-time

6. **View Display Mode**
   - Click **"Open Display Mode (TV View)"**
   - See the full-screen view
   - This refreshes automatically every 30 seconds

---

## Database Cleanup Configuration

The system automatically archives and deletes schedule data older than 1 month to maintain optimal database performance.

### What Gets Cleaned Up

- **Schedule Assignments**: Employee job assignments older than 1 month
- **Daily Targets**: Production targets older than 1 month
- **Retention Period**: 1 month (30 days)
- **Cleanup Frequency**: Weekly (recommended)

### Database Setup

1. **Run the Cleanup SQL**
   - Execute `sql-schema/database-cleanup.sql` in your Supabase SQL Editor
   - This creates:
     - Archive tables for old data
     - Cleanup functions
     - Monitoring views
     - Logging system

2. **Verify Setup**
   - Check that these functions exist:
     - `cleanup_old_schedules_with_logging()`
     - `get_cleanup_stats()`
     - `get_cleanup_log()`
     - `cleanup_status` view

### Manual Cleanup

#### Using the Admin Interface

1. Go to **Database Cleanup** from the main page
2. View current statistics and data status
3. Click **"Run Cleanup Now"** to manually trigger cleanup
4. Monitor the cleanup log for results

#### Using SQL (Advanced)

```sql
-- Run cleanup manually
SELECT * FROM cleanup_old_schedules_with_logging();

-- Check statistics
SELECT * FROM get_cleanup_stats();

-- View cleanup log
SELECT * FROM cleanup_log ORDER BY cleanup_date DESC LIMIT 10;
```

### Automated Weekly Cleanup

#### Option 1: Supabase Edge Functions (Recommended)

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

#### Option 2: External Cron Service

Use services like:
- **cron-job.org** (free)
- **EasyCron** (paid)
- **GitHub Actions** (free for public repos)

Set up a weekly webhook to call your cleanup endpoint.

### Data Recovery

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

---

## Password Management

### Changing Application Password

The application uses Supabase Authentication with individual user accounts. Password management is handled through:

1. **User Settings Page**
   - Users can change their own password via the Settings page
   - Requires current password verification

2. **Super Admin Password Reset**
   - Super Admins can reset passwords for any user
   - Done via User Management interface (Settings page or `/admin/users` page)
   - Requires Super Admin privileges (server-side API restriction)

### Security Notes

- Use strong passwords (12+ characters, mixed case, numbers, symbols)
- Never commit passwords to version control
- Consider using a password manager to generate secure passwords
- For multiple organizations, user management is handled through the admin interface

---

## Deployment

### Deploy to Netlify

1. **Push Code to GitHub**
   ```bash
   git init
   git add .
   git commit -m "Initial commit"
   git branch -M main
   git remote add origin your-repo-url
   git push -u origin main
   ```

2. **Deploy to Netlify**
   - Go to [netlify.com](https://netlify.com) and sign in
   - Click **"Add new site"** → **"Import an existing project"**
   - Connect your GitHub repository
   - Configure build settings:
     - **Build command**: `npm run generate`
     - **Publish directory**: `.output/public`
   - Add environment variables:
     - `SUPABASE_URL`: Your Supabase project URL
     - `SUPABASE_ANON_KEY`: Your Supabase anon key
   - Click **"Deploy site"**

3. **Your App is Live**
   - Available at `your-site-name.netlify.app`
   - HTTPS is automatically enabled
   - Automatic deployments on every Git push

### Environment Variables in Production

Make sure to set these in Netlify:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY` (if using admin features - server-side only)

**Important**: The service role key should NEVER be exposed to the client. It's only used server-side.

---

## Troubleshooting

### "Failed to fetch" or "Failed to connect to Supabase"

**Possible Causes:**
- Incorrect `.env` file values
- Extra spaces or quotes in `.env` file
- Supabase project is paused or inactive

**Solutions:**
- Double-check your `.env` file has the correct URL and key
- Make sure there are no spaces or quotes around the values
- Restart the dev server after changing `.env`
- Verify your Supabase project is active in the dashboard

### "No data showing" or Blank Page

**Possible Causes:**
- SQL schema wasn't executed successfully
- Tables don't exist
- JavaScript errors in browser

**Solutions:**
- Verify the SQL schema was executed successfully
- Check the Supabase Table Editor to see if tables exist
- Check browser console (F12) for error messages
- Check terminal for any build errors

### "Can't create assignments"

**Possible Causes:**
- Employees don't exist
- Job functions don't exist
- Employee not trained in that function

**Solutions:**
- Make sure employees exist in the Employees tab
- Make sure job functions exist in the Job Functions tab
- Check that employee is trained in that function (Update Training page)

### Page Shows Blank or Errors

**Possible Causes:**
- Node.js version too old
- Build errors
- Browser cache issues

**Solutions:**
- Make sure you're using Node.js 18 or higher (`node --version`)
- Check terminal for any build errors
- Try clearing browser cache and reload
- Check browser console (F12) for JavaScript errors

### Database Connection Errors

**Possible Causes:**
- Supabase project is paused
- Incorrect environment variables
- Network issues

**Solutions:**
- Check Supabase dashboard for service status
- Verify environment variables in Netlify (for production) or `.env` (for local)
- Check Supabase project is active (not paused)
- Verify API keys are correct

### Build Fails on Netlify

**Possible Causes:**
- Node.js version mismatch
- Missing environment variables
- Build errors

**Solutions:**
- Check Netlify build logs
- Verify Node.js version matches locally
- Check for missing environment variables
- Test build locally: `npm run build`

---

## Next Steps

After setup:

1. **Configure Your Data**
   - Add your real employees
   - Set up actual job functions and colors
   - Configure employee training

2. **Set Up Multi-Tenant** (if needed)
   - See [MULTI-TENANT.md](./MULTI-TENANT.md) for team isolation setup

3. **Review Security**
   - See [SECURITY.md](./SECURITY.md) for security best practices

4. **Set Up Monitoring**
   - See [MAINTENANCE.md](./MAINTENANCE.md) for maintenance procedures

---

## Need Help?

- Check the full [README.md](../README.md) for detailed documentation
- Review [PROJECT-SUMMARY.md](../PROJECT-SUMMARY.md) for feature overview
- Check Supabase logs in your dashboard for database errors
- Review [Troubleshooting](#troubleshooting) section above

---

**You're ready to schedule! 🎉**

