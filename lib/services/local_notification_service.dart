import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cwc/services/chat_service.dart';
import 'package:cwc/services/navigation_service.dart';
import 'package:cwc/services/supabase_service.dart';
import 'package:cwc/utils/notification_scope.dart';
import 'package:cwc/models/chat_model.dart';
import 'package:uuid/uuid.dart';

/// Shows alerts in the phone status bar with sound.
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final _uuid = const Uuid();

  static const _androidChannelId = 'cwc_notifications';
  static const _androidChannelName = 'CWC Notifications';
  static const _androidChatChannelId = 'cwc_chat_messages';
  static const _androidChatChannelName = 'Chat Messages';

  bool _initialized = false;
  bool _platformReady = false;

  /// Core plugin init — safe to call from [main] before [runApp].
  Future<void> initialize() async {
    if (kIsWeb || _initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTapped,
    );

    _initialized = true;
  }

  /// Channels and runtime permissions need an attached Activity on Android.
  /// Call after the first frame (or from a background FCM isolate).
  Future<void> ensurePlatformReady() async {
    if (kIsWeb || !_initialized || _platformReady) return;

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      try {
        const generalChannel = AndroidNotificationChannel(
          _androidChannelId,
          _androidChannelName,
          description: 'Booking and app alerts',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        );
        const chatChannel = AndroidNotificationChannel(
          _androidChatChannelId,
          _androidChatChannelName,
          description: 'New chat messages',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        );
        await androidPlugin.createNotificationChannel(generalChannel);
        await androidPlugin.createNotificationChannel(chatChannel);
        await androidPlugin.requestNotificationsPermission();
        _platformReady = true;
      } catch (e) {
        debugPrint('Android notification setup failed: $e');
      }
      return;
    }

    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    _platformReady = true;
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTapped(NotificationResponse response) {
    LocalNotificationService.instance._handleNotificationResponse(response);
  }

  void _onNotificationTapped(NotificationResponse response) {
    _handleNotificationResponse(response);
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final type = data['type'] as String?;
      final chatRoomId = data['chat_room_id'] as String?;

      if (type == 'chat_message' && chatRoomId != null) {
        if (response.actionId == 'reply' &&
            response.input != null &&
            response.input!.trim().isNotEmpty) {
          _sendQuickReply(chatRoomId, response.input!.trim());
        } else {
          NavigationService.openChatFromNotification(chatRoomId);
        }
        return;
      }

      final bookingId = data['booking_id'] as String?;
      if (bookingId != null &&
          type != null &&
          NotificationScopeHelper.isWorkspaceType(type)) {
        NavigationService.openBookingFromNotification(
          bookingId: bookingId,
          notificationType: type,
        );
        return;
      }

      final collaborationId = data['collaboration_id'] as String?;
      if (collaborationId != null &&
          type != null &&
          (type == 'collaboration_milestone_missed' ||
              NotificationScopeHelper.isProjectType(type))) {
        final tab = type == 'collaboration_milestone_missed' ? 2 : 0;
        NavigationService.openProjectFromNotification(collaborationId, initialTab: tab);
        return;
      }

      final reportId = data['report_id'] as String?;
      if (reportId != null &&
          type != null &&
          NotificationScopeHelper.isReportType(type)) {
        NavigationService.openReportFromNotification(reportId);
      }
    } catch (_) {
      // Legacy payload: plain notification id — ignore navigation.
    }
  }

  Future<void> _sendQuickReply(String chatRoomId, String text) async {
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return;

      final profile = await SupabaseService.client
          .from('users')
          .select('name, profile_image_url')
          .eq('id', user.id)
          .maybeSingle();

      final message = ChatMessageModel(
        id: _uuid.v4(),
        chatRoomId: chatRoomId,
        senderId: user.id,
        senderName: profile?['name'] as String? ?? 'User',
        senderProfileImage: profile?['profile_image_url'] as String?,
        message: text,
        createdAt: DateTime.now(),
      );

      await ChatService().sendMessage(message);
      NavigationService.openChatFromNotification(chatRoomId);
    } catch (e) {
      debugPrint('Quick reply failed: $e');
    }
  }

  Future<void> _ensureCanShow() async {
    if (kIsWeb || !_initialized) return;
    if (!_platformReady) {
      await ensurePlatformReady();
    }
  }

  Future<void> show({
    required String id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _ensureCanShow();
    if (kIsWeb || !_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: 'Booking and app alerts',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      id.hashCode,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload ?? id,
    );
  }

  Future<void> cancelChatNotification(String chatRoomId) async {
    if (kIsWeb || !_initialized) return;
    await _plugin.cancel('chat_$chatRoomId'.hashCode);
  }

  /// Chat message with Open + Reply actions (Android).
  Future<void> showChatMessage({
    required String id,
    required String title,
    required String body,
    required String chatRoomId,
  }) async {
    await _ensureCanShow();
    if (kIsWeb || !_initialized) return;

    final payload = jsonEncode({
      'type': 'chat_message',
      'chat_room_id': chatRoomId,
      'notification_id': id,
    });

    const androidDetails = AndroidNotificationDetails(
      _androidChatChannelId,
      _androidChatChannelName,
      channelDescription: 'New chat messages',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      actions: [
        AndroidNotificationAction(
          'reply',
          'Reply',
          inputs: [AndroidNotificationActionInput(label: 'Message')],
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'open_chat',
          'Open',
          showsUserInterface: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'chat_message',
    );

    await _plugin.show(
      'chat_$chatRoomId'.hashCode,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }
}
