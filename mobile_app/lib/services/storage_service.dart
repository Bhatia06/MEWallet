import 'package:shared_preferences/shared_preferences.dart';
import '../utils/config.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Token
  Future<void> saveToken(String token) async {
    await _prefs?.setString(AppConfig.tokenKey, token);
  }

  String? getToken() {
    return _prefs?.getString(AppConfig.tokenKey);
  }

  Future<void> removeToken() async {
    await _prefs?.remove(AppConfig.tokenKey);
  }

  // User Type
  Future<void> saveUserType(String userType) async {
    await _prefs?.setString(AppConfig.userTypeKey, userType);
  }

  String? getUserType() {
    return _prefs?.getString(AppConfig.userTypeKey);
  }

  // User ID
  Future<void> saveUserId(String userId) async {
    await _prefs?.setString(AppConfig.userIdKey, userId);
  }

  String? getUserId() {
    return _prefs?.getString(AppConfig.userIdKey);
  }

  // User Name
  Future<void> saveUserName(String userName) async {
    await _prefs?.setString(AppConfig.userNameKey, userName);
  }

  String? getUserName() {
    return _prefs?.getString(AppConfig.userNameKey);
  }

  // Clear all
  Future<void> clearAll() async {
    await _prefs?.clear();
  }

  // Check if logged in
  bool isLoggedIn() {
    return getToken() != null && getUserId() != null;
  }

  // Generic string storage
  Future<void> saveString(String key, String value) async {
    await _prefs?.setString(key, value);
  }

  String? getString(String key) {
    return _prefs?.getString(key);
  }
}
