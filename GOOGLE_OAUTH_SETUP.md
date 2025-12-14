# Google OAuth Setup Instructions for MEWallet

## Step 1: Get Google OAuth Credentials

### A. Create Google Cloud Project
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click "Select a project" → "New Project"
3. Enter project name: "MEWallet" → Click "Create"
4. Wait for project creation, then select it

### B. Enable Google Sign-In API
1. In your project, go to "APIs & Services" → "Library"
2. Search for "Google Sign-In API" or "Google+ API"
3. Click "Enable"

### C. Configure OAuth Consent Screen
1. Go to "APIs & Services" → "OAuth consent screen"
2. Select "External" → Click "Create"
3. Fill in required fields:
   - **App name**: MEWallet
   - **User support email**: Your email
   - **Developer contact**: Your email
4. Click "Save and Continue"
5. Skip "Scopes" → Click "Save and Continue"
6. Add test users (your email) → Click "Save and Continue"
7. Click "Back to Dashboard"

### D. Create OAuth 2.0 Client IDs

#### For Android:
1. Go to "APIs & Services" → "Credentials"
2. Click "Create Credentials" → "OAuth 2.0 Client ID"
3. Application type: **Android**
4. Name: "MEWallet Android"
5. **Package name**: `com.example.mewallet`
6. Get your **SHA-1 fingerprint**:
   ```bash
   # For debug (development):
   cd C:\Users\divya\OneDrive\Desktop\MEWallet\mobile_app\android
   keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
   
   # For release (production):
   keytool -list -v -keystore app\upload-keystore.jks -alias upload
   ```
7. Copy the SHA-1 fingerprint and paste it
8. Click "Create"

#### For Web (Backend):
1. Click "Create Credentials" → "OAuth 2.0 Client ID"
2. Application type: **Web application**
3. Name: "MEWallet Backend"
4. **Authorized redirect URIs**: Leave empty for now
5. Click "Create"
6. **IMPORTANT**: Copy the **Client ID** shown in the popup

#### For iOS (if needed later):
1. Create another OAuth 2.0 Client ID
2. Application type: **iOS**
3. Name: "MEWallet iOS"
4. Bundle ID: `com.example.mewallet`

---

## Step 2: Update Backend Configuration

### A. Add Google Client ID to .env
```bash
# Open backend/.env and update:
GOOGLE_CLIENT_ID=YOUR_WEB_CLIENT_ID_HERE.apps.googleusercontent.com
```

Replace `YOUR_WEB_CLIENT_ID_HERE` with the **Web application Client ID** from Step 1D.

### B. Run Database Migration
1. Open Supabase SQL Editor: https://supabase.com/dashboard/project/ivdnwhmdtigrnucdyzdz/sql
2. Copy contents from `backend/add_oauth_columns.sql`
3. Paste and click "Run"
4. Verify columns were added:
   ```sql
   SELECT column_name FROM information_schema.columns 
   WHERE table_name = 'users' AND column_name LIKE 'google%';
   ```

### C. Install Backend Dependencies
```powershell
cd C:\Users\divya\OneDrive\Desktop\MEWallet\backend
pip install -r requirements.txt
```

### D. Restart Backend
```powershell
python main.py
```

---

## Step 3: Configure Flutter App

### A. Install Flutter Dependencies
```powershell
cd C:\Users\divya\OneDrive\Desktop\MEWallet\mobile_app
flutter pub get
```

### B. Configure Android

#### 1. Update android/app/build.gradle
Add this at the bottom of the file (before the last closing brace):
```gradle
apply plugin: 'com.google.gms.google-services'
```

And add this in the `dependencies` section:
```gradle
dependencies {
    // ... existing dependencies
    implementation 'com.google.android.gms:play-services-auth:20.7.0'
}
```

#### 2. Update android/build.gradle
Add this to `dependencies` in buildscript:
```gradle
buildscript {
    dependencies {
        // ... existing dependencies
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

#### 3. Download google-services.json (IMPORTANT!)
1. Go back to Google Cloud Console → "APIs & Services" → "Credentials"
2. OR go to [Firebase Console](https://console.firebase.google.com/)
3. Add Android app with package name: `com.example.mewallet`
4. Download `google-services.json`
5. Place it at: `mobile_app/android/app/google-services.json`

**Without this file, Google Sign-In will NOT work on Android!**

---

## Step 4: Test Google OAuth

### A. Test Backend
```bash
# Test if backend is ready
curl http://192.168.68.113:8000/oauth/google
```
Should return error about missing token (that's expected).

### B. Test Flutter App
```powershell
cd C:\Users\divya\OneDrive\Desktop\MEWallet\mobile_app

# For Android device
flutter run

# For debugging
flutter run --verbose
```

### C. Test Login Flow
1. Open app on device
2. Click "Continue with Google" on login screen
3. Select/login with your Google account
4. You should be logged in automatically

---

## Step 5: Troubleshooting

### Issue: "Error 10" or "Sign-in failed"
**Solution**: SHA-1 fingerprint mismatch
```powershell
cd mobile_app\android
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```
Add the SHA-1 to Google Cloud Console → Credentials → Android OAuth client

### Issue: "ApiException: 12500"
**Solution**: Missing google-services.json
- Download from Firebase Console
- Place at: `android/app/google-services.json`

### Issue: "Invalid Google token"
**Solution**: Wrong Client ID in backend
- Make sure GOOGLE_CLIENT_ID in .env matches the **Web application Client ID**
- NOT the Android Client ID

### Issue: "Google sign-in cancelled"
**Solution**: User cancelled - this is normal behavior

### Issue: Backend can't verify token
**Solution**: 
1. Check GOOGLE_CLIENT_ID is set correctly
2. Make sure you're using the Web Client ID, not Android
3. Verify backend dependencies installed: `pip list | grep google`

---

## Step 6: Security Notes

### For Production:
1. **NEVER commit google-services.json** to git:
   ```bash
   echo "android/app/google-services.json" >> .gitignore
   ```

2. **Use environment variables** for Client IDs

3. **Enable HTTPS** before deploying (OAuth requires HTTPS in production)

4. **Restrict API Keys** in Google Cloud Console:
   - Go to Credentials
   - Click on your API key
   - Set "Application restrictions" to "Android apps"
   - Add your package name and SHA-1

5. **Move to Production** OAuth consent screen when ready:
   - Go to OAuth consent screen
   - Click "Publish App"
   - Submit for verification

---

## Verification Checklist

- [ ] Google Cloud project created
- [ ] OAuth consent screen configured
- [ ] Android OAuth client created with SHA-1
- [ ] Web OAuth client created
- [ ] Web Client ID added to backend/.env
- [ ] Database migration run (add_oauth_columns.sql)
- [ ] Backend dependencies installed
- [ ] google-services.json downloaded and placed correctly
- [ ] Flutter dependencies installed
- [ ] Android build.gradle files updated
- [ ] Backend running without errors
- [ ] Can see "Continue with Google" button in app
- [ ] Google sign-in works on device

---

## Quick Start Commands

```powershell
# Backend
cd C:\Users\divya\OneDrive\Desktop\MEWallet\backend
pip install -r requirements.txt
python main.py

# Frontend (new terminal)
cd C:\Users\divya\OneDrive\Desktop\MEWallet\mobile_app
flutter pub get
flutter run
```

**Note**: Make sure to complete Step 1 (Google Cloud setup) and Step 3B.3 (download google-services.json) before running!
