import 'dart:async';
import 'package:cwc/models/notification_model.dart';
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
  bool _seeded = false;
  String? _activeUserId;

  void start(String userId) {
    if (_activeUserId == userId && _subscription != null) return;

    stop();
    _activeUserId = userId;
    _knownIds.clear();
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
    _seeded = false;
  }

  Future<void> _onNotifications(List<NotificationModel> notifications) async {
    if (!_seeded) {
      _knownIds.addAll(notifications.map((n) => n.id));
      _seeded = true;
      return;
    }

    for (final notification in notifications) {
      if (_knownIds.contains(notification.id)) continue;
      _knownIds.add(notification.id);

      if (notification.isRead) continue;

      await LocalNotificationService.instance.show(
        id: notification.id,
        title: notification.title,
        body: notification.message,
        payload: notification.id,
      );
    }
  }
}
