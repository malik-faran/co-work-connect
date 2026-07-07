import 'package:cwc/utils/constants/app_constants.dart';
import 'package:cwc/utils/refund_policy.dart';
import 'package:cwc/utils/helpers/model_helpers.dart';

class BookingModel {
  final String id;
  final String userId;
  final String workspaceId;
  final String workspaceName;
  final DateTime startDate;
  final DateTime endDate;
  final int numberOfDays;
  final double totalPrice;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? notes;
  final bool isHourlyBooking;
  final String? bookingDateKey;
  final String? timeSlotId;
  final String? timeSlotLabel;
  final String? categoryType;
  final int seatCount;
  final double? pricePerHour;
  final double? pricePerDay;
  final int? durationHours;

  BookingModel({
    required this.id,
    required this.userId,
    required this.workspaceId,
    required this.workspaceName,
    required this.startDate,
    required this.endDate,
    required this.numberOfDays,
    required this.totalPrice,
    this.status = 'pending',
    required this.createdAt,
    this.updatedAt,
    this.notes,
    this.isHourlyBooking = false,
    this.bookingDateKey,
    this.timeSlotId,
    this.timeSlotLabel,
    this.categoryType,
    this.seatCount = 1,
    this.pricePerHour,
    this.pricePerDay,
    this.durationHours,
  });

  Map<String, dynamic> toBookingMap() {
    final map = <String, dynamic>{
      'id': id,
      'user_id': userId,
      'workspace_id': workspaceId,
      'workspace_name': workspaceName,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'number_of_days': numberOfDays,
      'total_price': totalPrice,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'is_hourly_booking': isHourlyBooking,
      'seat_count': seatCount,
    };

    if (bookingDateKey != null && bookingDateKey!.isNotEmpty) {
      map['booking_date'] = bookingDateKey;
    }
    if (timeSlotLabel != null && timeSlotLabel!.isNotEmpty) map['time_slot_label'] = timeSlotLabel;
    if (timeSlotId != null && _isValidUUID(timeSlotId)) {
      map['time_slot_id'] = timeSlotId;
    }
    if (categoryType != null && categoryType!.isNotEmpty) {
      map['category_type'] = categoryType;
    }
    if (durationHours != null) map['duration_hours'] = durationHours;
    if (updatedAt != null) map['updated_at'] = updatedAt!.toIso8601String();
    if (notes != null && notes!.isNotEmpty) map['notes'] = notes;
    if (pricePerHour != null) map['price_per_hour'] = pricePerHour;
    if (pricePerDay != null) map['price_per_day'] = pricePerDay;

    return map;
  }

