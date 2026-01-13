class AppConfig {
  // API Configuration - Production HTTPS URL
  static const String baseUrl = 'https://mewallet.tgenie.in';

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
