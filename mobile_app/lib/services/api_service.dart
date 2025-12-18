import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/config.dart';
import '../models/models.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final bool isUnauthorized;

  ApiException(this.message, [this.statusCode])
      : isUnauthorized = statusCode == 401;

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
    required String phone,
    required String pin,
  }) async {
    final response = await _makeRequest('POST', '/user/register', body: {
      'user_name': userName,
      'user_passw': password,
      'phone': phone,
      'pin': pin,
    });

    return AuthResponse.fromJson(response, false);
  }

  // Google OAuth Login
  Future<AuthResponse> loginWithGoogle({
    required String idToken,
    required String userType, // 'user' or 'merchant'
  }) async {
    final response = await _makeRequest('POST', '/oauth/google', body: {
      'id_token': idToken,
      'user_type': userType,
    });

    return AuthResponse.fromJson(response, userType == 'merchant');
  }

  // Complete Merchant OAuth Profile
  Future<Map<String, dynamic>> completeMerchantProfile({
    required String merchantId,
    required String storeName,
    required String ownerName,
    required String token,
    required String phone,
    String? storeAddress,
  }) async {
    final response =
        await _makeRequest('POST', '/oauth/merchant/complete-profile',
            body: {
              'merchant_id': merchantId,
              'store_name': storeName,
              'owner_name': ownerName,
              'phone': phone,
              if (storeAddress != null && storeAddress.isNotEmpty)
                'store_address': storeAddress,
            },
            token: token);

    return response;
  }

  // Complete User OAuth Profile
  Future<Map<String, dynamic>> completeUserProfile({
    required String userId,
    required String userName,
    required String token,
    required String phone,
    required String pin,
  }) async {
    final response = await _makeRequest('POST', '/oauth/user/complete-profile',
        body: {
          'user_id': userId,
          'user_name': userName,
          'pin': pin,
          'phone': phone,
        },
        token: token);

    return response;
  }

  // Complete User Profile with Phone and PIN (for existing users)
  Future<Map<String, dynamic>> completeUserProfileWithPin({
    required String userId,
    required String phone,
    required String pin,
    required String token,
  }) async {
    final response = await _makeRequest('POST', '/user/complete-profile',
        body: {
          'user_id': userId,
          'phone': phone,
          'pin': pin,
        },
        token: token);

    return response;
  }

  Future<AuthResponse> loginUser({
    required String phone,
    required String password,
  }) async {
    final response = await _makeRequest('POST', '/user/login', body: {
      'phone': phone,
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
    String? pin,
    required String token,
  }) async {
    final body = {
      'merchant_id': merchantId,
      'user_id': userId,
      'amount': amount,
    };

    // Only include pin if it's not empty (merchant doesn't need PIN)
    if (pin != null && pin.isNotEmpty) {
      body['pin'] = pin;
    }

    return await _makeRequest('POST', '/link/add-balance',
        body: body, token: token);
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

  Future<List<Transaction>> getMerchantTransactions({
    required String merchantId,
    required String token,
    int limit = 100,
  }) async {
    final response = await _makeRequest(
      'GET',
      '/link/merchant-transactions/$merchantId?limit=$limit',
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
    required String token,
  }) async {
    return await _makeRequest('POST', '/balance-requests/create',
        token: token,
        body: {
          'merchant_id': merchantId,
          'user_id': userId,
          'amount': amount,
          'pin': pin,
        });
  }

  Future<List<BalanceRequest>> getMerchantRequests(
      String merchantId, String token) async {
    try {
      final response = await _makeRequest(
          'GET', '/balance-requests/merchant/$merchantId',
          token: token);
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

  Future<Map<String, dynamic>> acceptBalanceRequest(
      int requestId, String token) async {
    return await _makeRequest('POST', '/balance-requests/accept/$requestId',
        token: token);
  }

  Future<Map<String, dynamic>> rejectBalanceRequest(
      int requestId, String token) async {
    return await _makeRequest('POST', '/balance-requests/reject/$requestId',
        token: token);
  }

  // Link Request APIs
  Future<Map<String, dynamic>> createLinkRequest({
    required String merchantId,
    required String userId,
    required String pin,
    required String token,
  }) async {
    return await _makeRequest('POST', '/link-requests/create',
        token: token,
        body: {
          'merchant_id': merchantId,
          'user_id': userId,
          'pin': pin,
        });
  }

  Future<List<LinkRequest>> getMerchantLinkRequests(
      String merchantId, String token) async {
    try {
      final response = await _makeRequest(
          'GET', '/link-requests/merchant/$merchantId',
          token: token);
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

  Future<Map<String, dynamic>> acceptLinkRequest(
      int requestId, String token) async {
    return await _makeRequest('POST', '/link-requests/accept/$requestId',
        token: token);
  }

  Future<Map<String, dynamic>> rejectLinkRequest(
      int requestId, String token) async {
    return await _makeRequest('POST', '/link-requests/reject/$requestId',
        token: token);
  }

  // Pay Request APIs
  Future<Map<String, dynamic>> createPayRequest({
    required String merchantId,
    required String userId,
    required double amount,
    String? description,
    required String token,
  }) async {
    return await _makeRequest(
      'POST',
      '/pay-requests/create',
      body: {
        'merchant_id': merchantId,
        'user_id': userId,
        'amount': amount,
        if (description != null) 'description': description,
      },
      token: token,
    );
  }

  Future<List<PayRequest>> getUserPayRequests(
      String userId, String token) async {
    try {
      final response =
          await _makeRequest('GET', '/pay-requests/user/$userId', token: token);
      if (response is List) {
        return response
            .map((json) => PayRequest.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error getting user pay requests: $e');
      return [];
    }
  }

  Future<List<PayRequest>> getMerchantPayRequests(
      String merchantId, String token) async {
    try {
      final response = await _makeRequest(
          'GET', '/pay-requests/merchant/$merchantId',
          token: token);
      if (response is List) {
        return response
            .map((json) => PayRequest.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error getting merchant pay requests: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> acceptPayRequest({
    required int requestId,
    required String pin,
    required String token,
  }) async {
    return await _makeRequest(
      'POST',
      '/pay-requests/accept',
      body: {
        'request_id': requestId,
        'pin': pin,
      },
      token: token,
    );
  }

  Future<Map<String, dynamic>> rejectPayRequest(
      int requestId, String token) async {
    return await _makeRequest('POST', '/pay-requests/reject/$requestId',
        token: token);
  }

  // User Profile APIs
  Future<Map<String, dynamic>> getUserProfileDetails({
    required String userId,
    required String token,
  }) async {
    return await _makeRequest('GET', '/user/profile/$userId', token: token);
  }

  Future<Map<String, dynamic>> updateUserProfile({
    required String userId,
    required String token,
    required String userName,
    required String phone,
    String? dob,
  }) async {
    return await _makeRequest('PUT', '/user/profile/$userId',
        body: {
          'user_name': userName,
          'phone': phone,
          if (dob != null) 'dob': dob,
        },
        token: token);
  }

  Future<Map<String, dynamic>> linkGoogleAccount({
    required String userId,
    required String token,
    required String idToken,
  }) async {
    return await _makeRequest('POST', '/user/link-google',
        body: {
          'user_id': userId,
          'id_token': idToken,
        },
        token: token);
  }

  Future<Map<String, dynamic>> deleteUserAccount({
    required String userId,
    required String token,
  }) async {
    return await _makeRequest('DELETE', '/user/account/$userId', token: token);
  }

  // Merchant Profile APIs
  Future<Map<String, dynamic>> getMerchantProfileDetails({
    required String merchantId,
    required String token,
  }) async {
    return await _makeRequest('GET', '/merchant/profile/$merchantId',
        token: token);
  }

  Future<Map<String, dynamic>> updateMerchantProfile({
    required String merchantId,
    required String token,
    required String storeName,
    required String phone,
    String? storeAddress,
  }) async {
    return await _makeRequest('PUT', '/merchant/profile/$merchantId',
        body: {
          'store_name': storeName,
          'phone': phone,
          if (storeAddress != null && storeAddress.isNotEmpty)
            'store_address': storeAddress,
        },
        token: token);
  }

  Future<Map<String, dynamic>> linkGoogleAccountMerchant({
    required String merchantId,
    required String token,
    required String idToken,
  }) async {
    return await _makeRequest('POST', '/merchant/link-google',
        body: {
          'merchant_id': merchantId,
          'id_token': idToken,
        },
        token: token);
  }

  Future<Map<String, dynamic>> setUserPassword({
    required String userId,
    required String token,
    required String password,
  }) async {
    return await _makeRequest('POST', '/user/set-password',
        body: {
          'user_id': userId,
          'password': password,
        },
        token: token);
  }

  Future<Map<String, dynamic>> updateUserPassword({
    required String userId,
    required String token,
    required String oldPassword,
    required String newPassword,
  }) async {
    return await _makeRequest('POST', '/user/update-password',
        body: {
          'user_id': userId,
          'old_password': oldPassword,
          'new_password': newPassword,
        },
        token: token);
  }

  Future<Map<String, dynamic>> setMerchantPassword({
    required String merchantId,
    required String token,
    required String password,
  }) async {
    return await _makeRequest('POST', '/merchant/set-password',
        body: {
          'merchant_id': merchantId,
          'password': password,
        },
        token: token);
  }

  Future<Map<String, dynamic>> updateMerchantPassword({
    required String merchantId,
    required String token,
    required String oldPassword,
    required String newPassword,
  }) async {
    return await _makeRequest('POST', '/merchant/update-password',
        body: {
          'merchant_id': merchantId,
          'old_password': oldPassword,
          'new_password': newPassword,
        },
        token: token);
  }
}
