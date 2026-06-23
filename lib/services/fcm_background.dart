import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cwc/firebase_options.dart';
import 'package:cwc/services/local_notification_service.dart';

/// Background FCM handler (app terminated / background).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await LocalNotificationService.instance.initialize();

  final notification = message.notification;
  if (notification == null) return;

  await LocalNotificationService.instance.show(
    id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
    title: notification.title ?? 'CWC',
    body: notification.body ?? '',
    payload: message.data['notification_id']?.toString(),
  );
}
