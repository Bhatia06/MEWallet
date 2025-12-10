import 'package:flutter/material.dart';
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
