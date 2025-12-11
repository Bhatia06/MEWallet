import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/config.dart';
import '../models/models.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final String baseUrl = AppConfig.baseUrl;

  // Helper method to handle HTTP requests
  Future<dynamic> _makeRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await http
              .get(url, headers: headers)
              .timeout(AppConfig.connectionTimeout);
          break;
        case 'POST':
          response = await http
              .post(
                url,
                headers: headers,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(AppConfig.connectionTimeout);
          break;
        case 'PUT':
          response = await http
              .put(
                url,
                headers: headers,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(AppConfig.connectionTimeout);
          break;
        case 'DELETE':
          response = await http
              .delete(url, headers: headers)
              .timeout(AppConfig.connectionTimeout);
          break;
        default:
          throw ApiException('Unsupported HTTP method: $method');
      }

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Connection error: ${e.toString()}');
    }
  }

  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;

    try {
      final data = jsonDecode(response.body);

      if (statusCode >= 200 && statusCode < 300) {
        return data;
      } else {
        final message = data is Map
            ? (data['detail'] ?? 'An error occurred')
            : 'An error occurred';
        throw ApiException(message, statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to parse response', statusCode);
    }
  }

  // Merchant APIs
  Future<AuthResponse> registerMerchant({
    required String storeName,
    required String phone,
    required String password,
  }) async {
    final response = await _makeRequest('POST', '/merchant/register', body: {
      'store_name': storeName,
      'phone': phone,
      'password': password,
    });

    return AuthResponse.fromJson(response, true);
  }

  Future<AuthResponse> loginMerchant({
    required String phone,
    required String password,
  }) async {
    final response = await _makeRequest('POST', '/merchant/login', body: {
      'phone': phone,
      'password': password,
    });

    return AuthResponse.fromJson(response, true);
  }

  Future<Merchant> getMerchantProfile(String merchantId, String token) async {
    final response = await _makeRequest(
      'GET',
      '/merchant/profile/$merchantId',
      token: token,
    );

    return Merchant.fromJson(response);
  }

  Future<List<MerchantUserLink>> getLinkedUsers(
    String merchantId,
    String token,
  ) async {
    final response = await _makeRequest(
      'GET',
      '/merchant/linked-users/$merchantId',
      token: token,
    );

    if (response is List) {
      return response
          .map((e) => MerchantUserLink.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  // User APIs
  Future<AuthResponse> registerUser({
    required String userName,
    required String password,
  }) async {
    final response = await _makeRequest('POST', '/user/register', body: {
      'user_name': userName,
      'user_passw': password,
    });

    return AuthResponse.fromJson(response, false);
  }

  Future<AuthResponse> loginUser({
    required String userId,
    required String password,
  }) async {
    final response = await _makeRequest('POST', '/user/login', body: {
      'user_id': userId,
      'user_passw': password,
    });

    return AuthResponse.fromJson(response, false);
  }

  Future<User> getUserProfile(String userId, String token) async {
    final response = await _makeRequest(
      'GET',
      '/user/profile/$userId',
      token: token,
    );

    return User.fromJson(response);
  }

  Future<List<MerchantUserLink>> getLinkedMerchants(
    String userId,
    String token,
  ) async {
    final response = await _makeRequest(
      'GET',
      '/user/linked-merchants/$userId',
      token: token,
    );

    if (response is List) {
      return response
          .map((e) => MerchantUserLink.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  // Transaction APIs
  Future<Map<String, dynamic>> createLink({
    required String merchantId,
    required String userId,
    required String pin,
    required String token,
  }) async {
    return await _makeRequest('POST', '/link/create',
        body: {
          'merchant_id': merchantId,
          'user_id': userId,
          'pin': pin,
        },
        token: token);
  }

  Future<Map<String, dynamic>> addBalance({
    required String merchantId,
    required String userId,
    required double amount,
    required String pin,
    required String token,
  }) async {
    return await _makeRequest('POST', '/link/add-balance',
        body: {
          'merchant_id': merchantId,
          'user_id': userId,
          'amount': amount,
          'pin': pin,
        },
        token: token);
  }

  Future<Map<String, dynamic>> processPurchase({
    required String merchantId,
    required String userId,
    required double amount,
    required String pin,
    required String token,
  }) async {
    return await _makeRequest('POST', '/link/purchase',
        body: {
          'merchant_id': merchantId,
          'user_id': userId,
          'amount': amount,
          'pin': pin,
        },
        token: token);
  }

  Future<Map<String, dynamic>> delinkMerchant({
    required String merchantId,
    required String userId,
    required String pin,
    required String token,
  }) async {
    return await _makeRequest('POST', '/link/delink',
        body: {
          'merchant_id': merchantId,
          'user_id': userId,
          'pin': pin,
        },
        token: token);
  }

  Future<Map<String, dynamic>> getBalance({
    required String merchantId,
    required String userId,
    required String token,
  }) async {
    return await _makeRequest(
      'GET',
      '/link/balance/$merchantId/$userId',
      token: token,
    );
  }

  Future<List<Transaction>> getTransactions({
    required String merchantId,
    required String userId,
    required String token,
    int limit = 50,
  }) async {
    final response = await _makeRequest(
      'GET',
      '/link/transactions/$merchantId/$userId?limit=$limit',
      token: token,
    );

    if (response is List) {
      return response
          .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<Transaction>> getUserTransactions({
    required String userId,
    required String token,
    int limit = 100,
  }) async {
    final response = await _makeRequest(
      'GET',
      '/link/user-transactions/$userId?limit=$limit',
      token: token,
    );

    if (response is List) {
      return response
          .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  // Health check
  Future<bool> checkHealth() async {
    try {
      final response = await _makeRequest('GET', '/health');
      return response['status'] == 'healthy';
    } catch (e) {
      return false;
    }
  }

  // Balance Request APIs
  Future<Map<String, dynamic>> createBalanceRequest({
    required String merchantId,
    required String userId,
    required double amount,
    required String pin,
  }) async {
    return await _makeRequest('POST', '/balance-requests/create', body: {
      'merchant_id': merchantId,
      'user_id': userId,
      'amount': amount,
      'pin': pin,
    });
  }

  Future<List<BalanceRequest>> getMerchantRequests(String merchantId) async {
    try {
      final response =
          await _makeRequest('GET', '/balance-requests/merchant/$merchantId');
      if (response is List) {
        return response
            .map(
                (json) => BalanceRequest.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error getting merchant requests: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> acceptBalanceRequest(int requestId) async {
    return await _makeRequest('POST', '/balance-requests/accept/$requestId');
  }

  Future<Map<String, dynamic>> rejectBalanceRequest(int requestId) async {
    return await _makeRequest('POST', '/balance-requests/reject/$requestId');
  }

  // Link Request APIs
  Future<Map<String, dynamic>> createLinkRequest({
    required String merchantId,
    required String userId,
    required String pin,
  }) async {
    return await _makeRequest('POST', '/link-requests/create', body: {
      'merchant_id': merchantId,
      'user_id': userId,
      'pin': pin,
    });
  }

  Future<List<LinkRequest>> getMerchantLinkRequests(String merchantId) async {
    try {
      final response =
          await _makeRequest('GET', '/link-requests/merchant/$merchantId');
      if (response is List) {
        return response
            .map((json) => LinkRequest.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error getting merchant link requests: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> acceptLinkRequest(int requestId) async {
    return await _makeRequest('POST', '/link-requests/accept/$requestId');
  }

  Future<Map<String, dynamic>> rejectLinkRequest(int requestId) async {
    return await _makeRequest('POST', '/link-requests/reject/$requestId');
  }
}
