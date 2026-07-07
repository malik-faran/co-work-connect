import 'package:cwc/utils/helpers/model_helpers.dart';

class RefundRequestModel {
  final String id;
  final String userId;
  final String bookingId;
  final String? paymentId;
  final double amount;
  final String? reason;
  final String status;
  final DateTime createdAt;

  const RefundRequestModel({
    required this.id,
    required this.userId,
    required this.bookingId,
    this.paymentId,
    required this.amount,
    this.reason,
    required this.status,
    required this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory RefundRequestModel.fromMap(Map<String, dynamic> map) {
    return RefundRequestModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      bookingId: map['booking_id'] as String,
      paymentId: map['payment_id'] as String?,
      amount: convertToDouble(map['amount'], 0),
      reason: map['reason'] as String?,
      status: map['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }
}
