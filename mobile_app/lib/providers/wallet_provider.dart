import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/models.dart';

class WalletProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  String? _error;
  List<MerchantUserLink> _links = [];
  List<Transaction> _transactions = [];
  double _currentBalance = 0.0;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<MerchantUserLink> get links => _links;
  List<Transaction> get transactions => _transactions;
  double get currentBalance => _currentBalance;
  ApiService get apiService => _apiService;

  Future<void> fetchLinkedUsers(String merchantId, String token) async {
    _setLoading(true);
    _error = null;

    try {
      _links = await _apiService.getLinkedUsers(merchantId, token);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchLinkedMerchants(String userId, String token) async {
    _setLoading(true);
    _error = null;

    try {
      _links = await _apiService.getLinkedMerchants(userId, token);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createLink({
    required String merchantId,
    required String userId,
    required String pin,
    required String token,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      await _apiService.createLink(
        merchantId: merchantId,
        userId: userId,
        pin: pin,
        token: token,
      );
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addBalance({
    required String merchantId,
    required String userId,
    required double amount,
    required String pin,
    required String token,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      await _apiService.addBalance(
        merchantId: merchantId,
        userId: userId,
        amount: amount,
        pin: pin,
        token: token,
      );
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> processPurchase({
    required String merchantId,
    required String userId,
    required double amount,
    required String pin,
    required String token,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      await _apiService.processPurchase(
        merchantId: merchantId,
        userId: userId,
        amount: amount,
        pin: pin,
        token: token,
      );
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> delinkMerchant({
    required String merchantId,
    required String userId,
    required String pin,
    required String token,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      await _apiService.delinkMerchant(
        merchantId: merchantId,
        userId: userId,
        pin: pin,
        token: token,
      );
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchBalance({
    required String merchantId,
    required String userId,
    required String token,
  }) async {
    try {
      final response = await _apiService.getBalance(
        merchantId: merchantId,
        userId: userId,
        token: token,
      );
      _currentBalance = response['balance']?.toDouble() ?? 0.0;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> fetchTransactions({
    required String merchantId,
    required String userId,
    required String token,
    int limit = 50,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      _transactions = await _apiService.getTransactions(
        merchantId: merchantId,
        userId: userId,
        token: token,
        limit: limit,
      );
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void reset() {
    _links = [];
    _transactions = [];
    _currentBalance = 0.0;
    _error = null;
    notifyListeners();
  }
}
