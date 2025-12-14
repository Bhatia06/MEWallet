-- Add OAuth profile completion fields
-- Run this in Supabase SQL Editor after add_oauth_columns.sql

-- Add owner_name and store_address to merchants table
ALTER TABLE merchants 
ADD COLUMN IF NOT EXISTS owner_name TEXT,
ADD COLUMN IF NOT EXISTS store_address TEXT;

-- Add phone to users table (for recovery, optional)
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS phone TEXT;

-- Add profile_completed flag to track OAuth profile completion
ALTER TABLE merchants 
ADD COLUMN IF NOT EXISTS profile_completed BOOLEAN DEFAULT FALSE;

ALTER TABLE users 
ADD COLUMN IF NOT EXISTS profile_completed BOOLEAN DEFAULT FALSE;

-- Create indexes for phone lookups
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone) WHERE phone IS NOT NULL;

-- Comments for clarity
COMMENT ON COLUMN merchants.owner_name IS 'Owner/manager name from OAuth or manual entry';
COMMENT ON COLUMN merchants.store_address IS 'Physical store address (optional)';
COMMENT ON COLUMN merchants.profile_completed IS 'TRUE when OAuth user completes profile setup';
COMMENT ON COLUMN users.phone IS 'Phone number for account recovery (optional)';
COMMENT ON COLUMN users.profile_completed IS 'TRUE when OAuth user completes profile setup';
