-- Step 1: Check your current super admin status
-- Replace 'm.johnson.legacy@gmail.com' with your actual email address
SELECT 
  id,
  email,
  username,
  is_super_admin,
  is_active,
  team_id,
  CASE 
    WHEN is_super_admin = true THEN '✅ You ARE a super admin'
    ELSE '❌ You are NOT a super admin'
  END as status
FROM user_profiles
WHERE email = 'm.johnson.legacy@gmail.com';

-- Step 2: If you need to set yourself as super admin, run this:
-- Replace 'm.johnson.legacy@gmail.com' with your actual email address
UPDATE user_profiles
SET is_super_admin = true
WHERE email = 'm.johnson.legacy@gmail.com';

-- Step 3: Verify the update worked
SELECT 
  id,
  email,
  username,
  is_super_admin,
  is_active,
  team_id,
  CASE 
    WHEN is_super_admin = true THEN '✅ You ARE now a super admin!'
    ELSE '❌ Still not a super admin - check for errors'
  END as status
FROM user_profiles
WHERE email = 'm.johnson.legacy@gmail.com';

