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
  });

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
    );
  }
}
