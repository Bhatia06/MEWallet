# 📡 MEWallet API Examples

Complete examples for testing all API endpoints using curl or your favorite HTTP client.

## Base URL
```
http://localhost:8000
```

## 🏪 Merchant Endpoints

### 1. Register Merchant
```bash
curl -X POST "http://localhost:8000/merchant/register" \
  -H "Content-Type: application/json" \
  -d '{
    "store_name": "SuperMart",
    "phone": "9876543210",
    "password": "password123"
  }'
```

**Response:**
```json
{
  "message": "Merchant registered successfully",
  "merchant_id": "MR1A2B3C",
  "store_name": "SuperMart",
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer"
}
```

### 2. Login Merchant
```bash
curl -X POST "http://localhost:8000/merchant/login" \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "9876543210",
    "password": "password123"
  }'
```

**Response:**
```json
{
  "message": "Login successful",
  "merchant_id": "MR1A2B3C",
  "store_name": "SuperMart",
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer"
}
```

### 3. Get Merchant Profile
```bash
curl -X GET "http://localhost:8000/merchant/profile/MR1A2B3C" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

**Response:**
```json
{
  "id": "MR1A2B3C",
  "store_name": "SuperMart",
  "phone": "9876543210",
  "created_at": "2024-01-01T12:00:00"
}
```

### 4. Get Linked Users
```bash
curl -X GET "http://localhost:8000/merchant/linked-users/MR1A2B3C" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

**Response:**
```json
[
  {
    "link_id": 1,
    "user_id": "UR4D5E6F",
    "user_name": "John Doe",
    "balance": 1500.00,
    "created_at": "2024-01-01T13:00:00"
  }
]
```

## 👤 User Endpoints

### 1. Register User
```bash
curl -X POST "http://localhost:8000/user/register" \
  -H "Content-Type: application/json" \
  -d '{
    "user_name": "John Doe",
    "user_passw": "password123"
  }'
```

**Response:**
```json
{
  "message": "User registered successfully",
  "user_id": "UR4D5E6F",
  "user_name": "John Doe",
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer"
}
```

### 2. Login User
```bash
curl -X POST "http://localhost:8000/user/login" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "UR4D5E6F",
    "user_passw": "password123"
  }'
```

**Response:**
```json
{
  "message": "Login successful",
  "user_id": "UR4D5E6F",
  "user_name": "John Doe",
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer"
}
```

### 3. Get User Profile
```bash
curl -X GET "http://localhost:8000/user/profile/UR4D5E6F" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

**Response:**
```json
{
  "id": "UR4D5E6F",
  "user_name": "John Doe",
  "created_at": "2024-01-01T12:30:00"
}
```

### 4. Get Linked Merchants
```bash
curl -X GET "http://localhost:8000/user/linked-merchants/UR4D5E6F" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

**Response:**
```json
[
  {
    "link_id": 1,
    "merchant_id": "MR1A2B3C",
    "store_name": "SuperMart",
    "balance": 1500.00,
    "created_at": "2024-01-01T13:00:00"
  }
]
```

## 🔗 Transaction Endpoints

### 1. Create Link (Merchant + User)
```bash
curl -X POST "http://localhost:8000/link/create" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{
    "merchant_id": "MR1A2B3C",
    "user_id": "UR4D5E6F",
    "pin": "1234"
  }'
```

**Response:**
```json
{
  "message": "Link created successfully",
  "link_id": 1,
  "merchant_id": "MR1A2B3C",
  "user_id": "UR4D5E6F",
  "balance": 0.00
}
```

### 2. Add Balance
```bash
curl -X POST "http://localhost:8000/link/add-balance" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{
    "merchant_id": "MR1A2B3C",
    "user_id": "UR4D5E6F",
    "amount": 1000.00
  }'
```

**Response:**
```json
{
  "message": "Balance added successfully",
  "merchant_id": "MR1A2B3C",
  "user_id": "UR4D5E6F",
  "amount_added": 1000.00,
  "new_balance": 1000.00,
  "transaction_id": 1
}
```

### 3. Process Purchase
```bash
curl -X POST "http://localhost:8000/link/purchase" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{
    "merchant_id": "MR1A2B3C",
    "user_id": "UR4D5E6F",
    "amount": 150.50,
    "pin": "1234"
  }'
```

**Response:**
```json
{
  "message": "Purchase successful",
  "merchant_id": "MR1A2B3C",
  "user_id": "UR4D5E6F",
  "amount_paid": 150.50,
  "remaining_balance": 849.50,
  "transaction_id": 2
}
```

