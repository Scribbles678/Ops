-- Debug Admin Login Issue
-- Run these queries to check what's wrong

-- 1. Check if auth user exists
SELECT 
  id as auth_id,
  email,
  email_confirmed_at,
  created_at
FROM auth.users 
WHERE email = 'admin@internal.local';

-- 2. Check if profile exists
SELECT 
  id as profile_id,
  username,
  is_active,
  is_super_admin,
  team_id
FROM user_profiles 
WHERE username = 'admin';

-- 3. Check if IDs match (they should be the same!)
SELECT 
  au.id as auth_user_id,
  au.email,
  up.id as profile_id,
  up.username,
  CASE 
    WHEN au.id = up.id THEN '✅ IDs MATCH - Should work!'
    WHEN au.id IS NULL THEN '❌ No auth user found'
    WHEN up.id IS NULL THEN '❌ No profile found'
    ELSE '❌ IDs DO NOT MATCH - This is the problem!'
  END as status
FROM auth.users au
FULL OUTER JOIN user_profiles up ON au.id = up.id
WHERE au.email = 'admin@internal.local' OR up.username = 'admin';

-- 4. If IDs don't match, you need to update the profile:
-- UPDATE user_profiles 
-- SET id = 'AUTH_USER_ID_FROM_QUERY_1'
-- WHERE username = 'admin';

