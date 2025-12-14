# Flutter App Updates Required for Backend Security

## 🔐 Backend Security Changes Applied

The backend now requires **JWT authentication** for all protected endpoints. Here's what needs to be updated in the Flutter app:

---

## ✅ Already Working (No Changes Needed)

The following endpoints are **already handled correctly** by your Flutter app:

1. ✅ **Login/Register endpoints** - Return access tokens
2. ✅ **OAuth endpoints** - Return access tokens
3. ✅ **Token storage** - Already using `StorageService`
4. ✅ **Authorization headers** - Already added in API calls

---

## 📝 Verification Checklist

### 1. API Service - Authorization Headers

Your `api_service.dart` should include the token in **ALL** API calls except login/register:

```dart
// ✅ GOOD - With Authorization header
final response = await http.get(
  Uri.parse('$baseUrl/user/profile/$userId'),
  headers: {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  },
);

// ❌ BAD - Missing Authorization header
final response = await http.get(
  Uri.parse('$baseUrl/user/profile/$userId'),
  headers: {'Content-Type': 'application/json'},
);
```

### 2. Error Handling - 401 Responses

Add global error handling for expired/invalid tokens:

```dart
// In api_service.dart or a wrapper
Future<http.Response> _makeAuthenticatedRequest(/* params */) async {
  final response = await http.get(/* ... */);
  
  if (response.statusCode == 401) {
    // Token expired or invalid
    // Clear stored token
    await StorageService.clearToken();
    // Navigate to login (use navigation service or callback)
    throw Exception('Session expired. Please login again.');
  }
  
  if (response.statusCode == 403) {
    throw Exception('You do not have permission to access this resource');
  }
  
  return response;
}
```

### 3. Token Refresh Strategy

Since tokens expire after 30 minutes, consider:

**Option A: Extended Token Expiration (Already implemented for OAuth)**
- OAuth tokens last 15 days
- Regular tokens last 30 minutes

**Option B: Token Refresh (Optional - for future enhancement)**
```dart
// If you want to implement token refresh in the future:
// 1. Add refresh_token to backend responses
// 2. Store refresh_token securely
// 3. Call refresh endpoint when 401 is received
// 4. Retry original request with new token
```

---

## 🛠️ Recommended App Updates

### 1. Add Global Error Handler

Create a wrapper for all API calls:

```dart
// lib/services/api_service.dart

class ApiService {
  final String baseUrl = 'http://your-api-url:8000';
  
  Future<http.Response> _authenticatedGet(String path, String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    
    _handleAuthErrors(response);
    return response;
  }
  
  Future<http.Response> _authenticatedPost(
    String path, 
    String token, 
    Map<String, dynamic> body
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(body),
    );
    
    _handleAuthErrors(response);
    return response;
  }
  
  void _handleAuthErrors(http.Response response) {
    if (response.statusCode == 401) {
      throw ApiException('Session expired. Please login again.', 401);
    } else if (response.statusCode == 403) {
      throw ApiException('Access denied.', 403);
    } else if (response.statusCode == 429) {
      throw ApiException('Too many requests. Please try again later.', 429);
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  
  ApiException(this.message, this.statusCode);
  
  @override
  String toString() => message;
}
```

### 2. Update AuthProvider to Handle Session Expiry

```dart
// lib/providers/auth_provider.dart

class AuthProvider extends ChangeNotifier {
  // ... existing code ...
  
  Future<void> handleUnauthorized() async {
    // Clear all session data
    await StorageService.clearToken();
    _token = null;
    _userId = null;
    _merchantId = null;
    _userType = null;
    notifyListeners();
  }
  
  bool isTokenValid() {
    // You can add token expiration check here if you decode JWT
    // For now, rely on backend 401 responses
    return _token != null && _token!.isNotEmpty;
  }
}
```

### 3. Add Session Expiry Screen Navigation

In your main app widget or navigation service:

```dart
// Catch ApiException globally
try {
  // Your API call
} on ApiException catch (e) {
  if (e.statusCode == 401) {
    // Clear auth state
    await context.read<AuthProvider>().handleUnauthorized();
    
    // Navigate to login
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen()),
        (route) => false,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  } else {
    // Handle other errors
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message)),
    );
  }
}
```

---

## 🎯 Rate Limiting Awareness

The backend now has rate limits. Handle 429 (Too Many Requests) responses:

```dart
void _handleAuthErrors(http.Response response) {
  // ... existing code ...
  
  if (response.statusCode == 429) {
    final data = json.decode(response.body);
    final retryAfter = data['detail'] ?? 'Please try again in a minute';
    throw ApiException(retryAfter, 429);
  }
}
```

Show user-friendly messages:
- "Too many login attempts. Please try again in a few minutes."
- "Request limit reached. Please wait a moment before trying again."

---

## 🔍 Testing Checklist

Test these scenarios:

1. ✅ **Valid token** - All API calls work normally
2. ✅ **Expired token** - App shows "Session expired" and redirects to login
3. ✅ **No token** - Protected endpoints return 401, app redirects to login
4. ✅ **Invalid token** - Same as expired token
5. ✅ **Rate limiting** - Show appropriate message when limit reached
6. ✅ **Unauthorized access** - User trying to access another user's data gets 403

---

## 📊 Current Endpoint Status

### Public Endpoints (No Token Required)
- ✅ `POST /user/register`
- ✅ `POST /user/login`
- ✅ `POST /merchant/register`
- ✅ `POST /merchant/login`
- ✅ `POST /oauth/google`
- ✅ `GET /health`

### Protected Endpoints (Token Required)
All other endpoints now require `Authorization: Bearer <token>` header:

- 🔐 All profile endpoints
- 🔐 All linked users/merchants endpoints
- 🔐 All transaction endpoints
- 🔐 All balance request endpoints
- 🔐 All link request endpoints
- 🔐 OAuth profile completion endpoints

---

## 🚀 Quick Implementation Steps

1. **Verify** all API calls in `api_service.dart` include Authorization header
2. **Add** global error handler for 401/403/429 status codes
3. **Update** AuthProvider with `handleUnauthorized()` method
4. **Test** session expiry by waiting 30 minutes or setting backend token expiry to 1 minute
5. **Add** user-friendly error messages for rate limiting

---

## ✨ Benefits of These Changes

1. ✅ **Security**: No unauthorized access to any protected endpoints
2. ✅ **Better UX**: Clear error messages when session expires
3. ✅ **Rate Limit Protection**: Prevents abuse and DoS attacks
4. ✅ **Resource Ownership**: Users can only access their own data
5. ✅ **Production Ready**: Enterprise-grade security implementation

---

## 📞 Need Help?

If you encounter any issues:

1. Check if token is being sent in Authorization header
2. Verify token format: `Bearer <actual-token>`
3. Check backend logs for specific error messages
4. Use browser dev tools or Postman to test endpoints directly
5. Verify token hasn't expired (30 min for regular, 15 days for OAuth)

The backend is now fully secured! Your Flutter app should continue working normally as long as it's sending the tokens correctly in the Authorization headers.