  static bool _isValidUUID(String? value) {
    if (value == null || value.isEmpty) return false;
    return RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false).hasMatch(value);
  }

  factory BookingModel.fromBookingMap(Map<String, dynamic> map) {
    return BookingModel(
      id: map['id'] ?? '',
      userId: getStringFromMap(map, 'user_id', 'userId') ?? '',
      workspaceId: getStringFromMap(map, 'workspace_id', 'workspaceId') ?? '',
      workspaceName: getStringFromMap(map, 'workspace_name', 'workspaceName') ?? '',
      startDate: getStringFromMap(map, 'start_date', 'startDate') != null
          ? DateTime.parse(getStringFromMap(map, 'start_date', 'startDate')!).toLocal()
          : DateTime.now(),
      endDate: getStringFromMap(map, 'end_date', 'endDate') != null
          ? DateTime.parse(getStringFromMap(map, 'end_date', 'endDate')!).toLocal()
          : DateTime.now(),
      numberOfDays: convertToInt(map['number_of_days'] ?? map['numberOfDays'], 0),
      totalPrice: convertToDouble(map['total_price'] ?? map['totalPrice'], 0.0),
      status: map['status'] ?? 'pending',
      createdAt: getStringFromMap(map, 'created_at', 'createdAt') != null
          ? DateTime.parse(getStringFromMap(map, 'created_at', 'createdAt')!).toLocal()
          : DateTime.now(),
      updatedAt: getStringFromMap(map, 'updated_at', 'updatedAt') != null
          ? DateTime.parse(getStringFromMap(map, 'updated_at', 'updatedAt')!).toLocal()
          : null,
      notes: getStringFromMap(map, 'notes', 'notes'),
      isHourlyBooking: getValueFromMap(map, 'is_hourly_booking', 'isHourlyBooking', false),
      bookingDateKey: getStringFromMap(map, 'booking_date', 'bookingDateKey'),
      timeSlotId: getStringFromMap(map, 'time_slot_id', 'timeSlotId'),
      timeSlotLabel: getStringFromMap(map, 'time_slot_label', 'timeSlotLabel'),
      categoryType: getStringFromMap(map, 'category_type', 'categoryType'),
      seatCount: convertToInt(map['seat_count'] ?? map['seatCount'], 1),
      pricePerHour: convertToDoubleNullable(map['price_per_hour'] ?? map['pricePerHour']),
      pricePerDay: convertToDoubleNullable(map['price_per_day'] ?? map['pricePerDay']),
      durationHours: convertToIntNullable(map['duration_hours'] ?? map['durationHours']),
    );
  }

  bool get _isSlotBooking =>
      isHourlyBooking ||
      (timeSlotLabel != null && timeSlotLabel!.isNotEmpty) ||
      (durationHours != null && durationHours! > 0 && durationHours! < 24);

  static int? _hourFromSlotLabel(String? label) {
    if (label == null || label.isEmpty) return null;
    final match = RegExp(r'(\d{1,2}):\d{2}').firstMatch(label);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  static int? _endHourFromSlotLabel(String? label) {
    if (label == null || label.isEmpty) return null;
    final match = RegExp(r'-\s*(\d{1,2}):\d{2}').firstMatch(label);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  static DateTime? _dateFromKey(String? key) {
    if (key == null || key.length < 10) return null;
    try {
      final p = key.split('-');
      return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    } catch (_) {
      return null;
    }
  }

  DateTime get _localStart => startDate.isUtc ? startDate.toLocal() : startDate;

  static int? _hourFromSlotId(String? id) {
    if (id == null || id.isEmpty) return null;
    final match = RegExp(r'slot_(\d+)_').firstMatch(id);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  /// Reliable slot start for refund checks (fixes midnight / timezone issues).
  DateTime get refundStartDate {
    final local = _localStart;

    if (_isSlotBooking) {
      final date = _dateFromKey(bookingDateKey) ??
          DateTime(local.year, local.month, local.day);
      final slotHour = _hourFromSlotLabel(timeSlotLabel) ??
          _hourFromSlotId(timeSlotId) ??
          (local.hour != 0 || local.minute != 0 ? local.hour : null);
      if (slotHour != null) {
        return DateTime(date.year, date.month, date.day, slotHour);
      }
    }

    final fromKey = _dateFromKey(bookingDateKey);
    if (fromKey != null && !_isSlotBooking) {
      return DateTime(fromKey.year, fromKey.month, fromKey.day, 9);
    }

    if (local.hour != 0 || local.minute != 0) return local;

    return RefundPolicy.effectiveStart(
      startDate: startDate,
      isHourlyBooking: _isSlotBooking,
    );
  }

  /// Reliable slot/booking end (for lifecycle + unpaid checks).
  DateTime get effectiveEndDate {
    final localEnd = endDate.isUtc ? endDate.toLocal() : endDate;

    if (_isSlotBooking) {
      final date = _dateFromKey(bookingDateKey) ??
          DateTime(localEnd.year, localEnd.month, localEnd.day);
      final endHour = _endHourFromSlotLabel(timeSlotLabel);
      if (endHour != null) {
        return DateTime(date.year, date.month, date.day, endHour);
      }
    }

    if (!_isSlotBooking &&
        localEnd.hour == 0 &&
        localEnd.minute == 0) {
      return DateTime(localEnd.year, localEnd.month, localEnd.day, 23, 59);
    }

    return localEnd;
  }

  bool get isSlotPast => DateTime.now().isAfter(effectiveEndDate);

  bool isUnpaidSlotMissed({required bool isPaid}) {
    if (isPaid || !isSlotPast) return false;
    return status == AppConstants.bookingStatusPending ||
        status == AppConstants.bookingStatusCancelled;
  }

  DateTime get refundBookedAt => createdAt.isUtc ? createdAt.toLocal() : createdAt;

  DateTime get cancellationDeadline => RefundPolicy.cancellationDeadline(
        startDate: refundStartDate,
        bookedAt: refundBookedAt,
      );

  bool get isWithinCancellationWindow => RefundPolicy.canCancelWithRefund(
        startDate: refundStartDate,
        bookedAt: refundBookedAt,
      );

  Duration get refundWindowRemaining => RefundPolicy.timeRemaining(
        startDate: refundStartDate,
        bookedAt: refundBookedAt,
      );

  String get refundIneligibleMessage => RefundPolicy.ineligibleMessage(
        startDate: refundStartDate,
        bookedAt: refundBookedAt,
      );

  String get refundNoticeLabel => RefundPolicy.noticeLabel(
        startDate: refundStartDate,
        bookedAt: refundBookedAt,
      );

  bool canCancelWithRefund({required bool isPaid}) =>
      status == AppConstants.bookingStatusConfirmed && isPaid && isWithinCancellationWindow;

  BookingModel copyBooking({
    String? id,
    String? userId,
    String? workspaceId,
    String? workspaceName,
    DateTime? startDate,
    DateTime? endDate,
    int? numberOfDays,
    double? totalPrice,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
    bool? isHourlyBooking,
    String? bookingDateKey,
    String? timeSlotId,
    String? timeSlotLabel,
    String? categoryType,
    int? seatCount,
    double? pricePerHour,
    double? pricePerDay,
    int? durationHours,
  }) {
    return BookingModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      workspaceId: workspaceId ?? this.workspaceId,
      workspaceName: workspaceName ?? this.workspaceName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      numberOfDays: numberOfDays ?? this.numberOfDays,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
      isHourlyBooking: isHourlyBooking ?? this.isHourlyBooking,
      bookingDateKey: bookingDateKey ?? this.bookingDateKey,
      timeSlotId: timeSlotId ?? this.timeSlotId,
      timeSlotLabel: timeSlotLabel ?? this.timeSlotLabel,
      categoryType: categoryType ?? this.categoryType,
      seatCount: seatCount ?? this.seatCount,
      pricePerHour: pricePerHour ?? this.pricePerHour,
      pricePerDay: pricePerDay ?? this.pricePerDay,
      durationHours: durationHours ?? this.durationHours,
    );
  }
}
