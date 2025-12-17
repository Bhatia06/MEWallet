# MEWallet - Profile Completion & Mobile Login Implementation Plan

## 📋 Overview
This document outlines the comprehensive changes needed to implement:
1. PIN column in users table
2. Mobile number + PIN based authentication
3. Profile completion flow for both OAuth and normal registration
4. Backend PIN hashing support
5. Code cleanup and unused code removal

---

## 🗑️ UNUSED CODE TO REMOVE

### Frontend (Mobile App)
**Files to potentially delete:**
- `link_merchant_screen.dart` - Users can no longer link merchants directly
- `user_transaction_screen.dart` - Not referenced in current implementation

**Code to review:**
- Check all import statements for unused imports
- Remove any commented-out code blocks

---

## 🗄️ DATABASE CHANGES

### 1. Update Users Table Schema

```sql
-- Add new columns to users table
ALTER TABLE users 
ADD COLUMN phone TEXT UNIQUE,
ADD COLUMN pin TEXT,
ADD COLUMN email TEXT,
ADD COLUMN profile_completed BOOLEAN DEFAULT FALSE,
ADD COLUMN oauth_provider TEXT,
ADD COLUMN oauth_id TEXT;

-- Create index for phone number lookups
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);

-- Update existing users to have profile_completed = FALSE
UPDATE users SET profile_completed = FALSE WHERE profile_completed IS NULL;
```

### 2. Migration Notes
- Existing users will need to complete their profile
- Phone number is now REQUIRED and UNIQUE
- PIN is hashed and stored (4 digits)
- Email is optional
- profile_completed must be TRUE to access dashboard

---

## 🔧 BACKEND CHANGES

### 1. Update `models.py`

#### Add New Models:
```python
class UserCreate(BaseModel):
    """Model for creating a new user - Initial registration"""
    user_name: str = Field(..., min_length=1, max_length=100)
    user_passw: str = Field(..., min_length=6, max_length=72)
    # No phone/pin required at registration - handled in profile completion

class UserProfileComplete(BaseModel):
    """Model for completing user profile"""
    user_id: str
    phone: str = Field(..., min_length=10, max_length=10)
    pin: str = Field(..., min_length=4, max_length=4)
    email: Optional[str] = None
    
    @validator('phone')
    def validate_phone(cls, v):
        if not re.match(r'^\d{10}$', v):
            raise ValueError('Phone must be exactly 10 digits')
        return v
    
    @validator('pin')
    def validate_pin(cls, v):
        if not re.match(r'^\d{4}$', v):
            raise ValueError('PIN must be exactly 4 digits')
        return v
    
    @validator('email')
    def validate_email(cls, v):
        if v and not re.match(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$', v):
            raise ValueError('Invalid email format')
        return v

class UserLoginMobile(BaseModel):
    """Model for user login with mobile number"""
    phone: str = Field(..., min_length=10, max_length=10)
    password: str = Field(..., min_length=6)
    
    @validator('phone')
    def validate_phone(cls, v):
        if not re.match(r'^\d{10}$', v):
            raise ValueError('Phone must be exactly 10 digits')
        return v

class UserLoginId(BaseModel):
    """Model for user login with ID (legacy)"""
    user_id: str
    user_passw: str
```

### 2. Update `utils.py`

Add PIN hashing function:
```python
def hash_pin(pin: str) -> str:
    """Hash a PIN using bcrypt"""
    return hash_password(pin)  # Reuse existing password hashing

def verify_pin(plain_pin: str, hashed_pin: str) -> bool:
    """Verify a PIN against its hash"""
    return verify_password(plain_pin, hashed_pin)
```

### 3. Update `user_routes.py`

#### Modify Registration Endpoint:
```python
@router.post("/register", response_model=dict, status_code=status.HTTP_201_CREATED)
@limiter.limit("5/minute")
async def register_user(request: Request, user: UserCreate):
    """Register a new user - Returns user_id, requires profile completion"""
    try:
        supabase = get_supabase_client()
        
        # Generate unique user ID
        user_id = generate_user_id()
        
        # Ensure ID is unique
        while True:
            check = supabase.table("users").select("*").eq("id", user_id).execute()
            if not check.data:
                break
            user_id = generate_user_id()
        
        # Hash password
        hashed_password = hash_password(user.user_passw)
        
        # Insert user with incomplete profile
        result = supabase.table("users").insert({
            "id": user_id,
            "user_name": user.user_name,
            "user_passw": hashed_password,
            "profile_completed": False,  # CRITICAL
            "phone": None,
            "pin": None,
            "email": None
        }).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to create user account"
            )
        
        # Create temporary access token for profile completion
        access_token = create_access_token(
            data={"sub": user_id, "user_type": "user", "temp": True},
            expires_delta=timedelta(minutes=15)  # Short expiry
        )
        
        return {
            "message": "User registered successfully. Please complete your profile.",
            "user_id": user_id,
            "user_name": user.user_name,
            "access_token": access_token,
            "token_type": "bearer",
            "profile_completed": False
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )
```

