-- Test Profile Access
-- Run this to verify RLS is working correctly

-- This simulates what happens during login
-- Replace the UUID with your actual user ID: aa9d7d32-9eea-42b2-bf7f-cedfa4d11373

-- Test 1: Check if you can see your profile (should work)
SELECT 
  id,
  username,
  email,
  is_active,
  is_super_admin
FROM user_profiles 
WHERE id = 'aa9d7d32-9eea-42b2-bf7f-cedfa4d11373';

-- Test 2: Check current auth context
SELECT auth.uid() as current_user_id;

-- Note: If Test 1 works but login doesn't, it's a client-side RLS issue
-- The session might not be fully established when we query

