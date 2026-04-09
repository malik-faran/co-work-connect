import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/models/chat_model.dart';
import 'package:cwc/services/chat_service.dart';
import 'package:cwc/utils/helpers/model_helpers.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/services/supabase_service.dart';
import 'package:uuid/uuid.dart';

/// Chat Screen
/// Real-time chat interface between users
class ChatScreen extends StatefulWidget {
  final String chatRoomId;

  const ChatScreen({super.key, required this.chatRoomId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _uuid = const Uuid();

  ChatRoomModel? _chatRoom;
  List<ChatMessageModel> _messages = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _otherUserName;
  String? _otherUserProfileImage;
  String? _otherUserRole;
  StreamSubscription<List<ChatMessageModel>>? _messageStreamSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadChatRoom();
    _setupMessageStream();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageStreamSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reloadMessages();
      _setupMessageStream();
    }
  }

  Future<void> _reloadMessages() async {
    try {
      final messages = await _chatService.getChatMessages(widget.chatRoomId, limit: 100);
      if (mounted) {
        setState(() {
          _messages = messages;
        });
        _scrollToBottom();

        final authController = context.read<AuthController>();
        final currentUser = authController.currentUser;
        if (currentUser != null) {
          await _chatService.markMessagesAsRead(widget.chatRoomId, currentUser.id);
        }
      }
    } catch (_) {}
  }

