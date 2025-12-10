# Mobile App Setup Guide

## Prerequisites

1. **Flutter SDK**: Install from https://flutter.dev/docs/get-started/install
2. **Android Studio** (for Android) or **Xcode** (for iOS)
3. **Android SDK** or **iOS Development Tools**

## Step 1: Verify Flutter Installation

```powershell
# Check Flutter installation
flutter doctor

# All checkmarks should be green (or at least Flutter and Android toolchain/Xcode)
```

## Step 2: Install Dependencies

```powershell
# Navigate to mobile app directory
cd mobile_app

# Get all Flutter packages
flutter pub get
```

## Step 3: Configure API Connection

**Important:** Update the backend URL based on your setup.

Edit `lib/utils/config.dart`:

### For Android Emulator:
```dart
static const String baseUrl = 'http://10.0.2.2:8000';
```

### For iOS Simulator:
```dart
static const String baseUrl = 'http://localhost:8000';
```

### For Real Android/iOS Device:
```dart
static const String baseUrl = 'http://192.168.1.XXX:8000';
```
Replace `192.168.1.XXX` with your computer's local IP address.

#### Finding Your Local IP:
```powershell
# On Windows
ipconfig
# Look for "IPv4 Address" under your active network adapter
```

## Step 4: Run the App

### For Android:
```powershell
# List available devices
flutter devices

# Run on connected device/emulator
flutter run

# Or specify a device
flutter run -d <device-id>
```

### For iOS (Mac only):
```powershell
# Open iOS simulator
open -a Simulator

# Run the app
flutter run
```

## Step 5: Testing the App

1. **Start Backend First:**
   ```powershell
   cd backend
   python main.py
   ```

2. **Then Run Mobile App:**
   ```powershell
   cd mobile_app
   flutter run
   ```

## Building APK for Android

### Debug APK (for testing):
```powershell
flutter build apk --debug
```
APK location: `build/app/outputs/flutter-apk/app-debug.apk`

### Release APK (for distribution):
```powershell
flutter build apk --release
```
APK location: `build/app/outputs/flutter-apk/app-release.apk`

### App Bundle (for Google Play):
```powershell
flutter build appbundle --release
```

## Building for iOS

### Requirements:
- Mac computer
- Xcode installed
- Apple Developer account (for distribution)

### Build iOS App:
```powershell
flutter build ios --release
```

## Common Issues

### Issue: "Connection refused" or "Network error"
**Solutions:**
1. Ensure backend server is running
2. Check `baseUrl` in `lib/utils/config.dart`
3. For Android emulator, use `10.0.2.2` not `localhost`
4. For real device:
   - Phone and computer must be on same WiFi
   - Use computer's IP address
   - Check firewall settings

### Issue: Package conflicts
**Solution:**
```powershell
flutter clean
flutter pub get
```

### Issue: Build fails
**Solution:**
```powershell
# Update Flutter
flutter upgrade

# Check for issues
flutter doctor -v

# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

### Issue: "Gradle build failed" (Android)
**Solution:**
1. Update Android SDK
2. Check Java installation
3. Clear Gradle cache:
   ```powershell
   cd android
   .\gradlew clean
   ```

## Testing on Real Device

### Android:
1. Enable Developer Options on phone:
   - Settings → About Phone → Tap "Build Number" 7 times
2. Enable USB Debugging:
   - Settings → Developer Options → USB Debugging
3. Connect phone via USB
4. Authorize computer on phone
5. Run: `flutter run`

### iOS:
1. Connect iPhone via USB
2. Trust the computer on iPhone
3. In Xcode, add your Apple ID
4. Select your device and run

## Network Configuration for Real Devices

### Allow backend connections:

#### Windows Firewall:
```powershell
# Allow Python through firewall
New-NetFirewallRule -DisplayName "Python for MEWallet" -Direction Inbound -Program "C:\Path\To\Python\python.exe" -Action Allow
```

#### Or run backend with specific host:
```python
# In backend/main.py
uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
```

## Hot Reload

While app is running:
- Press `r` to hot reload
- Press `R` to hot restart
- Press `q` to quit

## Debugging

### Enable debug mode:
```powershell
flutter run --debug
```

### View logs:
```powershell
flutter logs
```

### Inspect app:
```powershell
flutter attach
```

## Performance Optimization

### Profile mode (test performance):
```powershell
flutter run --profile
```

### Release mode (production performance):
```powershell
flutter run --release
```

## App Configuration

### Change App Name:
Edit `android/app/src/main/AndroidManifest.xml`:
```xml
<application android:label="MEWallet" ...>
```

### Change App Icon:
1. Add icon image to `assets/images/app_icon.png`
2. Use flutter_launcher_icons package

## Fonts Setup (Optional)

The app uses Poppins font. To add it:

1. Download Poppins from Google Fonts
2. Create `fonts/` folder in project root
3. Add font files:
   - fonts/Poppins-Regular.ttf
   - fonts/Poppins-Medium.ttf
   - fonts/Poppins-SemiBold.ttf
   - fonts/Poppins-Bold.ttf

4. Font declarations are already in `pubspec.yaml`

**Note:** App will work fine with system fonts if you skip this step.

## Deployment Checklist

- [ ] Update `baseUrl` to production server
- [ ] Test all features
- [ ] Build release APK/IPA
- [ ] Test on multiple devices
- [ ] Check permissions
- [ ] Update version in `pubspec.yaml`
- [ ] Create app signing key (Android)
- [ ] Configure app store listings

## Support

If you encounter issues:
1. Run `flutter doctor -v`
2. Check backend is accessible from device
3. Review error logs
4. Clear cache and rebuild