#### Add Profile Completion Endpoint:
```python
@router.post("/complete-profile", response_model=dict)
@limiter.limit("10/minute")
async def complete_profile(request: Request, profile_data: UserProfileComplete, current_user: dict = Depends(get_current_user)):
    """Complete user profile with phone and PIN"""
    try:
        supabase = get_supabase_client()
        
        # Verify user_id matches current user
        if profile_data.user_id != current_user["sub"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Cannot complete profile for another user"
            )
        
        # Check if phone already exists
        phone_check = supabase.table("users").select("*").eq("phone", profile_data.phone).execute()
        if phone_check.data:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Phone number already registered"
            )
        
        # Hash PIN
        hashed_pin = hash_pin(profile_data.pin)
        
        # Update user profile
        result = supabase.table("users").update({
            "phone": profile_data.phone,
            "pin": hashed_pin,
            "email": profile_data.email,
            "profile_completed": True
        }).eq("id", profile_data.user_id).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to update profile"
            )
        
        # Create new access token (full access)
        access_token = create_access_token(
            data={"sub": profile_data.user_id, "user_type": "user"},
            expires_delta=timedelta(minutes=10080)  # 7 days
        )
        
        return {
            "message": "Profile completed successfully",
            "user_id": profile_data.user_id,
            "access_token": access_token,
            "token_type": "bearer",
            "profile_completed": True
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )
```

#### Add Mobile Login Endpoint:
```python
@router.post("/login/mobile", response_model=dict)
@limiter.limit("10/minute")
async def login_user_mobile(request: Request, user: UserLoginMobile):
    """Login user with mobile number and password"""
    try:
        supabase = get_supabase_client()
        
        # Find user by phone
        result = supabase.table("users").select("*").eq("phone", user.phone).execute()
        
        if not result.data:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid credentials"
            )
        
        user_data = result.data[0]
        
        # Check if profile is completed
        if not user_data.get("profile_completed", False):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Profile not completed. Please complete your profile first."
            )
        
        # Verify password
        if not verify_password(user.password, user_data["user_passw"]):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid credentials"
            )
        
        # Create access token
        access_token = create_access_token(
            data={"sub": user_data["id"], "user_type": "user"},
            expires_delta=timedelta(minutes=10080)
        )
        
        return {
            "message": "Login successful",
            "user_id": user_data["id"],
            "user_name": user_data["user_name"],
            "access_token": access_token,
            "token_type": "bearer",
            "profile_completed": user_data.get("profile_completed", False)
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An error occurred: {str(e)}"
        )
```

### 4. Update `oauth_routes.py`

Modify OAuth endpoints to NOT create user in database until profile completion:

