-- Verify Admin User Setup
-- Run this to check if everything is linked correctly

-- 1. Check auth user
SELECT 
  'Auth User' as type,
  id,
  email,
  email_confirmed_at,
  created_at
FROM auth.users 
WHERE email = 'm.johnson.legacy@gmail.com';

-- 2. Check profile
SELECT 
  'Profile' as type,
  id,
  username,
  email,
  is_super_admin,
  is_active,
  team_id
FROM user_profiles 
WHERE email = 'm.johnson.legacy@gmail.com' OR username = 'admin';

-- 3. Check if IDs match
SELECT 
  au.id as auth_id,
  au.email as auth_email,
  up.id as profile_id,
  up.username,
  up.email as profile_email,
  CASE 
    WHEN au.id = up.id THEN '✅ IDs MATCH - Should work!'
    WHEN au.id IS NULL THEN '❌ No auth user found'
    WHEN up.id IS NULL THEN '❌ No profile found'
    ELSE '❌ IDs DO NOT MATCH - This is the problem!'
  END as status
FROM auth.users au
FULL OUTER JOIN user_profiles up ON au.id = up.id
WHERE au.email = 'm.johnson.legacy@gmail.com' OR up.email = 'm.johnson.legacy@gmail.com';

