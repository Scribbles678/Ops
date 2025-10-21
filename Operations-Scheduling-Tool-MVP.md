# Operations Scheduling Tool - MVP Documentation

## Project Overview
A modern web-based scheduling application for distribution center operations, replacing the current Excel-based system. The application will support 20-60 team members across multiple shifts and job functions, with separate interfaces for schedule management and display.

## Tech Stack
- **Frontend**: Nuxt 3 + Vue 3
- **Database**: Supabase (PostgreSQL)
- **Styling**: Tailwind CSS
- **Deployment**: Netlify (free tier)
- **Domain**: Netlify subdomain (e.g., `yourcompany-schedule.netlify.app`)

## User Roles (MVP)
- **Team Lead**: Full edit access to schedules and settings
- **Display Mode**: Read-only view for TV displays
- **Authentication**: Simple password protection (future enhancement)

---

## Database Schema

### 1. **employees** table
```sql
- id (uuid, primary key)
- first_name (text)
- last_name (text)
- is_active (boolean, default true)
- created_at (timestamp)
- updated_at (timestamp)
```

### 2. **job_functions** table
```sql
- id (uuid, primary key)
- name (text, unique) -- e.g., "RT-Pick", "Meter 11"
- color_code (text) -- hex color for display, e.g., "#FFFF00" for yellow
- productivity_rate (integer) -- cartons per hour (nullable)
- is_active (boolean, default true)
- sort_order (integer) -- for display ordering
- created_at (timestamp)
- updated_at (timestamp)
```

### 3. **employee_training** table (junction table)
```sql
- id (uuid, primary key)
- employee_id (uuid, foreign key -> employees.id)
- job_function_id (uuid, foreign key -> job_functions.id)
- created_at (timestamp)
- UNIQUE constraint on (employee_id, job_function_id)
```

### 4. **shifts** table
```sql
- id (uuid, primary key)
- name (text) -- e.g., "6:00 AM - 2:30 PM"
- start_time (time)
- end_time (time)
- break_1_start (time)
- break_1_end (time)
- break_2_start (time)
- break_2_end (time)
- lunch_start (time)
- lunch_end (time)
- is_active (boolean, default true)
- created_at (timestamp)
```

**Initial Shift Data:**
| Shift | Start | End | Break 1 | Break 2 | Lunch |
|-------|-------|-----|---------|---------|-------|
| 6:00 AM - 2:30 PM | 06:00 | 14:30 | 07:45-08:00 | 09:45-10:00 | 12:30-13:00 |
| 7:00 AM - 3:30 PM | 07:00 | 15:30 | 09:45-10:00 | 14:45-15:00 | 12:30-13:00 |
| 8:00 AM - 4:30 PM | 08:00 | 16:30 | 09:45-10:00 | 14:45-15:00 | 12:30-13:00 |
| 10:00 AM - 6:30 PM | 10:00 | 18:30 | 11:45-12:00 | 14:00-14:30 | 16:45-17:00 |
| 12:00 PM - 8:30 PM | 12:00 | 20:30 | 13:45-14:00 | 16:00-16:30 | 18:00-18:15 |
| 4:00 PM - 8:30 PM | 16:00 | 20:30 | N/A | N/A | N/A |

### 5. **schedule_assignments** table
```sql
- id (uuid, primary key)
- employee_id (uuid, foreign key -> employees.id)
- job_function_id (uuid, foreign key -> job_functions.id)
- shift_id (uuid, foreign key -> shifts.id)
- schedule_date (date)
- assignment_order (integer) -- for multiple assignments in one day
- start_time (time)
- end_time (time)
- created_at (timestamp)
- updated_at (timestamp)
```

### 6. **daily_targets** table
```sql
- id (uuid, primary key)
- schedule_date (date)
- job_function_id (uuid, foreign key -> job_functions.id)
- target_units (integer) -- e.g., 1000 cartons
- notes (text, nullable)
- created_at (timestamp)
- updated_at (timestamp)
- UNIQUE constraint on (schedule_date, job_function_id)
```

---

## Application Structure

### Main Landing Page (Team Lead View)
Four large, centered buttons:
1. **Update Training**
2. **Details** 
3. **Edit Today's Schedule**
4. **Make Tomorrow's Schedule**

