/// Tracks which chat room the user is currently viewing (suppresses duplicate alerts).
class ActiveChatTracker {
  ActiveChatTracker._();

  static String? _activeChatRoomId;

  static void setActive(String? chatRoomId) {
    _activeChatRoomId = chatRoomId;
  }

  static bool isActive(String chatRoomId) =>
      _activeChatRoomId != null && _activeChatRoomId == chatRoomId;
}
