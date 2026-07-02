import 'dart:async';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/models/chat_model.dart';
import 'package:cwc/services/active_chat_tracker.dart';
import 'package:cwc/services/chat_service.dart';
import 'package:cwc/services/local_notification_service.dart';
import 'package:cwc/services/notification_service.dart';
import 'package:cwc/services/storage_service.dart';
import 'package:cwc/utils/helpers/model_helpers.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/utils/constants/validation_constants.dart';
import 'package:cwc/utils/validators/form_validators.dart';
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
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _uuid = const Uuid();

  ChatRoomModel? _chatRoom;
  List<ChatMessageModel> _messages = [];
  bool _isLoading = true;
  bool _isUploadingImage = false;
  bool _isDraggingImage = false;
  String? _errorMessage;
  String? _otherUserName;
  String? _otherUserProfileImage;
  String? _otherUserRole;
  StreamSubscription<List<ChatMessageModel>>? _messageStreamSubscription;

  @override
  void initState() {
    super.initState();
    ActiveChatTracker.setActive(widget.chatRoomId);
    WidgetsBinding.instance.addObserver(this);
    _loadChatRoom();
    _setupMessageStream();
  }

  @override
  void dispose() {
    if (ActiveChatTracker.isActive(widget.chatRoomId)) {
      ActiveChatTracker.setActive(null);
    }
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

  Future<void> _clearChatAlerts() async {
    final currentUser = context.read<AuthController>().currentUser;
    if (currentUser == null) return;
    await _chatService.markMessagesAsRead(widget.chatRoomId, currentUser.id);
    await NotificationService().markChatNotificationsAsReadForRoom(
      currentUser.id,
      widget.chatRoomId,
    );
    await LocalNotificationService.instance
        .cancelChatNotification(widget.chatRoomId);
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
          await _clearChatAlerts();
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

      await _clearChatAlerts();
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

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (picked != null) {
        await _sendImageFromXFile(picked);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not pick image'),
          backgroundColor: CAppTheme.errorColor,
        ),
      );
    }
  }

  void _showImageSourceSheet() {
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
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text('Gallery', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSendImage(ImageSource.gallery);
              },
            ),
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: Text('Camera', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSendImage(ImageSource.camera);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _sendImageFromXFile(XFile file) async {
    if (_isUploadingImage || _chatRoom == null) return;

    final fileName = file.name.isNotEmpty ? file.name : 'image.jpg';
    if (!StorageService.isAllowedChatImage(fileName)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only JPG, PNG, GIF or WEBP images are allowed'),
          backgroundColor: CAppTheme.errorColor,
        ),
      );
      return;
    }

    final authController = context.read<AuthController>();
    final currentUser = authController.currentUser;
    if (currentUser == null) return;

    setState(() => _isUploadingImage = true);

    ChatMessageModel? pendingMessage;
    try {
      final bytes = await file.readAsBytes();
      final imageUrl = await _storageService.uploadChatImage(
        chatRoomId: widget.chatRoomId,
        bytes: bytes,
        fileName: fileName,
      );

      pendingMessage = ChatMessageModel(
        id: _uuid.v4(),
        chatRoomId: widget.chatRoomId,
        senderId: currentUser.id,
        senderName: currentUser.name,
        senderProfileImage: currentUser.profileImageUrl,
        message: '📷 Photo',
        messageType: 'image',
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
      );

      if (!mounted) return;
      setState(() {
        _messages = [..._messages, pendingMessage!];
        _isUploadingImage = false;
      });
      _scrollToBottom();

      await _chatService.sendMessage(pendingMessage!);
      await _chatService.markMessagesAsRead(widget.chatRoomId, currentUser.id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (pendingMessage != null) {
          _messages.removeWhere((m) => m.id == pendingMessage!.id);
        }
        _isUploadingImage = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: CAppTheme.errorColor,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _onImageDropped(DropDoneDetails details) {
    setState(() => _isDraggingImage = false);
    for (final file in details.files) {
      _sendImageFromXFile(file);
      break;
    }
  }

  void _showFullImage(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final validationError = FormValidators.chatMessage(text);
    if (validationError != null) {
      if (text.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(validationError),
            backgroundColor: CAppTheme.errorColor,
          ),
        );
      }
      return;
    }

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

  void _showMessageOptions(ChatMessageModel message) {
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
                'Delete Message',
                style: GoogleFonts.poppins(
                  color: CAppTheme.errorColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                final confirm = await _confirmDeleteMessage();
                if (confirm) await _deleteMessage(message);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDeleteMessage() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CAppTheme.radiusLarge)),
        title: Text('Delete Message', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'This message will be permanently removed. Are you sure?',
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

  Future<void> _deleteMessage(ChatMessageModel message) async {
    final removed = message;
    setState(() {
      _messages = _messages.where((m) => m.id != message.id).toList();
    });
    try {
      await _chatService.deleteMessage(message.id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, removed]
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete message', style: GoogleFonts.poppins()),
          backgroundColor: CAppTheme.errorColor,
        ),
      );
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
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: CAppTheme.primaryColor.withValues(alpha: 0.12),
          ),
        ),
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
      body: DropTarget(
        onDragEntered: (_) => setState(() => _isDraggingImage = true),
        onDragExited: (_) => setState(() => _isDraggingImage = false),
        onDragDone: _onImageDropped,
        child: Stack(
          children: [
            _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: CAppTheme.primaryColor),
                  )
                : _errorMessage != null
                    ? _buildErrorState()
                    : _buildChatBody(currentUser),
            if (_isDraggingImage) _buildDropOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBody(currentUser) {
    return Column(
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFEEF3FF),
                  CAppTheme.backgroundColor,
                ],
              ),
            ),
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: _buildMessageWidgets(currentUser),
                  ),
          ),
        ),
        _buildMessageInput(),
      ],
    );
  }

  List<Widget> _buildMessageWidgets(currentUser) {
    final widgets = <Widget>[];
    DateTime? lastDay;

    for (var index = 0; index < _messages.length; index++) {
      final message = _messages[index];
      final day = DateTime(
        message.createdAt.year,
        message.createdAt.month,
        message.createdAt.day,
      );
      if (lastDay == null || day != lastDay) {
        widgets.add(_DateSeparator(date: message.createdAt));
        lastDay = day;
      }

      final isMe = message.senderId == currentUser?.id;
      final showAvatar = index == 0 ||
          _messages[index - 1].senderId != message.senderId;

      widgets.add(
        _MessageBubble(
          message: message,
          isMe: isMe,
          showAvatar: showAvatar,
          onLongPress: isMe ? () => _showMessageOptions(message) : null,
          onImageTap: message.imageUrl != null
              ? () => _showFullImage(message.imageUrl!)
              : null,
        ),
      );
    }
    return widgets;
  }

  Widget _buildDropOverlay() {
    return Container(
      color: CAppTheme.primaryColor.withValues(alpha: 0.12),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
            border: Border.all(color: CAppTheme.primaryColor, width: 2),
            boxShadow: CAppTheme.softShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.file_download_outlined,
                size: 48,
                color: CAppTheme.primaryColor.withValues(alpha: 0.9),
              ),
              const SizedBox(height: 12),
              Text(
                'Drop image here',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: CAppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'JPG, PNG, GIF, WEBP — max 5 MB',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: CAppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
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
            IconButton(
              onPressed: _isUploadingImage ? null : _showImageSourceSheet,
              icon: _isUploadingImage
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.image_outlined, color: CAppTheme.primaryColor),
              tooltip: 'Send image',
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                maxLength: ValidationLimits.chatMessageMax,
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
                onPressed: _isUploadingImage ? null : _sendMessage,
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

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final String label;
    if (d == today) {
      label = 'Today';
    } else if (d == today.subtract(const Duration(days: 1))) {
      label = 'Yesterday';
    } else {
      label = '${date.day}/${date.month}/${date.year}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(CAppTheme.radiusRound),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: CAppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isMe;
  final bool showAvatar;
  final VoidCallback? onLongPress;
  final VoidCallback? onImageTap;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showAvatar,
    this.onLongPress,
    this.onImageTap,
  });

  bool get _isImageMessage =>
      message.messageType == 'image' && message.imageUrl != null;

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
            child: GestureDetector(
              onLongPress: onLongPress,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _isImageMessage ? 6 : 16,
                  vertical: _isImageMessage ? 6 : 12,
                ),
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
                    if (_isImageMessage)
                      GestureDetector(
                        onTap: onImageTap,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            message.imageUrl!,
                            width: 220,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return SizedBox(
                                width: 220,
                                height: 160,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: isMe
                                        ? Colors.white
                                        : CAppTheme.primaryColor,
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => Container(
                              width: 220,
                              height: 120,
                              color: CAppTheme.borderColor,
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: CAppTheme.textTertiary,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
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
