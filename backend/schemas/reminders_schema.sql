-- Reminders table for merchants to set payment reminders for users with negative balance
CREATE TABLE IF NOT EXISTS reminders (
    id SERIAL PRIMARY KEY,
    merchant_id TEXT NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    link_id INTEGER NOT NULL REFERENCES merchant_user_links(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    reminder_date TIMESTAMP WITH TIME ZONE NOT NULL,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'dismissed', 'expired')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for faster queries
CREATE INDEX IF NOT EXISTS idx_reminders_user_id ON reminders(user_id);
CREATE INDEX IF NOT EXISTS idx_reminders_merchant_id ON reminders(merchant_id);
CREATE INDEX IF NOT EXISTS idx_reminders_status ON reminders(status);
CREATE INDEX IF NOT EXISTS idx_reminders_date ON reminders(reminder_date);

-- Enable Row Level Security
ALTER TABLE reminders ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Merchants can see their own reminders
CREATE POLICY "Merchants can view their own reminders"
    ON reminders FOR SELECT
    USING (auth.uid() = merchant_id);

-- Merchants can create reminders
CREATE POLICY "Merchants can create reminders"
    ON reminders FOR INSERT
    WITH CHECK (auth.uid() = merchant_id);

-- Merchants can update their own reminders
CREATE POLICY "Merchants can update their own reminders"
    ON reminders FOR UPDATE
    USING (auth.uid() = merchant_id);

-- Merchants can delete their own reminders
CREATE POLICY "Merchants can delete their own reminders"
    ON reminders FOR DELETE
    USING (auth.uid() = merchant_id);

-- Users can view reminders set for them
CREATE POLICY "Users can view their reminders"
    ON reminders FOR SELECT
    USING (auth.uid() = user_id);

-- Users can update status of reminders (dismiss)
CREATE POLICY "Users can dismiss their reminders"
    ON reminders FOR UPDATE
    USING (auth.uid() = user_id);
