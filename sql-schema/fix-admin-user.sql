-- Fix Admin User - Create Auth User to Match Profile
-- Run this in Supabase SQL Editor

-- First, check what we have
SELECT 
  'Profile exists' as status,
  id,
  username,
  is_super_admin,
  is_active
FROM user_profiles 
WHERE username = 'admin';

-- Note: You cannot directly insert into auth.users via SQL
-- You need to create the user through Supabase Dashboard or Admin API

-- OPTION 1: Create via Supabase Dashboard (Easiest)
-- 1. Go to Authentication > Users
-- 2. Click "Add user" > "Create new user"
-- 3. Email: admin@internal.local
-- 4. Password: (your password)
-- 5. Auto Confirm: ON
-- 6. Copy the User ID that gets created
-- 7. Then run this SQL (replace NEW_USER_ID with the actual UUID):

-- UPDATE user_profiles 
-- SET id = 'NEW_USER_ID'
-- WHERE username = 'admin';

-- OPTION 2: Use the Admin API (if you have service role key)
-- This requires running code, not SQL

-- OPTION 3: Delete profile and recreate properly
-- If the above doesn't work, delete the profile and recreate via admin interface

-- Check current profile ID
SELECT id FROM user_profiles WHERE username = 'admin';

