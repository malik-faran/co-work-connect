import 'package:flutter/material.dart';
import 'package:cwc/services/local_notification_service.dart';
import 'package:cwc/views/screens/chat/chat_screen.dart';
import 'package:cwc/views/screens/user/user_home_screen.dart';

/// Global navigation for deep links (e.g. notification tap → chat).
class NavigationService {
  NavigationService._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static void openChatRoom(String chatRoomId) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    navigator.push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(chatRoomId: chatRoomId),
      ),
    );
  }

  /// Switch to Messages tab on the user home shell, then open a chat room.
  static void openChatFromNotification(String chatRoomId) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    LocalNotificationService.instance.cancelChatNotification(chatRoomId);

    navigator.popUntil((route) => route.isFirst);
    UserHomeScreen.tabRequest.value = 2;
    Future.delayed(const Duration(milliseconds: 300), () {
      openChatRoom(chatRoomId);
    });
  }
}
