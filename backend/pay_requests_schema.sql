-- Pay Requests Table Schema for Supabase
-- This table stores payment requests from merchants to users

-- Drop existing table if it exists (to recreate with correct types)
DROP TABLE IF EXISTS pay_requests CASCADE;

CREATE TABLE pay_requests (
    id BIGSERIAL PRIMARY KEY,
    merchant_id TEXT NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount DECIMAL(10, 2) NOT NULL CHECK (amount > 0),
    description TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    responded_at TIMESTAMPTZ
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_pay_requests_user_id ON pay_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_pay_requests_merchant_id ON pay_requests(merchant_id);
CREATE INDEX IF NOT EXISTS idx_pay_requests_status ON pay_requests(status);
CREATE INDEX IF NOT EXISTS idx_pay_requests_created_at ON pay_requests(created_at DESC);

-- Row Level Security (RLS) Policies
ALTER TABLE pay_requests ENABLE ROW LEVEL SECURITY;

-- Merchants can create pay requests for their linked users
CREATE POLICY "Merchants can create pay requests"
    ON pay_requests
    FOR INSERT
    WITH CHECK (
        auth.uid()::text = merchant_id
        AND EXISTS (
            SELECT 1 FROM merchant_user_links
            WHERE merchant_id = pay_requests.merchant_id
            AND user_id = pay_requests.user_id
            AND status = 'active'
        )
    );

-- Merchants can view their own pay requests
CREATE POLICY "Merchants can view their pay requests"
    ON pay_requests
    FOR SELECT
    USING (auth.uid()::text = merchant_id);

-- Users can view pay requests sent to them
CREATE POLICY "Users can view their pay requests"
    ON pay_requests
    FOR SELECT
    USING (auth.uid()::text = user_id);

-- Users can update pay requests sent to them (accept/reject)
CREATE POLICY "Users can respond to their pay requests"
    ON pay_requests
    FOR UPDATE
    USING (auth.uid()::text = user_id AND status = 'pending')
    WITH CHECK (
        auth.uid()::text = user_id 
        AND status IN ('accepted', 'rejected')
        AND responded_at IS NOT NULL
    );

-- Service role can do everything (for backend operations)
CREATE POLICY "Service role has full access"
    ON pay_requests
    FOR ALL
    USING (current_setting('request.jwt.claims', true)::json->>'role' = 'service_role');

-- Comments for documentation
COMMENT ON TABLE pay_requests IS 'Stores payment requests from merchants to users';
COMMENT ON COLUMN pay_requests.merchant_id IS 'ID of the merchant requesting payment';
COMMENT ON COLUMN pay_requests.user_id IS 'ID of the user being requested to pay';
COMMENT ON COLUMN pay_requests.amount IS 'Amount being requested';
COMMENT ON COLUMN pay_requests.description IS 'Optional description/reason for payment';
COMMENT ON COLUMN pay_requests.status IS 'Request status: pending, accepted, or rejected';
COMMENT ON COLUMN pay_requests.created_at IS 'Timestamp when request was created';
COMMENT ON COLUMN pay_requests.responded_at IS 'Timestamp when user responded to request';
