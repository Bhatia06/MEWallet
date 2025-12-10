# 📱 MEWallet - Complete Project Guide

## 🎯 Project Overview

MEWallet is a digital wallet application that enables merchants to manage customer wallet balances and allows users to make PIN-protected purchases at linked merchants.

### Key Concepts

1. **Merchants** register stores and link users with unique PINs
2. **Users** register accounts and link to multiple merchants
3. **Each merchant-user pair** has:
   - Unique PIN (set by merchant)
   - Separate balance
   - Independent transaction history
4. **Purchases** require PIN verification
5. **All data** is stored securely in Supabase

## 🏗️ Architecture

```
┌─────────────────┐
│  Flutter App    │ (Android/iOS)
│  (User/Merchant)│
└────────┬────────┘
         │ HTTP/JSON
         ↓
┌─────────────────┐
│   FastAPI       │ (Python Backend)
│   REST API      │
└────────┬────────┘
         │ Python Client
         ↓
┌─────────────────┐
│   Supabase      │ (PostgreSQL Database)
│   Database      │
└─────────────────┘
```

## 📊 Database Schema

```sql
merchants
├── id (TEXT, PK) - MRxxxxxx
├── store_name (TEXT)
├── phone (TEXT, UNIQUE)
├── password (TEXT, hashed)
└── created_at (TIMESTAMP)

users
├── id (TEXT, PK) - URxxxxxx
├── user_name (TEXT)
├── user_passw (TEXT, hashed)
└── created_at (TIMESTAMP)

merchant_user_links
├── id (SERIAL, PK)
├── merchant_id (TEXT, FK)
├── user_id (TEXT, FK)
├── pin (TEXT, hashed)
├── balance (DECIMAL)
└── created_at (TIMESTAMP)
└── UNIQUE(merchant_id, user_id)

transactions
├── id (SERIAL, PK)
├── merchant_id (TEXT, FK)
├── user_id (TEXT, FK)
├── amount (DECIMAL)
├── transaction_type (TEXT) - 'credit' or 'debit'
├── balance_after (DECIMAL)
└── created_at (TIMESTAMP)
```

## 🔄 Workflow Examples

### 1. Complete Merchant Flow

```
Register Merchant
    ↓
Login to Dashboard
    ↓
Add User (by User ID)
    ↓
Set PIN for User
    ↓
Add Balance to User
    ↓
View Transactions
```

### 2. Complete User Flow

```
Register User (get User ID)
    ↓
Login to Dashboard
    ↓
Link to Merchant (by Merchant ID)
    ↓
Set PIN for that Merchant
    ↓
Make Purchase (enter PIN)
    ↓
View Balance & History
```

### 3. Transaction Flow

```
User initiates purchase
    ↓
User enters amount & PIN
    ↓
API validates PIN
    ↓
Check sufficient balance
    ↓
Deduct amount from balance
    ↓
Record transaction
    ↓
Update balance
    ↓
Return success
```

## 🔐 Security Features

### Password Security
- Bcrypt hashing with automatic salt
- Minimum 6 characters
- Stored hashed in database

### PIN Security
- Bcrypt hashing
- 4-6 digit numeric
- Required for each purchase
- Different PIN per merchant

### API Security
- JWT token authentication
- 30-minute token expiration
- Bearer token in headers
- Token includes user ID and type

### Data Validation
- Phone: exactly 10 digits
- IDs: unique hashed values
- Amounts: positive numbers only
- PIN: 4-6 digits

## 📡 API Reference

### Merchant APIs

**Register Merchant**
```http
POST /merchant/register
Content-Type: application/json

{
  "store_name": "My Store",
  "phone": "1234567890",
  "password": "password123"
}

Response: 201
{
  "merchant_id": "MRxxxxxx",
  "store_name": "My Store",
  "access_token": "eyJ...",
  "token_type": "bearer"
}
```

**Login Merchant**
```http
POST /merchant/login
Content-Type: application/json

{
  "phone": "1234567890",
  "password": "password123"
}

Response: 200
{
  "merchant_id": "MRxxxxxx",
  "store_name": "My Store",
  "access_token": "eyJ...",
  "token_type": "bearer"
}
```

**Get Linked Users**
```http
GET /merchant/linked-users/{merchant_id}
Authorization: Bearer {token}

Response: 200
[
  {
    "user_id": "URxxxxxx",
    "user_name": "John Doe",
    "balance": 1000.00,
    "created_at": "2024-01-01T00:00:00"
  }
]
```

### User APIs

**Register User**
```http
POST /user/register
Content-Type: application/json

{
  "user_name": "John Doe",
  "user_passw": "password123"
}

Response: 201
{
  "user_id": "URxxxxxx",
  "user_name": "John Doe",
  "access_token": "eyJ...",
  "token_type": "bearer"
}
```

**Get Linked Merchants**
```http
GET /user/linked-merchants/{user_id}
Authorization: Bearer {token}

Response: 200
[
  {
    "merchant_id": "MRxxxxxx",
    "store_name": "My Store",
    "balance": 1000.00
  }
]
```

### Transaction APIs

**Create Link**
```http
POST /link/create
Authorization: Bearer {token}
Content-Type: application/json

{
  "merchant_id": "MRxxxxxx",
  "user_id": "URxxxxxx",
  "pin": "1234"
}

Response: 201
{
  "message": "Link created successfully",
  "link_id": 1,
  "balance": 0.00
}
```

