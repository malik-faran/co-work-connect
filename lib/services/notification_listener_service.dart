import 'dart:async';
import 'dart:convert';
import 'package:cwc/models/notification_model.dart';
import 'package:cwc/services/active_chat_tracker.dart';
import 'package:cwc/services/local_notification_service.dart';
import 'package:cwc/services/notification_service.dart';

/// Listens to Supabase realtime notifications and shows system alerts.
class NotificationListenerService {
  NotificationListenerService._();
  static final NotificationListenerService instance =
      NotificationListenerService._();

  final NotificationService _notificationService = NotificationService();
  StreamSubscription<List<NotificationModel>>? _subscription;
  final Set<String> _knownIds = {};
  final Map<String, String> _lastShownChatMessage = {};
  bool _seeded = false;
  String? _activeUserId;

  void start(String userId) {
    if (_activeUserId == userId && _subscription != null) return;

    stop();
    _activeUserId = userId;
    _knownIds.clear();
    _lastShownChatMessage.clear();
    _seeded = false;

    _subscription = _notificationService
        .getNotificationsStream(userId)
        .listen(_onNotifications, onError: (_) {});
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _activeUserId = null;
    _knownIds.clear();
    _lastShownChatMessage.clear();
    _seeded = false;
  }

  Future<void> _onNotifications(List<NotificationModel> notifications) async {
    if (!_seeded) {
      for (final n in notifications) {
        _knownIds.add(n.id);
        if (n.type == 'chat_message') {
          final roomId = n.metadata?['chat_room_id'] as String?;
          if (roomId != null) {
            _lastShownChatMessage[roomId] = n.message;
          }
        }
      }
      _seeded = true;
      return;
    }

    for (final notification in notifications) {
      if (notification.isRead) continue;

      if (notification.type == 'chat_message') {
        final chatRoomId =
            notification.metadata?['chat_room_id'] as String?;
        if (chatRoomId == null) continue;
        if (ActiveChatTracker.isActive(chatRoomId)) continue;

        final lastShown = _lastShownChatMessage[chatRoomId];
        if (lastShown == notification.message) continue;

        _lastShownChatMessage[chatRoomId] = notification.message;
        _knownIds.add(notification.id);

        await LocalNotificationService.instance.showChatMessage(
          id: notification.id,
          title: notification.title,
          body: notification.message,
          chatRoomId: chatRoomId,
        );
        continue;
      }

      if (_knownIds.contains(notification.id)) continue;
      _knownIds.add(notification.id);

      final bookingId = notification.metadata?['booking_id'] as String?;
      final payload = bookingId != null
          ? jsonEncode({
              'type': notification.type,
              'booking_id': bookingId,
            })
          : notification.id;

      await LocalNotificationService.instance.show(
        id: notification.id,
        title: notification.title,
        body: notification.message,
        payload: payload,
      );
    }
  }
}
