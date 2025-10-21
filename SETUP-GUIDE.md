# Quick Setup Guide

Follow these steps to get your Operations Scheduling Tool up and running.

## Step 1: Set Up Supabase Database

1. Create a Supabase account at https://supabase.com (free)
2. Create a new project
3. Go to SQL Editor
4. Copy and paste the entire contents of `supabase-schema.sql`
5. Click "Run" to execute the SQL
6. Verify tables were created in the Table Editor

## Step 2: Configure Environment Variables

1. In your Supabase dashboard, go to **Project Settings** → **API**
2. Copy your:
   - Project URL
   - anon/public key

3. Create a `.env` file in the `scheduling-app` folder:
   ```bash
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-anon-key-here
   ```

## Step 3: Install and Run

```bash
# Navigate to the project folder
cd scheduling-app

# Install dependencies
npm install

# Start development server
npm run dev
```

Visit http://localhost:3000 to see your app!

## Step 4: Test the Application

1. **Add Employees**: Go to Details → Employees → Add some team members
2. **Add Job Functions**: Go to Details → Job Functions → Verify seed data or add more
3. **Set Training**: Go to Update Training → Check which employees are trained in which functions
4. **Create Schedule**: 
   - Click "Edit Today's Schedule"
   - Click "+ Add Assignment"
   - Fill in employee, job function, shift, and times
   - Save
5. **View Display**: Click "Open Display Mode" to see the TV view

## Step 5: Deploy to Netlify (Optional)

1. Push your code to GitHub
2. Sign up at https://netlify.com
3. Click "Add new site" → "Import an existing project"
4. Select your GitHub repo
5. Set build settings:
   - Build command: `npm run generate`
   - Publish directory: `.output/public`
6. Add environment variables:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
7. Deploy!

## Common Issues

### "Failed to connect to Supabase"
- Double-check your `.env` file has the correct URL and key
- Make sure there are no spaces or quotes around the values
- Restart the dev server after changing `.env`

### "No data showing"
- Verify the SQL schema was executed successfully
- Check the Supabase Table Editor to see if tables exist
- Check browser console for error messages

### Page shows blank
- Make sure you're using Node.js 18 or higher
- Try clearing browser cache
- Check terminal for any build errors

## Need Help?

- Check the full README.md for detailed documentation
- Review the Operations-Scheduling-Tool-MVP.md for feature specifications
- Check Supabase logs in your dashboard for database errors

---

**You're ready to schedule! 🎉**