### Page 1: Update Training
**Purpose**: Manage which employees are trained in which job functions

**Features**:
- List of all active employees (alphabetically sorted)
- For each employee, show checkboxes for all job functions
- Search/filter employees by name
- Bulk actions: "Save All Changes"
- Visual indicator for unsaved changes

**UI Layout**:
```
┌─────────────────────────────────────────┐
│ Update Training             [< Back]     │
├─────────────────────────────────────────┤
│ Search: [____________]                   │
│                                          │
│ Employee Name    | Trained Functions     │
│ ──────────────────────────────────────  │
│ Williams, Hayley | [x] RT-Pick          │
│                  | [x] Meter 11          │
│                  | [ ] X4 Packsize       │
│                  | [x] Locus All         │
│ ──────────────────────────────────────  │
│ Lee, Jeffery     | [x] EM9 Packsize     │
│                  | [ ] RT-Pick           │
│                  | ...                   │
└─────────────────────────────────────────┘
         [Save Changes]
```

### Page 2: Details (Settings)
**Purpose**: Manage job functions, productivity rates, and other configuration

**Tabs**:
1. **Job Functions**
2. **Shifts** (view only for MVP)
3. **Employees**

**Job Functions Tab**:
- Add/Edit/Delete job functions
- Set name, color code (color picker), productivity rate
- Reorder functions (drag and drop for future)

