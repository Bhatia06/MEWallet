-- MEWallet Database Schema for Supabase

-- Table: merchants
CREATE TABLE IF NOT EXISTS merchants (
    id TEXT PRIMARY KEY,
    store_name TEXT NOT NULL,
    phone TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table: users
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    user_name TEXT NOT NULL,
    user_passw TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table: merchant_user_links
CREATE TABLE IF NOT EXISTS merchant_user_links (
    id SERIAL PRIMARY KEY,
    merchant_id TEXT NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    pin TEXT NOT NULL,
    balance DECIMAL(10, 2) DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(merchant_id, user_id)
);

-- Table: transactions
CREATE TABLE IF NOT EXISTS transactions (
    id SERIAL PRIMARY KEY,
    merchant_id TEXT NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount DECIMAL(10, 2) NOT NULL,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('credit', 'debit')),
    balance_after DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for better performance
CREATE INDEX IF NOT EXISTS idx_merchants_phone ON merchants(phone);
CREATE INDEX IF NOT EXISTS idx_merchant_user_links_merchant ON merchant_user_links(merchant_id);
CREATE INDEX IF NOT EXISTS idx_merchant_user_links_user ON merchant_user_links(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_merchant ON transactions(merchant_id);
CREATE INDEX IF NOT EXISTS idx_transactions_user ON transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_created ON transactions(created_at DESC);

-- Enable Row Level Security (RLS) - Optional but recommended
ALTER TABLE merchants ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE merchant_user_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

-- Note: You'll need to set up RLS policies in Supabase dashboard based on your security requirements
-- For development, you can disable RLS or create permissive policies
