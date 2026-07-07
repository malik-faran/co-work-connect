import 'package:cwc/utils/helpers/model_helpers.dart';

/// Chat Room Model
/// Represents a conversation between two users
class ChatRoomModel {
  final String id;
  final String user1Id; // First user ID (group: creator/owner)
  final String user2Id; // Second user ID (group: empty)
  final String roomType; // 'direct' | 'group'
  final String? name; // group room name (e.g. project title)
  final String? user1Name; // Cached name for quick access
  final String? user2Name;
  final String? user1ProfileImage;
  final String? user2ProfileImage;
  final String? lastMessage; // Last message preview
  final DateTime? lastMessageAt; // Timestamp of last message
  final int unreadCount1; // Unread count for user1
  final int unreadCount2; // Unread count for user2
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? collaborationId; // If chat is related to a collaboration
  final String? workspaceId; // If chat is related to a workspace booking

  ChatRoomModel({
    required this.id,
    required this.user1Id,
    this.user2Id = '',
    this.roomType = 'direct',
    this.name,
    this.user1Name,
    this.user2Name,
    this.user1ProfileImage,
    this.user2ProfileImage,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount1 = 0,
    this.unreadCount2 = 0,
    required this.createdAt,
    this.updatedAt,
    this.collaborationId,
    this.workspaceId,
  });

  /// Convert to map for database
  Map<String, dynamic> toChatRoomMap() {
    final map = <String, dynamic>{
      'id': id,
      'user1_id': user1Id,
      'room_type': roomType,
      'unread_count1': unreadCount1,
      'unread_count2': unreadCount2,
      'created_at': createdAt.toIso8601String(),
    };

    if (roomType == 'group') {
      if (user2Id.isNotEmpty) map['user2_id'] = user2Id;
    } else {
      map['user2_id'] = user2Id;
    }
    if (name != null) map['name'] = name;
    if (user1Name != null) map['user1_name'] = user1Name;
    if (user2Name != null) map['user2_name'] = user2Name;
    if (user1ProfileImage != null) map['user1_profile_image'] = user1ProfileImage;
    if (user2ProfileImage != null) map['user2_profile_image'] = user2ProfileImage;
    if (lastMessage != null) map['last_message'] = lastMessage;
    if (lastMessageAt != null) map['last_message_at'] = lastMessageAt!.toIso8601String();
    if (updatedAt != null) map['updated_at'] = updatedAt!.toIso8601String();
    if (collaborationId != null) map['collaboration_id'] = collaborationId;
    if (workspaceId != null) map['workspace_id'] = workspaceId;

    return map;
  }

  /// Create from database map
  factory ChatRoomModel.fromChatRoomMap(Map<String, dynamic> map) {
    return ChatRoomModel(
      id: map['id'] ?? '',
      user1Id: getStringFromMap(map, 'user1_id', 'user1Id') ?? '',
      user2Id: getStringFromMap(map, 'user2_id', 'user2Id') ?? '',
      roomType: getStringFromMap(map, 'room_type', 'roomType') ?? 'direct',
      name: getStringFromMap(map, 'name', 'name'),
      user1Name: getStringFromMap(map, 'user1_name', 'user1Name'),
      user2Name: getStringFromMap(map, 'user2_name', 'user2Name'),
      user1ProfileImage: getStringFromMap(map, 'user1_profile_image', 'user1ProfileImage'),
      user2ProfileImage: getStringFromMap(map, 'user2_profile_image', 'user2ProfileImage'),
      lastMessage: getStringFromMap(map, 'last_message', 'lastMessage'),
      lastMessageAt: getStringFromMap(map, 'last_message_at', 'lastMessageAt') != null
          ? DateTime.parse(getStringFromMap(map, 'last_message_at', 'lastMessageAt')!)
          : null,
      unreadCount1: convertToInt(map['unread_count1'], 0),
      unreadCount2: convertToInt(map['unread_count2'], 0),
      createdAt: getStringFromMap(map, 'created_at', 'createdAt') != null
          ? DateTime.parse(getStringFromMap(map, 'created_at', 'createdAt')!)
          : DateTime.now(),
      updatedAt: getStringFromMap(map, 'updated_at', 'updatedAt') != null
          ? DateTime.parse(getStringFromMap(map, 'updated_at', 'updatedAt')!)
          : null,
      collaborationId: getStringFromMap(map, 'collaboration_id', 'collaborationId'),
      workspaceId: getStringFromMap(map, 'workspace_id', 'workspaceId'),
    );
  }

