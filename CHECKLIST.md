# ✅ MEWallet Setup Checklist

Use this checklist to ensure everything is configured correctly.

## 📋 Pre-Setup Checklist

- [ ] Python 3.8+ installed
- [ ] Flutter SDK 3.0+ installed
- [ ] Android Studio or Xcode installed
- [ ] Git installed (optional, for version control)

## 🗄️ Database Setup

- [ ] Created Supabase account at https://supabase.com
- [ ] Created new Supabase project
- [ ] Copied Supabase URL from Project Settings → API
- [ ] Copied Supabase Anon Key from Project Settings → API
- [ ] Opened SQL Editor in Supabase
- [ ] Ran entire contents of `backend/schema.sql`
- [ ] Verified tables created (merchants, users, merchant_user_links, transactions)
- [ ] Disabled Row Level Security (RLS) for development:
  ```sql
  ALTER TABLE merchants DISABLE ROW LEVEL SECURITY;
  ALTER TABLE users DISABLE ROW LEVEL SECURITY;
  ALTER TABLE merchant_user_links DISABLE ROW LEVEL SECURITY;
  ALTER TABLE transactions DISABLE ROW LEVEL SECURITY;
  ```

## 🔧 Backend Setup

- [ ] Navigated to `backend/` directory
- [ ] Created virtual environment: `python -m venv venv`
- [ ] Activated virtual environment: `.\venv\Scripts\Activate`
- [ ] Installed dependencies: `pip install -r requirements.txt`
- [ ] Created `.env` file: `Copy-Item .env.example .env`
- [ ] Edited `.env` file with:
  - [ ] SUPABASE_URL
  - [ ] SUPABASE_ANON_KEY
  - [ ] SECRET_KEY (generated with: `python -c "import secrets; print(secrets.token_hex(32))"`)
- [ ] Started server: `python main.py`
- [ ] Verified server running at http://localhost:8000
- [ ] Checked health endpoint: http://localhost:8000/health
- [ ] Checked API docs: http://localhost:8000/docs

## 📱 Mobile App Setup

- [ ] Navigated to `mobile_app/` directory
- [ ] Installed dependencies: `flutter pub get`
- [ ] Edited `lib/utils/config.dart`
- [ ] Set `baseUrl` correctly:
  - [ ] Android Emulator: `http://10.0.2.2:8000`
  - [ ] iOS Simulator: `http://localhost:8000`
  - [ ] Real Device: `http://YOUR_IP:8000`
- [ ] Started emulator/simulator or connected device
- [ ] Ran app: `flutter run`
- [ ] App launched successfully

## 🧪 Testing

- [ ] Backend test: `python backend/test_api.py`
- [ ] Test merchant registration in app
- [ ] Test user registration in app
- [ ] Test linking merchant and user
- [ ] Test adding balance
- [ ] Test making purchase
- [ ] Test viewing transactions

## 🔍 Verification

### Backend
- [ ] Server starts without errors
- [ ] Database connection successful
- [ ] API docs accessible
- [ ] Health check returns "healthy"

### Mobile App
- [ ] App launches without errors
- [ ] Can navigate between screens
- [ ] Forms validate correctly
- [ ] API calls work
- [ ] Error messages display properly

## 📝 Important Information to Save

**Supabase:**
- URL: ______________________
- Anon Key: ______________________

**Test Merchant:**
- Phone: ______________________
- Password: ______________________
- Merchant ID: ______________________

**Test User:**
- Name: ______________________
- Password: ______________________
- User ID: ______________________

## 🚀 Ready to Use

Once all items are checked:
- [ ] Backend is running
- [ ] Mobile app is running
- [ ] Can register merchants
- [ ] Can register users
- [ ] Can link and transact
- [ ] Documentation reviewed

## 🆘 Troubleshooting

If something doesn't work, check:

**Backend Issues:**
- [ ] Virtual environment activated
- [ ] `.env` file has correct values
- [ ] Supabase tables created
- [ ] No port conflicts (8000 in use)

**Mobile App Issues:**
- [ ] Backend is running
- [ ] Correct `baseUrl` in config.dart
- [ ] Flutter dependencies installed
- [ ] Device/emulator is running

**Database Issues:**
- [ ] Schema SQL executed completely
- [ ] RLS disabled for development
- [ ] Supabase project is active
- [ ] Correct credentials in `.env`

## 📚 Next Steps

After setup is complete:
1. Read QUICKSTART.md for usage examples
2. Review GUIDE.md for technical details
3. Check README.md for feature overview
4. Explore API docs at /docs
5. Start building!

## 🎉 Congratulations!

If all items are checked, your MEWallet app is ready to use!

---

**Need help?** Refer to:
- QUICKSTART.md - Quick setup guide
- README.md - Full documentation
- GUIDE.md - Technical reference
- backend/SETUP.md - Backend details
- mobile_app/SETUP.md - App details
