
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS pin TEXT;

UPDATE users SET phone = 'PENDING_' || id WHERE phone IS NULL OR phone = '';

-- Then make it NOT NULL and UNIQUE
ALTER TABLE users 
ALTER COLUMN phone SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_phone_unique ON users(phone);

-- Step 3: Create index for faster PIN lookups (though we'll validate via user_id)
CREATE INDEX IF NOT EXISTS idx_users_pin ON users(pin);

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

SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'merchant_user_links' 
ORDER BY ordinal_position;
