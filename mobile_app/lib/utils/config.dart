class AppConfig {
  // API Configuration - UPDATE THESE VALUES
  static const String baseUrl = 'http://93.127.172.13:8000';

  // For Android Emulator use: http://10.0.2.2:8000
  // For iOS Simulator use: http://localhost:8000
  // For Real Device use: http://YOUR_LOCAL_IP:8000 (e.g., http://192.168.1.100:8000)

  static const String apiVersion = 'v1';

  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Storage keys
  static const String tokenKey = 'auth_token';
  static const String userTypeKey = 'user_type';
  static const String userIdKey = 'user_id';
  static const String userNameKey = 'user_name';
}
