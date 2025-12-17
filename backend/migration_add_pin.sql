-- Migration: Add PIN column to users table and update constraints
-- Run this in Supabase SQL Editor

-- Step 1: Add pin column to users table
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS pin TEXT;

-- Step 2: Make phone NOT NULL (will fail if existing users don't have phone)
-- First, update existing users who don't have phone
UPDATE users SET phone = 'PENDING_' || id WHERE phone IS NULL OR phone = '';

-- Then make it NOT NULL and UNIQUE
ALTER TABLE users 
ALTER COLUMN phone SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_phone_unique ON users(phone);

-- Step 3: Create index for faster PIN lookups (though we'll validate via user_id)
CREATE INDEX IF NOT EXISTS idx_users_pin ON users(pin);

-- Step 4: Add check to ensure profile_completed is set
-- Update existing users without profile_completed
UPDATE users SET profile_completed = FALSE WHERE profile_completed IS NULL;

-- Step 5: Remove PIN column from merchant_user_links (PIN now stored in users table only)
ALTER TABLE merchant_user_links 
DROP COLUMN IF EXISTS pin;

-- Step 6: Verify the changes
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'users' 
ORDER BY ordinal_position;

-- Expected columns:
-- id (TEXT, NO)
-- user_name (TEXT, NO)
-- user_passw (TEXT, NO)
-- created_at (TIMESTAMP, YES)
-- google_id (TEXT, YES)
-- google_email (TEXT, YES)
-- phone (TEXT, NO) -- NOW REQUIRED
-- profile_completed (BOOLEAN, YES)
-- pin (TEXT, YES) -- NEW COLUMN

-- Verify merchant_user_links no longer has pin column
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'merchant_user_links' 
ORDER BY ordinal_position;

-- Expected columns (no pin):
-- id (BIGINT, NO)
-- merchant_id (TEXT, NO)
-- user_id (TEXT, NO)
-- balance (NUMERIC, YES)
-- created_at (TIMESTAMP, YES)
