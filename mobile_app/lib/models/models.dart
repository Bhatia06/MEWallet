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
  final String? storeName;
  final String? userName;

  Transaction({
    required this.id,
    required this.merchantId,
    required this.userId,
    required this.amount,
    required this.transactionType,
    required this.balanceAfter,
    this.createdAt,
    this.storeName,
    this.userName,
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
      storeName: json['store_name'],
      userName: json['user_name'],
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
  final bool? profileCompleted;
  final bool? needsPhone;
  final bool? needsPin;
  final String? ownerName; // For OAuth merchants
  final String? googleEmail; // For OAuth users/merchants

  AuthResponse({
    required this.message,
    required this.id,
    required this.name,
    required this.accessToken,
    required this.tokenType,
    this.profileCompleted,
    this.needsPhone,
    this.needsPin,
    this.ownerName,
    this.googleEmail,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json, bool isMerchant) {
    return AuthResponse(
      message: json['message'] ?? '',
      id: json[isMerchant ? 'merchant_id' : 'user_id'] ?? '',
      name: json[isMerchant ? 'store_name' : 'user_name'] ?? '',
      accessToken: json['access_token'] ?? '',
      tokenType: json['token_type'] ?? 'bearer',
      profileCompleted: json['profile_completed'],
      needsPhone: json['needs_phone'],
      needsPin: json['needs_pin'],
      ownerName: json['owner_name'],
      googleEmail: json['google_email'],
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
  final String? requestType;

  BalanceRequest({
    this.id,
    required this.merchantId,
    required this.userId,
    required this.amount,
    this.pin,
    this.status = 'pending',
    this.userName,
    this.createdAt,
    this.requestType,
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
      requestType: json['request_type'],
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

class LinkRequest {
  final int? id;
  final String merchantId;
  final String userId;
  final String? pin;
  final String status;
  final String? userName;
  final DateTime? createdAt;

  LinkRequest({
    this.id,
    required this.merchantId,
    required this.userId,
    this.pin,
    this.status = 'pending',
    this.userName,
    this.createdAt,
  });

  factory LinkRequest.fromJson(Map<String, dynamic> json) {
    return LinkRequest(
      id: json['request_id'] ?? json['id'],
      merchantId: json['merchant_id'] ?? '',
      userId: json['user_id'] ?? '',
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
      'pin': pin,
    };
  }
}

class PayRequest {
  final int id;
  final String merchantId;
  final String userId;
  final double amount;
  final String? description;
  final String status; // 'pending', 'accepted', 'rejected'
  final DateTime? createdAt;
  final DateTime? respondedAt;
  final String? storeName;
  final String? userName;

  PayRequest({
    required this.id,
    required this.merchantId,
    required this.userId,
    required this.amount,
    this.description,
    required this.status,
    this.createdAt,
    this.respondedAt,
    this.storeName,
    this.userName,
  });

  factory PayRequest.fromJson(Map<String, dynamic> json) {
    return PayRequest(
      id: json['id'],
      merchantId: json['merchant_id'] ?? '',
      userId: json['user_id'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      description: json['description'],
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'])
          : null,
      storeName: json['store_name'],
      userName: json['user_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchant_id': merchantId,
      'user_id': userId,
      'amount': amount,
      'description': description,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
      'responded_at': respondedAt?.toIso8601String(),
      'store_name': storeName,
      'user_name': userName,
    };
  }
}

class Reminder {
  final int id;
  final String merchantId;
  final String userId;
  final int linkId;
  final String message;
  final DateTime reminderDate;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? storeName;
  final String? userName;
  final double? balance;

  Reminder({
    required this.id,
    required this.merchantId,
    required this.userId,
    required this.linkId,
    required this.message,
    required this.reminderDate,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.storeName,
    this.userName,
    this.balance,
  });

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'] ?? 0,
      merchantId: json['merchant_id'] ?? '',
      userId: json['user_id'] ?? '',
      linkId: json['link_id'] ?? 0,
      message: json['message'] ?? '',
      reminderDate: json['reminder_date'] != null
          ? DateTime.parse(json['reminder_date'])
          : DateTime.now(),
      status: json['status'] ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      storeName: json['store_name'],
      userName: json['user_name'],
      balance:
          json['balance'] != null ? (json['balance'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchant_id': merchantId,
      'user_id': userId,
      'link_id': linkId,
      'message': message,
      'reminder_date': reminderDate.toIso8601String(),
      'status': status,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'store_name': storeName,
      'user_name': userName,
      'balance': balance,
    };
  }
}

class UserNotification {
  final int id;
  final String merchantId;
  final String storeName;
  final double balance;
  final String message;
  final DateTime reminderDate;
  final String status;
  final DateTime? createdAt;
  final String type;

  UserNotification({
    required this.id,
    required this.merchantId,
    required this.storeName,
    required this.balance,
    required this.message,
    required this.reminderDate,
    required this.status,
    this.createdAt,
    required this.type,
  });

  factory UserNotification.fromJson(Map<String, dynamic> json) {
    return UserNotification(
      id: json['id'] ?? 0,
      merchantId: json['merchant_id'] ?? '',
      storeName: json['store_name'] ?? 'Unknown Store',
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      message: json['message'] ?? '',
      reminderDate: json['reminder_date'] != null
          ? DateTime.parse(json['reminder_date'])
          : DateTime.now(),
      status: json['status'] ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      type: json['type'] ?? 'payment_reminder',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchant_id': merchantId,
      'store_name': storeName,
      'balance': balance,
      'message': message,
      'reminder_date': reminderDate.toIso8601String(),
      'status': status,
      'created_at': createdAt?.toIso8601String(),
      'type': type,
    };
  }
}
