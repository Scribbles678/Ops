-- Fix User Profile RLS Policy
-- The "Users can view own profile" policy should allow users to see their profile
-- Run this in Supabase SQL Editor

-- Check current policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE tablename = 'user_profiles';

-- Drop and recreate the "Users can view own profile" policy to ensure it works
DROP POLICY IF EXISTS "Users can view own profile" ON user_profiles;

CREATE POLICY "Users can view own profile" 
ON user_profiles FOR SELECT 
USING (auth.uid() = id);

-- Also ensure the policy allows the user to see their profile during login
-- The above should work, but let's also check if there are any other issues

-- Test: Try to select your own profile (this should work)
-- SELECT * FROM user_profiles WHERE id = auth.uid();