**Add Balance**
```http
POST /link/add-balance
Authorization: Bearer {token}
Content-Type: application/json

{
  "merchant_id": "MRxxxxxx",
  "user_id": "URxxxxxx",
  "amount": 1000.00
}

Response: 200
{
  "message": "Balance added successfully",
  "new_balance": 1000.00,
  "transaction_id": 1
}
```

**Process Purchase**
```http
POST /link/purchase
Authorization: Bearer {token}
Content-Type: application/json

{
  "merchant_id": "MRxxxxxx",
  "user_id": "URxxxxxx",
  "amount": 100.00,
  "pin": "1234"
}

Response: 200
{
  "message": "Purchase successful",
  "remaining_balance": 900.00,
  "transaction_id": 2
}
```

**Get Transactions**
```http
GET /link/transactions/{merchant_id}/{user_id}?limit=50
Authorization: Bearer {token}

Response: 200
[
  {
    "id": 1,
    "amount": 1000.00,
    "transaction_type": "credit",
    "balance_after": 1000.00,
    "created_at": "2024-01-01T00:00:00"
  },
  {
    "id": 2,
    "amount": 100.00,
    "transaction_type": "debit",
    "balance_after": 900.00,
    "created_at": "2024-01-01T01:00:00"
  }
]
```

## 🎨 Flutter App Structure

```
lib/
├── main.dart                    # Entry point
├── models/
│   └── models.dart              # Data models
├── providers/
│   ├── auth_provider.dart       # Authentication state
│   └── wallet_provider.dart     # Wallet state
├── screens/
│   ├── home_screen.dart         # Landing page
│   ├── merchant_login_screen.dart
│   ├── merchant_register_screen.dart
│   ├── merchant_dashboard_screen.dart
│   ├── user_login_screen.dart
│   ├── user_register_screen.dart
│   ├── user_dashboard_screen.dart
│   ├── add_user_screen.dart
│   ├── link_merchant_screen.dart
│   ├── transaction_detail_screen.dart
│   └── user_transaction_screen.dart
├── services/
│   ├── api_service.dart         # API communication
│   └── storage_service.dart     # Local storage
└── utils/
    ├── config.dart              # Configuration
    └── theme.dart               # UI theme
```

## 🚀 Deployment Guide

### Backend Deployment (Example: Heroku)

1. Create `Procfile`:
```
web: uvicorn main:app --host 0.0.0.0 --port $PORT
```

2. Add to requirements.txt:
```
gunicorn
```

3. Deploy:
```bash
heroku create mewallet-api
heroku config:set SUPABASE_URL=your_url
heroku config:set SUPABASE_ANON_KEY=your_key
heroku config:set SECRET_KEY=your_secret
git push heroku main
```

### Mobile App Deployment

**Android (Google Play):**
1. Create signing key
2. Build release: `flutter build appbundle --release`
3. Upload to Google Play Console

**iOS (App Store):**
1. Configure in Xcode
2. Build: `flutter build ios --release`
3. Upload via Xcode or Transporter

## 🧪 Testing

### Backend Testing
```powershell
cd backend
python test_api.py
```

### Manual Testing Checklist
- [ ] Merchant registration
- [ ] Merchant login
- [ ] User registration
- [ ] User login
- [ ] Create merchant-user link
- [ ] Add balance
- [ ] Make purchase with correct PIN
- [ ] Make purchase with wrong PIN (should fail)
- [ ] Make purchase with insufficient balance (should fail)
- [ ] View transaction history
- [ ] View balance

## 📈 Future Enhancements

### Planned Features
1. **QR Code Integration**
   - Generate QR for merchant ID
   - Scan QR to link merchant

2. **Notifications**
   - Push notifications for transactions
   - Email receipts

3. **Analytics**
   - Transaction reports
   - Spending insights
   - Monthly statements

4. **Security**
   - Biometric authentication
   - Two-factor authentication
   - Transaction limits

5. **Features**
   - Refund functionality
   - Split payments
   - Recurring payments
   - Loyalty points

## 📝 Best Practices

### For Development
1. Always test API with Swagger first
2. Use virtual environment for Python
3. Keep .env secure and never commit
4. Test on both Android and iOS
5. Handle errors gracefully

### For Production
1. Use environment-specific configs
2. Enable HTTPS
3. Implement rate limiting
4. Add logging and monitoring
5. Regular backups
6. Implement proper RLS in Supabase

## 🆘 Support & Troubleshooting

### Common Issues

**"Invalid credentials"**
- Check password is correct
- Ensure user/merchant exists
- Token may be expired (re-login)

**"Insufficient balance"**
- Check current balance
- Ensure balance was added successfully

**"Invalid PIN"**
- PIN is specific to each merchant
- Re-enter PIN carefully
- Contact merchant to reset PIN

**Connection errors**
- Check backend is running
- Verify baseUrl in config
- Check firewall settings

### Getting Help
1. Check QUICKSTART.md
2. Review setup guides
3. Check API docs at /docs
4. Review error messages in logs

## 📄 License

This project is for educational purposes.

---

**Created with ❤️ using FastAPI, Flutter, and Supabase**
