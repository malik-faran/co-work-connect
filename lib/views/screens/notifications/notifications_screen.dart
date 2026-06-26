import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/models/collaboration_hub_models.dart';
import 'package:cwc/models/notification_model.dart';
import 'package:cwc/services/collaboration_hub_service.dart';
import 'package:cwc/services/notification_service.dart';
import 'package:cwc/utils/notification_scope.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/services/navigation_service.dart';
import 'package:cwc/views/screens/user/booking_history_screen.dart';
import 'package:cwc/views/screens/collaboration/collaboration_detail_screen.dart';
import 'package:intl/intl.dart';

enum InviteCardState {
  actionable,
  expired,
  accepted,
  declined,
  unavailable,
}

/// Notifications Screen — filtered by [scope] (projects vs workspaces).
class NotificationsScreen extends StatefulWidget {
  final NotificationScope scope;

  const NotificationsScreen({
    super.key,
    this.scope = NotificationScope.all,
  });

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
  final Map<String, InviteCardState> _inviteStates = {};
  StreamSubscription<List<NotificationModel>>? _notificationStreamSubscription;

  List<NotificationModel> get _visibleNotifications =>
      NotificationScopeHelper.filter(_notifications, widget.scope);

  int get _visibleUnreadCount =>
      _visibleNotifications.where((n) => !n.isRead).length;

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

