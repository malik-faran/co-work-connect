import 'package:flutter/foundation.dart';
import 'package:cwc/models/booking_model.dart';
import 'package:cwc/services/notification_service.dart';
import 'package:cwc/services/supabase_service.dart';

class BookingService {
  final _supabase = SupabaseService.client;
  final _notificationService = NotificationService();

  Future<String> createBooking(BookingModel booking) async {
    try {
      final bookingData = booking.toBookingMap();
      bookingData.removeWhere((key, value) => value == null);
      
      await _supabase
          .from('bookings')
          .insert(bookingData);

      try {
        final workspace = await _supabase
            .from('workspaces')
            .select('owner_id, name')
            .eq('id', booking.workspaceId)
            .maybeSingle();

        final user = await _supabase
            .from('users')
            .select('name')
            .eq('id', booking.userId)
            .maybeSingle();

        if (workspace != null) {
          await _notificationService.sendBookingCreatedNotification(
            ownerUserId: workspace['owner_id'],
            userName: user?['name'] ?? 'A user',
            workspaceName: workspace['name'] ?? booking.workspaceName,
            bookingId: booking.id,
          );
        }
      } catch (e) {
        debugPrint('Booking notification failed: $e');
      }

      return booking.id;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<BookingModel>> getUserBookings(String userId) async {
    final rows = await _supabase
        .from('bookings')
        .select('*, workspaces(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return rows.map((b) => BookingModel.fromBookingMap(b)).toList();
  }

  Stream<List<BookingModel>> getUserBookingsStream(String userId) {
    return _supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((data) => data.map((b) => BookingModel.fromBookingMap(b)).toList());
  }

  Future<List<BookingModel>> getOwnerBookings(String ownerId) async {
    try {
      final workspaceRows = await _supabase
          .from('workspaces')
          .select('id')
          .eq('owner_id', ownerId);
      
      final workspaceIds = workspaceRows.map((w) => w['id'] as String).toList();
      
      if (workspaceIds.isEmpty) {
        return [];
      }
      
      if (workspaceIds.length == 1) {
        final bookingRows = await _supabase
            .from('bookings')
            .select('*')
            .eq('workspace_id', workspaceIds[0])
            .order('created_at', ascending: false);
        
        return bookingRows.map((b) => BookingModel.fromBookingMap(b)).toList();
      } else {
        final orCondition = workspaceIds
            .map((id) => 'workspace_id.eq.$id')
            .join(',');
        
        final bookingRows = await _supabase
            .from('bookings')
            .select('*')
            .or(orCondition)
            .order('created_at', ascending: false);
        
        return bookingRows.map((b) => BookingModel.fromBookingMap(b)).toList();
      }
    } catch (e) {
      try {
        final rows = await _supabase
            .from('bookings')
            .select('*, workspaces!inner(owner_id)')
            .eq('workspaces.owner_id', ownerId)
            .order('created_at', ascending: false);
        
        return rows.map((b) => BookingModel.fromBookingMap(b)).toList();
      } catch (e2) {
        rethrow;
      }
    }
  }

  Stream<List<BookingModel>> getOwnerBookingsStream(String ownerId) {
    // Use a controlled stream that doesn't cause infinite loops
    return Stream.periodic(const Duration(seconds: 10), (_) async {
      return await getOwnerBookings(ownerId);
    }).asyncMap((future) => future).timeout(
      const Duration(seconds: 30),
      onTimeout: (sink) {
        sink.add([]); // Return empty list on timeout
      },
    );
  }

  Future<BookingModel?> updateBookingStatus(String id, String status) async {
    final result = await _supabase
        .from('bookings')
        .update({'status': status})
        .eq('id', id)
        .select()
        .single();

    final booking = BookingModel.fromBookingMap(result);

    // Send notification to the user about status change
    try {
      if (status == 'confirmed') {
        await _notificationService.sendBookingConfirmedNotification(
          userId: booking.userId,
          workspaceName: booking.workspaceName,
          bookingId: booking.id,
        );
      } else if (status == 'cancelled') {
        await _notificationService.sendBookingCancelledNotification(
          userId: booking.userId,
          workspaceName: booking.workspaceName,
          bookingId: booking.id,
        );
      }
    } catch (_) {}

    return booking;
  }
  
  Future<BookingModel?> getBookingById(String id) async {
    final result = await _supabase
        .from('bookings')
        .select()
        .eq('id', id)
        .maybeSingle();
    
    if (result == null) return null;
    return BookingModel.fromBookingMap(result);
  }

  Future<List<BookingModel>> getBookingsByWorkspaceAndDate(
    String workspaceId,
    String dateKey,
  ) async {
    final rows = await _supabase
        .from('bookings')
        .select()
        .eq('workspace_id', workspaceId)
        .eq('booking_date', dateKey)
        .or('status.eq.pending,status.eq.confirmed');

    return rows.map((b) => BookingModel.fromBookingMap(b)).toList();
  }

  Future<List<BookingModel>> getBookingsByWorkspaceId(String workspaceId) async {
    final rows = await _supabase
        .from('bookings')
        .select()
        .eq('workspace_id', workspaceId)
        .order('created_at', ascending: false);

    return rows.map((b) => BookingModel.fromBookingMap(b)).toList();
  }
}
