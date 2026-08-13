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
import 'package:cwc/views/screens/chat/new_message_screen.dart';

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
  String? _errorMessage;
  StreamSubscription<List<ChatRoomModel>>? _chatRoomsStreamSubscription;
  final Map<String, String> _roleCache = {};
  final Set<String> _hiddenRoomIds = {};
  final TextEditingController _listSearchController = TextEditingController();
  String _listSearch = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadChatRooms();
    _setupChatRoomsStream();
    _listSearchController.addListener(() {
      if (_listSearch != _listSearchController.text) {
        setState(() => _listSearch = _listSearchController.text.trim().toLowerCase());
      }
    });
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
        final hidden = await _chatService.getHiddenRoomIds(currentUser.id);
        chatRooms = await _chatService.getUserChatRooms(currentUser.id).timeout(
          const Duration(seconds: 15),
        );
        if (mounted) _hiddenRoomIds.addAll(hidden);
      } on TimeoutException {
        if (!mounted) return;
        setState(() {
          _chatRooms = [];
          _isLoading = false;
          _errorMessage = 'Request timed out. Pull down to retry.';
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _chatRooms = chatRooms.where((r) => !_hiddenRoomIds.contains(r.id)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
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
        if (chatRooms.isEmpty && _chatRooms.isNotEmpty) return;
        setState(() {
          _chatRooms = chatRooms.where((r) => !_hiddenRoomIds.contains(r.id)).toList();
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
    _listSearchController.dispose();
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
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(currentUser),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _listSearchController,
                decoration: InputDecoration(
                  hintText: 'Search conversations...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: CAppTheme.primaryColor),
                    )
                  : _errorMessage != null
                      ? _buildErrorState()
                      : _buildChatRoomsList(currentUser),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(UserModel currentUser) {
    final unreadTotal = _chatRooms.fold<int>(
      0,
      (sum, r) => sum + r.getUnreadCount(currentUser.id),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 18),
      decoration: const BoxDecoration(
        gradient: CAppTheme.primaryGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Messages',
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _chatRooms.isEmpty
                      ? 'Chat with owners & teammates'
                      : '${_chatRooms.length} chat${_chatRooms.length == 1 ? '' : 's'}'
                          '${unreadTotal > 0 ? ' · $unreadTotal unread' : ''}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NewMessageScreen()),
                ).then((_) => _loadChatRooms());
              },
              borderRadius: BorderRadius.circular(14),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.edit_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatRoomsList(UserModel currentUser) {
    var rooms = _chatRooms.where((r) => !_hiddenRoomIds.contains(r.id)).toList();
    rooms.sort((a, b) {
      final aUnread = a.getUnreadCount(currentUser.id);
      final bUnread = b.getUnreadCount(currentUser.id);
      if (aUnread > 0 && bUnread == 0) return -1;
      if (bUnread > 0 && aUnread == 0) return 1;
      final aTime = a.lastMessageAt ?? a.createdAt;
      final bTime = b.lastMessageAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });

    if (_listSearch.isNotEmpty) {
      rooms = rooms.where((r) {
        final name = r.getOtherUserName(currentUser.id)?.toLowerCase() ?? '';
        final msg = r.lastMessage?.toLowerCase() ?? '';
        return name.contains(_listSearch) || msg.contains(_listSearch);
      }).toList();
    }

    if (rooms.isEmpty) {
      return _listSearch.isNotEmpty ? _buildNoSearchResults() : _buildEmptyState();
    }

    return RefreshIndicator(
      color: CAppTheme.primaryColor,
      onRefresh: _loadChatRooms,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: rooms.length,
        itemBuilder: (context, index) {
          final chatRoom = rooms[index];
          final otherUserName = chatRoom.getOtherUserName(currentUser.id);
          final otherUserProfileImage = chatRoom.getOtherUserProfileImage(currentUser.id);
          final unreadCount = chatRoom.getUnreadCount(currentUser.id);
          final otherId = chatRoom.getOtherUserId(currentUser.id);

          return FutureBuilder<String>(
            future: _getUserRole(otherId),
            builder: (context, snapshot) {
              final role = snapshot.data ?? 'user';
              return Dismissible(
                key: ValueKey(chatRoom.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: CAppTheme.errorColor,
                    borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
                ),
                confirmDismiss: (_) async {
                  final confirm = await _confirmDeleteChat(otherUserName ?? 'User');
                  if (!confirm) return false;
                  return _performDeleteChat(chatRoom.id);
                },
                onDismissed: (_) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Chat deleted', style: GoogleFonts.poppins()),
                      backgroundColor: CAppTheme.successColor,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: _ChatRoomCard(
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
                  onLongPress: () => _showChatOptions(chatRoom.id, otherUserName ?? 'User'),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<bool> _confirmDeleteChat(String userName) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CAppTheme.radiusLarge)),
        title: Text('Delete Chat', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'Remove your chat with $userName from your list? It will stay hidden until you message them again.',
          style: GoogleFonts.poppins(fontSize: 14, color: CAppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: CAppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: CAppTheme.errorColor),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _showChatOptions(String chatRoomId, String userName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: CAppTheme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: CAppTheme.errorColor),
              title: Text(
                'Delete Chat',
                style: GoogleFonts.poppins(
                  color: CAppTheme.errorColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                final confirm = await _confirmDeleteChat(userName);
                if (confirm) {
                  final deleted = await _performDeleteChat(chatRoomId);
                  if (deleted && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Chat deleted', style: GoogleFonts.poppins()),
                        backgroundColor: CAppTheme.successColor,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<bool> _performDeleteChat(String chatRoomId) async {
    try {
      await _chatService.deleteChatRoom(chatRoomId);
      if (!mounted) return true;
      setState(() {
        _hiddenRoomIds.add(chatRoomId);
        _chatRooms = _chatRooms.where((c) => c.id != chatRoomId).toList();
      });
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete chat', style: GoogleFonts.poppins()),
            backgroundColor: CAppTheme.errorColor,
          ),
        );
      }
      return false;
    }
  }

  Widget _buildNoSearchResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 56, color: CAppTheme.textTertiary),
            const SizedBox(height: 16),
            Text(
              'No chats found',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: CAppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different name or message keyword',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: CAppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.45,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      gradient: CAppTheme.coolGradient,
                      shape: BoxShape.circle,
                      boxShadow: CAppTheme.softShadow,
                    ),
                    child: const Icon(
                      Icons.forum_rounded,
                      size: 46,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'No messages yet',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: CAppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Message workspace owners, project teammates, or find someone new',
                    style: GoogleFonts.poppins(
                      color: CAppTheme.textSecondary,
                      fontSize: 14,
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NewMessageScreen()),
                      ).then((_) => _loadChatRooms());
                    },
                    icon: const Icon(Icons.person_search_rounded),
                    label: const Text('Start a conversation'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
  final VoidCallback? onLongPress;

  const _ChatRoomCard({
    required this.chatRoom,
    required this.otherUserName,
    this.otherUserProfileImage,
    required this.unreadCount,
    required this.role,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;
    final preview = chatRoom.lastMessage ?? 'No messages yet';
    final isPhoto = preview.contains('📷') || preview.toLowerCase().contains('photo');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        border: hasUnread
            ? Border.all(color: CAppTheme.primaryColor.withValues(alpha: 0.25))
            : null,
        boxShadow: CAppTheme.softShadow,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasUnread)
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: CAppTheme.primaryColor,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(CAppTheme.radiusLarge),
                    ),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: hasUnread ? CAppTheme.primaryGradient : null,
                              color: hasUnread ? null : Colors.transparent,
                            ),
                            child: CircleAvatar(
                              radius: 26,
                              backgroundColor:
                                  CAppTheme.primaryColor.withValues(alpha: 0.1),
                              backgroundImage: otherUserProfileImage != null
                                  ? NetworkImage(otherUserProfileImage!)
                                  : null,
                              child: otherUserProfileImage == null
                                  ? Text(
                                      safeInitial(otherUserName),
                                      style: GoogleFonts.poppins(
                                        color: CAppTheme.primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          if (hasUnread)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: CAppTheme.accentColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: Text(
                                  unreadCount > 9 ? '9+' : '$unreadCount',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          otherUserName,
                                          style: GoogleFonts.poppins(
                                            fontWeight: hasUnread
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                            fontSize: 15.5,
                                            color: CAppTheme.textPrimary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: role == 'owner'
                                              ? const Color(0xFFEF8B2C)
                                                  .withValues(alpha: 0.12)
                                              : CAppTheme.primaryColor
                                                  .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            CAppTheme.radiusSmall,
                                          ),
                                        ),
                                        child: Text(
                                          role == 'owner' ? 'Owner' : 'User',
                                          style: GoogleFonts.poppins(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: role == 'owner'
                                                ? const Color(0xFFEF8B2C)
                                                : CAppTheme.primaryColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (chatRoom.lastMessageAt != null)
                                  Text(
                                    _formatTime(chatRoom.lastMessageAt!),
                                    style: GoogleFonts.poppins(
                                      fontSize: 11.5,
                                      color: hasUnread
                                          ? CAppTheme.primaryColor
                                          : CAppTheme.textTertiary,
                                      fontWeight: hasUnread
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                if (isPhoto) ...[
                                  Icon(
                                    Icons.image_rounded,
                                    size: 15,
                                    color: hasUnread
                                        ? CAppTheme.primaryColor
                                        : CAppTheme.textTertiary,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Expanded(
                                  child: Text(
                                    isPhoto ? 'Photo' : preview,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: hasUnread
                                          ? CAppTheme.textPrimary
                                          : CAppTheme.textSecondary,
                                      fontWeight: hasUnread
                                          ? FontWeight.w500
                                          : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 20,
                                  color: CAppTheme.textTertiary
                                      .withValues(alpha: 0.7),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
