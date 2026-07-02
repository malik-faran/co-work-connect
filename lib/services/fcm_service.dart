import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:cwc/firebase_options.dart';
import 'package:cwc/services/active_chat_tracker.dart';
import 'package:cwc/services/auth_service.dart';
import 'package:cwc/services/fcm_background.dart';
import 'package:cwc/services/local_notification_service.dart';
import 'package:cwc/services/navigation_service.dart';
import 'package:cwc/utils/notification_scope.dart';

/// Firebase Cloud Messaging — push notifications when app is closed/background.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final AuthService _authService = AuthService();
  bool _ready = false;
  String? _cachedToken;

  bool get isReady => _ready;

  Future<void> initialize() async {
    if (kIsWeb) return;
    if (_ready) return;

    try {
      if (DefaultFirebaseOptions.android.apiKey == 'REPLACE_ME') {
        debugPrint(
          'FCM: Run "flutterfire configure" and add google-services.json — see supabase/FCM_SETUP.md',
        );
        return;
      }

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _openFromMessage(initialMessage);
      }

      _messaging.onTokenRefresh.listen((token) async {
        _cachedToken = token;
        final userId = _authService.currentAuthUser?.id;
        if (userId != null) {
          await _authService.saveFcmToken(userId, token);
        }
      });

      _ready = true;
      debugPrint('FCM initialized');
    } catch (e) {
      debugPrint('FCM init failed: $e');
    }
  }

  Future<void> syncTokenForUser(String userId) async {
    if (kIsWeb || !_ready) return;
    try {
      final token = _cachedToken ?? await _messaging.getToken();
      if (token == null || token.isEmpty) return;
      _cachedToken = token;
      await _authService.saveFcmToken(userId, token);
      debugPrint('FCM token saved for user');
    } catch (e) {
      debugPrint('FCM token sync failed: $e');
    }
  }

  Future<void> clearTokenForUser(String userId) async {
    if (kIsWeb || !_ready) return;
    try {
      await _authService.clearFcmToken(userId);
      await _messaging.deleteToken();
      _cachedToken = null;
    } catch (e) {
      debugPrint('FCM token clear failed: $e');
    }
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final data = message.data;
    final chatRoomId = data['chat_room_id']?.toString();
    final notification = message.notification;

    if (chatRoomId != null && chatRoomId.isNotEmpty) {
      if (ActiveChatTracker.isActive(chatRoomId)) return;
      await LocalNotificationService.instance.showChatMessage(
        id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: notification?.title ?? data['title']?.toString() ?? 'New message',
        body: notification?.body ?? data['body']?.toString() ?? '',
        chatRoomId: chatRoomId,
      );
      return;
    }

    if (notification == null) return;

    final type = data['type']?.toString();
    final bookingId = data['booking_id']?.toString();
    final reportId = data['report_id']?.toString();
    final collaborationId = data['collaboration_id']?.toString();
    String? payload;
    if (chatRoomId != null && chatRoomId.isNotEmpty) {
      payload = jsonEncode({'type': 'chat_message', 'chat_room_id': chatRoomId});
    } else if (bookingId != null &&
        type != null &&
        NotificationScopeHelper.isWorkspaceType(type)) {
      payload = jsonEncode({'type': type, 'booking_id': bookingId});
    } else if (reportId != null &&
        type != null &&
        NotificationScopeHelper.isReportType(type)) {
      payload = jsonEncode({'type': type, 'report_id': reportId});
    } else if (collaborationId != null &&
        type != null &&
        (type == 'collaboration_milestone_missed' ||
            NotificationScopeHelper.isProjectType(type))) {
      payload = jsonEncode({'type': type, 'collaboration_id': collaborationId});
    } else {
      payload = data['notification_id']?.toString();
    }

    await LocalNotificationService.instance.show(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: notification.title ?? 'CWC',
      body: notification.body ?? '',
      payload: payload,
    );
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    _openFromMessage(message);
  }

  void _openFromMessage(RemoteMessage message) {
    final data = message.data;
    final chatRoomId = data['chat_room_id']?.toString();
    if (chatRoomId != null && chatRoomId.isNotEmpty) {
      NavigationService.openChatFromNotification(chatRoomId);
      return;
    }

    final bookingId = data['booking_id']?.toString();
    final type = data['type']?.toString();
    if (bookingId != null &&
        bookingId.isNotEmpty &&
        type != null &&
        NotificationScopeHelper.isWorkspaceType(type)) {
      NavigationService.openBookingFromNotification(
        bookingId: bookingId,
        notificationType: type,
      );
      return;
    }

    final collaborationId = data['collaboration_id']?.toString();
    if (collaborationId != null &&
        collaborationId.isNotEmpty &&
        type != null &&
        (type == 'collaboration_milestone_missed' ||
            NotificationScopeHelper.isProjectType(type))) {
      final tab = type == 'collaboration_milestone_missed' ? 2 : 0;
      NavigationService.openProjectFromNotification(collaborationId, initialTab: tab);
      return;
    }

    final reportId = data['report_id']?.toString();
    if (reportId != null &&
        reportId.isNotEmpty &&
        type != null &&
        NotificationScopeHelper.isReportType(type)) {
      NavigationService.openReportFromNotification(reportId);
    }
  }
}
