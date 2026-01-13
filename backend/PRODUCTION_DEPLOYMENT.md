# MEWallet Production Deployment Guide

## 1. HTTPS Setup Options

### Option A: Deploy to Railway (Easiest - Free HTTPS)

1. Create account at [railway.app](https://railway.app)
2. Install Railway CLI:
   ```bash
   npm install -g @railway/cli
   ```
3. Login and deploy:
   ```bash
   railway login
   railway init
   railway up
   ```
4. Add environment variables in Railway dashboard
5. Railway provides automatic HTTPS with domain like: `mewallet.railway.app`

### Option B: Deploy to Render (Free Tier)

1. Create account at [render.com](https://render.com)
2. Connect your GitHub repository
3. Create new Web Service
4. Set build command: `pip install -r requirements.txt`
5. Set start command: `uvicorn main:app --host 0.0.0.0 --port $PORT`
6. Add environment variables
7. Deploy - gets automatic HTTPS

### Option C: Self-hosted with Nginx + Let's Encrypt

1. **Get a domain** (from Namecheap, GoDaddy, etc.)

2. **Install Certbot**:
   ```bash
   sudo apt-get update
   sudo apt-get install certbot python3-certbot-nginx
   ```

3. **Create Nginx config** (`/etc/nginx/sites-available/mewallet`):
   ```nginx
   server {
       listen 80;
       server_name yourdomain.com www.yourdomain.com;

       location / {
           proxy_pass http://localhost:8000;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;
       }

       location /ws {
           proxy_pass http://localhost:8000;
           proxy_http_version 1.1;
           proxy_set_header Upgrade $http_upgrade;
           proxy_set_header Connection "upgrade";
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
       }
   }
   ```

4. **Get SSL Certificate**:
   ```bash
   sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
   ```

5. **Auto-renewal**:
   ```bash
   sudo certbot renew --dry-run
   ```

## 2. Update Flutter App for Production

### Update config.dart for HTTPS:

```dart
class AppConfig {
  // Production URL (HTTPS)
  static const String baseUrl = 'https://yourdomain.com';
  
  // For WebSocket (wss:// for HTTPS)
  static String get wsUrl => baseUrl.replaceFirst('https://', 'wss://');
}
```

## 3. Security Hardening

### Backend Security Checklist:

- [ ] **Environment Variables**: Move all secrets to `.env` (never commit)
- [ ] **CORS**: Update to specific origins in production
- [ ] **Rate Limiting**: Already implemented ✓
- [ ] **SQL Injection**: Using Supabase ORM ✓
- [ ] **JWT Security**: Set strong SECRET_KEY
- [ ] **Password Hashing**: Using bcrypt ✓
- [ ] **Input Validation**: Using Pydantic ✓
- [ ] **HTTPS Only**: Enforce SSL
- [ ] **API Key Rotation**: Regularly rotate Supabase keys

### Update main.py CORS for production:

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://yourdomain.com",
        # Add your app's scheme if using deep links
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["*"],
)
```

## 4. Play Store Deployment

### A. Prepare App for Release

1. **Update app version** in `pubspec.yaml`:
   ```yaml
   version: 1.0.0+1  # version+buildNumber
   ```

2. **Create app icons**:
   - Use [App Icon Generator](https://appicon.co/)
   - Replace files in `android/app/src/main/res/mipmap-*`

3. **Update app name** in `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <application
       android:label="MEWallet"
       android:icon="@mipmap/ic_launcher">
   ```

4. **Add permissions** (already in AndroidManifest.xml):
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
   ```

### B. Generate Signing Key

1. **Create keystore**:
   ```bash
   keytool -genkey -v -keystore ~/mewallet-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias mewallet
   ```

2. **Create `android/key.properties`**:
   ```properties
   storePassword=YOUR_STORE_PASSWORD
   keyPassword=YOUR_KEY_PASSWORD
   keyAlias=mewallet
   storeFile=C:/Users/divya/mewallet-keystore.jks
   ```

3. **Update `android/app/build.gradle`**:
   ```gradle
   def keystoreProperties = new Properties()
   def keystorePropertiesFile = rootProject.file('key.properties')
   if (keystorePropertiesFile.exists()) {
       keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
   }

   android {
       ...
       signingConfigs {
           release {
               keyAlias keystoreProperties['keyAlias']
               keyPassword keystoreProperties['keyPassword']
               storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
               storePassword keystoreProperties['storePassword']
           }
       }
       buildTypes {
           release {
               signingConfig signingConfigs.release
               minifyEnabled true
               shrinkResources true
           }
       }
   }
   ```

### C. Build Release APK/AAB

1. **Build App Bundle** (recommended for Play Store):
   ```bash
   flutter build appbundle --release
   ```
   Output: `build/app/outputs/bundle/release/app-release.aab`

2. **Build APK** (for direct distribution):
   ```bash
   flutter build apk --release
   ```
   Output: `build/app/outputs/flutter-apk/app-release.apk`

### D. Play Store Submission

1. **Create Google Play Console Account**:
   - Go to [play.google.com/console](https://play.google.com/console)
   - Pay $25 one-time registration fee

2. **Create New App**:
   - Click "Create app"
   - Fill in app details:
     - App name: MEWallet
     - Default language: English
     - App/Game: App
     - Free/Paid: Free

3. **Prepare Store Listing**:
   - **Short description** (80 chars): Digital wallet for seamless merchant-customer transactions
   - **Full description** (4000 chars max):
     ```
     MEWallet is a secure digital wallet app that enables seamless transactions between merchants and customers.

     Features:
     • Secure user authentication with OTP and OAuth
     • Link with multiple merchants
     • Add balance and make payments
     • Real-time transaction notifications
     • Voice announcements for merchants
     • Transaction history tracking
     • Secure PIN protection
     ```

   - **Screenshots**: Minimum 2, maximum 8 (1080x1920 or 1920x1080)
   - **Feature graphic**: 1024x500 pixels
   - **App icon**: 512x512 pixels

4. **Content Rating**:
   - Complete questionnaire
   - Will likely be rated "Everyone"

5. **App Content**:
   - Privacy policy URL (create one)
   - Target audience
   - News app: No
   - COVID-19 contact tracing: No

6. **Pricing & Distribution**:
   - Select countries
   - Mark as free

7. **App Release**:
   - Upload `app-release.aab`
   - Create release notes
   - Submit for review

### E. Privacy Policy (Required)

Create a simple privacy policy and host it (use [privacypolicygenerator.info](https://www.privacypolicygenerator.info/)):

Key points to include:
- Data collection (name, phone, email)
- Data usage (authentication, transactions)
- Data storage (Supabase)
- Third-party services (Google OAuth, 2Factor OTP)
- User rights

## 5. Testing Before Release

### Test Production Build:
```bash
flutter build apk --release
flutter install
```

### Test Checklist:
- [ ] All features work on release build
- [ ] HTTPS API calls work
- [ ] WebSocket connections work (wss://)
- [ ] OAuth login works
- [ ] OTP verification works
- [ ] TTS announcements work
- [ ] Payment flows complete successfully
- [ ] App doesn't crash on various Android versions
- [ ] Network error handling works

## 6. Post-Deployment

### Monitoring:
- Set up backend logging (Sentry, LogRocket)
- Monitor API performance
- Track app crashes in Play Console
- Monitor user reviews

### Updates:
- Increment version in `pubspec.yaml`
- Build and upload new AAB
- Write release notes
- Submit for review

## 7. Estimated Costs

| Item | Cost | Frequency |
|------|------|-----------|
| Google Play Console | $25 | One-time |
| Domain (optional) | $10-15/year | Annual |
| Cloud Hosting | Free-$7/month | Monthly |
| SSL Certificate | Free (Let's Encrypt) | - |

## 8. Timeline

1. **Backend HTTPS setup**: 1-2 hours
2. **App configuration**: 30 mins
3. **Signing key setup**: 15 mins
4. **Play Store account**: 30 mins
5. **Store listing prep**: 2-3 hours
6. **Testing**: 2-4 hours
7. **Review wait time**: 1-7 days

**Total**: ~1 week from start to Play Store approval

## Quick Start Commands

### 1. Update app for production:
```bash
cd mobile_app
# Update lib/utils/config.dart with HTTPS URL
flutter clean
flutter pub get
```

### 2. Build release:
```bash
flutter build appbundle --release
```

### 3. Test release:
```bash
flutter build apk --release
flutter install
```

### 4. Deploy backend:
```bash
cd backend
# Push to Railway/Render or configure Nginx
```

## Support

- **Flutter Docs**: https://docs.flutter.dev/deployment/android
- **Play Console**: https://support.google.com/googleplay/android-developer
- **Railway**: https://docs.railway.app/
- **Render**: https://render.com/docs
