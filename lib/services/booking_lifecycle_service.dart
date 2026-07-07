import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cwc/services/supabase_service.dart';

/// Checks confirmed bookings: 10-min ending reminders + auto-complete.
class BookingLifecycleService {
  BookingLifecycleService._();
  static final BookingLifecycleService instance = BookingLifecycleService._();

  Timer? _timer;
  bool _running = false;

  void startPolling() {
    _timer?.cancel();
    processDueBookings();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => processDueBookings());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> processDueBookings() async {
    if (_running) return;
    if (SupabaseService.client.auth.currentUser == null) return;

    _running = true;
    try {
      await SupabaseService.client.rpc('process_booking_lifecycle');
    } catch (e) {
      debugPrint('Booking lifecycle check failed: $e');
    } finally {
      _running = false;
    }
  }
}
