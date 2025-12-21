"""
SQL Schema for link_requests table

Run this in Supabase SQL Editor:
"""

CREATE_LINK_REQUESTS_TABLE = """
DROP TABLE IF EXISTS link_requests CASCADE;

CREATE TABLE link_requests (
    id SERIAL PRIMARY KEY,
    merchant_id VARCHAR(255) NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
    user_id VARCHAR(255) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    pin VARCHAR(255) NOT NULL,
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_link_requests_merchant ON link_requests(merchant_id, status);
CREATE INDEX idx_link_requests_user ON link_requests(user_id, status);
"""

# Execute in Supabase:
# Copy and paste the SQL above into Supabase SQL Editor and run it