```python
@router.post("/google", response_model=dict)
@limiter.limit("10/minute")
async def google_oauth_login(request: Request, oauth_data: GoogleOAuthLogin):
    """Login or register using Google OAuth - Returns temp token for profile completion"""
    try:
        from google.oauth2 import id_token
        from google.auth.transport import requests
        
        # Verify token
        idinfo = id_token.verify_oauth2_token(
            oauth_data.id_token,
            requests.Request(),
            settings.GOOGLE_CLIENT_ID
        )
        
        google_id = idinfo['sub']
        google_email = idinfo.get('email', '')
        google_name = idinfo.get('name', '')
        
        supabase = get_supabase_client()
        
        if oauth_data.user_type == "user":
            # Check if user exists
            check = supabase.table("users").select("*").eq("oauth_id", google_id).eq("oauth_provider", "google").execute()
            
            if check.data:
                # Existing user
                user_data = check.data[0]
                
                # Check profile completion
                if not user_data.get("profile_completed", False):
                    # Profile incomplete - return temp token
                    temp_token = create_access_token(
                        data={"sub": user_data["id"], "user_type": "user", "temp": True},
                        expires_delta=timedelta(minutes=15)
                    )
                    
                    return {
                        "message": "Please complete your profile",
                        "user_id": user_data["id"],
                        "access_token": temp_token,
                        "token_type": "bearer",
                        "profile_completed": False,
                        "email": google_email,  # Pre-fill
                        "name": google_name
                    }
                
                # Profile complete - normal login
                access_token = create_access_token(
                    data={"sub": user_data["id"], "user_type": "user"},
                    expires_delta=timedelta(minutes=10080)
                )
                
                return {
                    "message": "Login successful",
                    "user_id": user_data["id"],
                    "user_name": user_data["user_name"],
                    "access_token": access_token,
                    "token_type": "bearer",
                    "profile_completed": True
                }
            
            # New user - create with incomplete profile
            user_id = generate_user_id()
            
            while True:
                check = supabase.table("users").select("*").eq("id", user_id).execute()
                if not check.data:
                    break
                user_id = generate_user_id()
            
            # Create user WITHOUT adding to database yet
            # Return temp token for profile completion with pre-filled data
            
            # Actually, we should create the user but with profile_completed = FALSE
            result = supabase.table("users").insert({
                "id": user_id,
                "user_name": google_name,
                "user_passw": "",  # No password for OAuth
                "oauth_provider": "google",
                "oauth_id": google_id,
                "email": google_email,
                "phone": None,
                "pin": None,
                "profile_completed": False
            }).execute()
            
            temp_token = create_access_token(
                data={"sub": user_id, "user_type": "user", "temp": True},
                expires_delta=timedelta(minutes=15)
            )
            
            return {
                "message": "Account created. Please complete your profile.",
                "user_id": user_id,
                "access_token": temp_token,
                "token_type": "bearer",
                "profile_completed": False,
                "email": google_email,  # Pre-fill
                "name": google_name
            }
```

### 5. Update All Transaction Endpoints

Replace all instances of `verify_password(pin, hashed_pin)` with `verify_pin(pin, hashed_pin)`:

**Files to update:**
- `transaction_routes.py` - All endpoints using PIN verification
- `balance_request_routes.py` - PIN verification
- `link_request_routes.py` - PIN verification  
- `routes/pay_request_routes.py` - PIN verification

**Example:**
```python
# OLD
if not verify_password(transaction_data.pin, link_data["pin"]):
    raise HTTPException(...)

# NEW
from utils import verify_pin

if not verify_pin(transaction_data.pin, link_data["pin"]):
    raise HTTPException(...)
```

---

## 📱 FRONTEND CHANGES

### 1. Create Complete Profile Screen

**File:** `mobile_app/lib/screens/complete_profile_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pinput/pinput.dart';
import '../providers/auth_provider.dart';
import '../utils/theme.dart';
import 'user_dashboard_screen.dart';

class CompleteProfileScreen extends StatefulWidget {
  final String userId;
  final String? prefilledEmail;
  final String? prefilledName;
  final bool isOAuth;

  const CompleteProfileScreen({
    super.key,
    required this.userId,
    this.prefilledEmail,
    this.prefilledName,
    this.isOAuth = false,
  });

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledEmail != null) {
      _emailController.text = widget.prefilledEmail!;
    }
  }

  Future<void> _completeProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_pinController.text != _confirmPinController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PINs do not match')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      
      await authProvider.completeProfile(
        userId: widget.userId,
        phone: _phoneController.text,
        pin: _pinController.text,
        email: _emailController.text.isNotEmpty ? _emailController.text : null,
      );

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const UserDashboardScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Complete Your Profile'),
          automaticallyImplyLeading: false,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Almost there!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please provide your mobile number and create a secure PIN to continue.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),

                // Email (optional, pre-filled for OAuth)
                TextFormField(
                  controller: _emailController,
                  enabled: !widget.isOAuth,
                  decoration: InputDecoration(
                    labelText: 'Email (Optional)',
                    prefixIcon: const Icon(Icons.email),
                    suffixIcon: widget.isOAuth
                        ? const Icon(Icons.lock_outline, size: 16)
                        : null,
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                // Phone (required)
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number *',
                    prefixIcon: Icon(Icons.phone),
                    prefix: Text('+91 '),
                  ),
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Mobile number is required';
                    }
                    if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                      return 'Enter a valid 10-digit mobile number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // PIN section
                const Text(
                  'Create a 4-digit PIN',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This PIN will be used for secure transactions',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 16),

                // PIN input
                Pinput(
                  controller: _pinController,
                  length: 4,
                  obscureText: true,
                  defaultPinTheme: PinTheme(
                    width: 56,
                    height: 56,
                    textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                const Text('Confirm PIN', style: TextStyle(fontSize: 14)),
                const SizedBox(height: 8),
                Pinput(
                  controller: _confirmPinController,
                  length: 4,
                  obscureText: true,
                  defaultPinTheme: PinTheme(
                    width: 56,
                    height: 56,
                    textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _completeProfile,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Complete Profile'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

### 2. Update User Registration Screen

**File:** `mobile_app/lib/screens/user_register_screen.dart`

- Remove phone and PIN fields
- After successful registration, navigate to CompleteProfileScreen
- Pass user_id to CompleteProfileScreen

### 3. Update User Login Screen

**File:** `mobile_app/lib/screens/user_login_screen.dart`

- Add toggle between "Login with ID" and "Login with Mobile"
- Two separate forms
- Mobile login uses phone + password (no PIN for login)

### 4. Update Auth Provider

**File:** `mobile_app/lib/providers/auth_provider.dart`

Add methods:
```dart
Future<void> completeProfile({
  required String userId,
  required String phone,
  required String pin,
  String? email,
}) async {
  final response = await _apiService.completeProfile(
    userId: userId,
    phone: phone,
    pin: pin,
    email: email,
  );
  
  // Save token and user data
  _token = response['access_token'];
  _userId = response['user_id'];
  notifyListeners();
}