  Future<void> _loadChatRoom() async {
    try {
      final chatRoom = await _chatService.getChatRoomById(widget.chatRoomId);
      if (chatRoom == null) {
        setState(() {
          _errorMessage = 'Chat room not found';
          _isLoading = false;
        });
        return;
      }

      final authController = context.read<AuthController>();
      final currentUser = authController.currentUser;
      if (currentUser == null) return;

      final otherUserName = chatRoom.getOtherUserName(currentUser.id);
      final otherUserProfileImage = chatRoom.getOtherUserProfileImage(currentUser.id);

      String? otherUserRole;
      try {
        final otherUserId = chatRoom.getOtherUserId(currentUser.id);
        final roleData = await SupabaseService.client
            .from('users')
            .select('role')
            .eq('id', otherUserId)
            .maybeSingle();
        otherUserRole = roleData?['role'] as String? ?? 'user';
      } catch (_) {
        otherUserRole = 'user';
      }

      setState(() {
        _chatRoom = chatRoom;
        _otherUserName = otherUserName;
        _otherUserProfileImage = otherUserProfileImage;
        _otherUserRole = otherUserRole;
        _isLoading = false;
      });

      await _chatService.markMessagesAsRead(widget.chatRoomId, currentUser.id);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _setupMessageStream() {
    _messageStreamSubscription?.cancel();

    _messageStreamSubscription = _chatService.getMessagesStream(widget.chatRoomId).listen(
      (messages) {
        if (mounted) {
          setState(() {
            if (messages.length >= _messages.length) {
              _messages = messages;
            } else {
              final streamIds = messages.map((m) => m.id).toSet();
              final localOnly = _messages.where((m) => !streamIds.contains(m.id)).toList();
              _messages = [...messages, ...localOnly];
            }
          });
          _scrollToBottom();
        }
      },
      onError: (_) {
        if (mounted) _reloadMessages();
      },
      cancelOnError: false,
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final authController = context.read<AuthController>();
    final currentUser = authController.currentUser;
    if (currentUser == null || _chatRoom == null) return;

    final message = ChatMessageModel(
      id: _uuid.v4(),
      chatRoomId: widget.chatRoomId,
      senderId: currentUser.id,
      senderName: currentUser.name,
      senderProfileImage: currentUser.profileImageUrl,
      message: text,
      createdAt: DateTime.now(),
    );

    _messageController.clear();

    setState(() {
      _messages = [..._messages, message];
    });
    _scrollToBottom();

    try {
      await _chatService.sendMessage(message);
      await _chatService.markMessagesAsRead(widget.chatRoomId, currentUser.id);
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages = _messages.where((m) => m.id != message.id).toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message'),
            backgroundColor: CAppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final currentUser = authController.currentUser;

    return Scaffold(
      backgroundColor: CAppTheme.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: CAppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: CAppTheme.primaryColor.withValues(alpha: 0.1),
              backgroundImage: _otherUserProfileImage != null
                  ? NetworkImage(_otherUserProfileImage!)
                  : null,
              child: _otherUserProfileImage == null
                  ? Text(
                      safeInitial(_otherUserName),
                      style: GoogleFonts.poppins(
                        color: CAppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _otherUserName ?? 'User',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: CAppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (_otherUserRole != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _otherUserRole == 'owner'
                                ? const Color(0xFFEF8B2C).withValues(alpha: 0.1)
                                : CAppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(CAppTheme.radiusSmall),
                          ),
                          child: Text(
                            _otherUserRole == 'owner' ? 'Owner' : 'User',
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _otherUserRole == 'owner'
                                  ? const Color(0xFFEF8B2C)
                                  : CAppTheme.primaryColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    _chatRoom?.lastMessageAt != null
                        ? _formatTime(_chatRoom!.lastMessageAt!)
                        : 'Online',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: CAppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: CAppTheme.primaryColor))
          : _errorMessage != null
              ? _buildErrorState()
              : _buildChatBody(currentUser),
    );
  }

  Widget _buildChatBody(currentUser) {
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isMe = message.senderId == currentUser?.id;
                    final showAvatar = index == 0 ||
                        _messages[index - 1].senderId != message.senderId;

                    return _MessageBubble(
                      message: message,
                      isMe: isMe,
                      showAvatar: showAvatar,
                    );
                  },
                ),
        ),
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: GoogleFonts.poppins(color: CAppTheme.textTertiary, fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(CAppTheme.radiusRound),
                    borderSide: const BorderSide(color: CAppTheme.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(CAppTheme.radiusRound),
                    borderSide: const BorderSide(color: CAppTheme.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(CAppTheme.radiusRound),
                    borderSide: const BorderSide(color: CAppTheme.primaryColor, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: CAppTheme.backgroundColor,
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: const BoxDecoration(
                gradient: CAppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: CAppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 40,
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
            'Start the conversation!',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: CAppTheme.textSecondary,
            ),
          ),
        ],
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
              onPressed: _loadChatRoom,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

/// Message Bubble Widget
class _MessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isMe;
  final bool showAvatar;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showAvatar)
            CircleAvatar(
              radius: 16,
              backgroundColor: CAppTheme.primaryColor.withValues(alpha: 0.1),
              backgroundImage: message.senderProfileImage != null
                  ? NetworkImage(message.senderProfileImage!)
                  : null,
              child: message.senderProfileImage == null
                  ? Text(
                      safeInitial(message.senderName),
                      style: GoogleFonts.poppins(
                        color: CAppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    )
                  : null,
            ),
          if (!isMe && showAvatar) const SizedBox(width: 8),
          if (!isMe && !showAvatar) const SizedBox(width: 40),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe
                    ? CAppTheme.primaryColor
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isMe
                        ? CAppTheme.primaryColor.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe && showAvatar)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.senderName,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: CAppTheme.primaryColor,
                        ),
                      ),
                    ),
                  Text(
                    message.message,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isMe ? Colors.white : CAppTheme.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.createdAt),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.7)
                              : CAppTheme.textTertiary,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isRead ? Icons.done_all : Icons.done,
                          size: 14,
                          color: message.isRead
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe && showAvatar) const SizedBox(width: 8),
          if (isMe && showAvatar)
            CircleAvatar(
              radius: 16,
              backgroundColor: CAppTheme.primaryColor.withValues(alpha: 0.1),
              backgroundImage: message.senderProfileImage != null
                  ? NetworkImage(message.senderProfileImage!)
                  : null,
              child: message.senderProfileImage == null
                  ? Text(
                      safeInitial(message.senderName),
                      style: GoogleFonts.poppins(
                        color: CAppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    )
                  : null,
            ),
          if (isMe && !showAvatar) const SizedBox(width: 40),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');

    if (now.difference(dateTime).inDays == 0) {
      return '${hour > 12 ? hour - 12 : hour}:$minute ${hour >= 12 ? 'PM' : 'AM'}';
    } else {
      return '${dateTime.day}/${dateTime.month} ${hour > 12 ? hour - 12 : hour}:$minute ${hour >= 12 ? 'PM' : 'AM'}';
    }
  }
}
