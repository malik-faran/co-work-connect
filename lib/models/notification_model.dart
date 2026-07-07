import 'package:cwc/utils/helpers/model_helpers.dart';

/// Notification Model
/// Represents a notification for users
class NotificationModel {
  final String id;
  final String userId; // User who receives the notification
  final String title;
  final String message;
  final String
  type; // 'registration_approved', 'registration_rejected', 'collaboration_response', 'chat_message', etc.
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;
  final Map<String, dynamic>? metadata; // Additional data

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.isRead = false,
    required this.createdAt,
    this.readAt,
    this.metadata,
  });

  /// Convert to map for database
  Map<String, dynamic> toNotificationMap() {
    final map = <String, dynamic>{
      'id': id,
      'user_id': userId,
      'title': title,
      'message': message,
      'type': type,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };

    if (readAt != null) map['read_at'] = readAt!.toIso8601String();
    if (metadata != null) map['metadata'] = metadata;

    return map;
  }

  /// Create from database map
  factory NotificationModel.fromNotificationMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] ?? '',
      userId: getStringFromMap(map, 'user_id', 'userId') ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: getStringFromMap(map, 'type', 'type') ?? '',
      isRead: getValueFromMap(map, 'is_read', 'isRead', false),
      createdAt: getStringFromMap(map, 'created_at', 'createdAt') != null
          ? DateTime.parse(getStringFromMap(map, 'created_at', 'createdAt')!)
          : DateTime.now(),
      readAt: getStringFromMap(map, 'read_at', 'readAt') != null
          ? DateTime.parse(getStringFromMap(map, 'read_at', 'readAt')!)
          : null,
      metadata: map['metadata'] != null
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : null,
    );
  }

  NotificationModel copyNotification({
    String? id,
    String? userId,
    String? title,
    String? message,
    String? type,
    bool? isRead,
    DateTime? createdAt,
    DateTime? readAt,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      metadata: metadata ?? this.metadata,
    );
  }
}
