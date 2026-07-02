import 'package:cwc/utils/helpers/model_helpers.dart';

/// Payment Model
/// Represents a payment transaction for a booking
class PaymentModel {
  final String id;
  final String bookingId;
  final String userId;
  final double amount;
  final String currency; // e.g., 'USD', 'PKR'
  final String status; // pending, processing, completed, failed, cancelled, expired
  final String paymentMethod; // stripe, cash, etc.
  final String? stripePaymentIntentId; // Stripe payment intent ID
  final String? stripeClientSecret; // Stripe client secret for payment
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? expiresAt; // Payment expiry time (30 minutes from creation)
  final String? failureReason;
  final Map<String, dynamic>? metadata;
  final String? receiptUrl;
  final String? receiptStatus;
  final String? ownerAccountId;
  final String? platformAccountId;
  final String? transferReference;
  final DateTime? ownerVerifiedAt;
  final String? payeeType;
  final String? verifiedBy;
  final double walletAmount;
  final double? externalAmount;

  PaymentModel({
    required this.id,
    required this.bookingId,
    required this.userId,
    required this.amount,
    this.currency = 'PKR',
    this.status = 'pending',
    this.paymentMethod = 'stripe',
    this.stripePaymentIntentId,
    this.stripeClientSecret,
    required this.createdAt,
    this.updatedAt,
    this.expiresAt,
    this.failureReason,
    this.metadata,
    this.receiptUrl,
    this.receiptStatus,
    this.ownerAccountId,
    this.platformAccountId,
    this.transferReference,
    this.ownerVerifiedAt,
    this.payeeType,
    this.verifiedBy,
    this.walletAmount = 0,
    this.externalAmount,
  });

  bool get isManual => paymentMethod == 'manual' || paymentMethod == 'split';

  bool get isSplit => paymentMethod == 'split';

  double get amountDueExternally =>
      externalAmount ?? (amount - walletAmount).clamp(0, amount);

  bool get isPlatformPayment =>
      payeeType == 'platform' || (payeeType == null && ownerAccountId == null);

  bool get isAwaitingReceiptReview =>
      receiptStatus == 'awaiting_verification' && status == 'pending';

  bool get isReceiptRejected => receiptStatus == 'rejected';

  /// Check if payment has expired (30 minutes passed)
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Get remaining time in minutes
  int? get remainingMinutes {
    if (expiresAt == null) return null;
    if (isExpired) return 0;
    final remaining = expiresAt!.difference(DateTime.now());
    return remaining.inMinutes;
  }

  /// Convert to map for database
  Map<String, dynamic> toPaymentMap() {
    final map = <String, dynamic>{
      'id': id,
      'booking_id': bookingId,
      'user_id': userId,
      'amount': amount,
      'currency': currency,
      'status': status,
      'payment_method': paymentMethod,
      'created_at': createdAt.toIso8601String(),
    };

    if (stripePaymentIntentId != null) {
      map['stripe_payment_intent_id'] = stripePaymentIntentId;
    }
    if (stripeClientSecret != null) {
      map['stripe_client_secret'] = stripeClientSecret;
    }
    if (updatedAt != null) {
      map['updated_at'] = updatedAt!.toIso8601String();
    }
    if (expiresAt != null) {
      map['expires_at'] = expiresAt!.toIso8601String();
    }
    if (failureReason != null) {
      map['failure_reason'] = failureReason;
    }
    if (metadata != null) {
      map['metadata'] = metadata;
    }
    if (receiptUrl != null) map['receipt_url'] = receiptUrl;
    if (receiptStatus != null) map['receipt_status'] = receiptStatus;
    if (ownerAccountId != null) map['owner_account_id'] = ownerAccountId;
    if (platformAccountId != null) map['platform_account_id'] = platformAccountId;
    if (transferReference != null) map['transfer_reference'] = transferReference;
    if (payeeType != null) map['payee_type'] = payeeType;
    if (verifiedBy != null) map['verified_by'] = verifiedBy;
    if (ownerVerifiedAt != null) {
      map['owner_verified_at'] = ownerVerifiedAt!.toIso8601String();
    }
    if (walletAmount > 0) map['wallet_amount'] = walletAmount;
    if (externalAmount != null) map['external_amount'] = externalAmount;

    return map;
  }