### 4. Get Balance
```bash
curl -X GET "http://localhost:8000/link/balance/MR1A2B3C/UR4D5E6F" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

**Response:**
```json
{
  "merchant_id": "MR1A2B3C",
  "user_id": "UR4D5E6F",
  "balance": 849.50
}
```

### 5. Get Transactions
```bash
curl -X GET "http://localhost:8000/link/transactions/MR1A2B3C/UR4D5E6F?limit=50" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

**Response:**
```json
[
  {
    "id": 2,
    "merchant_id": "MR1A2B3C",
    "user_id": "UR4D5E6F",
    "amount": 150.50,
    "transaction_type": "debit",
    "balance_after": 849.50,
    "created_at": "2024-01-01T14:30:00"
  },
  {
    "id": 1,
    "merchant_id": "MR1A2B3C",
    "user_id": "UR4D5E6F",
    "amount": 1000.00,
    "transaction_type": "credit",
    "balance_after": 1000.00,
    "created_at": "2024-01-01T14:00:00"
  }
]
```

## 🏥 Utility Endpoints

### Health Check
```bash
curl -X GET "http://localhost:8000/health"
```

**Response:**
```json
{
  "status": "healthy",
  "database": "connected"
}
```

### Root
```bash
curl -X GET "http://localhost:8000/"
```

**Response:**
```json
{
  "message": "Welcome to MEWallet API",
  "version": "1.0.0",
  "status": "active"
}
```

## 🔄 Complete Workflow Example

### Step 1: Register Merchant
```bash
curl -X POST "http://localhost:8000/merchant/register" \
  -H "Content-Type: application/json" \
  -d '{"store_name": "My Shop", "phone": "1234567890", "password": "pass123"}'
```
Save `merchant_id` and `access_token`

### Step 2: Register User
```bash
curl -X POST "http://localhost:8000/user/register" \
  -H "Content-Type: application/json" \
  -d '{"user_name": "Test User", "user_passw": "pass123"}'
```
Save `user_id` and `access_token`

### Step 3: Create Link (use merchant token)
```bash
curl -X POST "http://localhost:8000/link/create" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer MERCHANT_TOKEN" \
  -d '{"merchant_id": "MRxxxxxx", "user_id": "URxxxxxx", "pin": "1234"}'
```

### Step 4: Add Balance (use merchant token)
```bash
curl -X POST "http://localhost:8000/link/add-balance" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer MERCHANT_TOKEN" \
  -d '{"merchant_id": "MRxxxxxx", "user_id": "URxxxxxx", "amount": 500}'
```

### Step 5: Make Purchase (use user token)
```bash
curl -X POST "http://localhost:8000/link/purchase" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer USER_TOKEN" \
  -d '{"merchant_id": "MRxxxxxx", "user_id": "URxxxxxx", "amount": 50, "pin": "1234"}'
```

### Step 6: View Transactions (use either token)
```bash
curl -X GET "http://localhost:8000/link/transactions/MRxxxxxx/URxxxxxx" \
  -H "Authorization: Bearer TOKEN"
```

## ❌ Error Response Examples

### Invalid Credentials
```json
{
  "detail": "Invalid credentials"
}
```

### Invalid PIN
```json
{
  "detail": "Invalid PIN"
}
```

### Insufficient Balance
```json
{
  "detail": "Insufficient balance. Current balance: 100.00"
}
```

### Link Already Exists
```json
{
  "detail": "Link already exists between this merchant and user"
}
```

### Not Found
```json
{
  "detail": "Merchant not found"
}
```

### Validation Error
```json
{
  "detail": "Validation error",
  "errors": [
    {
      "loc": ["body", "phone"],
      "msg": "Phone must be exactly 10 digits",
      "type": "value_error"
    }
  ]
}
```

## 🧪 Testing with Postman

1. Import these examples as a Postman collection
2. Set base URL as environment variable
3. Save tokens after login
4. Use {{token}} variable in Authorization headers

## 🔒 Authentication Notes

- All protected endpoints require `Authorization: Bearer <token>` header
- Tokens expire after 30 minutes
- Re-login to get new token
- Include token in all requests except register/login

## 📝 Tips

1. **Save tokens**: Store access tokens after login
2. **Use variables**: Store merchant_id, user_id, tokens as variables
3. **Check responses**: Always verify status codes and response data
4. **Error handling**: Check error messages for debugging
5. **API Docs**: Use http://localhost:8000/docs for interactive testing

---

**Happy Testing! 🚀**
