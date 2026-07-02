import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/controllers/workspace_controller.dart';
import 'package:cwc/models/notification_model.dart';
import 'package:cwc/models/workspace_model.dart';
import 'package:cwc/services/notification_service.dart';
import 'package:cwc/utils/notification_scope.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/views/screens/owner/add_workspace_screen.dart';
import 'package:cwc/views/screens/owner/owner_analytics_screen.dart';
import 'package:cwc/views/screens/owner/workspace_management_screen.dart';
import 'package:cwc/views/screens/owner/owner_bookings_screen.dart';
import 'package:cwc/views/screens/profile/profile_screen.dart';
import 'package:cwc/views/screens/role_selection_screen.dart';
import 'package:cwc/views/screens/sos/sos_screen.dart';
import 'package:cwc/views/screens/chat/chat_list_screen.dart';
import 'package:cwc/views/screens/notifications/notifications_screen.dart';
import 'package:cwc/views/screens/owner/qr_scanner_screen.dart';

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  int _selectedIndex = 0;
  StreamSubscription<List<WorkspaceModel>>? _workspaceStreamSub;
  StreamSubscription<List<NotificationModel>>? _notificationStreamSub;
  final NotificationService _notificationService = NotificationService();
  final ValueNotifier<int> _notificationsRefresh = ValueNotifier(0);
  AuthController? _auth;
  int _unreadNotifications = 0;

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
            ),
            title: Text(
              'Logout',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: CAppTheme.textPrimary,
              ),
            ),
            content: Text(
              'Do you want to logout from your owner account?',
              style: GoogleFonts.poppins(color: CAppTheme.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(color: CAppTheme.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CAppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                  ),
                ),
                child: Text(
                  'Logout',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldLogout) {
      await context.read<AuthController>().signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const RoleSelectionScreen(),
        ),
        (route) => false,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthController>();
    _auth!.addListener(_onAuthChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
      _setupWorkspaceStream();
      _loadNotificationCount();
      _setupNotificationStream();
    });
  }

  void _onAuthChanged() {
    if (_auth?.currentUser == null) return;
    _refreshData();
    if (_notificationStreamSub == null) {
      _loadNotificationCount();
      _setupNotificationStream();
    }
    if (_workspaceStreamSub == null) {
      _setupWorkspaceStream();
    }
  }

  void _updateUnreadBadge(List<NotificationModel> notifications) {
    final count = NotificationScopeHelper.unreadCount(
      notifications,
      NotificationScope.workspaces,
    );
    if (count == _unreadNotifications || !mounted) return;
    setState(() => _unreadNotifications = count);
  }

  Future<void> _loadNotificationCount() async {
    final user = _auth?.currentUser;
    if (user == null) return;
    try {
      final count = NotificationScopeHelper.unreadCount(
        await _notificationService.getUserNotifications(user.id),
        NotificationScope.workspaces,
      );
      if (mounted && count != _unreadNotifications) {
        setState(() => _unreadNotifications = count);
      }
    } catch (_) {}
  }

  void _setupNotificationStream() {
    final user = _auth?.currentUser;
    if (user == null) return;
    _notificationStreamSub?.cancel();
    _notificationStreamSub =
        _notificationService.getNotificationsStream(user.id).listen(
      (notifications) => _updateUnreadBadge(notifications),
      onError: (_) {},
      cancelOnError: false,
    );
  }

  void _setupWorkspaceStream() {
    final ownerId = _auth?.currentUser?.id;
    if (ownerId == null) return;
    final wsController =
        Provider.of<WorkspaceController>(context, listen: false);
    _workspaceStreamSub?.cancel();
    _workspaceStreamSub =
        wsController.getOwnerWorkspacesStream(ownerId).listen(
      (workspaces) {
        if (mounted) {
          wsController.applyOwnerWorkspacesFromStream(workspaces);
        }
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }

  void _refreshData() {
    final authController = Provider.of<AuthController>(context, listen: false);
    if (authController.currentUser != null) {
      Provider.of<WorkspaceController>(context, listen: false)
          .loadOwnerWorkspaces(authController.currentUser!.id);
    }
  }

  @override
  void dispose() {
    _auth?.removeListener(_onAuthChanged);
    _workspaceStreamSub?.cancel();
    _notificationStreamSub?.cancel();
    _notificationsRefresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _handleLogout();
        }
      },
      child: Scaffold(
        backgroundColor: CAppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'Owner Dashboard',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              color: CAppTheme.textPrimary,
              fontSize: 20,
            ),
          ),
          actions: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CAppTheme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: CAppTheme.primaryColor,
                  size: 18,
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const QrScannerScreen(),
                  ),
                );
              },
              tooltip: 'Scan Booking QR',
            ),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFDC2626),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emergency,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SosScreen(),
                  ),
                );
              },
              tooltip: 'Emergency SOS',
            ),
            IconButton(
              icon: Builder(
                builder: (context) {
                  final user = context.watch<AuthController>().currentUser;
                  final hasImage = user?.profileImageUrl != null && user!.profileImageUrl!.isNotEmpty;
                  return Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: CAppTheme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: hasImage
                        ? ClipOval(
                            child: Image.network(
                              user!.profileImageUrl!,
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.person_outline_rounded,
                                color: CAppTheme.primaryColor,
                                size: 20,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.person_outline_rounded,
                            color: CAppTheme.primaryColor,
                            size: 20,
                          ),
                  );
                },
              ),
              tooltip: 'Profile',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProfileScreen(),
                  ),
                );
              },
            ),
            IconButton(
              icon: Icon(
                Icons.logout_rounded,
                color: CAppTheme.textSecondary,
              ),
              onPressed: _handleLogout,
            ),
          ],
        ),
        body: IndexedStack(
          index: _selectedIndex.clamp(0, 4),
          children: [
            const _WorkspacesTab(),
            OwnerBookingsScreen(showFab: _selectedIndex == 1),
            const _AnalyticsTab(),
            const ChatListScreen(),
            NotificationsScreen(
              scope: NotificationScope.workspaces,
              showBackButton: false,
              refreshListenable: _notificationsRefresh,
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex.clamp(0, 4),
            onTap: (index) {
              if (index >= 0 && index < 5) {
                final switchingToNotifications =
                    index == 4 && _selectedIndex != 4;
                setState(() {
                  _selectedIndex = index;
                });
                if (switchingToNotifications) {
                  _notificationsRefresh.value++;
                }
              }
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            elevation: 0,
            selectedItemColor: CAppTheme.primaryColor,
            unselectedItemColor: CAppTheme.textTertiary,
            selectedLabelStyle: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.normal,
            ),
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.workspaces_outlined),
                activeIcon: Icon(Icons.workspaces),
                label: 'Workspaces',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.book_outlined),
                activeIcon: Icon(Icons.book),
                label: 'Bookings',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.analytics_outlined),
                activeIcon: Icon(Icons.analytics),
                label: 'Analytics',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.chat_bubble_outline),
                activeIcon: Icon(Icons.chat_bubble),
                label: 'Messages',
              ),
              BottomNavigationBarItem(
                icon: _NavBadgeIcon(
                  icon: Icons.notifications_outlined,
                  badgeCount: _unreadNotifications,
                ),
                activeIcon: _NavBadgeIcon(
                  icon: Icons.notifications,
                  badgeCount: _unreadNotifications,
                ),
                label: 'Notifications',
              ),
            ],
          ),
        ),
        floatingActionButton: _selectedIndex == 0
            ? FloatingActionButton.extended(
                heroTag: 'owner_home_add_workspace_fab',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddWorkspaceScreen(),
                    ),
                  );
                },
                backgroundColor: CAppTheme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                ),
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  'Add Workspace',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              )
            : null,
      ),
    );
  }
}