  /// Create from database map
  factory PaymentModel.fromPaymentMap(Map<String, dynamic> map) {
    return PaymentModel(
      id: map['id'] ?? '',
      bookingId: getStringFromMap(map, 'booking_id', 'bookingId') ?? '',
      userId: getStringFromMap(map, 'user_id', 'userId') ?? '',
      amount: convertToDouble(map['amount'], 0.0),
      currency: getStringFromMap(map, 'currency', 'currency') ?? 'PKR',
      status: getStringFromMap(map, 'status', 'status') ?? 'pending',
      paymentMethod: getStringFromMap(map, 'payment_method', 'paymentMethod') ?? 'stripe',
      stripePaymentIntentId: getStringFromMap(map, 'stripe_payment_intent_id', 'stripePaymentIntentId'),
      stripeClientSecret: getStringFromMap(map, 'stripe_client_secret', 'stripeClientSecret'),
      createdAt: getStringFromMap(map, 'created_at', 'createdAt') != null
          ? DateTime.parse(getStringFromMap(map, 'created_at', 'createdAt')!)
          : DateTime.now(),
      updatedAt: getStringFromMap(map, 'updated_at', 'updatedAt') != null
          ? DateTime.parse(getStringFromMap(map, 'updated_at', 'updatedAt')!)
          : null,
      expiresAt: getStringFromMap(map, 'expires_at', 'expiresAt') != null
          ? DateTime.parse(getStringFromMap(map, 'expires_at', 'expiresAt')!)
          : null,
      failureReason: getStringFromMap(map, 'failure_reason', 'failureReason'),
      metadata: map['metadata'] != null
          ? Map<String, dynamic>.from(map['metadata'])
          : null,
      receiptUrl: getStringFromMap(map, 'receipt_url', 'receiptUrl'),
      receiptStatus: getStringFromMap(map, 'receipt_status', 'receiptStatus'),
      ownerAccountId: getStringFromMap(map, 'owner_account_id', 'ownerAccountId'),
      platformAccountId: getStringFromMap(map, 'platform_account_id', 'platformAccountId'),
      transferReference: getStringFromMap(map, 'transfer_reference', 'transferReference'),
      payeeType: getStringFromMap(map, 'payee_type', 'payeeType'),
      verifiedBy: getStringFromMap(map, 'verified_by', 'verifiedBy'),
      ownerVerifiedAt: getStringFromMap(map, 'owner_verified_at', 'ownerVerifiedAt') != null
          ? DateTime.parse(getStringFromMap(map, 'owner_verified_at', 'ownerVerifiedAt')!)
          : null,
      walletAmount: convertToDouble(map['wallet_amount'] ?? map['walletAmount'], 0.0),
      externalAmount: convertToDoubleNullable(map['external_amount'] ?? map['externalAmount']),
    );
  }

  PaymentModel copyPayment({
    String? id,
    String? bookingId,
    String? userId,
    double? amount,
    String? currency,
    String? status,
    String? paymentMethod,
    String? stripePaymentIntentId,
    String? stripeClientSecret,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? expiresAt,
    String? failureReason,
    Map<String, dynamic>? metadata,
    String? receiptUrl,
    String? receiptStatus,
    String? ownerAccountId,
    String? platformAccountId,
    String? transferReference,
    DateTime? ownerVerifiedAt,
    String? payeeType,
    String? verifiedBy,
    double? walletAmount,
    double? externalAmount,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      stripePaymentIntentId: stripePaymentIntentId ?? this.stripePaymentIntentId,
      stripeClientSecret: stripeClientSecret ?? this.stripeClientSecret,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      failureReason: failureReason ?? this.failureReason,
      metadata: metadata ?? this.metadata,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      receiptStatus: receiptStatus ?? this.receiptStatus,
      ownerAccountId: ownerAccountId ?? this.ownerAccountId,
      platformAccountId: platformAccountId ?? this.platformAccountId,
      transferReference: transferReference ?? this.transferReference,
      ownerVerifiedAt: ownerVerifiedAt ?? this.ownerVerifiedAt,
      payeeType: payeeType ?? this.payeeType,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      walletAmount: walletAmount ?? this.walletAmount,
      externalAmount: externalAmount ?? this.externalAmount,
    );
  }
}
