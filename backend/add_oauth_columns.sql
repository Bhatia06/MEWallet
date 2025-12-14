-- Add Google OAuth columns to users and merchants tables
-- Run this in Supabase SQL Editor

-- Add Google OAuth fields to users table
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS google_id TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS google_email TEXT;

-- Add Google OAuth fields to merchants table
ALTER TABLE merchants 
ADD COLUMN IF NOT EXISTS google_id TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS google_email TEXT;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_users_google_id ON users(google_id);
CREATE INDEX IF NOT EXISTS idx_merchants_google_id ON merchants(google_id);

-- Make password optional for OAuth users (allow empty string)
ALTER TABLE users ALTER COLUMN user_passw DROP NOT NULL;
ALTER TABLE merchants ALTER COLUMN password DROP NOT NULL;
ALTER TABLE merchants ALTER COLUMN phone DROP NOT NULL;
