# 🚀 MEWallet - Quick Start Guide

Get your wallet app running in 5 minutes!

## ⚡ Quick Setup

### 1. Supabase Setup (2 minutes)

1. Go to https://supabase.com and create account
2. Create new project
3. Copy Project URL and anon key from Settings → API
4. In SQL Editor, paste and run this:

```sql
-- Copy the entire contents of backend/schema.sql and run it
-- Then run this to disable RLS for development:
ALTER TABLE merchants DISABLE ROW LEVEL SECURITY;
ALTER TABLE users DISABLE ROW LEVEL SECURITY;
ALTER TABLE merchant_user_links DISABLE ROW LEVEL SECURITY;
ALTER TABLE transactions DISABLE ROW LEVEL SECURITY;
```

### 2. Backend Setup (2 minutes)

```powershell
cd backend
python -m venv venv
.\venv\Scripts\Activate
pip install -r requirements.txt
Copy-Item .env.example .env
```

**Edit `.env` file:**
```env
SUPABASE_URL=paste_your_url_here
SUPABASE_ANON_KEY=paste_your_key_here
SECRET_KEY=generate_with_openssl_rand_hex_32
```

**Start server:**
```powershell
python main.py
```

### 3. Mobile App Setup (1 minute)

```powershell
cd mobile_app
flutter pub get
```

**Edit `lib/utils/config.dart`:**
- For Android Emulator: `http://10.0.2.2:8000`
- For iOS Simulator: `http://localhost:8000`
- For Real Device: `http://YOUR_IP:8000`

**Run app:**
```powershell
flutter run
```

## 🎯 Testing the App

### Test as Merchant:
1. Open app → "I am a Merchant" → Register
2. Fill: Store Name, Phone (10 digits), Password
3. **Save your Merchant ID (MRxxxxxx)**
4. Dashboard opens → Ready to add users!

### Test as User:
1. Open app → "I am a User" → Register
2. Fill: Name, Password
3. **SAVE YOUR USER ID (URxxxxxx)** - Important!
4. Dashboard opens → Ready to link merchants!

### Link Merchant and User:
1. **On Merchant App:** Click "Add User"
   - Enter User ID
   - Set 4-digit PIN
   - User linked!

2. **Add Balance:** Click on user → "Add Balance"
   - Enter amount (e.g., 1000)
   - Balance added!

3. **Make Purchase (User App):** Click on merchant → "Make Purchase"
   - Enter amount
   - Enter PIN
   - Purchase successful!

## 📋 Requirements

- Python 3.8+
- Flutter SDK 3.0+
- Supabase account (free)
- Android Studio / Xcode

## 🐛 Troubleshooting

**Backend won't start?**
- Check .env has correct Supabase credentials
- Activate virtual environment

**App can't connect?**
- Ensure backend is running (`python main.py`)
- Check baseUrl in config.dart
- Android emulator must use `10.0.2.2` not `localhost`

**Database errors?**
- Run schema.sql in Supabase
- Disable RLS (see Supabase setup above)

## 📚 Full Documentation

- See `README.md` for complete features
- See `backend/SETUP.md` for backend details
- See `mobile_app/SETUP.md` for app details

## 🎉 You're Ready!

API Documentation: http://localhost:8000/docs

---

**Need help?** Check the detailed README.md or setup guides!
