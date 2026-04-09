import 'package:flutter/foundation.dart';
import 'package:cwc/models/notification_model.dart';
import 'package:cwc/services/supabase_service.dart';
import 'package:uuid/uuid.dart';

/// Notification Service
/// Handles all notification-related operations
class NotificationService {
  final _supabase = SupabaseService.client;
  final _uuid = const Uuid();

  /// Create a new notification
  Future<String> createNotification(NotificationModel notification) async {
    try {
      final notificationData = notification.toNotificationMap();
      notificationData.removeWhere((key, value) => value == null);

      await _supabase
          .from('notifications')
          .insert(notificationData);

      return notification.id;
    } catch (e) {
      debugPrint('Failed to create notification: $e');
      throw Exception('Failed to create notification: ${e.toString()}');
    }
  }

  /// Get all notifications for a user
  Future<List<NotificationModel>> getUserNotifications(String userId) async {
    try {
      final rows = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return rows
          .map((n) => NotificationModel.fromNotificationMap(n))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch notifications: ${e.toString()}');
    }
  }

  /// Get unread notifications count
  Future<int> getUnreadCount(String userId) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .eq('is_read', false);

      return response.length;
    } catch (e) {
      return 0;
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificationId);
    } catch (e) {
      throw Exception('Failed to mark notification as read: ${e.toString()}');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      await _supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      throw Exception('Failed to mark all notifications as read: ${e.toString()}');
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId);
    } catch (e) {
      throw Exception('Failed to delete notification: ${e.toString()}');
    }
  }

  /// Get stream of notifications for real-time updates
  Stream<List<NotificationModel>> getNotificationsStream(String userId) {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .timeout(
          const Duration(seconds: 30),
          onTimeout: (sink) {
            sink.add([]); // Return empty list on timeout
          },
        )
        .map((data) => data
            .map((n) => NotificationModel.fromNotificationMap(n))
            .toList());
  }

  /// Send registration approval notification
  Future<void> sendRegistrationApprovalNotification({
    required String userId,
    required bool approved,
    String? reason,
  }) async {
    final notification = NotificationModel(
      id: _uuid.v4(),
      userId: userId,
      title: approved ? 'Registration Approved' : 'Registration Rejected',
      message: approved
          ? 'Your registration has been approved. You can now login to your account.'
          : reason ?? 'Your registration has been rejected. Please contact support for more information.',
      type: approved ? 'registration_approved' : 'registration_rejected',
      createdAt: DateTime.now(),
      metadata: reason != null ? {'reason': reason} : null,
    );

    await createNotification(notification);
  }

  /// Send chat message notification to the receiver
  Future<void> sendChatMessageNotification({
    required String receiverUserId,
    required String senderName,
    required String message,
    required String chatRoomId,
  }) async {
    try {
      final truncatedMessage = message.length > 100
          ? '${message.substring(0, 100)}...'
          : message;

      final notification = NotificationModel(
        id: _uuid.v4(),
        userId: receiverUserId,
        title: 'New message from $senderName',
        message: truncatedMessage,
        type: 'chat_message',
        createdAt: DateTime.now(),
        metadata: {'chat_room_id': chatRoomId, 'sender_name': senderName},
      );

      await createNotification(notification);
    } catch (e) {
      debugPrint('Chat notification error: $e');
    }
  }

  /// Send collaboration response notification to the collaboration owner
  Future<void> sendCollaborationResponseNotification({
    required String ownerUserId,
    required String responderName,
    required String collaborationTitle,
    required String collaborationId,
  }) async {
    try {
      final notification = NotificationModel(
        id: _uuid.v4(),
        userId: ownerUserId,
        title: 'New response on your collaboration',
        message: '$responderName responded to "$collaborationTitle"',
        type: 'collaboration_response',
        createdAt: DateTime.now(),
        metadata: {
          'collaboration_id': collaborationId,
          'responder_name': responderName,
        },
      );

      await createNotification(notification);
    } catch (e) {
      debugPrint('Collaboration response notification error: $e');
    }
  }

  /// Send collaboration accepted notification
  Future<void> sendCollaborationAcceptedNotification({
    required String userId,
    required String collaborationTitle,
    required String collaborationId,
  }) async {
    try {
      final notification = NotificationModel(
        id: _uuid.v4(),
        userId: userId,
        title: 'Collaboration Response Accepted',
        message: 'Your response to "$collaborationTitle" has been accepted!',
        type: 'collaboration_response',
        createdAt: DateTime.now(),
        metadata: {'collaboration_id': collaborationId},
      );

      await createNotification(notification);
    } catch (e) {
      debugPrint('Collaboration accepted notification error: $e');
    }
  }

  /// Send booking notification to workspace owner
  Future<void> sendBookingCreatedNotification({
    required String ownerUserId,
    required String userName,
    required String workspaceName,
    required String bookingId,
  }) async {
    try {
      final notification = NotificationModel(
        id: _uuid.v4(),
        userId: ownerUserId,
        title: 'New Booking',
        message: '$userName booked "$workspaceName"',
        type: 'booking_confirmed',
        createdAt: DateTime.now(),
        metadata: {
          'booking_id': bookingId,
          'workspace_name': workspaceName,
        },
      );

      await createNotification(notification);
    } catch (e) {
      // Don't throw
    }
  }

  /// Send booking confirmation notification to user
  Future<void> sendBookingConfirmedNotification({
    required String userId,
    required String workspaceName,
    required String bookingId,
  }) async {
    try {
      final notification = NotificationModel(
        id: _uuid.v4(),
        userId: userId,
        title: 'Booking Confirmed',
        message: 'Your booking for "$workspaceName" has been confirmed!',
        type: 'booking_confirmed',
        createdAt: DateTime.now(),
        metadata: {'booking_id': bookingId, 'workspace_name': workspaceName},
      );

      await createNotification(notification);
    } catch (e) {
      // Don't throw
    }
  }

  /// Send seat reserved notification to user (when owner manually reserves)
  Future<void> sendSeatReservedNotification({
    required String userId,
    required String workspaceName,
    required String bookingId,
    required String timeSlotLabel,
    required int seatCount,
  }) async {
    try {
      final notification = NotificationModel(
        id: _uuid.v4(),
        userId: userId,
        title: 'Seat Reserved',
        message: 'A seat has been reserved for you at "$workspaceName" ($timeSlotLabel, $seatCount seat${seatCount > 1 ? 's' : ''})',
        type: 'booking_confirmed',
        createdAt: DateTime.now(),
        metadata: {
          'booking_id': bookingId,
          'workspace_name': workspaceName,
          'time_slot': timeSlotLabel,
        },
      );

      await createNotification(notification);
    } catch (e) {
      // Don't throw
    }
  }

  /// Send booking cancelled notification to user
  Future<void> sendBookingCancelledNotification({
    required String userId,
    required String workspaceName,
    required String bookingId,
    String? reason,
  }) async {
    try {
      final notification = NotificationModel(
        id: _uuid.v4(),
        userId: userId,
        title: 'Booking Cancelled',
        message: reason ?? 'Your booking for "$workspaceName" has been cancelled.',
        type: 'booking_cancelled',
        createdAt: DateTime.now(),
        metadata: {'booking_id': bookingId, 'workspace_name': workspaceName},
      );

      await createNotification(notification);
    } catch (e) {
      // Don't throw
    }
  }
}
