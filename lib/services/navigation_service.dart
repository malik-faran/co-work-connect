import 'package:flutter/material.dart';
import 'package:cwc/services/booking_service.dart';
import 'package:cwc/services/local_notification_service.dart';
import 'package:cwc/services/supabase_service.dart';
import 'package:cwc/utils/constants/app_constants.dart';
import 'package:cwc/views/screens/booking/booking_confirmation_screen.dart';
import 'package:cwc/views/screens/chat/chat_screen.dart';
import 'package:cwc/views/screens/owner/owner_bookings_screen.dart';
import 'package:cwc/views/screens/payment/payment_screen.dart';
import 'package:cwc/views/screens/user/booking_history_screen.dart';
import 'package:cwc/views/screens/user/user_home_screen.dart';
import 'package:cwc/views/screens/auth/reset_password_screen.dart';

import 'package:cwc/views/screens/collaboration/collaboration_detail_screen.dart';
import 'package:cwc/views/screens/collaboration/collaboration_project_screen.dart';
import 'package:cwc/views/screens/report/report_detail_screen.dart';

/// Global navigation for deep links (e.g. notification tap → chat).
class NavigationService {
  NavigationService._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static void openResetPassword() {
    void push() {
      final navigator = navigatorKey.currentState;
      if (navigator == null) return;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
        (route) => false,
      );
    }

    if (navigatorKey.currentState != null) {
      push();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => push());
    }
  }

  static void openProjectFromNotification(String collaborationId, {int initialTab = 0}) {
    void push() {
      final navigator = navigatorKey.currentState;
      if (navigator == null || collaborationId.isEmpty) return;
      navigator.push(
        MaterialPageRoute(
          builder: (_) => initialTab > 0
              ? CollaborationProjectScreen(
                  collaborationId: collaborationId,
                  initialTab: initialTab,
                )
              : CollaborationDetailScreen(collaborationId: collaborationId),
        ),
      );
    }

    if (navigatorKey.currentState != null) {
      push();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => push());
    }
  }

  static void openReportFromNotification(String reportId) {
    void push() {
      final navigator = navigatorKey.currentState;
      if (navigator == null || reportId.isEmpty) return;
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ReportDetailScreen(reportId: reportId),
        ),
      );
    }

    if (navigatorKey.currentState != null) {
      push();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => push());
    }
  }

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

  /// Open the booking tied to a workspace notification (booking / payment).
  static Future<void> openBookingFromNotification({
    required String bookingId,
    String? notificationType,
  }) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    final booking = await BookingService().getBookingById(bookingId);
    if (booking == null) {
      navigator.push(
        MaterialPageRoute(builder: (_) => const BookingHistoryScreen()),
      );
      return;
    }

    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;

    final profile = await SupabaseService.client
        .from('users')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
    final role = profile?['role'] as String? ?? AppConstants.roleUser;
    final isOwner = role == AppConstants.roleOwner;

    if (isOwner) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => OwnerBookingsScreen(
            initialBookingId: bookingId,
            initialTabIndex: notificationType == 'payment_receipt' ? 1 : 0,
            showFab: false,
          ),
        ),
      );
      return;
    }

    if (notificationType == 'payment_rejected') {
      navigator.push(
        MaterialPageRoute(builder: (_) => PaymentScreen(booking: booking)),
      );
      return;
    }

    navigator.push(
      MaterialPageRoute(
        builder: (_) => BookingConfirmationScreen(booking: booking),
      ),
    );
  }
}