      setState(() {
        _notifications = notifications;
        _unreadCount = NotificationScopeHelper.unreadCount(
          notifications,
          widget.scope,
        );
        _isLoading = false;
      });
      if (widget.scope == NotificationScope.projects ||
          widget.scope == NotificationScope.all) {
        await _refreshInviteStates(_visibleNotifications, currentUser.id);
      }
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
      (notifications) async {
        if (mounted) {
          setState(() {
            _notifications = notifications;
            _unreadCount = NotificationScopeHelper.unreadCount(
              notifications,
              widget.scope,
            );
          });
          if (widget.scope == NotificationScope.projects ||
              widget.scope == NotificationScope.all) {
            await _refreshInviteStates(_visibleNotifications, currentUser.id);
          }
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

  Future<void> _refreshInviteStates(
    List<NotificationModel> notifications,
    String userId,
  ) async {
    final inviteNotifications =
        notifications.where((n) => n.type == 'collaboration_invite').toList();
    if (inviteNotifications.isEmpty) {
      if (mounted) setState(() => _inviteStates.clear());
      return;
    }

    try {
      final invites = await _hub.getAllUserInvites(userId);
      final byId = {for (final invite in invites) invite.id: invite};
      final byCollab = <String, CollaborationInvite>{};
      for (final invite in invites) {
        byCollab.putIfAbsent(invite.collaborationId, () => invite);
      }

      final collabIds = inviteNotifications
          .map((n) => n.metadata?['collaboration_id'] as String?)
          .whereType<String>()
          .toSet();
      final projectStatuses = await _hub.getCollaborationStatuses(collabIds);

      final states = <String, InviteCardState>{};
      for (final notification in inviteNotifications) {
        final inviteId = notification.metadata?['invite_id'] as String?;
        final collaborationId =
            notification.metadata?['collaboration_id'] as String?;

        CollaborationInvite? invite;
        if (inviteId != null) invite = byId[inviteId];
        if (invite == null && collaborationId != null) {
          invite = byCollab[collaborationId];
        }

        states[notification.id] = _inviteStateFor(
          invite: invite,
          notification: notification,
          projectStatus: collaborationId != null
              ? projectStatuses[collaborationId]
              : null,
        );
      }

      if (mounted) setState(() => _inviteStates..clear()..addAll(states));
    } catch (_) {}
  }

  InviteCardState _inviteStateFor({
    required CollaborationInvite? invite,
    required NotificationModel notification,
    String? projectStatus,
  }) {
    if (invite == null) return InviteCardState.unavailable;
    if (invite.status == 'accepted') return InviteCardState.accepted;
    if (invite.status == 'declined') return InviteCardState.declined;
    if (_hub.isInviteExpired(
      invite,
      projectStatus: projectStatus,
    )) {
      return InviteCardState.expired;
    }
    if (invite.status == 'pending') return InviteCardState.actionable;
    return InviteCardState.unavailable;
  }

  String _inviteStateMessage(InviteCardState state) {
    switch (state) {
      case InviteCardState.expired:
        return 'This invitation has expired';
      case InviteCardState.accepted:
        return 'You already accepted this invitation';
      case InviteCardState.declined:
        return 'You declined this invitation';
      case InviteCardState.unavailable:
        return 'This invitation is no longer available';
      case InviteCardState.actionable:
        return '';
    }
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

      for (final notification in _visibleNotifications.where((n) => !n.isRead)) {
        await _notificationService.markAsRead(notification.id);
      }
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
    if (!mounted) return;

    if (NotificationScopeHelper.isProjectType(notification.type)) {
      final collaborationId =
          notification.metadata?['collaboration_id'] as String?;
      if (collaborationId == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CollaborationDetailScreen(collaborationId: collaborationId),
        ),
      );
      return;
    }

    if (NotificationScopeHelper.isWorkspaceType(notification.type)) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BookingHistoryScreen()),
      );
      return;
    }

    if (notification.type == 'chat_message') {
      final chatRoomId = notification.metadata?['chat_room_id'] as String?;
      if (chatRoomId != null) {
        NavigationService.openChatFromNotification(chatRoomId);
      }
    }
  }

  Future<void> _respondToInvite(NotificationModel notification, bool accept) async {
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;

    final cachedState = _inviteStates[notification.id];
    if (cachedState != null && cachedState != InviteCardState.actionable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_inviteStateMessage(cachedState)),
          backgroundColor: CAppTheme.warningColor,
        ),
      );
      return;
    }

    final inviteId = notification.metadata?['invite_id'] as String?;
    final collaborationId = notification.metadata?['collaboration_id'] as String?;
    if (inviteId == null && collaborationId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid invitation — please open the project from Collaborate'),
          backgroundColor: CAppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _respondingInviteIds.add(notification.id));
    try {
      CollaborationInvite? invite;
      if (inviteId != null) {
        invite = await _hub.getInviteById(inviteId);
      }
      invite ??= collaborationId != null
          ? await _hub.getInviteForUserOnProject(collaborationId, user.id)
          : null;

      if (invite == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This invitation is no longer available'),
            backgroundColor: CAppTheme.warningColor,
          ),
        );
        await _markAsRead(notification);
        await _refreshInviteStates(_notifications, user.id);
        return;
      }

      final projectStatuses =
          await _hub.getCollaborationStatuses({invite.collaborationId});
      final projectStatus = projectStatuses[invite.collaborationId];

      if (invite.status != 'pending' ||
          _hub.isInviteExpired(invite, projectStatus: projectStatus)) {
        if (!mounted) return;
        final state = _inviteStateFor(
          invite: invite,
          notification: notification,
          projectStatus: projectStatus,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_inviteStateMessage(state)),
            backgroundColor: CAppTheme.warningColor,
          ),
        );
        await _markAsRead(notification);
        await _refreshInviteStates(_notifications, user.id);
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

      await _loadNotifications();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: CAppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _respondingInviteIds.remove(notification.id));
    }
  }

  Map<String, List<NotificationModel>> _groupByDate() {
    final grouped = <String, List<NotificationModel>>{};
    for (final n in _visibleNotifications) {
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
          NotificationScopeHelper.titleFor(widget.scope),
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
          if (_visibleUnreadCount > 0)
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
              : _visibleNotifications.isEmpty
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
                    inviteState: notification.type == 'collaboration_invite'
                        ? _inviteStates[notification.id]
                        : null,
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
              NotificationScopeHelper.emptyMessageFor(widget.scope),
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: CAppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.scope == NotificationScope.projects
                  ? 'Invites and project updates will appear here'
                  : widget.scope == NotificationScope.workspaces
                      ? 'Bookings and payment updates will appear here'
                      : 'You\'re all caught up!',
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
  final InviteCardState? inviteState;
  final VoidCallback onTap;
  final VoidCallback? onAcceptInvite;
  final VoidCallback? onDeclineInvite;
  final bool isResponding;

  const _NotificationCard({
    required this.notification,
    this.inviteState,
    required this.onTap,
    this.onAcceptInvite,
    this.onDeclineInvite,
    this.isResponding = false,
  });

  bool get _isInvite => notification.type == 'collaboration_invite';
  bool get _canRespondToInvite =>
      _isInvite && inviteState == InviteCardState.actionable;

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
                if (_canRespondToInvite) ...[
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
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _inviteStatusColor(inviteState).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                      border: Border.all(
                        color: _inviteStatusColor(inviteState).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _inviteStatusIcon(inviteState),
                          size: 18,
                          color: _inviteStatusColor(inviteState),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _inviteStatusLabel(inviteState),
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _inviteStatusColor(inviteState),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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

  String _inviteStatusLabel(InviteCardState? state) {
    switch (state) {
      case InviteCardState.expired:
        return 'Invitation expired';
      case InviteCardState.accepted:
        return 'Invitation accepted';
      case InviteCardState.declined:
        return 'Invitation declined';
      case InviteCardState.unavailable:
        return 'Invitation no longer available';
      case InviteCardState.actionable:
      case null:
        return 'Checking invitation...';
    }
  }

  Color _inviteStatusColor(InviteCardState? state) {
    switch (state) {
      case InviteCardState.expired:
      case InviteCardState.unavailable:
        return CAppTheme.warningColor;
      case InviteCardState.accepted:
        return CAppTheme.successColor;
      case InviteCardState.declined:
        return CAppTheme.errorColor;
      case InviteCardState.actionable:
      case null:
        return CAppTheme.textSecondary;
    }
  }

  IconData _inviteStatusIcon(InviteCardState? state) {
    switch (state) {
      case InviteCardState.expired:
      case InviteCardState.unavailable:
        return Icons.schedule_rounded;
      case InviteCardState.accepted:
        return Icons.check_circle_outline_rounded;
      case InviteCardState.declined:
        return Icons.cancel_outlined;
      case InviteCardState.actionable:
      case null:
        return Icons.hourglass_empty_rounded;
    }
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
