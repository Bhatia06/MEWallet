import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();

  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;
  String? _userId;
  String? _userName;
  String? _userType;
  String? _token;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;
  String? get userId => _userId;
  String? get userName => _userName;
  String? get userType => _userType;
  String? get token => _token;
  bool get isMerchant => _userType == 'merchant';
  bool get isUser => _userType == 'user';

  AuthProvider() {
    _checkAuthStatus();
  }

  void _checkAuthStatus() {
    _isAuthenticated = _storageService.isLoggedIn();
    if (_isAuthenticated) {
      _userId = _storageService.getUserId();
      _userName = _storageService.getUserName();
      _userType = _storageService.getUserType();
      _token = _storageService.getToken();
    }
    notifyListeners();
  }

  Future<void> registerMerchant({
    required String storeName,
    required String phone,
    required String password,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await _apiService.registerMerchant(
        storeName: storeName,
        phone: phone,
        password: password,
      );

      await _saveAuthData(
        id: response.id,
        name: response.name,
        token: response.accessToken,
        userType: 'merchant',
      );

      _isAuthenticated = true;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loginMerchant({
    required String phone,
    required String password,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await _apiService.loginMerchant(
        phone: phone,
        password: password,
      );

      await _saveAuthData(
        id: response.id,
        name: response.name,
        token: response.accessToken,
        userType: 'merchant',
      );

      _isAuthenticated = true;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> registerUser({
    required String userName,
    required String password,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await _apiService.registerUser(
        userName: userName,
        password: password,
      );

      await _saveAuthData(
        id: response.id,
        name: response.name,
        token: response.accessToken,
        userType: 'user',
      );

      _isAuthenticated = true;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Google Sign-In
  Future<Map<String, dynamic>> signInWithGoogle(
      {required String userType}) async {
    _setLoading(true);
    _error = null;

    try {
      // Configure Google Sign-In
      // On Android, the OAuth client is automatically configured via google-services.json
      // The serverClientId (Web client ID) is only needed for backend token verification
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        serverClientId:
            '443131879916-rfdrg8e0fob1f325bbpkl1ppf1n5lcjp.apps.googleusercontent.com',
      );

      // Sign out first to ensure account picker shows
      await googleSignIn.signOut();

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        throw ApiException('Google sign-in cancelled');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.idToken == null) {
        throw ApiException('Failed to get Google ID token');
      }

      // Send to backend for verification
      final response = await _apiService.loginWithGoogle(
        idToken: googleAuth.idToken!,
        userType: userType,
      );

      // Check if profile needs completion
      if (response.profileCompleted == false) {
        // Return data for profile completion screen
        return {
          'needs_profile': true,
          'user_type': userType,
          'id': response.id,
          'name': response.name,
          'owner_name': response.ownerName ?? '',
          'google_email': response.googleEmail ?? '',
          'token': response.accessToken,
        };
      }

      // Profile already complete, save and login
      await _saveAuthData(
        id: response.id,
        name: response.name,
        token: response.accessToken,
        userType: userType,
      );

      _isAuthenticated = true;
      notifyListeners();

      return {'needs_profile': false};
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Complete Merchant OAuth Profile
  Future<void> completeMerchantProfile({
    required String merchantId,
    required String storeName,
    required String ownerName,
    required String token,
    String? phone,
    String? storeAddress,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      // Save token first so API calls work
      await _storageService.saveToken(token);
      _token = token;

      await _apiService.completeMerchantProfile(
        merchantId: merchantId,
        storeName: storeName,
        ownerName: ownerName,
        phone: phone,
        storeAddress: storeAddress,
      );

      // Profile completed, update local state
      await _storageService.saveUserId(merchantId);
      await _storageService.saveUserName(storeName);
      await _storageService.saveUserType('merchant');

      _userId = merchantId;
      _userName = storeName;
      _userType = 'merchant';
      _isAuthenticated = true;

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Complete User OAuth Profile
  Future<void> completeUserProfile({
    required String userId,
    required String userName,
    required String token,
    String? phone,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      // Save token first so API calls work
      await _storageService.saveToken(token);
      _token = token;

      await _apiService.completeUserProfile(
        userId: userId,
        userName: userName,
        phone: phone,
      );

      // Profile completed, update local state
      await _storageService.saveUserId(userId);
      await _storageService.saveUserName(userName);
      await _storageService.saveUserType('user');

      _userId = userId;
      _userName = userName;
      _userType = 'user';
      _isAuthenticated = true;

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loginUser({
    required String userId,
    required String password,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await _apiService.loginUser(
        userId: userId,
        password: password,
      );

      await _saveAuthData(
        id: response.id,
        name: response.name,
        token: response.accessToken,
        userType: 'user',
      );

      _isAuthenticated = true;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await _storageService.clearAll();
    _isAuthenticated = false;
    _userId = null;
    _userName = null;
    _userType = null;
    _token = null;
    notifyListeners();
  }

  Future<void> _saveAuthData({
    required String id,
    required String name,
    required String token,
    required String userType,
  }) async {
    await _storageService.saveUserId(id);
    await _storageService.saveUserName(name);
    await _storageService.saveToken(token);
    await _storageService.saveUserType(userType);

    _userId = id;
    _userName = name;
    _token = token;
    _userType = userType;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