Future<void> loginWithMobile(String phone, String password) async {
  final response = await _apiService.loginUserMobile(phone, password);
  
  // Check profile_completed
  if (response['profile_completed'] != true) {
    throw Exception('Profile not completed');
  }
  
  _token = response['access_token'];
  _userId = response['user_id'];
  _userName = response['user_name'];
  notifyListeners();
}
```

### 5. Update API Service

**File:** `mobile_app/lib/services/api_service.dart`

Add methods:
```dart
Future<Map<String, dynamic>> completeProfile({
  required String userId,
  required String phone,
  required String pin,
  String? email,
}) async {
  return await _makeRequest('POST', '/user/complete-profile',
      body: {
        'user_id': userId,
        'phone': phone,
        'pin': pin,
        if (email != null) 'email': email,
      });
}

Future<Map<String, dynamic>> loginUserMobile(String phone, String password) async {
  return await _makeRequest('POST', '/user/login/mobile',
      body: {
        'phone': phone,
        'password': password,
      });
}
```

---

## ✅ TESTING CHECKLIST

### Backend Testing:
- [ ] New user registration creates user with profile_completed = FALSE
- [ ] Profile completion endpoint updates user correctly
- [ ] Phone number uniqueness is enforced
- [ ] PIN is properly hashed
- [ ] Mobile login works with phone + password
- [ ] OAuth login redirects to profile completion
- [ ] All transaction endpoints accept hashed PIN
- [ ] Users with incomplete profiles cannot access protected endpoints

### Frontend Testing:
- [ ] Normal registration → Complete Profile → Dashboard flow works
- [ ] OAuth login → Complete Profile → Dashboard flow works
- [ ] Mobile login works
- [ ] ID login still works (legacy)
- [ ] PIN is required (4 digits)
- [ ] Phone validation works
- [ ] Cannot access dashboard without completing profile

---

## 📝 DEPLOYMENT STEPS

1. **Database Migration:**
   ```sql
   -- Run the ALTER TABLE commands on production
   ```

2. **Backend Deployment:**
   - Update models.py
   - Update utils.py (add hash_pin, verify_pin)
   - Update user_routes.py (add endpoints)
   - Update oauth_routes.py
   - Update all transaction routes (use verify_pin)
   - Restart backend server

3. **Frontend Deployment:**
   - Create complete_profile_screen.dart
   - Update user_register_screen.dart
   - Update user_login_screen.dart
   - Update auth_provider.dart
   - Update api_service.dart
   - Rebuild app

4. **User Migration:**
   - Existing users must complete profile on next login
   - Show profile completion screen for users with profile_completed = FALSE

---

## 🔒 SECURITY CONSIDERATIONS

1. **PIN Storage:**
   - ALWAYS hash PIN before storing (use bcrypt)
   - NEVER store plain PIN
   - Use same hashing as passwords

2. **Profile Completion:**
   - Use temporary short-lived tokens (15 min)
   - Require profile completion before dashboard access
   - Validate all inputs

3. **Mobile Login:**
   - Phone must be verified (consider SMS OTP in future)
   - Rate limit login attempts
   - Enforce strong passwords

---

## 📞 SUPPORT

If you encounter issues during implementation:
1. Check database schema is updated
2. Verify all backend endpoints are working (use /docs)
3. Test each flow independently
4. Check logs for errors

---

**Document Version:** 1.0  
**Last Updated:** December 17, 2025  
**Author:** GitHub Copilot
