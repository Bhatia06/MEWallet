-- MEWallet Row Level Security (RLS) Setup for Supabase
-- Run these commands in Supabase SQL Editor to enable RLS

-- ============================================
-- ENABLE ROW LEVEL SECURITY ON ALL TABLES
-- ============================================

ALTER TABLE merchants ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE merchant_user_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE balance_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE link_requests ENABLE ROW LEVEL SECURITY;

-- ============================================
-- MERCHANTS TABLE POLICIES
-- ============================================

-- Merchants can read their own data
CREATE POLICY "Merchants can view own data"
ON merchants FOR SELECT
USING (auth.uid()::text = id OR auth.role() = 'service_role');

-- Merchants can update their own data
CREATE POLICY "Merchants can update own data"
ON merchants FOR UPDATE
USING (auth.uid()::text = id OR auth.role() = 'service_role');

-- Allow service role (backend) to insert merchants
CREATE POLICY "Service can insert merchants"
ON merchants FOR INSERT
WITH CHECK (auth.role() = 'service_role');

-- ============================================
-- USERS TABLE POLICIES
-- ============================================

-- Users can read their own data
CREATE POLICY "Users can view own data"
ON users FOR SELECT
USING (auth.uid()::text = id OR auth.role() = 'service_role');

-- Users can update their own data
CREATE POLICY "Users can update own data"
ON users FOR UPDATE
USING (auth.uid()::text = id OR auth.role() = 'service_role');

-- Allow service role (backend) to insert users
CREATE POLICY "Service can insert users"
ON users FOR INSERT
WITH CHECK (auth.role() = 'service_role');

-- ============================================
-- MERCHANT_USER_LINKS TABLE POLICIES
-- ============================================

-- Merchants can view their own links
CREATE POLICY "Merchants can view own links"
ON merchant_user_links FOR SELECT
USING (
    merchant_id IN (SELECT id FROM merchants WHERE auth.uid()::text = id)
    OR auth.role() = 'service_role'
);

-- Users can view their own links
CREATE POLICY "Users can view own links"
ON merchant_user_links FOR SELECT
USING (
    user_id IN (SELECT id FROM users WHERE auth.uid()::text = id)
    OR auth.role() = 'service_role'
);

-- Service role can manage all links
CREATE POLICY "Service can manage links"
ON merchant_user_links FOR ALL
USING (auth.role() = 'service_role');

-- ============================================
-- TRANSACTIONS TABLE POLICIES
-- ============================================

-- Merchants can view transactions for their links
CREATE POLICY "Merchants can view own transactions"
ON transactions FOR SELECT
USING (
    merchant_id IN (SELECT id FROM merchants WHERE auth.uid()::text = id)
    OR auth.role() = 'service_role'
);

-- Users can view their own transactions
CREATE POLICY "Users can view own transactions"
ON transactions FOR SELECT
USING (
    user_id IN (SELECT id FROM users WHERE auth.uid()::text = id)
    OR auth.role() = 'service_role'
);

-- Service role can insert transactions
CREATE POLICY "Service can insert transactions"
ON transactions FOR INSERT
WITH CHECK (auth.role() = 'service_role');

-- ============================================
-- BALANCE_REQUESTS TABLE POLICIES
-- ============================================

-- Merchants can view requests sent to them
CREATE POLICY "Merchants can view own balance requests"
ON balance_requests FOR SELECT
USING (
    merchant_id IN (SELECT id FROM merchants WHERE auth.uid()::text = id)
    OR auth.role() = 'service_role'
);

-- Users can view their own requests
CREATE POLICY "Users can view own balance requests"
ON balance_requests FOR SELECT
USING (
    user_id IN (SELECT id FROM users WHERE auth.uid()::text = id)
    OR auth.role() = 'service_role'
);

-- Service role can manage all balance requests
CREATE POLICY "Service can manage balance requests"
ON balance_requests FOR ALL
USING (auth.role() = 'service_role');

-- ============================================
-- LINK_REQUESTS TABLE POLICIES
-- ============================================

-- Merchants can view requests sent to them
CREATE POLICY "Merchants can view own link requests"
ON link_requests FOR SELECT
USING (
    merchant_id IN (SELECT id FROM merchants WHERE auth.uid()::text = id)
    OR auth.role() = 'service_role'
);

-- Users can view their own requests
CREATE POLICY "Users can view own link requests"
ON link_requests FOR SELECT
USING (
    user_id IN (SELECT id FROM users WHERE auth.uid()::text = id)
    OR auth.role() = 'service_role'
);

-- Service role can manage all link requests
CREATE POLICY "Service can manage link requests"
ON link_requests FOR ALL
USING (auth.role() = 'service_role');

-- ============================================
-- GRANT NECESSARY PERMISSIONS
-- ============================================

-- Grant service role full access (your backend uses service_role key)
GRANT ALL ON merchants TO service_role;
GRANT ALL ON users TO service_role;
GRANT ALL ON merchant_user_links TO service_role;
GRANT ALL ON transactions TO service_role;
GRANT ALL ON balance_requests TO service_role;
GRANT ALL ON link_requests TO service_role;

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Run these to verify RLS is enabled:
-- SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public';
-- SELECT * FROM pg_policies WHERE schemaname = 'public';