/// Workspaces Tab
class _WorkspacesTab extends StatelessWidget {
  const _WorkspacesTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkspaceController>(
      builder: (context, controller, child) {
        if (controller.isLoading) {
          return Center(
            child: CircularProgressIndicator(
              color: CAppTheme.primaryColor,
            ),
          );
        }

        final authController = Provider.of<AuthController>(context, listen: false);
        final ownerId = authController.currentUser?.id;

        if (ownerId == null) {
          return Center(
            child: Text(
              'User not found',
              style: GoogleFonts.poppins(color: CAppTheme.textSecondary),
            ),
          );
        }

        final ownerWorkspaces = controller.ownerWorkspaces;

        if (ownerWorkspaces.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CAppTheme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.workspaces_outlined,
                      size: 40,
                      color: CAppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No workspaces yet',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: CAppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap the + button to add your first workspace',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: CAppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          color: CAppTheme.primaryColor,
          onRefresh: () async {
            final authController = Provider.of<AuthController>(context, listen: false);
            if (authController.currentUser != null) {
              await controller.loadOwnerWorkspaces(authController.currentUser!.id);
            }
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: ownerWorkspaces.length,
            itemBuilder: (context, index) {
              final workspace = ownerWorkspaces[index];
              return _OwnerWorkspaceCard(workspace: workspace);
            },
          ),
        );
      },
    );
  }
}

