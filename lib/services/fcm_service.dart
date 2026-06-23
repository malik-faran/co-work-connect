import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:cwc/firebase_options.dart';
import 'package:cwc/services/auth_service.dart';
import 'package:cwc/services/fcm_background.dart';
import 'package:cwc/services/local_notification_service.dart';

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
    final notification = message.notification;
    if (notification == null) return;

    await LocalNotificationService.instance.show(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: notification.title ?? 'CWC',
      body: notification.body ?? '',
      payload: message.data['notification_id']?.toString(),
    );
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    debugPrint('FCM opened app: ${message.data}');
  }
}
