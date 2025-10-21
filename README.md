# Operations Scheduling Tool - MVP

A modern web-based scheduling application for distribution center operations, built with Nuxt 3, Vue 3, Supabase, and Tailwind CSS.

## 🚀 Features

- **Landing Page**: Quick access to all main features
- **Update Training**: Manage employee job function training matrix
- **Details Page**: Configure job functions, view shifts, and manage employees
- **Schedule Management**: Create and edit daily schedules with drag-and-drop functionality
- **Labor Hours Tracking**: Real-time calculation of staffing levels vs targets
- **Copy Schedule**: Duplicate today's schedule for tomorrow
- **Display Mode**: Full-screen TV view with auto-refresh every 30 seconds
- **Validation**: Ensure employees are trained, prevent double-booking
- **Color Coding**: Visual job function identification

## 📋 Prerequisites

- Node.js 18+ installed
- A Supabase account (free tier works great)
- Git for version control

## 🛠️ Setup Instructions

### 1. Supabase Setup

1. Go to [supabase.com](https://supabase.com) and create a new project
2. Wait for the database to initialize (takes ~2 minutes)
3. Go to the SQL Editor in your Supabase dashboard
4. Copy the entire contents of `supabase-schema.sql` and run it in the SQL Editor
5. This will create all tables, relationships, and seed data

### 2. Environment Variables

1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Get your Supabase credentials:
   - Go to Project Settings → API
   - Copy the `Project URL` and `anon/public` key

3. Update `.env` with your credentials:
   ```
   SUPABASE_URL=your_project_url_here
   SUPABASE_ANON_KEY=your_anon_key_here
   ```

### 3. Install Dependencies

```bash
npm install
```

### 4. Run Development Server

```bash
npm run dev
```

The application will be available at `http://localhost:3000`

## 📱 Pages & Routes

- `/` - Landing page with main navigation
- `/training` - Employee training management
- `/details` - Job functions, shifts, and employee configuration
- `/schedule/[date]` - Edit schedule for a specific date
  - Example: `/schedule/2025-10-21`
- `/schedule/tomorrow` - Create tomorrow's schedule (blank or copy)
- `/display` - TV display mode (read-only, auto-refresh)

## 🎨 Database Schema

The application uses 6 main tables:

1. **employees** - Employee information
2. **job_functions** - Job roles with colors and productivity rates
3. **employee_training** - Junction table for employee-job training
4. **shifts** - Shift schedules with break times
5. **schedule_assignments** - Daily employee assignments
6. **daily_targets** - Production targets by job function

See `supabase-schema.sql` for the complete schema.

## 🚢 Deployment (Netlify)

### 1. Push to GitHub

```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin your-repo-url
git push -u origin main
```

### 2. Deploy to Netlify

1. Go to [netlify.com](https://netlify.com) and sign in
2. Click "Add new site" → "Import an existing project"
3. Connect your GitHub repository
4. Configure build settings:
   - **Build command**: `npm run generate`
   - **Publish directory**: `.output/public`
5. Add environment variables:
   - `SUPABASE_URL`: Your Supabase project URL
   - `SUPABASE_ANON_KEY`: Your Supabase anon key
6. Click "Deploy site"

Your app will be live at `your-site-name.netlify.app`

## 📖 Usage Guide

### Managing Employees & Job Functions

1. Click **Details** from the home page
2. Use the **Job Functions** tab to add/edit job roles and set colors
3. Use the **Employees** tab to add/edit team members
4. View configured shifts in the **Shifts** tab

### Setting Up Training

1. Click **Update Training** from the home page
2. Check boxes to indicate which employees are trained in which functions
3. Click **Save Changes** to persist updates

### Creating Schedules

1. Click **Edit Today's Schedule** to modify current day
2. Click **Make Tomorrow's Schedule** to create next day's schedule
3. Choose to start blank or copy today's schedule
4. Click **+ Add Assignment** to create new assignments
5. Fill in: Employee, Job Function, Shift, Start/End times
6. Set daily targets in the sidebar for labor hour calculations

### Display Mode for TVs

1. Click **Open Display Mode** from the home page
2. Full-screen the browser (F11 on most browsers)
3. The display auto-refreshes every 30 seconds
4. Shows today's schedule in a clean, large format

## 🎯 Key Validation Rules

- ✅ Employees can only be assigned to jobs they're trained in
- ✅ Employees cannot be double-booked (same time, different jobs)
- ✅ Assignment duration must be at least 30 minutes
- ✅ Assignments must fit within shift boundaries

## 🎨 Customization

### Colors

Job function colors are fully customizable in the Details page. Use the color picker to set any hex color.

### Shifts

Shifts are pre-configured but can be edited directly in Supabase if needed. Future versions will include a shift editor UI.

## 🔧 Development

### Project Structure

```
scheduling-app/
├── app/
│   └── app.vue                 # Root app component
├── assets/
│   └── css/
│       └── main.css            # Global styles
├── components/
│   ├── details/                # Settings components
│   ├── schedule/               # Schedule components
│   └── training/               # Training components
├── composables/                # Reusable logic
│   ├── useEmployees.ts
│   ├── useJobFunctions.ts
│   ├── useLaborCalculations.ts
│   └── useSchedule.ts
├── pages/                      # Route pages
│   ├── index.vue
│   ├── training.vue
│   ├── details.vue
│   ├── display.vue
│   └── schedule/
│       ├── [date].vue
│       └── tomorrow.vue
├── plugins/
│   └── supabase.client.ts      # Supabase client
├── utils/                      # Helper functions
│   └── validationRules.ts
└── nuxt.config.ts              # Nuxt configuration
```

### Key Composables

- `useEmployees()` - CRUD operations for employees and training
- `useJobFunctions()` - CRUD operations for job functions
- `useSchedule()` - Schedule management and assignments
- `useLaborCalculations()` - Hours calculations and formatting

## 🐛 Troubleshooting

### "Failed to fetch" errors

- Check that your Supabase URL and keys are correct in `.env`
- Verify your Supabase project is active
- Check browser console for specific error messages

### Schedules not saving

- Verify Row Level Security policies are set up (included in schema SQL)
- Check Supabase logs for permission errors
- Ensure all required fields are filled in assignment forms

### Display mode not refreshing

- Check browser console for errors
- Verify internet connection
- Clear browser cache and reload

## 📝 Future Enhancements

- [ ] Authentication (team lead vs display-only access)
- [ ] Drag-and-drop schedule builder
- [ ] Mobile app for on-floor managers
- [ ] Attendance tracking integration
- [ ] Historical schedule archive
- [ ] Analytics dashboard
- [ ] Notification system for changes
- [ ] Print-friendly view
- [ ] Multi-week planning
- [ ] Employee availability/time-off requests

## 📄 License

This project is for internal use. All rights reserved.

## 🤝 Support

For issues or questions, please contact the development team.

---

**Built with ❤️ using Nuxt 3, Vue 3, Supabase, and Tailwind CSS**