/// Owner Workspace Card
class _OwnerWorkspaceCard extends StatelessWidget {
  final WorkspaceModel workspace;

  const _OwnerWorkspaceCard({required this.workspace});

  static String _workspaceStatusLabel(WorkspaceModel ws) {
    if (ws.workspaceApproved == null) return 'Pending Review';
    if (ws.workspaceApproved == false) return 'Rejected';
    return ws.isAvailable ? 'Listed' : 'Unavailable';
  }

  static Color _workspaceStatusColor(WorkspaceModel ws) {
    if (ws.workspaceApproved == null) return CAppTheme.warningColor;
    if (ws.workspaceApproved == false) return CAppTheme.errorColor;
    return ws.isAvailable ? CAppTheme.successColor : CAppTheme.errorColor;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        boxShadow: CAppTheme.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WorkspaceManagementScreen(
                  workspaceId: workspace.id,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(CAppTheme.radiusLarge),
                ),
                child: Container(
                  height: 200,
                  width: double.infinity,
                  color: CAppTheme.borderColor,
                  child: workspace.imageUrls.isNotEmpty
                      ? RepaintBoundary(
                          child: Image.network(
                            workspace.imageUrls.first,
                            fit: BoxFit.cover,
                            cacheWidth: 800,
                            cacheHeight: 600,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Icon(
                                  Icons.workspaces_outlined,
                                  size: 48,
                                  color: CAppTheme.textTertiary,
                                ),
                              );
                            },
                          ),
                        )
                      : Center(
                          child: Icon(
                            Icons.workspaces_outlined,
                            size: 48,
                            color: CAppTheme.textTertiary,
                          ),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            workspace.name,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: CAppTheme.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _workspaceStatusColor(workspace)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(CAppTheme.radiusRound),
                          ),
                          child: Text(
                            _workspaceStatusLabel(workspace),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: _workspaceStatusColor(workspace),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: CAppTheme.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${workspace.address}, ${workspace.city}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: CAppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Rs. ${workspace.pricePerDay.toStringAsFixed(0)}/day',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: CAppTheme.primaryColor,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WorkspaceManagementScreen(
                                  workspaceId: workspace.id,
                                ),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: CAppTheme.primaryColor,
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: Text(
                            'Manage',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
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
    );
  }
}

/// Analytics Tab
class _AnalyticsTab extends StatelessWidget {
  const _AnalyticsTab();

  @override
  Widget build(BuildContext context) {
    return const OwnerAnalyticsScreen();
  }
}

class _NavBadgeIcon extends StatelessWidget {
  final IconData icon;
  final int badgeCount;

  const _NavBadgeIcon({
    required this.icon,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (badgeCount > 0)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: CAppTheme.errorColor,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                badgeCount > 9 ? '9+' : '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
