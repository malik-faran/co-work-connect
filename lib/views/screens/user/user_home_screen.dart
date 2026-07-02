import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/controllers/workspace_controller.dart';
import 'package:cwc/models/workspace_model.dart';
import 'package:cwc/utils/constants/app_constants.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/views/screens/profile/profile_screen.dart';
import 'package:cwc/views/screens/profile/collaboration_profile_screen.dart';
import 'package:cwc/views/screens/profile/portfolio_editor_screen.dart';
import 'package:cwc/views/screens/role_selection_screen.dart';
import 'package:cwc/views/screens/user/workspace_detail_screen.dart';
import 'package:cwc/views/screens/user/booking_history_screen.dart';
import 'package:cwc/views/screens/collaboration/collaboration_list_screen.dart';
import 'package:cwc/views/screens/notifications/notifications_screen.dart';
import 'package:cwc/views/screens/payment/wallet_screen.dart';
import 'package:cwc/views/screens/payment/payment_history_screen.dart';
import 'package:cwc/views/screens/report/report_screen.dart';
import 'package:cwc/views/screens/report/my_reports_screen.dart';
import 'package:cwc/views/screens/sos/sos_screen.dart';
import 'package:cwc/views/screens/chat/chat_list_screen.dart';
import 'package:cwc/services/notification_service.dart';
import 'package:cwc/services/chat_service.dart';
import 'package:cwc/services/recommendation_service.dart';
import 'package:cwc/services/workspace_service.dart';
import 'package:cwc/services/location_service.dart';
import 'package:cwc/models/workspace_recommendation.dart';
import 'package:cwc/utils/helpers/geo_utils.dart';
import 'package:cwc/models/chat_model.dart';
import 'package:cwc/models/notification_model.dart';
import 'package:cwc/utils/notification_scope.dart';
import 'package:cwc/views/widgets/workspaces_map_view.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  /// Lets any deeper screen request a bottom-nav tab switch.
  /// 0 = Projects, 1 = Spaces, 2 = Messages, 3 = Profile.
  static final ValueNotifier<int> tabRequest = ValueNotifier<int>(0);

  /// Pop back to the home shell and switch to [index].
  static void goToTab(BuildContext context, int index) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    tabRequest.value = index;
  }

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final NotificationService _notificationService = NotificationService();
  final ChatService _chatService = ChatService();
  Timer? _refreshTimer;
  int _selectedTab = 0;
  int _unreadWorkspaceNotifications = 0;
  int _unreadMessageCount = 0;
  StreamSubscription<List<NotificationModel>>? _notifSub;
  StreamSubscription<List<ChatRoomModel>>? _chatSub;

  @override
  void initState() {
    super.initState();
    UserHomeScreen.tabRequest.addListener(_onTabRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotificationCount();
      _loadUnreadMessageCount();
      _setupNotificationStream();
      _setupChatUnreadStream();
      context.read<WorkspaceController>().loadWorkspaces();
    });
  }

  void _onTabRequest() {
    if (mounted) setState(() => _selectedTab = UserHomeScreen.tabRequest.value);
  }

  Future<void> _loadUnreadMessageCount() async {
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;
    try {
      final count = await _chatService.getTotalUnreadCount(user.id);
      if (mounted) setState(() => _unreadMessageCount = count);
    } catch (_) {}
  }

  void _setupChatUnreadStream() {
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;
    _chatSub?.cancel();
    _chatSub = _chatService.getChatRoomsStream(user.id).listen(
      (_) => _loadUnreadMessageCount(),
      onError: (_) {},
      cancelOnError: false,
    );
  }

  Future<void> _loadNotificationCount() async {
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;
    try {
      final count = NotificationScopeHelper.unreadCount(
        await _notificationService.getUserNotifications(user.id),
        NotificationScope.workspaces,
      );
      if (mounted) setState(() => _unreadWorkspaceNotifications = count);
    } catch (_) {}
  }

  void _setupNotificationStream() {
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;
    _notifSub?.cancel();
    _notifSub = _notificationService
        .getNotificationsStream(user.id)
        .listen(
          (notifs) {
            if (mounted) {
              setState(
                () => _unreadWorkspaceNotifications =
                    NotificationScopeHelper.unreadCount(
                  notifs,
                  NotificationScope.workspaces,
                ),
              );
            }
          },
          onError: (_) {},
          cancelOnError: false,
        );
  }

  @override
  void dispose() {
    UserHomeScreen.tabRequest.removeListener(_onTabRequest);
    _notifSub?.cancel();
    _chatSub?.cancel();
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    final shouldLogout =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CAppTheme.radiusXL),
            ),
            title: const Text('Logout'),
            content: const Text('Do you want to logout from your CWL account?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Logout'),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldLogout) {
      await context.read<AuthController>().signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleLogout();
      },
      child: Scaffold(
        backgroundColor: CAppTheme.backgroundColor,
        body: IndexedStack(
          index: _selectedTab,
          children: [
            const CollaborationListScreen(),
            _HomeTab(
              searchController: _searchController,
              unreadCount: _unreadWorkspaceNotifications,
              onNotificationTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(
                      scope: NotificationScope.workspaces,
                    ),
                  ),
                ).then((_) => _loadNotificationCount());
              },
            ),
            const ChatListScreen(),
            _ProfileTab(onLogout: _handleLogout),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                    icon: Icons.rocket_launch_rounded,
                    label: 'Projects',
                    isActive: _selectedTab == 0,
                    onTap: () => setState(() => _selectedTab = 0),
                  ),
                  _NavItem(
                    icon: Icons.meeting_room_rounded,
                    label: 'Spaces',
                    isActive: _selectedTab == 1,
                    onTap: () => setState(() => _selectedTab = 1),
                  ),
                  _NavItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Messages',
                    isActive: _selectedTab == 2,
                    badgeCount: _unreadMessageCount,
                    onTap: () {
                      setState(() => _selectedTab = 2);
                      _loadUnreadMessageCount();
                    },
                  ),
                  _NavItem(
                    icon: Icons.person_outline_rounded,
                    label: 'Profile',
                    isActive: _selectedTab == 3,
                    onTap: () => setState(() => _selectedTab = 3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    this.badgeCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? CAppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isActive ? CAppTheme.primaryColor : CAppTheme.textTertiary,
                  size: 24,
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -8,
                    top: -6,
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
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? CAppTheme.primaryColor
                    : CAppTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── HOME TAB ──────────────────────────────────────────────
class _HomeTab extends StatefulWidget {
  final TextEditingController searchController;
  final int unreadCount;
  final VoidCallback onNotificationTap;

  const _HomeTab({
    required this.searchController,
    required this.unreadCount,
    required this.onNotificationTap,
  });

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  bool _showMapView = false;
  List<WorkspaceRecommendation> _recommendations = [];
  bool _loadingRecommendations = false;

  static const _categories = <_CategoryDef>[
    _CategoryDef(label: 'All', icon: Icons.grid_view_rounded, value: null),
    _CategoryDef(
      label: 'Private Office',
      icon: Icons.business_outlined,
      value: 'private',
    ),
    _CategoryDef(
      label: 'Meeting Room',
      icon: Icons.meeting_room_outlined,
      value: 'meeting-room',
    ),
    _CategoryDef(
      label: 'Shared Desk',
      icon: Icons.desk_outlined,
      value: 'shared',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRecommendations());
  }

  Future<void> _loadRecommendations() async {
    final user = context.read<AuthController>().currentUser;
    if (user == null || !mounted) return;

    setState(() => _loadingRecommendations = true);
    try {
      final controller = context.read<WorkspaceController>();
      var workspaces = controller.workspaces;
      if (workspaces.isEmpty) {
        workspaces = await WorkspaceService().getAllWorkspaces();
      }

      final location = await LocationService.instance.getCurrentLocation();
      final recs = await RecommendationService().getRecommendations(
        userId: user.id,
        workspaces: workspaces,
        userLat: location?.latitude,
        userLng: location?.longitude,
      );

      if (mounted) setState(() => _recommendations = recs);
    } catch (_) {
      if (mounted) setState(() => _recommendations = []);
    } finally {
      if (mounted) setState(() => _loadingRecommendations = false);
    }
  }

  bool _hasActiveFilters(WorkspaceController controller) =>
      controller.selectedCategory != null ||
      controller.selectedAmenities.isNotEmpty ||
      widget.searchController.text.trim().isNotEmpty;

  Widget _buildRecommendedSection() {
    if (_loadingRecommendations) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    if (_recommendations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, size: 20, color: CAppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Recommended for you',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: CAppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 218,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _recommendations.length,
            itemBuilder: (context, index) {
              final rec = _recommendations[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: index < _recommendations.length - 1 ? 14 : 0,
                ),
                child: _RecommendedWorkspaceCard(
                  recommendation: rec,
                  onWhyTap: () => _showRecommendationWhySheet(rec),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  void _showRecommendationWhySheet(WorkspaceRecommendation rec) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: CAppTheme.borderColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Why recommended?',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              rec.workspace.name,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: CAppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ...rec.reasons.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle,
                        size: 18, color: CAppTheme.primaryColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        r,
                        style: GoogleFonts.poppins(fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkspaceDetailScreen(
                        workspaceId: rec.workspace.id,
                      ),
                    ),
                  );
                },
                child: Text(
                  'View workspace',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;
    final wsController = context.watch<WorkspaceController>();
    final activeCategory = wsController.selectedCategory;

    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hi, ${user?.name.split(' ').first ?? 'Explorer'}',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: CAppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 14,
                            color: CAppTheme.primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            user?.city ?? 'Pakistan',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: CAppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _HeaderIcon(
                  icon: Icons.emergency,
                  color: CAppTheme.errorColor,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SosScreen()),
                  ),
                ),
                const SizedBox(width: 10),
                Stack(
                  children: [
                    _HeaderIcon(
                      icon: Icons.notifications_outlined,
                      onTap: widget.onNotificationTap,
                    ),
                    if (widget.unreadCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: CAppTheme.errorColor,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            widget.unreadCount > 9 ? '9+' : '${widget.unreadCount}',
                            style: const TextStyle(
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
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Category chips
          SizedBox(
            height: 44,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              children: _categories.map((cat) {
                final isActive = cat.value == activeCategory;
                return _CategoryChip(
                  label: cat.label,
                  icon: cat.icon,
                  isActive: isActive,
                  onTap: () => wsController.filterByCategory(cat.value),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                boxShadow: CAppTheme.softShadow,
              ),
              child: TextField(
                controller: widget.searchController,
                decoration: InputDecoration(
                  hintText: 'Search workspaces...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: SizedBox(
                    width: 88,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              widget.searchController.clear();
                              context
                                  .read<WorkspaceController>()
                                  .searchWorkspaces('');
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.tune_rounded, size: 20),
                          onPressed: () => _showFilterSheet(context),
                        ),
                      ],
                    ),
                  ),
                  suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: (v) =>
                    context.read<WorkspaceController>().searchWorkspaces(v),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // List / Map toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                boxShadow: CAppTheme.softShadow,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ViewToggleButton(
                      icon: Icons.view_list_rounded,
                      label: 'List',
                      isActive: !_showMapView,
                      onTap: () => setState(() => _showMapView = false),
                    ),
                  ),
                  Expanded(
                    child: _ViewToggleButton(
                      icon: Icons.map_rounded,
                      label: 'Map',
                      isActive: _showMapView,
                      onTap: () => setState(() => _showMapView = true),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Workspace list or map
          Expanded(
            child: Consumer<WorkspaceController>(
              builder: (context, controller, _) {
                if (controller.isLoading && controller.workspaces.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (controller.errorMessage != null &&
                    controller.workspaces.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: CAppTheme.errorColor,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            controller.errorMessage!,
                            style: GoogleFonts.poppins(
                              color: CAppTheme.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final workspaces = controller.workspaces;
                if (workspaces.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 64,
                          color: CAppTheme.textTertiary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No workspaces found',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: CAppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try adjusting your search or filters',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: CAppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (_showMapView) {
                  return WorkspacesMapView(
                    workspaces: workspaces,
                    fallbackCity: user?.city,
                  );
                }

                // Group by city
                final byCity = <String, List<WorkspaceModel>>{};
                for (var ws in workspaces) {
                  (byCity[ws.city] ??= []).add(ws);
                }

                final showRecommendations = !_hasActiveFilters(controller);

                return RefreshIndicator(
                  onRefresh: () async {
                    await controller.loadWorkspaces();
                    await _loadRecommendations();
                  },
                  color: CAppTheme.primaryColor,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (showRecommendations) _buildRecommendedSection(),
                      ...byCity.entries.map((entry) {
                        final city = entry.key;
                        final list = entry.value;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 12),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.location_city_rounded,
                                    size: 18,
                                    color: CAppTheme.primaryColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    city,
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: CAppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ...list.map(
                              (ws) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _WorkspaceCard(workspace: ws),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    final controller = context.read<WorkspaceController>();
    final selected = List<String>.from(controller.selectedAmenities);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AmenityFilterSheet(
        initialSelection: selected,
        availableAmenities: controller.filterAmenityOptions,
      ),
    );
  }
}

class _CategoryDef {
  final String label;
  final IconData icon;
  final String? value;
  const _CategoryDef({
    required this.label,
    required this.icon,
    required this.value,
  });
}

class _ViewToggleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ViewToggleButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? CAppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isActive ? Colors.white : CAppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : CAppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  const _HeaderIcon({required this.icon, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: (color ?? CAppTheme.textSecondary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
        ),
        child: Icon(icon, size: 22, color: color ?? CAppTheme.textPrimary),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? CAppTheme.primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
            border: isActive ? null : Border.all(color: CAppTheme.borderColor),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? Colors.white : CAppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isActive ? Colors.white : CAppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── RECOMMENDED WORKSPACE CARD ─────────────────────────────
class _RecommendedWorkspaceCard extends StatelessWidget {
  final WorkspaceRecommendation recommendation;
  final VoidCallback? onWhyTap;

  const _RecommendedWorkspaceCard({
    required this.recommendation,
    this.onWhyTap,
  });

  @override
  Widget build(BuildContext context) {
    final ws = recommendation.workspace;
    final distLabel = recommendation.distanceKm != null
        ? formatRoadDistanceKm(recommendation.distanceKm!)
        : null;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkspaceDetailScreen(workspaceId: ws.id),
        ),
      ),
      onLongPress: onWhyTap,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(CAppTheme.radiusXL),
          boxShadow: CAppTheme.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: SizedBox(
                height: 100,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ws.imageUrls.isNotEmpty
                        ? Image.network(
                            ws.imageUrls.first,
                            fit: BoxFit.cover,
                            cacheWidth: kIsWeb ? 300 : 500,
                            errorBuilder: (_, __, ___) => Container(
                              color: CAppTheme.borderColor,
                              child: const Icon(Icons.workspaces_outlined),
                            ),
                          )
                        : Container(
                            color: CAppTheme.borderColor,
                            child: const Icon(Icons.workspaces_outlined),
                          ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: CAppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          recommendation.reason,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    if (onWhyTap != null)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Material(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: onWhyTap,
                            borderRadius: BorderRadius.circular(16),
                            child: const Padding(
                              padding: EdgeInsets.all(5),
                              child: Icon(Icons.info_outline,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ws.name,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: CAppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    distLabel != null ? '${ws.city} · $distLabel' : ws.city,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: distLabel != null
                          ? CAppTheme.primaryColor
                          : CAppTheme.textSecondary,
                      fontWeight:
                          distLabel != null ? FontWeight.w500 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Rs. ${ws.pricePerDay.toStringAsFixed(0)}/day',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: CAppTheme.primaryColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if ((ws.rating ?? 0) > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, size: 12, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text(
                              (ws.rating ?? 0).toStringAsFixed(1),
                              style: GoogleFonts.poppins(fontSize: 11),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── WORKSPACE CARD ─────────────────────────────────────────
class _WorkspaceCard extends StatelessWidget {
  final WorkspaceModel workspace;

  const _WorkspaceCard({required this.workspace});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkspaceDetailScreen(workspaceId: workspace.id),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(CAppTheme.radiusXL),
          boxShadow: CAppTheme.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'workspace_card_image_${workspace.id}',
                      child: workspace.imageUrls.isNotEmpty
                          ? Image.network(
                              workspace.imageUrls.first,
                              fit: BoxFit.cover,
                              cacheWidth: kIsWeb ? 400 : 800,
                              loadingBuilder: (_, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  color: CAppTheme.borderColor,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (_, __, ___) => Container(
                                color: CAppTheme.borderColor,
                                child: const Icon(
                                  Icons.image_not_supported_outlined,
                                  size: 48,
                                  color: CAppTheme.textTertiary,
                                ),
                              ),
                            )
                          : Container(
                              color: CAppTheme.borderColor,
                              child: const Icon(
                                Icons.workspaces_outlined,
                                size: 48,
                                color: CAppTheme.textTertiary,
                              ),
                            ),
                    ),
                    // Status badge
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: workspace.isAvailable
                              ? CAppTheme.successColor
                              : CAppTheme.errorColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          workspace.isAvailable ? 'Available' : 'Unavailable',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    // Price badge
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: CAppTheme.softShadow,
                        ),
                        child: Text(
                          'Rs. ${workspace.pricePerDay.toStringAsFixed(0)}/day',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: CAppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workspace.name,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: CAppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: CAppTheme.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${workspace.address}, ${workspace.city}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: CAppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Amenity chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: workspace.amenities
                        .take(4)
                        .map(
                          (a) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F3FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              a,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: CAppTheme.primaryColor,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── PROFILE TAB ────────────────────────────────────────────
class _ProfileTab extends StatelessWidget {
  final VoidCallback onLogout;

  const _ProfileTab({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Avatar
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                gradient: CAppTheme.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: CAppTheme.cardShadow,
              ),
              child:
                  user?.profileImageUrl != null &&
                      user!.profileImageUrl!.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        user.profileImageUrl!,
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(
                            (user.name).substring(0, 1).toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        (user?.name ?? 'U').substring(0, 1).toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              user?.name ?? 'User',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: CAppTheme.textPrimary,
              ),
            ),
            Text(
              user?.email ?? '',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: CAppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // Quick "Open to Collaborate" toggle
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: CAppTheme.softShadow,
                border: Border.all(
                  color: (user?.collaborationEnabled ?? false)
                      ? CAppTheme.primaryColor.withValues(alpha: 0.4)
                      : CAppTheme.borderColor,
                ),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: user?.collaborationEnabled ?? false,
                secondary: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: CAppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.handshake_rounded, color: CAppTheme.primaryColor, size: 20),
                ),
                title: Text('Open to Collaborate',
                    style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  (user?.collaborationEnabled ?? false)
                      ? 'You appear in "Open Teammates" — owners can invite you'
                      : 'Turn on to get discovered and invited to projects',
                  style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.textSecondary),
                ),
                onChanged: user == null
                    ? null
                    : (value) async {
                        await auth.updateProfile(
                          user.copyUser(collaborationEnabled: value),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(value
                                ? 'You are now open to collaborate'
                                : 'You are no longer listed as open'),
                            backgroundColor: CAppTheme.successColor,
                          ),
                        );
                      },
              ),
            ),

            _ProfileMenuItem(
              icon: Icons.person_outline,
              label: 'Edit Profile',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
            ),
            _ProfileMenuItem(
              icon: Icons.handshake_outlined,
              label: 'Collaboration Profile',
              color: CAppTheme.primaryColor,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CollaborationProfileScreen()),
              ),
            ),
            _ProfileMenuItem(
              icon: Icons.work_outline_rounded,
              label: 'My Portfolio',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PortfolioEditorScreen()),
              ),
            ),
            _ProfileMenuItem(
              icon: Icons.book_outlined,
              label: 'Booking History',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BookingHistoryScreen()),
              ),
            ),
            if (user?.role == AppConstants.roleUser)
              _ProfileMenuItem(
                icon: Icons.account_balance_wallet_outlined,
                label: 'My Wallet',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WalletScreen()),
                ),
              ),
            _ProfileMenuItem(
              icon: Icons.receipt_long_outlined,
              label: 'Payment History',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaymentHistoryScreen()),
              ),
            ),
            _ProfileMenuItem(
              icon: Icons.flag_outlined,
              label: 'Report an Issue',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportScreen()),
              ),
            ),
            _ProfileMenuItem(
              icon: Icons.list_alt_rounded,
              label: 'My Reports',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyReportsScreen()),
              ),
            ),
            const SizedBox(height: 8),
            _ProfileMenuItem(
              icon: Icons.logout_rounded,
              label: 'Logout',
              color: CAppTheme.errorColor,
              onTap: onLogout,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _ProfileMenuItem({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? CAppTheme.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: c, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: c,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: CAppTheme.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── AMENITY FILTER SHEET ───────────────────────────────────
class _AmenityFilterSheet extends StatefulWidget {
  final List<String> initialSelection;
  final List<String> availableAmenities;

  const _AmenityFilterSheet({
    required this.initialSelection,
    required this.availableAmenities,
  });

  @override
  State<_AmenityFilterSheet> createState() => _AmenityFilterSheetState();
}

class _AmenityFilterSheetState extends State<_AmenityFilterSheet> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.initialSelection);
  }

  List<String> get _customAmenities => widget.availableAmenities
      .where(
        (a) => !AppConstants.commonAmenities
            .any((c) => c.toLowerCase() == a.toLowerCase()),
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.75;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: CAppTheme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Filter by Amenities',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppConstants.commonAmenities.map((a) {
                      return _buildAmenityChip(a);
                    }).toList(),
                  ),
                  if (_customAmenities.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'More amenities',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: CAppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _customAmenities.map(_buildAmenityChip).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    context.read<WorkspaceController>().clearFilters();
                    Navigator.pop(context);
                  },
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    context.read<WorkspaceController>().filterByAmenities(
                      _selected,
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmenityChip(String a) {
    final on = _selected.any(
      (s) => s.toLowerCase() == a.toLowerCase(),
    );
    final isCustom = !AppConstants.commonAmenities
        .any((c) => c.toLowerCase() == a.toLowerCase());

    return FilterChip(
      label: Text(
        a,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: on ? Colors.white : CAppTheme.primaryColor,
        ),
      ),
      selected: on,
      selectedColor: CAppTheme.primaryColor,
      checkmarkColor: Colors.white,
      backgroundColor: isCustom
          ? CAppTheme.primaryColor.withValues(alpha: 0.06)
          : const Color(0xFFF0F3FF),
      side: isCustom
          ? BorderSide(color: CAppTheme.primaryColor.withValues(alpha: 0.25))
          : BorderSide.none,
      onSelected: (_) {
        setState(() {
          if (on) {
            _selected.removeWhere(
              (s) => s.toLowerCase() == a.toLowerCase(),
            );
          } else {
            _selected.add(a);
          }
        });
      },
    );
  }
}
