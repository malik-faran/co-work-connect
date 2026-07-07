/// Refund/cancellation — 70% rule: cancel while at least 70% of the booking
/// window (from booking time to slot start) still remains. Minimum 10 min notice.
class RefundPolicy {
  RefundPolicy._();

  /// Cancel allowed while this fraction of (start − bookedAt) still remains.
  static const double remainFraction = 0.70;

  static const Duration minNoticeBeforeStart = Duration(minutes: 10);

  static const String userSummary =
      'Cancellation & Refund Policy\n'
      '• You can cancel for a refund only while at least 70% of the time between '
      'booking and slot start still remains.\n'
      '• Once less than 70% of that time is left, cancellation and refund are not available.\n'
      '• Minimum 10 minutes notice before slot start.\n'
      '• Example: book 1 hour ahead → cancel within the first 42 minutes after booking.\n'
      '• Approved refunds are credited to your CWC wallet.';

  static const String compactSummary =
      'Refund only while ≥70% of booking window remains (min. 10 min before start).';

  /// Notice required before slot start = max(10 min, 30% of booking window).
  static Duration requiredNotice({
    required DateTime startDate,
    required DateTime bookedAt,
  }) {
    final start = _toLocal(startDate);
    final booked = _toLocal(bookedAt);
    final total = start.difference(booked);
    if (total.inMinutes <= 0) {
      // Fallback when created_at is after start (bad data): use time from now.
      final fromNow = start.difference(_toLocal(DateTime.now()));
      if (fromNow.inMinutes > 0) {
        final fromPercent = Duration(
          milliseconds: (fromNow.inMilliseconds * (1 - remainFraction)).round(),
        );
        return fromPercent > minNoticeBeforeStart ? fromPercent : minNoticeBeforeStart;
      }
      return minNoticeBeforeStart;
    }
    final fromPercent = Duration(
      milliseconds: (total.inMilliseconds * (1 - remainFraction)).round(),
    );
    return fromPercent > minNoticeBeforeStart ? fromPercent : minNoticeBeforeStart;
  }

  static DateTime cancellationDeadline({
    required DateTime startDate,
    required DateTime bookedAt,
  }) {
    final start = _toLocal(startDate);
    return start.subtract(requiredNotice(startDate: start, bookedAt: bookedAt));
  }

  static bool canCancelWithRefund({
    required DateTime startDate,
    required DateTime bookedAt,
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    return n.isBefore(cancellationDeadline(startDate: startDate, bookedAt: bookedAt));
  }

  static Duration timeUntilStart(DateTime startDate, [DateTime? now]) {
    final n = now ?? DateTime.now();
    final remaining = _toLocal(startDate).difference(n);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  static Duration timeRemaining({
    required DateTime startDate,
    required DateTime bookedAt,
    DateTime? now,
  }) {
    final deadline = cancellationDeadline(startDate: startDate, bookedAt: bookedAt);
    final n = now ?? DateTime.now();
    final remaining = deadline.difference(n);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  static RefundEligibility eligibility({
    required DateTime startDate,
    required DateTime bookedAt,
    DateTime? now,
  }) {
    if (canCancelWithRefund(startDate: startDate, bookedAt: bookedAt, now: now)) {
      return RefundEligibility.eligible;
    }
    final until = timeUntilStart(startDate, now);
    if (until > Duration.zero) {
      return RefundEligibility.tooLate;
    }
    return RefundEligibility.started;
  }

  static String noticeLabel({
    required DateTime startDate,
    required DateTime bookedAt,
  }) =>
      formatHumanDuration(requiredNotice(startDate: startDate, bookedAt: bookedAt));

  static String ineligibleMessage({
    required DateTime startDate,
    required DateTime bookedAt,
    DateTime? now,
  }) {
    switch (eligibility(startDate: startDate, bookedAt: bookedAt, now: now)) {
      case RefundEligibility.eligible:
        return '';
      case RefundEligibility.tooLate:
        final until = timeUntilStart(startDate, now);
        final notice = noticeLabel(startDate: startDate, bookedAt: bookedAt);
        return 'Too late to cancel — booking starts in ${formatHumanDuration(until)}. '
            'You needed at least $notice notice (70% window rule).';
      case RefundEligibility.started:
        return 'Booking has already started — refund not available.';
    }
  }

  static String messageForBooking({
    required DateTime startDate,
    required DateTime bookedAt,
    DateTime? now,
  }) {
    if (canCancelWithRefund(startDate: startDate, bookedAt: bookedAt, now: now)) {
      final left = formatHumanDuration(
        timeRemaining(startDate: startDate, bookedAt: bookedAt, now: now),
      );
      final notice = noticeLabel(startDate: startDate, bookedAt: bookedAt);
      return 'Refund available — cancel until $notice before start ($left left).';
    }
    return ineligibleMessage(startDate: startDate, bookedAt: bookedAt, now: now);
  }

  static String formatHumanDuration(Duration d) {
    if (d <= Duration.zero) return '0 min';
    if (d.inDays >= 1) {
      final hours = d.inHours % 24;
      if (hours == 0) return '${d.inDays} day${d.inDays == 1 ? '' : 's'}';
      return '${d.inDays}d ${hours}h';
    }
    if (d.inHours >= 1) {
      final mins = d.inMinutes % 60;
      if (mins == 0) return '${d.inHours} hr${d.inHours == 1 ? '' : 's'}';
      return '${d.inHours}h ${mins}m';
    }
    return '${d.inMinutes} min';
  }

  static String formatDuration(Duration d) => formatHumanDuration(d);

  /// Daily/monthly bookings store midnight — treat day bookings as 9 AM start.
  static DateTime effectiveStart({
    required DateTime startDate,
    required bool isHourlyBooking,
    int dayStartHour = 9,
  }) {
    final start = _toLocal(startDate);
    if (isHourlyBooking) return start;
    if (start.hour == 0 && start.minute == 0) {
      return DateTime(start.year, start.month, start.day, dayStartHour);
    }
    return start;
  }

  static DateTime _toLocal(DateTime dt) => dt.isUtc ? dt.toLocal() : dt;
}

enum RefundEligibility { eligible, tooLate, started }
