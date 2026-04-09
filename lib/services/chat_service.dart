import 'package:cwc/models/chat_model.dart';
import 'package:cwc/services/notification_service.dart';
import 'package:cwc/services/supabase_service.dart';
import 'package:uuid/uuid.dart';

/// Chat Service
/// Handles all chat-related database operations
class ChatService {
  final _supabase = SupabaseService.client;
  final _uuid = const Uuid();

  /// Get or create a chat room between two users
  Future<ChatRoomModel> getOrCreateChatRoom({
    required String user1Id,
    required String user2Id,
    String? collaborationId,
    String? workspaceId,
  }) async {
    try {
      // Try to find existing chat room
      final existingRooms = await _supabase
          .from('chat_rooms')
          .select()
          .or('and(user1_id.eq.$user1Id,user2_id.eq.$user2Id),and(user1_id.eq.$user2Id,user2_id.eq.$user1Id)')
          .maybeSingle();

      if (existingRooms != null) {
        return ChatRoomModel.fromChatRoomMap(existingRooms);
      }

      // Get user details for caching
      final user1Data = await _supabase
          .from('users')
          .select('name, profile_image_url')
          .eq('id', user1Id)
          .maybeSingle();

      final user2Data = await _supabase
          .from('users')
          .select('name, profile_image_url')
          .eq('id', user2Id)
          .maybeSingle();

      // Create new chat room
      final chatRoom = ChatRoomModel(
        id: _uuid.v4(),
        user1Id: user1Id,
        user2Id: user2Id,
        user1Name: user1Data?['name'],
        user2Name: user2Data?['name'],
        user1ProfileImage: user1Data?['profile_image_url'],
        user2ProfileImage: user2Data?['profile_image_url'],
        createdAt: DateTime.now(),
        collaborationId: collaborationId,
        workspaceId: workspaceId,
      );

      final chatRoomData = chatRoom.toChatRoomMap();
      chatRoomData.removeWhere((key, value) => value == null);

      await _supabase.from('chat_rooms').insert(chatRoomData);

      return chatRoom;
    } catch (e) {
      throw Exception('Failed to get or create chat room: ${e.toString()}');
    }
  }

  /// Get all chat rooms for a user
  Future<List<ChatRoomModel>> getUserChatRooms(String userId) async {
    try {
      final rows = await _supabase
          .from('chat_rooms')
          .select()
          .or('user1_id.eq.$userId,user2_id.eq.$userId')
          .order('last_message_at', ascending: false);

      return rows.map((r) => ChatRoomModel.fromChatRoomMap(r)).toList();
    } catch (e) {
      throw Exception('Failed to fetch chat rooms: ${e.toString()}');
    }
  }

  /// Get chat room by ID
  Future<ChatRoomModel?> getChatRoomById(String chatRoomId) async {
    try {
      final result = await _supabase
          .from('chat_rooms')
          .select()
          .eq('id', chatRoomId)
          .maybeSingle();

      if (result == null) return null;
      return ChatRoomModel.fromChatRoomMap(result);
    } catch (e) {
      throw Exception('Failed to fetch chat room: ${e.toString()}');
    }
  }

  /// Send a message
  Future<String> sendMessage(ChatMessageModel message) async {
    try {
      final messageData = message.toMessageMap();
      messageData.removeWhere((key, value) => value == null);

      await _supabase
          .from('messages')
          .insert(messageData);

      // Update chat room with last message
      final chatRoom = await getChatRoomById(message.chatRoomId);
      if (chatRoom != null) {
        final isUser1 = message.senderId == chatRoom.user1Id;
        final receiverId = isUser1 ? chatRoom.user2Id : chatRoom.user1Id;
        final updateData = {
          'last_message': message.message,
          'last_message_at': message.createdAt.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          if (isUser1) 'unread_count2': chatRoom.unreadCount2 + 1,
          if (!isUser1) 'unread_count1': chatRoom.unreadCount1 + 1,
        };

        await _supabase
            .from('chat_rooms')
            .update(updateData)
            .eq('id', message.chatRoomId);

        // Send notification to the receiver
        final notificationService = NotificationService();
        await notificationService.sendChatMessageNotification(
          receiverUserId: receiverId,
          senderName: message.senderName,
          message: message.message,
          chatRoomId: message.chatRoomId,
        );
      }

      return message.id;
    } catch (e) {
      throw Exception('Failed to send message: ${e.toString()}');
    }
  }

  /// Get messages for a chat room
  Future<List<ChatMessageModel>> getChatMessages(String chatRoomId, {int limit = 50}) async {
    try {
      final rows = await _supabase
          .from('messages')
          .select()
          .eq('chat_room_id', chatRoomId)
          .order('created_at', ascending: false)
          .limit(limit);

      final messages = rows
          .map((m) => ChatMessageModel.fromMessageMap(m))
          .toList();

      // Reverse to show oldest first
      return messages.reversed.toList();
    } catch (e) {
      throw Exception('Failed to fetch messages: ${e.toString()}');
    }
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(String chatRoomId, String userId) async {
    try {
      // Mark all unread messages as read
      await _supabase
          .from('messages')
          .update({'is_read': true, 'updated_at': DateTime.now().toIso8601String()})
          .eq('chat_room_id', chatRoomId)
          .neq('sender_id', userId)
          .eq('is_read', false);

      // Reset unread count in chat room
      final chatRoom = await getChatRoomById(chatRoomId);
      if (chatRoom != null) {
        final isUser1 = userId == chatRoom.user1Id;
        final updateData = {
          if (isUser1) 'unread_count1': 0,
          if (!isUser1) 'unread_count2': 0,
          'updated_at': DateTime.now().toIso8601String(),
        };

        await _supabase
            .from('chat_rooms')
            .update(updateData)
            .eq('id', chatRoomId);
      }
    } catch (e) {
      throw Exception('Failed to mark messages as read: ${e.toString()}');
    }
  }

  /// Get stream of messages for real-time chat
  Stream<List<ChatMessageModel>> getMessagesStream(String chatRoomId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_room_id', chatRoomId)
        .order('created_at', ascending: false)
        .limit(50)
        .map((data) {
          final messages = data
              .map((m) => ChatMessageModel.fromMessageMap(m))
              .toList();
          return messages.reversed.toList();
        });
  }

  /// Get stream of chat rooms for real-time updates
  Stream<List<ChatRoomModel>> getChatRoomsStream(String userId) {
    return _supabase
        .from('chat_rooms')
        .stream(primaryKey: ['id'])
        .map((data) {
          // Filter chat rooms where user is either user1 or user2
          final filteredData = data.where((room) {
            return room['user1_id'] == userId || room['user2_id'] == userId;
          }).toList();
          
          // Sort by last_message_at
          filteredData.sort((a, b) {
            final aTime = a['last_message_at'] != null 
                ? DateTime.parse(a['last_message_at']).millisecondsSinceEpoch 
                : 0;
            final bTime = b['last_message_at'] != null 
                ? DateTime.parse(b['last_message_at']).millisecondsSinceEpoch 
                : 0;
            return bTime.compareTo(aTime); // Descending order
          });
          
          return filteredData.map((r) => ChatRoomModel.fromChatRoomMap(r)).toList();
        });
  }

  /// Delete a message
  Future<void> deleteMessage(String messageId) async {
    try {
      await _supabase.from('messages').delete().eq('id', messageId);
    } catch (e) {
      throw Exception('Failed to delete message: ${e.toString()}');
    }
  }
}