  /// Get the other user's ID
  String getOtherUserId(String currentUserId) {
    return currentUserId == user1Id ? user2Id : user1Id;
  }

  /// Get the other user's name
  String? getOtherUserName(String currentUserId) {
    return currentUserId == user1Id ? user2Name : user1Name;
  }

  /// Get the other user's profile image
  String? getOtherUserProfileImage(String currentUserId) {
    return currentUserId == user1Id ? user2ProfileImage : user1ProfileImage;
  }

  /// Get unread count for current user
  int getUnreadCount(String currentUserId) {
    return currentUserId == user1Id ? unreadCount1 : unreadCount2;
  }

  bool get isGroup => roomType == 'group';
}

/// Chat Message Model
/// Represents a single message in a chat room
class ChatMessageModel {
  final String id;
  final String chatRoomId;
  final String senderId;
  final String senderName; // Cached name
  final String? senderProfileImage; // Cached profile image
  final String message;
  final String messageType; // 'text', 'image', 'file'
  final String? imageUrl; // If message type is image
  final String? fileUrl; // If message type is file
  final bool isRead;
  final bool isEdited;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? editedAt;

  ChatMessageModel({
    required this.id,
    required this.chatRoomId,
    required this.senderId,
    required this.senderName,
    this.senderProfileImage,
    required this.message,
    this.messageType = 'text',
    this.imageUrl,
    this.fileUrl,
    this.isRead = false,
    this.isEdited = false,
    required this.createdAt,
    this.updatedAt,
    this.editedAt,
  });

  /// Convert to map for database
  Map<String, dynamic> toMessageMap() {
    final map = <String, dynamic>{
      'id': id,
      'chat_room_id': chatRoomId,
      'sender_id': senderId,
      'sender_name': senderName,
      'message': message,
      'message_type': messageType,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };

    if (senderProfileImage != null) map['sender_profile_image'] = senderProfileImage;
    if (imageUrl != null) map['image_url'] = imageUrl;
    if (fileUrl != null) map['file_url'] = fileUrl;
    if (updatedAt != null) map['updated_at'] = updatedAt!.toIso8601String();
    if (isEdited) map['is_edited'] = true;
    if (editedAt != null) map['edited_at'] = editedAt!.toIso8601String();

    return map;
  }

  /// Create from database map
  factory ChatMessageModel.fromMessageMap(Map<String, dynamic> map) {
    return ChatMessageModel(
      id: map['id'] ?? '',
      chatRoomId: getStringFromMap(map, 'chat_room_id', 'chatRoomId') ?? '',
      senderId: getStringFromMap(map, 'sender_id', 'senderId') ?? '',
      senderName: getStringFromMap(map, 'sender_name', 'senderName') ?? '',
      senderProfileImage: getStringFromMap(map, 'sender_profile_image', 'senderProfileImage'),
      message: map['message'] ?? '',
      messageType: getStringFromMap(map, 'message_type', 'messageType') ?? 'text',
      imageUrl: getStringFromMap(map, 'image_url', 'imageUrl'),
      fileUrl: getStringFromMap(map, 'file_url', 'fileUrl'),
      isRead: getValueFromMap(map, 'is_read', 'isRead', false),
      isEdited: getValueFromMap(map, 'is_edited', 'isEdited', false),
      createdAt: getStringFromMap(map, 'created_at', 'createdAt') != null
          ? DateTime.parse(getStringFromMap(map, 'created_at', 'createdAt')!)
          : DateTime.now(),
      updatedAt: getStringFromMap(map, 'updated_at', 'updatedAt') != null
          ? DateTime.parse(getStringFromMap(map, 'updated_at', 'updatedAt')!)
          : null,
      editedAt: getStringFromMap(map, 'edited_at', 'editedAt') != null
          ? DateTime.parse(getStringFromMap(map, 'edited_at', 'editedAt')!)
          : null,
    );
  }

  /// Check if message is from current user
  bool isFromUser(String userId) => senderId == userId;

  ChatMessageModel copyWith({
    String? message,
    bool? isEdited,
    DateTime? editedAt,
    DateTime? updatedAt,
    bool? isRead,
  }) {
    return ChatMessageModel(
      id: id,
      chatRoomId: chatRoomId,
      senderId: senderId,
      senderName: senderName,
      senderProfileImage: senderProfileImage,
      message: message ?? this.message,
      messageType: messageType,
      imageUrl: imageUrl,
      fileUrl: fileUrl,
      isRead: isRead ?? this.isRead,
      isEdited: isEdited ?? this.isEdited,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      editedAt: editedAt ?? this.editedAt,
    );
  }
}
