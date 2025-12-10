class Merchant {
  final String id;
  final String storeName;
  final String phone;
  final DateTime? createdAt;

  Merchant({
    required this.id,
    required this.storeName,
    required this.phone,
    this.createdAt,
  });

  factory Merchant.fromJson(Map<String, dynamic> json) {
    return Merchant(
      id: json['id'] ?? '',
      storeName: json['store_name'] ?? '',
      phone: json['phone'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'store_name': storeName,
      'phone': phone,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class User {
  final String id;
  final String userName;
  final DateTime? createdAt;

  User({
    required this.id,
    required this.userName,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      userName: json['user_name'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_name': userName,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class MerchantUserLink {
  final int linkId;
  final String merchantId;
  final String userId;
  final String? storeName;
  final String? userName;
  final double balance;
  final DateTime? createdAt;

  MerchantUserLink({
    required this.linkId,
    required this.merchantId,
    required this.userId,
    this.storeName,
    this.userName,
    required this.balance,
    this.createdAt,
  });

  factory MerchantUserLink.fromJson(Map<String, dynamic> json) {
    return MerchantUserLink(
      linkId: json['link_id'] ?? json['id'] ?? 0,
      merchantId: json['merchant_id'] ?? '',
      userId: json['user_id'] ?? '',
      storeName: json['store_name'],
      userName: json['user_name'],
      balance: (json['balance'] ?? 0).toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }
}

class Transaction {
  final int id;
  final String merchantId;
  final String userId;
  final double amount;
  final String transactionType;
  final double balanceAfter;
  final DateTime? createdAt;

  Transaction({
    required this.id,
    required this.merchantId,
    required this.userId,
    required this.amount,
    required this.transactionType,
    required this.balanceAfter,
    this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] ?? 0,
      merchantId: json['merchant_id'] ?? '',
      userId: json['user_id'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      transactionType: json['transaction_type'] ?? '',
      balanceAfter: (json['balance_after'] ?? 0).toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  bool get isCredit => transactionType == 'credit';
  bool get isDebit => transactionType == 'debit';
}

class AuthResponse {
  final String message;
  final String id;
  final String name;
  final String accessToken;
  final String tokenType;

  AuthResponse({
    required this.message,
    required this.id,
    required this.name,
    required this.accessToken,
    required this.tokenType,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json, bool isMerchant) {
    return AuthResponse(
      message: json['message'] ?? '',
      id: json[isMerchant ? 'merchant_id' : 'user_id'] ?? '',
      name: json[isMerchant ? 'store_name' : 'user_name'] ?? '',
      accessToken: json['access_token'] ?? '',
      tokenType: json['token_type'] ?? 'bearer',
    );
  }
}

class BalanceRequest {
  final int? id;
  final String merchantId;
  final String userId;
  final double amount;
  final String? pin;
  final String status;
  final String? userName;
  final DateTime? createdAt;

  BalanceRequest({
    this.id,
    required this.merchantId,
    required this.userId,
    required this.amount,
    this.pin,
    this.status = 'pending',
    this.userName,
    this.createdAt,
  });

  factory BalanceRequest.fromJson(Map<String, dynamic> json) {
    return BalanceRequest(
      id: json['request_id'] ?? json['id'],
      merchantId: json['merchant_id'] ?? '',
      userId: json['user_id'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      pin: json['pin'],
      status: json['status'] ?? 'pending',
      userName: json['user_name'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'merchant_id': merchantId,
      'user_id': userId,
      'amount': amount,
      'pin': pin,
    };
  }
}