**UI Layout**:
```
┌─────────────────────────────────────────┐
│ Details                     [< Back]     │
├─────────────────────────────────────────┤
│ [Job Functions] [Shifts] [Employees]    │
│                                          │
│ + Add New Job Function                   │
│                                          │
│ ┌─────────────────────────────────────┐ │
│ │ RT-Pick                    [Edit]    │ │
│ │ Color: [■ Yellow]                    │ │
│ │ Rate: 200 cartons/hour              │ │
│ └─────────────────────────────────────┘ │
│                                          │
│ ┌─────────────────────────────────────┐ │
│ │ Meter 11                   [Edit]    │ │
│ │ Color: [■ Blue]                      │ │
│ │ Rate: 150 cartons/hour              │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

**Employees Tab**:
- Add/Edit/Deactivate employees
- Simple form: First Name, Last Name, Active checkbox

### Page 3: Edit Today's Schedule
**Purpose**: Modify the current day's schedule

**Features**:
- Full interactive schedule grid (similar to Excel layout)
- Click to assign employee to time slot
- Drag to extend assignment duration
- Right-click or button to change assignment
- Color-coded by job function
- Real-time labor hours calculation panel

**Key Interactions**:
1. Click empty cell → Modal opens to select Employee + Job Function
2. Click filled cell → Edit/Delete assignment
3. Auto-calculate break times based on shift
4. Validate: Employee can only be in one place at a time
5. Validate: Employee must be trained in assigned function

**Labor Hours Panel** (Sidebar or Bottom):
```
┌──────────────────────────────────────┐
│ Labor Hours by Function              │
├──────────────────────────────────────┤
│ RT-Pick          [■■■■■■░░] 24/30h   │
│ Target: 1000 units | Rate: 200/hr    │
│ Status: ⚠️ Need 5 more hours         │
├──────────────────────────────────────┤
│ Meter 11         [■■■■■■■■] 16/15h   │
│ Target: 800 units | Rate: 150/hr     │
│ Status: ✅ Staffed                   │
└──────────────────────────────────────┘
```

**UI Layout** (Simplified):
```
┌────────────────────────────────────────────────────────────┐
│ Edit Today's Schedule - Tuesday, October 21, 2025  [< Back]│
├────────────────────────────────────────────────────────────┤
│ [Refresh Display] [Save Changes] [Labor Hours →]           │
│                                                             │
│ 6:00 AM Shift                                              │
│ ┌──────────────┬──────────┬──────────┬──────────────────┐ │
│ │ Employee     │ 6:00-8:00│ 8:00-10  │ 10:00-12:30 ...  │ │
│ ├──────────────┼──────────┼──────────┼──────────────────┤ │
│ │ Williams, H  │ RT-Pick  │ RT-Pick  │ Lunch            │ │
│ │ Lee, Jeffery │ EM9 Pack │ Help Desk│ Lunch            │ │
│ └──────────────┴──────────┴──────────┴──────────────────┘ │
│                                                             │
│ 7:00 AM Shift                                              │
│ ┌──────────────┬──────────┬──────────┬──────────────────┐ │
│ │ ...                                                     │ │
└────────────────────────────────────────────────────────────┘
```

### Page 4: Make Tomorrow's Schedule
**Purpose**: Create next day's schedule from scratch or template

**Features**:
- Option 1: "Start from Blank"
- Option 2: "Copy Today's Schedule"
- If copying, load today's assignments and change date to tomorrow
- Same interface as "Edit Today's Schedule" after selection
- Set daily targets for each job function

**Initial Screen**:
```
┌─────────────────────────────────────────┐
│ Make Tomorrow's Schedule    [< Back]    │
│                                          │
│ Schedule Date: Wednesday, October 22     │
│                                          │
│  ┌─────────────────────────────────┐   │
│  │   Start from Blank Schedule     │   │
│  └─────────────────────────────────┘   │
│                                          │
│  ┌─────────────────────────────────┐   │
│  │   Copy Today's Schedule         │   │
│  └─────────────────────────────────┘   │
│                                          │
└─────────────────────────────────────────┘
```

### Display Mode (TV/Tablet View)
**Purpose**: Read-only schedule view for distribution center displays

**Features**:
- Full-screen responsive layout
- Auto-refresh every 30 seconds (or manual refresh button)
- Color-coded job assignments
- Current time indicator
- Show only today's schedule by default
- Large, readable text
- No edit controls
- URL parameter: `?display=true` to trigger display mode

**UI Layout**:
```
┌─────────────────────────────────────────────────────────┐
│ OPERATIONS SCHEDULE - Tuesday, October 21, 2025        │
│ Last Updated: 3:51 PM                    [🔄 Refresh]  │
├─────────────────────────────────────────────────────────┤
│                                                          │
│ 6:00 AM - 2:30 PM                                       │
│ ┏━━━━━━━━━━━━━┯━━━━━━━━━━┯━━━━━━━━━━┯━━━━━━━━━━━━┓  │
│ ┃ Employee     │ 6:00-8:00│ 8:00-10  │ 10:00-12:30┃  │
│ ┣━━━━━━━━━━━━━┿━━━━━━━━━━┿━━━━━━━━━━┿━━━━━━━━━━━━┫  │
│ ┃ Williams, H  │ RT-Pick  │ RT-Pick  │ Lunch      ┃  │ ← Current
│ ┃ Lee, Jeffery │ EM9 Pack │ Help Desk│ Lunch      ┃  │
│ ┗━━━━━━━━━━━━━┷━━━━━━━━━━┷━━━━━━━━━━┷━━━━━━━━━━━━┛  │
│                                                          │
│ 7:00 AM - 3:30 PM                                       │
│ [Similar layout...]                                     │
└─────────────────────────────────────────────────────────┘
```

---

## Key Features & Logic

### 1. Labor Hours Calculation
**Formula**: 
```
Required Hours = Target Units ÷ Productivity Rate
Scheduled Hours = Sum of all assignment durations for that function
Status = Scheduled Hours - Required Hours
```

**Color Coding**:
- 🔴 Red: Understaffed by 20%+ 
- 🟡 Yellow: Understaffed by 5-20%
- 🟢 Green: Adequately staffed (±5%)
- 🔵 Blue: Overstaffed by 5%+

### 2. Schedule Validation Rules
1. Employee cannot be assigned to multiple jobs at the same time
2. Employee can only be assigned to jobs they're trained in
3. Assignment duration must be at least 30 minutes
4. Assignment must fit within shift boundaries
5. Auto-insert break times (greyed out, non-editable)

### 3. Break Time Logic
Breaks are automatically inserted based on shift:
- Breaks are NOT assignments (separate visual treatment)
- Breaks cannot be edited or deleted
- Breaks appear as greyed-out blocks with "Break" or "Lunch" label

### 4. Color Coding System
Each job function has an associated hex color stored in database:
- RT-Pick: Yellow (#FFFF00)
- EM9 Packsize: Green (#90EE90)
- X4 Packsize: Lime (#32CD32)
- Meter Functions: Various blues
- (All customizable in Details page)

### 5. Real-time Updates
- Team Lead edits schedule → Saves to Supabase
- Display mode polls database every 30 seconds OR uses Supabase real-time subscriptions
- "Last Updated" timestamp shown on display

---

## MVP Screens Summary

### Navigation Flow
```
Landing Page
  ├─→ Update Training
  │     └─→ Employee Training Matrix
  │
  ├─→ Details
  │     ├─→ Job Functions (CRUD)
  │     ├─→ Shifts (View Only)
  │     └─→ Employees (CRUD)
  │
  ├─→ Edit Today's Schedule
  │     └─→ Interactive Schedule Grid
  │
  └─→ Make Tomorrow's Schedule
        ├─→ Blank or Copy Choice
        └─→ Interactive Schedule Grid (tomorrow's date)

Display Mode (separate URL)
  └─→ Read-only Schedule View
```

---

## Technical Implementation Notes

### Nuxt 3 Structure
```
/pages
  /index.vue                 # Landing page (4 buttons)
  /training.vue              # Update Training
  /details.vue               # Settings & config
  /schedule/[date].vue       # Edit schedule (dynamic date)
  /display.vue               # TV display mode

/components
  /schedule
    /ScheduleGrid.vue        # Main schedule table
    /AssignmentCell.vue      # Individual cell with assignment
    /LaborHoursPanel.vue     # Sidebar calculations
  /training
    /EmployeeRow.vue         # Training checkbox row
  /details
    /JobFunctionForm.vue     # Job function CRUD
    /EmployeeForm.vue        # Employee CRUD

/composables
  /useSchedule.js            # Schedule CRUD operations
  /useEmployees.js           # Employee operations
  /useJobFunctions.js        # Job function operations
  /useLaborCalculations.js   # Hours calculations

/utils
  /timeHelpers.js            # Time parsing and formatting
  /colorHelpers.js           # Color manipulation
  /validationRules.js        # Schedule validation logic
```

### Supabase Setup
1. Create project on Supabase
2. Run SQL migrations for all tables
3. Set up Row Level Security (RLS) policies:
   - Read access: Public (for display mode)
   - Write access: Authenticated only (future)
4. Enable Realtime for `schedule_assignments` table

### Netlify Deployment
1. Connect GitHub repository to Netlify
2. Build command: `npm run generate` (static site generation)
3. Publish directory: `.output/public`
4. Environment variables:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`

---

## Future Enhancements (Post-MVP)
- Authentication (team lead login vs display-only access)
- Mobile app for on-floor managers
- Attendance tracking integration
- Historical schedule archive
- Analytics dashboard (productivity trends)
- Notification system for schedule changes
- Drag-and-drop schedule builder
- Print-friendly view
- Multi-week schedule planning
- Employee availability/time-off requests
- Automatic schedule suggestions based on AI/optimization

---

## MVP Success Criteria
✅ Team lead can create and edit schedules  
✅ Schedules display correctly on TV screens  
✅ Labor hours calculated accurately  
✅ Employee training tracked and enforced  
✅ Color-coded job functions  
✅ Copy today's schedule to tomorrow  
✅ Responsive on desktop and tablet  
✅ Data persists in Supabase  
✅ Deployed to Netlify with working URL  

---

## Development Phases

### Phase 1: Database & Backend (Week 1)
- Set up Supabase project
- Create all tables and relationships
- Seed initial data (shifts, sample employees, job functions)
- Test CRUD operations

### Phase 2: Core UI (Week 2)
- Build landing page
- Create Details page (Job Functions & Employees CRUD)
- Build Update Training page
- Set up routing

### Phase 3: Schedule Builder (Week 3)
- Build schedule grid component
- Implement assignment creation/editing
- Add validation rules
- Build labor hours panel

### Phase 4: Display Mode & Polish (Week 4)
- Create TV display view
- Implement auto-refresh
- Style refinements
- Responsive testing
- Deploy to Netlify

---

## Questions for Development
1. Do you want a dark mode toggle for the display screens?
2. Should employees be able to see their own schedules (future)?
3. Any specific branding/colors for the app UI?
4. What happens to old schedules? Archive after X days?
5. Do you need to print schedules as backup?

---

This MVP documentation provides a complete foundation for building the scheduling tool in Cursor. Each section can be used as a reference during development.

