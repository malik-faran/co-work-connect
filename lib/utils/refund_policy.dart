/// Dynamic refund/cancellation window based on time until booking starts.
///
/// Examples from product spec:
/// - Booking ~2 hours away → cancel at least 20 minutes before start
/// - Next-day booking → cancel at least 1 hour before start
/// - Further out → longer lead times
class RefundPolicy {
  RefundPolicy._();

  /// Required lead time (minutes before start) for a refund-eligible cancellation.
  static int leadMinutesFor(Duration untilStart) {
    if (untilStart.inMinutes <= 0) return 0;
    if (untilStart.inHours <= 2) return 20;
    if (untilStart.inHours <= 24) return 60;
    if (untilStart.inHours <= 72) return 180;
    return 24 * 60;
  }

  /// Last moment the user can request a refund.
  static DateTime cancellationDeadline(DateTime startDate, [DateTime? now]) {
    final n = now ?? DateTime.now();
    final untilStart = startDate.difference(n);
    if (untilStart.isNegative) return n;
    final lead = Duration(minutes: leadMinutesFor(untilStart));
    return startDate.subtract(lead);
  }

  static bool canCancelWithRefund(DateTime startDate, [DateTime? now]) {
    final n = now ?? DateTime.now();
    return n.isBefore(cancellationDeadline(startDate, n));
  }

  static Duration timeRemaining(DateTime startDate, [DateTime? now]) {
    final deadline = cancellationDeadline(startDate, now);
    final n = now ?? DateTime.now();
    final remaining = deadline.difference(n);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  static String formatDuration(Duration d) {
    if (d <= Duration.zero) return '0:00';
    final totalSec = d.inSeconds;
    if (totalSec >= 3600) {
      final h = totalSec ~/ 3600;
      final m = (totalSec % 3600) ~/ 60;
      final s = totalSec % 60;
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static String leadTimeLabel(DateTime startDate, [DateTime? now]) {
    final mins = leadMinutesFor(startDate.difference(now ?? DateTime.now()));
    if (mins < 60) return '$mins minutes';
    final hours = mins ~/ 60;
    return hours == 1 ? '1 hour' : '$hours hours';
  }
}
