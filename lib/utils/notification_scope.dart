import 'package:cwc/models/notification_model.dart';

/// Which section of the app a notification belongs to.
enum NotificationScope {
  projects,
  workspaces,
  all,
}

class NotificationScopeHelper {
  NotificationScopeHelper._();

  static const Set<String> projectTypes = {
    'collaboration_response',
    'collaboration_accepted',
    'collaboration_rejected',
    'collaboration_application',
    'collaboration_shortlisted',
    'collaboration_launched',
    'collaboration_invite',
    'collaboration_join_request',
    'collaboration_completed',
    'collaboration_milestone',
  };

  static const Set<String> workspaceTypes = {
    'booking_confirmed',
    'booking_cancelled',
    'payment_receipt',
    'payment_rejected',
  };

  static bool isProjectType(String type) => projectTypes.contains(type);

  static bool isWorkspaceType(String type) => workspaceTypes.contains(type);

  static bool matches(NotificationModel notification, NotificationScope scope) {
    switch (scope) {
      case NotificationScope.projects:
        return isProjectType(notification.type);
      case NotificationScope.workspaces:
        return isWorkspaceType(notification.type);
      case NotificationScope.all:
        return true;
    }
  }

  static List<NotificationModel> filter(
    List<NotificationModel> notifications,
    NotificationScope scope,
  ) {
    if (scope == NotificationScope.all) return notifications;
    return notifications.where((n) => matches(n, scope)).toList();
  }

  static int unreadCount(
    List<NotificationModel> notifications,
    NotificationScope scope,
  ) {
    return filter(notifications, scope).where((n) => !n.isRead).length;
  }

  static String titleFor(NotificationScope scope) {
    switch (scope) {
      case NotificationScope.projects:
        return 'Project Notifications';
      case NotificationScope.workspaces:
        return 'Workspace Notifications';
      case NotificationScope.all:
        return 'Notifications';
    }
  }

  static String emptyMessageFor(NotificationScope scope) {
    switch (scope) {
      case NotificationScope.projects:
        return 'No project updates yet';
      case NotificationScope.workspaces:
        return 'No booking or payment updates yet';
      case NotificationScope.all:
        return 'No notifications';
    }
  }
}
