-- Reminders table for merchants to set payment reminders for users with negative balance
-- Run this SQL in your Supabase SQL editor

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Merchants can view their own reminders" ON reminders;
DROP POLICY IF EXISTS "Merchants can create reminders" ON reminders;
DROP POLICY IF EXISTS "Merchants can update their own reminders" ON reminders;
DROP POLICY IF EXISTS "Merchants can delete their own reminders" ON reminders;
DROP POLICY IF EXISTS "Users can view their reminders" ON reminders;
DROP POLICY IF EXISTS "Users can dismiss their reminders" ON reminders;

-- Drop table if exists (be careful with this in production!)
DROP TABLE IF EXISTS reminders;

-- Create reminders table
CREATE TABLE reminders (
    id SERIAL PRIMARY KEY,
    merchant_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    link_id BIGINT NOT NULL,
    message TEXT NOT NULL,
    reminder_date TIMESTAMP WITH TIME ZONE NOT NULL,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'dismissed', 'expired')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add foreign key constraints
ALTER TABLE reminders ADD CONSTRAINT fk_merchant FOREIGN KEY (merchant_id) REFERENCES merchants(id) ON DELETE CASCADE;
ALTER TABLE reminders ADD CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE reminders ADD CONSTRAINT fk_link FOREIGN KEY (link_id) REFERENCES merchant_user_links(id) ON DELETE CASCADE;

-- Create indexes for faster queries
CREATE INDEX idx_reminders_user_id ON reminders(user_id);
CREATE INDEX idx_reminders_merchant_id ON reminders(merchant_id);
CREATE INDEX idx_reminders_status ON reminders(status);
CREATE INDEX idx_reminders_date ON reminders(reminder_date);

-- Disable Row Level Security (since you're using API key authentication)
ALTER TABLE reminders DISABLE ROW LEVEL SECURITY;

-- Grant permissions to service role
GRANT ALL ON reminders TO service_role;
GRANT ALL ON reminders TO anon;
GRANT USAGE, SELECT ON SEQUENCE reminders_id_seq TO service_role;
GRANT USAGE, SELECT ON SEQUENCE reminders_id_seq TO anon;

-- Success message
SELECT 'Reminders table created successfully!' as message;
