import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cwc/firebase_options.dart';
import 'package:cwc/services/local_notification_service.dart';
import 'package:cwc/utils/notification_scope.dart';
/// Background FCM handler (app terminated / background).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await LocalNotificationService.instance.initialize();
  await LocalNotificationService.instance.ensurePlatformReady();

  final notification = message.notification;
  if (notification == null) return;

  final data = message.data;
  final type = data['type']?.toString();
  final bookingId = data['booking_id']?.toString();
  final reportId = data['report_id']?.toString();
  final collaborationId = data['collaboration_id']?.toString();
  final chatRoomId = data['chat_room_id']?.toString();
  String? payload;
  if (chatRoomId != null && chatRoomId.isNotEmpty) {
    payload = jsonEncode({'type': 'chat_message', 'chat_room_id': chatRoomId});
  } else if (bookingId != null &&
      type != null &&
      NotificationScopeHelper.isWorkspaceType(type)) {
    payload = jsonEncode({'type': type, 'booking_id': bookingId});
  } else if (collaborationId != null &&
      type != null &&
      (type == 'collaboration_milestone_missed' ||
          NotificationScopeHelper.isProjectType(type))) {
    payload = jsonEncode({'type': type, 'collaboration_id': collaborationId});
  } else if (reportId != null &&
      type != null &&
      NotificationScopeHelper.isReportType(type)) {
    payload = jsonEncode({'type': type, 'report_id': reportId});
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