# MEWallet - Digital Wallet Application

A comprehensive digital wallet solution for merchant-user transactions built with FastAPI backend and Flutter mobile app.

## 🚀 Features

### Merchant Features
- ✅ Merchant registration and authentication
- ✅ Link users to merchant account
- ✅ View all linked users and their balances
- ✅ Add balance to user accounts
- ✅ View transaction history
- ✅ Unique merchant ID (MRxxxxxx format)

### User Features
- ✅ User registration and authentication
- ✅ Link with multiple merchants using unique PINs
- ✅ Make purchases using PIN verification
- ✅ View balance across all merchants
- ✅ View transaction history
- ✅ Unique user ID (URxxxxxx format)

### Technical Features
- ✅ Secure password hashing (bcrypt)
- ✅ JWT token-based authentication
- ✅ PIN-protected transactions
- ✅ Real-time balance updates
- ✅ Comprehensive error handling
- ✅ RESTful API design
- ✅ Cross-platform mobile app (Android & iOS)

## 📋 Prerequisites

### Backend
- Python 3.8+
- Supabase account
- pip package manager

### Mobile App
- Flutter SDK 3.0+
- Android Studio / Xcode
- Android SDK / iOS development tools

## 🛠️ Installation & Setup

### 1. Database Setup (Supabase)

1. Create a Supabase account at https://supabase.com
2. Create a new project
3. Go to SQL Editor and run the schema from `backend/schema.sql`
4. Get your Supabase URL and Anon Key from Project Settings > API

### 2. Backend Setup

```powershell
# Navigate to backend directory
cd backend

# Create virtual environment
python -m venv venv

# Activate virtual environment
.\venv\Scripts\Activate

# Install dependencies
pip install -r requirements.txt

# Create .env file
Copy-Item .env.example .env

# Edit .env file and add your credentials:
# - SUPABASE_URL
# - SUPABASE_ANON_KEY
# - SECRET_KEY (generate using: openssl rand -hex 32)

# Run the server
python main.py
```

The API will be available at `http://localhost:8000`

### 3. Mobile App Setup

```powershell
# Navigate to mobile app directory
cd mobile_app

# Install dependencies
flutter pub get

# Update API configuration
# Edit lib/utils/config.dart and set the baseUrl:
# - For Android Emulator: http://10.0.2.2:8000
# - For iOS Simulator: http://localhost:8000
# - For Real Device: http://YOUR_LOCAL_IP:8000

# Run the app
flutter run
```

## 📡 API Endpoints

### Merchant Endpoints
- `POST /merchant/register` - Register new merchant
- `POST /merchant/login` - Merchant login
- `GET /merchant/profile/{merchant_id}` - Get merchant profile
- `GET /merchant/linked-users/{merchant_id}` - Get linked users

### User Endpoints
- `POST /user/register` - Register new user
- `POST /user/login` - User login
- `GET /user/profile/{user_id}` - Get user profile
- `GET /user/linked-merchants/{user_id}` - Get linked merchants

### Transaction Endpoints
- `POST /link/create` - Create merchant-user link with PIN
- `POST /link/add-balance` - Add balance to user account
- `POST /link/purchase` - Process purchase with PIN
- `GET /link/balance/{merchant_id}/{user_id}` - Get balance
- `GET /link/transactions/{merchant_id}/{user_id}` - Get transaction history

### Utility Endpoints
- `GET /health` - Health check
- `GET /` - API info

## 📱 App Usage

### For Merchants

1. **Register/Login**
   - Open app and select "I am a Merchant"
   - Register with store name, phone, and password
   - Save your Merchant ID (MRxxxxxx)

2. **Add Users**
   - Click the "Add User" button
   - Enter user's User ID
   - Set a 4-digit PIN for the user
   - User is now linked!

3. **Add Balance**
   - Select a user from the list
   - Click "Add Balance"
   - Enter amount and confirm

4. **View Transactions**
   - Click on any user to view their transaction history

### For Users

1. **Register/Login**
   - Open app and select "I am a User"
   - Register with your name and password
   - **IMPORTANT:** Save your User ID (URxxxxxx) - you'll need it to login

2. **Link with Merchant**
   - Click "Link Merchant"
   - Enter merchant's Merchant ID
   - Set a 4-digit PIN (remember this!)
   - You're linked!

3. **Make Purchase**
   - Select a merchant from your list
   - Click "Make Purchase"
   - Enter amount and your PIN
   - Transaction complete!

4. **View Balance & History**
   - View your balance with each merchant on the dashboard
   - Click on any merchant to see transaction history

## 🔒 Security Features

- Passwords hashed using bcrypt
- PINs hashed and stored securely
- JWT token authentication
- PIN required for each purchase
- Different PINs for different merchants
- Secure API communication

## 🏗️ Project Structure

```
MEWallet/
├── backend/
│   ├── main.py                 # FastAPI application
│   ├── config.py               # Configuration management
│   ├── database.py             # Supabase client
│   ├── models.py               # Pydantic models
│   ├── utils.py                # Utility functions
│   ├── merchant_routes.py      # Merchant API routes
│   ├── user_routes.py          # User API routes
│   ├── transaction_routes.py   # Transaction API routes
│   ├── schema.sql              # Database schema
│   ├── requirements.txt        # Python dependencies
│   └── .env.example            # Environment template
│
└── mobile_app/
    ├── lib/
    │   ├── main.dart           # App entry point
    │   ├── models/             # Data models
    │   ├── providers/          # State management
    │   ├── screens/            # UI screens
    │   ├── services/           # API & storage services
    │   ├── utils/              # Utilities & theme
    │   └── widgets/            # Reusable widgets
    └── pubspec.yaml            # Flutter dependencies
```

## 🐛 Troubleshooting

### Backend Issues

**Database Connection Error**
- Verify Supabase URL and key in `.env`
- Check if Supabase project is active
- Ensure tables are created using `schema.sql`

**Import Errors**
- Activate virtual environment
- Reinstall dependencies: `pip install -r requirements.txt`

### Mobile App Issues

**Connection Refused**
- Check if backend is running
- Verify `baseUrl` in `lib/utils/config.dart`
- For Android emulator, use `10.0.2.2` instead of `localhost`
- For real device, use your computer's local IP

**Package Errors**
- Run `flutter pub get`
- Run `flutter clean` and then `flutter pub get`

**Build Errors**
- Ensure Flutter SDK is properly installed
- Run `flutter doctor` to check setup

## 📞 Support

For issues or questions:
1. Check the troubleshooting section
2. Review API documentation at `http://localhost:8000/docs`
3. Check backend logs for detailed error messages

## 🔄 Future Enhancements

- [ ] Email/SMS notifications
- [ ] QR code scanning for merchant IDs
- [ ] Transaction receipts
- [ ] Monthly statements
- [ ] Multi-language support
- [ ] Biometric authentication
- [ ] Export transaction history

## 📄 License

This project is created for educational purposes.

---

**Built with ❤️ using FastAPI and Flutter**
