import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/models/chat_model.dart';
import 'package:cwc/services/chat_service.dart';
import 'package:cwc/utils/helpers/model_helpers.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/models/user_model.dart';
import 'package:cwc/services/supabase_service.dart';
import 'package:cwc/views/screens/chat/chat_screen.dart';

/// Chat List Screen
/// Shows all chat conversations for the current user
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with WidgetsBindingObserver {
  final ChatService _chatService = ChatService();
  List<ChatRoomModel> _chatRooms = [];
  bool _isLoading = true;
  bool _initialLoadCompleted = false;
  String? _errorMessage;
  StreamSubscription<List<ChatRoomModel>>? _chatRoomsStreamSubscription;
  final Map<String, String> _roleCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadChatRooms();
    _setupChatRoomsStream();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _loadChatRooms();
      _setupChatRoomsStream();
    }
  }

  Future<void> _loadChatRooms() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _roleCache.clear();

    try {
      final authController = context.read<AuthController>();
      final currentUser = authController.currentUser;
      if (currentUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      List<ChatRoomModel> chatRooms;
      try {
        chatRooms = await _chatService.getUserChatRooms(currentUser.id).timeout(
          const Duration(seconds: 15),
        );
      } on TimeoutException {
        if (!mounted) return;
        setState(() {
          _chatRooms = [];
          _isLoading = false;
          _initialLoadCompleted = true;
          _errorMessage = 'Request timed out. Pull down to retry.';
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _chatRooms = chatRooms;
        _isLoading = false;
        _initialLoadCompleted = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _initialLoadCompleted = true;
      });
    }
  }

  void _setupChatRoomsStream() {
    final authController = context.read<AuthController>();
    final currentUser = authController.currentUser;
    if (currentUser == null) return;

    _chatRoomsStreamSubscription?.cancel();

    _chatRoomsStreamSubscription = _chatService.getChatRoomsStream(currentUser.id).listen(
      (chatRooms) {
        if (!mounted) return;
        // Don't overwrite existing chats with an empty list (stream timeout or initial empty snapshot)
        if (chatRooms.isEmpty && _chatRooms.isNotEmpty) return;
        setState(() {
          _chatRooms = chatRooms;
        });
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }

  Future<String> _getUserRole(String userId) async {
    if (_roleCache.containsKey(userId)) return _roleCache[userId]!;
    try {
      final data = await SupabaseService.client
          .from('users')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      final rawRole = data?['role'] as String?;
      final role = (rawRole != null && rawRole.isNotEmpty) ? rawRole : 'user';
      // Only cache when we got a real row from DB (don't cache failed/default so we can retry)
      if (data != null && rawRole != null && rawRole.isNotEmpty) {
        _roleCache[userId] = role;
      }
      return role;
    } catch (_) {
      return 'user';
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chatRoomsStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final currentUser = authController.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        backgroundColor: CAppTheme.backgroundColor,
        body: Center(child: CircularProgressIndicator(color: CAppTheme.primaryColor)),
      );
    }

    return Scaffold(
      backgroundColor: CAppTheme.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: Text(
          'Messages',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: CAppTheme.textPrimary,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: CAppTheme.primaryColor))
          : _errorMessage != null
              ? _buildErrorState()
              : _chatRooms.isEmpty
                  ? _buildEmptyState()
                  : _buildChatRoomsList(currentUser),
    );
  }

  Widget _buildChatRoomsList(UserModel currentUser) {
    return RefreshIndicator(
      color: CAppTheme.primaryColor,
      onRefresh: _loadChatRooms,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _chatRooms.length,
        itemBuilder: (context, index) {
          final chatRoom = _chatRooms[index];
          final otherUserName = chatRoom.getOtherUserName(currentUser.id);
          final otherUserProfileImage = chatRoom.getOtherUserProfileImage(currentUser.id);
          final unreadCount = chatRoom.getUnreadCount(currentUser.id);
          final otherId = chatRoom.getOtherUserId(currentUser.id);

          return FutureBuilder<String>(
            future: _getUserRole(otherId),
            builder: (context, snapshot) {
              final role = snapshot.data ?? 'user';
              return _ChatRoomCard(
                chatRoom: chatRoom,
                otherUserName: otherUserName ?? 'User',
                otherUserProfileImage: otherUserProfileImage,
                unreadCount: unreadCount,
                role: role,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(chatRoomId: chatRoom.id),
                    ),
                  ).then((_) => _loadChatRooms());
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: CAppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 44,
                color: CAppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No messages yet',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: CAppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a conversation from collaborations or bookings',
              style: GoogleFonts.poppins(
                color: CAppTheme.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: CAppTheme.errorColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 36, color: CAppTheme.errorColor),
            ),
            const SizedBox(height: 20),
            Text(
              'Something went wrong',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: CAppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              style: GoogleFonts.poppins(color: CAppTheme.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadChatRooms,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chat Room Card Widget
class _ChatRoomCard extends StatelessWidget {
  final ChatRoomModel chatRoom;
  final String otherUserName;
  final String? otherUserProfileImage;
  final int unreadCount;
  final String role;
  final VoidCallback onTap;

  const _ChatRoomCard({
    required this.chatRoom,
    required this.otherUserName,
    this.otherUserProfileImage,
    required this.unreadCount,
    required this.role,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        boxShadow: CAppTheme.softShadow,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: CAppTheme.primaryColor.withValues(alpha: 0.1),
                    backgroundImage: otherUserProfileImage != null
                        ? NetworkImage(otherUserProfileImage!)
                        : null,
                    child: otherUserProfileImage == null
                        ? Text(
                            safeInitial(otherUserName),
                            style: GoogleFonts.poppins(
                              color: CAppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          )
                        : null,
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: CAppTheme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  otherUserName,
                                  style: GoogleFonts.poppins(
                                    fontWeight: unreadCount > 0 ? FontWeight.w700 : FontWeight.w600,
                                    fontSize: 16,
                                    color: CAppTheme.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: role == 'owner'
                                      ? const Color(0xFFEF8B2C).withValues(alpha: 0.1)
                                      : CAppTheme.primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(CAppTheme.radiusSmall),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (role == 'owner')
                                      Padding(
                                        padding: const EdgeInsets.only(right: 3),
                                        child: Icon(
                                          Icons.business_rounded,
                                          size: 10,
                                          color: const Color(0xFFEF8B2C),
                                        ),
                                      ),
                                    Text(
                                      role == 'owner' ? 'Owner' : 'User',
                                      style: GoogleFonts.poppins(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: role == 'owner'
                                            ? const Color(0xFFEF8B2C)
                                            : CAppTheme.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (chatRoom.lastMessageAt != null)
                          Text(
                            _formatTime(chatRoom.lastMessageAt!),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: unreadCount > 0
                                  ? CAppTheme.primaryColor
                                  : CAppTheme.textTertiary,
                              fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      chatRoom.lastMessage ?? 'No messages yet',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: unreadCount > 0
                            ? CAppTheme.textPrimary
                            : CAppTheme.textSecondary,
                        fontWeight: unreadCount > 0
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      final hour = dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '${hour > 12 ? hour - 12 : hour}:$minute ${hour >= 12 ? 'PM' : 'AM'}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }
}
