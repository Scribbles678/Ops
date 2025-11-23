-- Add email column to user_profiles for easier lookup
-- Run this in Supabase SQL Editor

-- Add email column (optional, but helpful for display)
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS email TEXT;

-- Create index for email lookups
CREATE INDEX IF NOT EXISTS idx_user_profiles_email ON user_profiles(email);

-- Update existing profiles with email from auth.users
UPDATE user_profiles up
SET email = au.email
FROM auth.users au
WHERE up.id = au.id
AND up.email IS NULL;

-- Note: For new users, we'll populate email when creating the profile
-- The email comes from auth.users.email

