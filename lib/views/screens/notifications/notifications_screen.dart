import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/models/collaboration_hub_models.dart';
import 'package:cwc/models/notification_model.dart';
import 'package:cwc/services/collaboration_hub_service.dart';
import 'package:cwc/services/notification_service.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/views/screens/collaboration/collaboration_detail_screen.dart';
import 'package:intl/intl.dart';

/// Notifications Screen
/// Shows all notifications for the current user
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  final CollaborationHubService _hub = CollaborationHubService();
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _unreadCount = 0;
  final Set<String> _respondingInviteIds = {};
  StreamSubscription<List<NotificationModel>>? _notificationStreamSubscription;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _setupNotificationStream();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authController = context.read<AuthController>();
      final currentUser = authController.currentUser;
      if (currentUser == null) return;

      final notifications = await _notificationService.getUserNotifications(currentUser.id);
      final unreadCount = await _notificationService.getUnreadCount(currentUser.id);

      setState(() {
        _notifications = notifications;
        _unreadCount = unreadCount;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _setupNotificationStream() {
    final authController = context.read<AuthController>();
    final currentUser = authController.currentUser;
    if (currentUser == null) return;

    _notificationStreamSubscription?.cancel();

    _notificationStreamSubscription = _notificationService.getNotificationsStream(currentUser.id).listen(
      (notifications) {
        if (mounted) {
          setState(() {
            _notifications = notifications;
            _unreadCount = notifications.where((n) => !n.isRead).length;
          });
        }
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }

  @override
  void dispose() {
    _notificationStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.isRead) return;

    try {
      await _notificationService.markAsRead(notification.id);
      if (!mounted) return;
      _loadNotifications();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: CAppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final authController = context.read<AuthController>();
      final currentUser = authController.currentUser;
      if (currentUser == null) return;

      await _notificationService.markAllAsRead(currentUser.id);
      if (!mounted) return;
      _loadNotifications();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: CAppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _openNotification(NotificationModel notification) async {
    await _markAsRead(notification);
    final collaborationId = notification.metadata?['collaboration_id'] as String?;
    if (collaborationId == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CollaborationDetailScreen(collaborationId: collaborationId),
      ),
    );
  }

  Future<void> _respondToInvite(NotificationModel notification, bool accept) async {
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;

    final inviteId = notification.metadata?['invite_id'] as String?;
    final collaborationId = notification.metadata?['collaboration_id'] as String?;
    if (inviteId == null && collaborationId == null) return;

    setState(() => _respondingInviteIds.add(notification.id));
    try {
      CollaborationInvite? invite;
      if (inviteId != null) {
        invite = await _hub.getInviteById(inviteId);
      }
      invite ??= collaborationId != null
          ? await _hub.getPendingInviteForProject(collaborationId, user.id)
          : null;

      if (invite == null || invite.status != 'pending') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This invitation is no longer available'),
            backgroundColor: CAppTheme.warningColor,
          ),
        );
        await _markAsRead(notification);
        _loadNotifications();
        return;
      }

      if (accept) {
        await _hub.acceptInvite(
          invite: invite,
          userId: user.id,
          userName: user.name,
          userEmail: user.email,
          userImage: user.profileImageUrl,
          userSkills: user.skills ?? [],
        );
      } else {
        await _hub.respondToInvite(invite, false);
      }

      await _markAsRead(notification);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? 'Invitation accepted' : 'Invitation declined'),
          backgroundColor: accept ? CAppTheme.successColor : CAppTheme.textSecondary,
        ),
      );

      if (accept) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CollaborationDetailScreen(collaborationId: invite!.collaborationId),
          ),
        );
      }

      _loadNotifications();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: CAppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _respondingInviteIds.remove(notification.id));
    }
  }

  Map<String, List<NotificationModel>> _groupByDate() {
    final grouped = <String, List<NotificationModel>>{};
    for (final n in _notifications) {
      final now = DateTime.now();
      final diff = now.difference(n.createdAt);
      String key;
      if (diff.inDays == 0) {
        key = 'Today';
      } else if (diff.inDays == 1) {
        key = 'Yesterday';
      } else if (diff.inDays < 7) {
        key = 'This Week';
      } else {
        key = 'Earlier';
      }
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(n);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CAppTheme.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: CAppTheme.textPrimary,
          ),
        ),
        automaticallyImplyLeading: false,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: CAppTheme.textPrimary),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          if (_unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Mark all read'),
              style: TextButton.styleFrom(
                foregroundColor: CAppTheme.primaryColor,
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: CAppTheme.primaryColor))
          : _errorMessage != null
              ? _buildErrorState()
              : _notifications.isEmpty
                  ? _buildEmptyState()
                  : _buildNotificationsList(),
    );
  }

  Widget _buildNotificationsList() {
    final grouped = _groupByDate();
    final sortedKeys = ['Today', 'Yesterday', 'This Week', 'Earlier']
        .where((k) => grouped.containsKey(k))
        .toList();

    return RefreshIndicator(
      color: CAppTheme.primaryColor,
      onRefresh: _loadNotifications,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sortedKeys.length,
        itemBuilder: (context, sectionIndex) {
          final key = sortedKeys[sectionIndex];
          final items = grouped[key]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sectionIndex > 0) const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  key,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CAppTheme.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              ...items.map((notification) => _NotificationCard(
                    notification: notification,
                    isResponding: _respondingInviteIds.contains(notification.id),
                    onTap: () => _openNotification(notification),
                    onAcceptInvite: () => _respondToInvite(notification, true),
                    onDeclineInvite: () => _respondToInvite(notification, false),
                  )),
            ],
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
                Icons.notifications_none_rounded,
                size: 44,
                color: CAppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No notifications',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: CAppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'re all caught up!',
              style: GoogleFonts.poppins(
                color: CAppTheme.textSecondary,
                fontSize: 14,
              ),
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
              onPressed: _loadNotifications,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Notification Card Widget
class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback? onAcceptInvite;
  final VoidCallback? onDeclineInvite;
  final bool isResponding;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
    this.onAcceptInvite,
    this.onDeclineInvite,
    this.isResponding = false,
  });

  bool get _isInvite => notification.type == 'collaboration_invite';

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    final icon = _getIconForType(notification.type);
    final color = _getColorForType(notification.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isUnread
            ? color.withValues(alpha: 0.04)
            : Colors.white,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        boxShadow: CAppTheme.softShadow,
        border: isUnread
            ? Border.all(color: color.withValues(alpha: 0.2), width: 1)
            : null,
      ),
      child: InkWell(
        onTap: _isInvite ? null : onTap,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: GoogleFonts.poppins(
                                  fontWeight: isUnread
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  fontSize: 14,
                                  color: CAppTheme.textPrimary,
                                ),
                              ),
                            ),
                            if (isUnread)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.message,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: CAppTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatTime(notification.createdAt),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: CAppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_isInvite) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CAppTheme.successColor,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: isResponding ? null : onAcceptInvite,
                        child: isResponding
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Accept'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          foregroundColor: CAppTheme.errorColor,
                          side: const BorderSide(color: CAppTheme.errorColor),
                        ),
                        onPressed: isResponding ? null : onDeclineInvite,
                        child: const Text('Decline'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onTap,
                    child: const Text('View project'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'registration_approved':
        return Icons.check_circle_rounded;
      case 'registration_rejected':
        return Icons.cancel_rounded;
      case 'collaboration_response':
      case 'collaboration_accepted':
      case 'collaboration_application':
      case 'collaboration_shortlisted':
      case 'collaboration_launched':
      case 'collaboration_completed':
        return Icons.people_rounded;
      case 'collaboration_invite':
        return Icons.mail_rounded;
      case 'chat_message':
        return Icons.chat_bubble_rounded;
      case 'booking_confirmed':
        return Icons.event_available_rounded;
      case 'booking_cancelled':
        return Icons.event_busy_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'registration_approved':
        return CAppTheme.successColor;
      case 'registration_rejected':
        return CAppTheme.errorColor;
      case 'collaboration_response':
      case 'collaboration_accepted':
      case 'collaboration_application':
      case 'collaboration_shortlisted':
      case 'collaboration_launched':
      case 'collaboration_completed':
        return CAppTheme.primaryColor;
      case 'collaboration_invite':
        return CAppTheme.infoColor;
      case 'collaboration_rejected':
        return CAppTheme.errorColor;
      case 'chat_message':
        return CAppTheme.infoColor;
      case 'booking_confirmed':
        return CAppTheme.successColor;
      case 'booking_cancelled':
        return CAppTheme.errorColor;
      default:
        return CAppTheme.primaryColor;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('MMM dd, yyyy').format(dateTime);
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
