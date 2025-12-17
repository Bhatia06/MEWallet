# MEWallet Backend Architecture - Complete Guide

## 📋 Table of Contents
1. [System Overview](#system-overview)
2. [Database Architecture](#database-architecture)
3. [Authentication & Security](#authentication--security)
4. [API Routes & Business Logic](#api-routes--business-logic)
5. [Configuration Management](#configuration-management)
6. [Error Handling & Troubleshooting](#error-handling--troubleshooting)

---

## System Overview

### Technology Stack
- **Framework**: FastAPI (Python) - Modern, fast, async web framework
- **Database**: Supabase (PostgreSQL) - Cloud-hosted Postgres with built-in auth
- **Authentication**: JWT (JSON Web Tokens) + OAuth (Google Sign-In)
- **Password Hashing**: bcrypt - Industry-standard password encryption
- **Deployment**: Docker containers (optional) or direct Python

### Why This Stack?

**FastAPI**:
- ✅ Automatic API documentation (Swagger UI at `/docs`)
- ✅ Built-in request/response validation with Pydantic
- ✅ Async support for better performance
- ✅ Type hints for better code quality

**Supabase**:
- ✅ PostgreSQL with Row-Level Security (RLS)
- ✅ Built-in realtime subscriptions
- ✅ Auto-generated REST API
- ✅ No server management needed

**JWT**:
- ✅ Stateless authentication (no session storage)
- ✅ Self-contained tokens with user info
- ✅ Works across multiple devices/platforms

---

## Database Architecture

### 1. Database Structure

```
┌─────────────┐         ┌─────────────┐
│  merchants  │         │    users    │
│─────────────│         │─────────────│
│ id (TEXT)   │         │ id (TEXT)   │
│ store_name  │         │ name        │
│ phone       │         │ password    │
│ password    │         │ google_id   │
└─────────────┘         └─────────────┘
       │                       │
       └───────┬───────────────┘
               │
        ┌──────▼──────────┐
        │ merchant_user_  │
        │     links       │
        │─────────────────│
        │ merchant_id (FK)│
        │ user_id (FK)    │
        │ balance         │
        │ pin (hashed)    │
        │ status          │
        └─────────────────┘
               │
       ┌───────┴────────┐
       │                │
┌──────▼───────┐  ┌─────▼──────────┐
│ transactions │  │ balance_requests│
│──────────────│  │─────────────────│
│ merchant_id  │  │ merchant_id     │
│ user_id      │  │ user_id         │
│ amount       │  │ amount          │
│ is_credit    │  │ status          │
└──────────────┘  └─────────────────┘
                        │
                 ┌──────┴─────────┐
          ┌──────▼──────┐  ┌──────▼──────┐
          │ link_requests│  │pay_requests │
          │──────────────│  │─────────────│
          │ merchant_id  │  │ merchant_id │
          │ user_id      │  │ user_id     │
          │ status       │  │ amount      │
          └──────────────┘  │ description │
                            │ status      │
                            └─────────────┘
```

### 2. Core Tables Explained

#### **merchants** Table
```sql
CREATE TABLE merchants (
    id TEXT PRIMARY KEY,              -- e.g., "MR8A3F12"
    store_name TEXT NOT NULL,         -- Business name
    phone TEXT UNIQUE,                -- Phone number (nullable for OAuth)
    password TEXT,                    -- bcrypt hashed (nullable for OAuth)
    owner_name TEXT,                  -- Owner's name
    store_address TEXT,               -- Physical address
    google_id TEXT UNIQUE,            -- Google account ID for OAuth
    google_email TEXT,                -- Google email
    profile_completed BOOLEAN DEFAULT false,  -- OAuth profile setup flag
    created_at TIMESTAMP DEFAULT NOW()
);
```

**Why this structure?**
- `id` as TEXT allows custom IDs like "MR8A3F12" (merchant-friendly)
- OAuth fields (`google_id`, `profile_completed`) enable Google Sign-In
- Nullable `password` allows merchants to register via Google without password

**What if something fails?**
- Duplicate phone: Error `23505` - Check if merchant already exists
- Missing required fields: Pydantic validation catches before DB insert
- Google ID conflict: User already registered with that Google account

#### **users** Table
```sql
CREATE TABLE users (
    id TEXT PRIMARY KEY,              -- e.g., "UR6B2E9A"
    name TEXT NOT NULL,               -- User's display name
    password TEXT,                    -- bcrypt hashed
    phone TEXT UNIQUE,                -- Phone number
    google_id TEXT UNIQUE,            -- For Google Sign-In
    google_email TEXT,
    profile_completed BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW()
);
```

**Same pattern as merchants** - Supports both traditional and OAuth registration.

#### **merchant_user_links** Table
```sql
CREATE TABLE merchant_user_links (
    merchant_id TEXT REFERENCES merchants(id),
    user_id TEXT REFERENCES users(id),
    balance DECIMAL(10,2) DEFAULT 0,
    pin TEXT NOT NULL,                -- bcrypt hashed 4-digit PIN
    status TEXT DEFAULT 'active',     -- 'active', 'inactive', 'pending'
    created_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (merchant_id, user_id)
);
```

**Why composite primary key?**
- A merchant-user pair should only exist once
- Prevents duplicate links
- Enables efficient lookups in both directions

**The PIN field:**
- User sets 4-digit PIN when linking
- Hashed with bcrypt (never stored plain text)
- Required for purchases and balance requests
- Different PIN per merchant-user relationship

**What if something fails?**
- Duplicate link: Primary key violation - Link already exists
- Invalid merchant/user: Foreign key violation - ID doesn't exist
- Balance becomes negative: Check constraint prevents it

#### **transactions** Table
```sql
CREATE TABLE transactions (
    id BIGSERIAL PRIMARY KEY,
    merchant_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    is_credit BOOLEAN NOT NULL,       -- true = add, false = deduct
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (merchant_id, user_id) REFERENCES merchant_user_links
);
```

**Why track every transaction?**
- Audit trail - Complete history of all money movements
- Reconciliation - Can verify balances at any point in time
- User trust - Transparency in financial operations
- Dispute resolution - Evidence for any disagreements

**is_credit flag:**
- `true` → Money added to user's wallet (merchant adds balance)
- `false` → Money spent (user makes purchase)

#### **balance_requests** & **link_requests** Tables
```sql
-- User requests balance from merchant
CREATE TABLE balance_requests (
    id BIGSERIAL PRIMARY KEY,
    merchant_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    pin TEXT NOT NULL,                -- Verified before approval
    status TEXT DEFAULT 'pending',    -- 'pending', 'accepted', 'rejected'
    created_at TIMESTAMP DEFAULT NOW(),
    responded_at TIMESTAMP
);

-- User requests to link with merchant
CREATE TABLE link_requests (
    id BIGSERIAL PRIMARY KEY,
    merchant_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    pin TEXT NOT NULL,                -- Will be used if accepted
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT NOW(),
    responded_at TIMESTAMP
);
```

**Request-Response Pattern:**
1. User sends request → Status: 'pending'
2. Merchant sees in their dashboard
3. Merchant accepts/rejects → Status updated + responded_at timestamp
4. If accepted → Action performed (link created or balance added)

**Why separate request tables?**
- Merchant approval control
- Request history preserved
- Can track response times
- Prevents unauthorized actions

#### **pay_requests** Table
```sql
CREATE TABLE pay_requests (
    id BIGSERIAL PRIMARY KEY,
    merchant_id UUID NOT NULL,        -- Now UUID to match Supabase auth
    user_id UUID NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    description TEXT,
    status TEXT DEFAULT 'pending',    -- 'pending', 'accepted', 'rejected'
    created_at TIMESTAMP DEFAULT NOW(),
    responded_at TIMESTAMP
);
```

**Reverse of balance_requests:**
- Merchant requests payment FROM user
- User sees in notifications
- User accepts (with PIN) or rejects
- Used for outstanding bills, services rendered, etc.

### 3. Row-Level Security (RLS)

**What is RLS?**
Row-Level Security is PostgreSQL's way of controlling which rows users can see/modify based on their identity.

**Example RLS Policy:**
```sql
-- Merchants can only see their own data
CREATE POLICY "Merchants can view own data"
    ON merchants
    FOR SELECT
    USING (auth.uid()::text = id);

-- Users can view their links
CREATE POLICY "Users view their links"
    ON merchant_user_links
    FOR SELECT
    USING (auth.uid()::text = user_id);
```

**Why use RLS?**
- Database-level security (can't be bypassed)
- Works even if backend is compromised
- Supabase enforces it automatically
- Reduces backend validation code

**Current implementation:**
- Service role key used in backend → RLS bypassed
- Backend code enforces authorization manually
- Future: Switch to user JWTs for direct Supabase access

### 4. Indexes for Performance

```sql
-- Speed up lookups by merchant_id
CREATE INDEX idx_links_merchant ON merchant_user_links(merchant_id);

-- Speed up lookups by user_id
CREATE INDEX idx_links_user ON merchant_user_links(user_id);

-- Speed up transaction queries
CREATE INDEX idx_txn_merchant_user ON transactions(merchant_id, user_id);
CREATE INDEX idx_txn_created ON transactions(created_at DESC);
```

**Why indexes matter?**
- Without index: Database scans ALL rows (slow)
- With index: Database uses tree structure (fast)
- Example: Finding user's transactions goes from O(n) to O(log n)

**When to add indexes?**
- ✅ Foreign key columns (merchant_id, user_id)
- ✅ Frequently searched columns (status, created_at)
- ✅ Columns used in WHERE, ORDER BY, JOIN
- ❌ Small tables (< 1000 rows) don't benefit much

---

## Authentication & Security

### 1. JWT (JSON Web Tokens)

**What is a JWT?**
A JWT is a cryptographically signed string containing user information.

**Structure:**
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJNUjhBM0YxMiIsInVzZXJfdHlwZSI6Im1lcmNoYW50IiwiZXhwIjoxNzM0MzQzMjAwfQ.signature
│─────────── Header ──────────│─────────────── Payload ───────────────│─ Signature ─│
```

**Decoded Payload:**
```json
{
  "sub": "MR8A3F12",           // Subject (user ID)
  "user_type": "merchant",     // Custom claim
  "exp": 1734343200            // Expiration timestamp
}
```

**How JWT works in MEWallet:**

1. **Login Flow:**
```python
# User sends credentials
POST /user/login
{
    "user_id": "UR6B2E9A",
    "password": "secret123"
}

# Backend verifies password
hashed = user.password
if bcrypt.checkpw(password, hashed):
    # Create JWT
    token = create_access_token({
        "sub": user.id,
        "user_type": "user"
    })
    # Token expires in 7 days (10080 minutes)
    return {"access_token": token}
```

2. **Using the Token:**
```python
# Client sends token in every request
GET /user/UR6B2E9A/merchants
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Backend verifies token
payload = verify_token(token)
# → {"sub": "UR6B2E9A", "user_type": "user"}

# Check authorization
if payload["sub"] != requested_user_id:
    raise HTTPException(403, "Unauthorized")
```

**Why JWT over sessions?**
- ✅ **Stateless**: No server-side session storage needed
- ✅ **Scalable**: Works across multiple backend servers
- ✅ **Mobile-friendly**: Easy to store in mobile apps
- ✅ **Cross-domain**: Works with separate frontend/backend

**JWT Security in MEWallet:**
```python
# config.py
SECRET_KEY: str  # 256-bit random key from .env
ALGORITHM: str = "HS256"  # HMAC-SHA256
ACCESS_TOKEN_EXPIRE_MINUTES: int = 10080  # 7 days
```

**Why 7 days?**
- Long enough: Users don't login daily
- Short enough: Compromised tokens expire
- Balance: Convenience vs security

**What if token is stolen?**
- Token valid until expiry
- No logout mechanism (stateless)
- Solution: Keep expiry reasonable
- Future: Add token blacklist/refresh tokens

### 2. Password Security (bcrypt)

**How bcrypt works:**
```python
import bcrypt

# Hashing (registration)
password = "myPassword123"
salt = bcrypt.gensalt()  # Random salt
hashed = bcrypt.hashpw(password.encode(), salt)
# → "$2b$12$abcd...xyz" (60 chars)

# Verification (login)
entered_password = "myPassword123"
is_valid = bcrypt.checkpw(entered_password.encode(), hashed)
# → True
```

**Key features:**
- **Salt**: Random data mixed with password
- **Cost factor**: 12 rounds (adjustable difficulty)
- **One-way**: Can't reverse to get original password
- **Slow by design**: Prevents brute-force attacks

**In MEWallet:**
```python
# Registration
def hash_password(password: str) -> str:
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(password.encode('utf-8'), salt).decode('utf-8')

# Login
def verify_password(plain_password: str, hashed_password: str) -> bool:
    return bcrypt.checkpw(
        plain_password.encode('utf-8'),
        hashed_password.encode('utf-8')
    )
```

**Why not MD5/SHA256?**
- ❌ Too fast → Easy to brute force
- ❌ No salt → Rainbow table attacks
- ✅ bcrypt is designed for passwords
- ✅ Industry standard (10+ years proven)

### 3. PIN Security

**4-Digit PIN vs Password:**
- Shorter (convenience)
- Per-merchant relationship
- Used for quick transactions
- Still bcrypt hashed!

**Why hash 4-digit PINs?**
Even though only 10,000 combinations (0000-9999), hashing prevents:
- Database breach exposure
- Insider threats
- Log file leaks

**PIN Verification Flow:**
```python
# User creates link with PIN
POST /user/link
{
    "merchant_id": "MR8A3F12",
    "user_id": "UR6B2E9A",
    "pin": "1234"
}

# Backend hashes and stores
pin_hash = hash_password("1234")
# → "$2b$12$..."

# Later: User makes purchase
POST /user/purchase
{
    "merchant_id": "MR8A3F12",
    "amount": 500,
    "pin": "1234"
}

# Backend verifies
if not verify_password("1234", stored_pin_hash):
    raise HTTPException(401, "Invalid PIN")
```

### 4. OAuth 2.0 (Google Sign-In)

**OAuth Flow:**
```
┌─────────┐                                    ┌────────┐
│ Mobile  │                                    │ Google │
│   App   │                                    │        │
└────┬────┘                                    └───┬────┘
     │                                             │
     │ 1. User clicks "Sign in with Google"       │
     │────────────────────────────────────────────>│
     │                                             │
     │ 2. Google shows login screen               │
     │<────────────────────────────────────────────│
     │                                             │
     │ 3. User enters credentials                 │
     │────────────────────────────────────────────>│
     │                                             │
     │ 4. Google returns ID Token                 │
     │<────────────────────────────────────────────│
     │                                             │
     │ 5. App sends ID Token to backend           │
     │─────────────────────────>                  │
     │                          ┌──────────┐      │
     │                          │ MEWallet │      │
     │                          │ Backend  │      │
     │                          └────┬─────┘      │
     │                               │            │
     │ 6. Backend verifies with Google            │
     │                               │────────────>│
     │                               │            │
     │ 7. Google confirms token valid             │
     │                               │<────────────│
     │                               │
     │ 8. Backend creates user/merchant
     │    & returns MEWallet JWT
     │<──────────────────────────────│
```

**Implementation:**
```python
@router.post("/oauth/google")
async def login_with_google(request: GoogleLoginRequest):
    # 1. Verify Google ID token
    google_user = verify_google_token(request.id_token)
    # → {"email": "user@gmail.com", "name": "John", "sub": "12345"}
    
    # 2. Check if user exists
    user = supabase.table("users")\
        .select("*")\
        .eq("google_id", google_user["sub"])\
        .execute()
    
    # 3. Create if new user
    if not user.data:
        user_id = generate_user_id()
        supabase.table("users").insert({
            "id": user_id,
            "name": google_user["name"],
            "google_id": google_user["sub"],
            "google_email": google_user["email"],
            "profile_completed": False  # Need more info
        }).execute()
    
    # 4. Return MEWallet JWT
    token = create_access_token({
        "sub": user_id,
        "user_type": "user"
    })
    
    return {
        "access_token": token,
        "profile_completed": user["profile_completed"]
    }
```

**Why OAuth?**
- ✅ No password to remember
- ✅ Google handles security
- ✅ One-tap registration
- ✅ Verified email addresses

**Profile Completion:**
If user signs in with Google, we need additional info:
- Phone number (optional but useful)
- For merchants: Store address, business details

---

## API Routes & Business Logic

### Route Structure

```
backend/
├── main.py                    # FastAPI app entry point
├── routes/
│   ├── merchant_routes.py     # Merchant registration/login
│   ├── user_routes.py         # User registration/login
│   ├── link_routes.py         # Link management
│   ├── wallet_routes.py       # Transactions, balances
│   ├── oauth_routes.py        # Google Sign-In
│   └── pay_request_routes.py  # Payment requests
├── auth_middleware.py         # JWT verification
├── database.py                # Supabase client
├── utils.py                   # Password hashing, token creation
└── config.py                  # Environment settings
```

### 1. Merchant Routes

**Registration:**
```python
POST /merchant/register
{
    "store_name": "ABC Store",
    "phone": "+919876543210",
    "password": "securePass123"
}

# Backend logic:
1. Validate input (Pydantic)
2. Check if phone already exists
3. Generate merchant ID (e.g., "MR8A3F12")
4. Hash password with bcrypt
5. Insert into database
6. Create JWT token
7. Return merchant ID + token
```

**Why this flow?**
- Phone as unique identifier (easy to remember)
- Auto-generated ID (merchant-friendly)
- Immediate login after registration

**Login:**
```python
POST /merchant/login
{
    "phone": "+919876543210",
    "password": "securePass123"
}

# Backend logic:
1. Find merchant by phone
2. Verify password with bcrypt
3. Create JWT token
4. Return merchant data + token
```

### 2. User Routes

**Same pattern as merchants:**
- Register with username/password
- Auto-generated ID ("UR6B2E9A")
- JWT token on login

**Get Linked Merchants:**
```python
GET /user/{user_id}/merchants
Authorization: Bearer <token>

# Backend logic:
1. Verify JWT token
2. Check user_id matches token
3. Query merchant_user_links for this user
4. Join with merchants table to get store names
5. Return list with balances

# Response:
[
    {
        "merchant_id": "MR8A3F12",
        "store_name": "ABC Store",
        "balance": 1500.00,
        "status": "active"
    }
]
```

**Why join tables?**
- Links table has balance
- Merchants table has store name
- User needs both in one call

### 3. Link Routes

**Creating a Link Request:**
```python
POST /user/link-request
{
    "merchant_id": "MR8A3F12",
    "user_id": "UR6B2E9A",
    "pin": "1234"
}

# Backend logic:
1. Verify merchant exists
2. Verify user exists
3. Check if link already exists
4. Hash PIN
5. Create link_requests entry (status: pending)
6. Return request ID

# Merchant sees this in their dashboard
# Can accept/reject from there
```

**Accepting Link Request:**
```python
POST /link-requests/{request_id}/accept

# Backend logic:
1. Find link_request by ID
2. Verify merchant_id matches JWT
3. Create merchant_user_links entry
   - merchant_id, user_id from request
   - pin from request
   - balance = 0
   - status = 'active'
4. Update link_request status = 'accepted'
5. Set responded_at timestamp
```

**Why request-approval pattern?**
- Merchant control over who links
- Prevents spam links
- Merchant can verify user identity
- Audit trail of all requests

### 4. Wallet Routes (Core Business Logic)

**Add Balance:**
```python
POST /wallet/add-balance
{
    "merchant_id": "MR8A3F12",
    "user_id": "UR6B2E9A",
    "amount": 500,
    "pin": "1234"
}

# Backend logic:
1. Verify JWT (merchant must be authenticated)
2. Find link between merchant and user
3. Verify PIN matches stored hash
4. Start database transaction
   a. UPDATE merchant_user_links
      SET balance = balance + 500
      WHERE merchant_id = X AND user_id = Y
   b. INSERT INTO transactions
      (merchant_id, user_id, amount, is_credit)
      VALUES (X, Y, 500, true)
5. Commit transaction
6. Return new balance

# If ANY step fails → Rollback (balance stays same)
```

**Why database transactions?**
```python
# Without transaction - DANGER!
balance_updated = True   # Step 1 succeeds
# Server crashes here!
txn_created = False      # Step 2 never happens

# Result: Balance changed but no transaction record!

# With transaction:
BEGIN TRANSACTION
    UPDATE balance...    # Step 1
    INSERT transaction... # Step 2
    # Crash here = BOTH steps rollback
COMMIT
```

**Purchase (Deduct Balance):**
```python
POST /wallet/purchase
{
    "merchant_id": "MR8A3F12",
    "user_id": "UR6B2E9A",
    "amount": 200,
    "pin": "1234"
}

# Backend logic (similar to add balance):
1. Verify JWT (user must be authenticated)
2. Find link
3. Verify PIN
4. Check if balance >= amount (IMPORTANT!)
5. Start transaction
   a. UPDATE balance = balance - 200
   b. INSERT transaction (is_credit = false)
6. Commit
7. Return new balance
```

**Critical validation:**
```python
if link["balance"] < amount:
    raise HTTPException(400, "Insufficient balance")

# Without this check:
# balance = 100
# amount = 200
# New balance = -100 (WRONG!)
```

**Get Transactions:**
```python
GET /user/{user_id}/transactions

# Backend logic:
1. Verify JWT
2. Query transactions table
   - WHERE user_id = X
   - ORDER BY created_at DESC
   - JOIN merchants for store names
3. Return list

# Response:
[
    {
        "id": 123,
        "amount": 500,
        "is_credit": true,
        "store_name": "ABC Store",
        "created_at": "2024-12-16T10:30:00Z"
    },
    {
        "id": 124,
        "amount": 200,
        "is_credit": false,
        "store_name": "ABC Store",
        "created_at": "2024-12-16T11:45:00Z"
    }
]
```

### 5. Pay Request Routes

**Merchant Creates Request:**
```python
POST /pay-requests/create
{
    "merchant_id": "MR8A3F12",
    "user_id": "UR6B2E9A",
    "amount": 300,
    "description": "Coffee and snacks"
}

# Backend logic:
1. Verify JWT (merchant authenticated)
2. Verify link exists and active
3. Check amount <= user balance
4. Create pay_requests entry
5. Return request details

# User will see this in notifications
```

**User Accepts Request:**
```python
POST /pay-requests/accept
{
    "request_id": 456,
    "pin": "1234"
}

# Backend logic:
1. Verify JWT (user authenticated)
2. Find pay_request by ID
3. Verify user_id matches
4. Verify status is 'pending'
5. Verify PIN
6. Start transaction
   a. Deduct balance
   b. Create transaction record
   c. Update request status = 'accepted'
   d. Set responded_at
7. Commit
8. Return success
```

**Why validate amount <= balance during creation?**
```python
# Scenario 1: No validation
Merchant requests ₹1000
User balance is ₹500
Request created (pending)
User tries to accept → "Insufficient balance"
❌ Bad UX: User sees request they can't fulfill

# Scenario 2: With validation
Merchant requests ₹1000
User balance is ₹500
Request blocked immediately
✅ Good UX: Merchant knows to request less
```

---

## Configuration Management

### 1. Environment Variables (.env)

**Why use .env?**
- ✅ Secrets not in code (security)
- ✅ Different configs for dev/prod
- ✅ Easy to change without code updates
- ✅ `.env` in `.gitignore` (never committed)

**MEWallet .env:**
```bash
# Supabase Configuration
SUPABASE_URL=https://xyz.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# JWT Configuration
SECRET_KEY=your-super-secret-256-bit-key-here-change-in-production
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=10080

# Google OAuth
GOOGLE_CLIENT_ID=443131879916-xxx.apps.googleusercontent.com
```

**How it's loaded:**
```python
# config.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    SUPABASE_URL: str
    SUPABASE_SERVICE_ROLE_KEY: str
    SECRET_KEY: str
    # ... etc
    
    class Config:
        env_file = ".env"  # Load from .env file

settings = Settings()  # Reads .env automatically
```

### 2. Supabase Keys Explained

**Anon Key (Public):**
- Used in frontend
- RLS policies enforced
- Limited permissions
- Can be exposed publicly

**Service Role Key (Private):**
- Used in backend
- Bypasses RLS
- Full database access
- MUST be kept secret

**Why backend uses service role?**
```python
# With anon key + RLS:
User A tries to update User B's balance
RLS blocks it → Can't proceed

# With service role:
Backend validates authorization in code
Then uses service role to update
More flexibility in business logic
```

**Future improvement:**
- Use anon key + RLS for direct Supabase calls
- Backend only handles business logic
- More secure (defense in depth)

### 3. SECRET_KEY Generation

**Current issue:**
```python
# If you use a weak/default key:
SECRET_KEY = "changeme"  # ❌ DANGER!

# Anyone can create fake JWTs:
fake_token = jwt.encode(
    {"sub": "MRXXXXXX"}, 
    "changeme",  # They know your secret!
    algorithm="HS256"
)
# → Can impersonate any merchant/user!
```

**Generate strong key:**
```python
import secrets
print(secrets.token_urlsafe(32))
# → "dGhpc19pc19hX3JhbmRvbV9zZWNyZXRfa2V5"
```

Or:
```bash
openssl rand -base64 32
```

**Must be:**
- At least 256 bits (32 bytes)
- Randomly generated
- Changed if ever compromised
- Different for dev/staging/production

---

## Error Handling & Troubleshooting

### 1. Common Error Patterns

#### Database Errors

**Duplicate Key:**
```python
# Error: 23505
supabase.table("users").insert({
    "id": "UR6B2E9A",  # Already exists!
    "name": "John"
}).execute()

# Solution:
try:
    result = supabase.table("users").insert(data).execute()
except Exception as e:
    if "23505" in str(e):
        raise HTTPException(409, "User already exists")
    raise
```

**Foreign Key Violation:**
```python
# Error: 23503
supabase.table("merchant_user_links").insert({
    "merchant_id": "MRXXXXXX",  # Doesn't exist!
    "user_id": "UR6B2E9A"
}).execute()

# Solution:
# Check existence first
merchant = supabase.table("merchants").select("id").eq("id", merchant_id).execute()
if not merchant.data:
    raise HTTPException(404, "Merchant not found")
```

**Check Constraint:**
```python
# Error: 23514
supabase.table("merchant_user_links").update({
    "balance": -100  # Violates: CHECK (balance >= 0)
}).execute()

# Solution:
if new_balance < 0:
    raise HTTPException(400, "Insufficient balance")
```

#### Authentication Errors

**Invalid Token:**
```python
# Error: Invalid signature
payload = jwt.decode(token, "wrong-secret", algorithms=["HS256"])

# Solution in verify_token():
try:
    payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    return payload
except jwt.ExpiredSignatureError:
    return None  # Token expired
except jwt.InvalidTokenError:
    return None  # Invalid token
```

**Expired Token:**
```python
# Frontend handles:
if (error.statusCode == 401) {
    // Token expired
    logout();
    navigateToLogin();
}
```

**Wrong Password:**
```python
# bcrypt returns False (not exception)
if not verify_password(entered_pw, stored_hash):
    raise HTTPException(401, "Invalid credentials")
```

### 2. Debugging Strategies

**Enable Logging:**
```python
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@router.post("/wallet/purchase")
async def purchase(...):
    logger.info(f"Purchase attempt: {merchant_id}, {user_id}, ₹{amount}")
    
    try:
        result = process_purchase(...)
        logger.info(f"Purchase successful: {result}")
        return result
    except Exception as e:
        logger.error(f"Purchase failed: {e}", exc_info=True)
        raise
```

**Check Supabase Logs:**
- Go to Supabase Dashboard
- Database → Logs
- See all queries executed
- Find slow queries
- Check error messages

**Test with Postman/curl:**
```bash
# Test login
curl -X POST http://localhost:8000/user/login \
  -H "Content-Type: application/json" \
  -d '{"user_id":"UR6B2E9A","password":"test123"}'

# Test with token
curl -X GET http://localhost:8000/user/UR6B2E9A/merchants \
  -H "Authorization: Bearer eyJhbGciOiJI..."
```

**Common Fixes:**

1. **"Unauthorized" errors:**
   - Check token in Authorization header
   - Verify SECRET_KEY matches
   - Check token not expired
   - Verify user_id in token matches route param

2. **"Not found" errors:**
   - Check IDs are correct
   - Verify data exists in database
   - Check RLS policies (if using anon key)

3. **"Insufficient balance" errors:**
   - Check balance >= amount before deduct
   - Verify transaction order (check → deduct)
   - Use database transactions

4. **"Invalid PIN" errors:**
   - Verify PIN is hashed before storing
   - Use bcrypt.checkpw() for verification
   - Don't compare hashes directly

### 3. Production Checklist

**Before deploying:**

- [ ] Change SECRET_KEY to strong random value
- [ ] Set ACCESS_TOKEN_EXPIRE_MINUTES appropriately
- [ ] Use HTTPS only (no HTTP)
- [ ] Set CORS to specific domains (not "*")
- [ ] Enable Supabase RLS policies
- [ ] Add rate limiting (prevent brute force)
- [ ] Set up monitoring (Sentry, DataDog, etc.)
- [ ] Database backups enabled
- [ ] Environment variables in secure vault
- [ ] Remove debug endpoints (/test, /debug)
- [ ] Add request logging
- [ ] Set up alerting for errors

**Monitoring:**
```python
# Add to main.py
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware

app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=["yourdomain.com", "*.yourdomain.com"]
)

# Log all requests
@app.middleware("http")
async def log_requests(request: Request, call_next):
    logger.info(f"{request.method} {request.url}")
    response = await call_next(request)
    logger.info(f"Response: {response.status_code}")
    return response
```

---

## Summary: Key Principles

### 1. Security
- All passwords/PINs hashed with bcrypt
- JWT for stateless authentication
- Authorization checks on every route
- Secrets in environment variables
- HTTPS in production

### 2. Data Integrity
- Database transactions for multi-step operations
- Foreign key constraints prevent orphaned data
- Check constraints prevent invalid states
- Unique constraints prevent duplicates

### 3. User Experience
- Request-approval pattern (user control)
- Clear error messages
- Audit trail (transaction history)
- Token auto-refresh (7 days)

### 4. Scalability
- Stateless JWT (horizontal scaling)
- Indexed queries (fast lookups)
- Async FastAPI (handle concurrency)
- Cloud database (Supabase handles scaling)

### 5. Maintainability
- Modular route structure
- Type hints everywhere
- Pydantic validation
- Environment-based config
- Comprehensive error handling

---

## Next Steps & Improvements

### Short-term
1. Add rate limiting (prevent abuse)
2. Implement refresh tokens (better security)
3. Add request validation middleware
4. Set up comprehensive logging
5. Add API documentation examples

### Medium-term
1. Move to RLS-based security
2. Add two-factor authentication
3. Implement notification system
4. Add merchant analytics
5. Support multiple currencies

### Long-term
1. Microservices architecture
2. Real-time balance updates (WebSockets)
3. Machine learning fraud detection
4. International expansion
5. Bank integration APIs

---

**Questions? Need Clarification?**

This document covers the core architecture. For specific implementation details, refer to:
- `backend/routes/*.py` - Actual route implementations
- `backend/database.py` - Database client setup
- `backend/auth_middleware.py` - JWT verification logic
- Supabase dashboard - Database schema and RLS policies
