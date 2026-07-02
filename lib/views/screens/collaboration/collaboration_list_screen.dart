import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/models/collaboration_hub_models.dart';
import 'package:cwc/models/collaboration_model.dart';
import 'package:cwc/models/notification_model.dart';
import 'package:cwc/services/collaboration_hub_service.dart';
import 'package:cwc/services/collaboration_service.dart';
import 'package:cwc/services/notification_service.dart';
import 'package:cwc/utils/constants/app_constants.dart';
import 'package:cwc/utils/notification_scope.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/views/screens/collaboration/collaboration_create_screen.dart';
import 'package:cwc/views/screens/collaboration/collaboration_detail_screen.dart';
import 'package:cwc/views/screens/collaboration/collaboration_join_screen.dart';
import 'package:cwc/views/screens/collaboration/collaboration_project_screen.dart';
import 'package:cwc/views/screens/notifications/notifications_screen.dart';
import 'package:cwc/views/screens/profile/public_profile_screen.dart';
import 'package:cwc/views/widgets/collaboration_widgets.dart';

/// Projects hub — the primary app experience.
class CollaborationListScreen extends StatefulWidget {
  const CollaborationListScreen({super.key});

  @override
  State<CollaborationListScreen> createState() => _CollaborationListScreenState();
}

class _CollaborationListScreenState extends State<CollaborationListScreen>
    with SingleTickerProviderStateMixin {
  final _collab = CollaborationService();
  final _hub = CollaborationHubService();
  final _notificationService = NotificationService();
  late final TabController _tabController;
  final _searchController = TextEditingController();
  StreamSubscription<List<NotificationModel>>? _notifSub;
  int _unreadProjectNotifications = 0;

  List<CollaborationModel> _discover = [];
  List<Map<String, dynamic>> _openTeammates = [];
  List<CollaborationModel> _myPosts = [];
  List<CollaborationModel> _myTeams = [];
  List<CollaborationApplication> _myApps = [];
  List<CollaborationInvite> _invites = [];
  Map<String, int> _responseCounts = {};

  bool _loading = true;
  String _search = '';
  String _discoverCategory = 'All';

  static final List<String> _discoverCategories = [
    'All',
    ...AppConstants.projectCategories,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _searchController.addListener(() {
      if (_search != _searchController.text) {
        setState(() => _search = _searchController.text);
      }
    });
    _loadAll();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotificationCount();
      _setupNotificationStream();
    });
  }

  Future<void> _loadNotificationCount() async {
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;
    try {
      final notifications =
          await _notificationService.getUserNotifications(user.id);
      if (mounted) {
        setState(() {
          _unreadProjectNotifications = NotificationScopeHelper.unreadCount(
            notifications,
            NotificationScope.projects,
          );
        });
      }
    } catch (_) {}
  }

  void _setupNotificationStream() {
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;
    _notifSub?.cancel();
    _notifSub = _notificationService
        .getNotificationsStream(user.id)
        .listen(
          (notifications) {
            if (mounted) {
              setState(() {
                _unreadProjectNotifications =
                    NotificationScopeHelper.unreadCount(
                  notifications,
                  NotificationScope.projects,
                );
              });
            }
          },
          onError: (_) {},
          cancelOnError: false,
        );
  }

  void _openProjectNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificationsScreen(
          scope: NotificationScope.projects,
        ),
      ),
    ).then((_) => _loadNotificationCount());
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Runs a fetch in isolation so one failing query never blanks the whole
  /// screen (e.g. a discover list staying empty because an unrelated query
  /// threw). Returns [fallback] on error.
  Future<T> _safe<T>(Future<T> Function() task, T fallback) async {
    try {
      return await task();
    } catch (e) {
      debugPrint('collaboration load step failed: $e');
      return fallback;
    }
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final uid = context.read<AuthController>().currentUser?.id;

    final discover = await _safe(() => _collab.getAllCollaborations(), <CollaborationModel>[]);
    final teammates =
        await _safe(() => _hub.getOpenTeammates(excludeUserId: uid), <Map<String, dynamic>>[]);
    final myPosts = uid != null
        ? await _safe(() => _collab.getUserCollaborations(uid), <CollaborationModel>[])
        : <CollaborationModel>[];
    final myTeams = uid != null
        ? await _safe(() => _hub.getUserTeams(uid), <CollaborationModel>[])
        : <CollaborationModel>[];
    final myApps = uid != null
        ? await _safe(() => _hub.getUserApplications(uid), <CollaborationApplication>[])
        : <CollaborationApplication>[];
    final invites = uid != null
        ? await _safe(() => _hub.getUserInvites(uid), <CollaborationInvite>[])
        : <CollaborationInvite>[];
    final counts = await _safe(
        () => _collab.getResponseCounts(discover.map((c) => c.id).toList()), <String, int>{});

    if (!mounted) return;
    setState(() {
      // Don't show the viewer their own posts in Discover — those live in "My Posts".
      _discover = uid == null ? discover : discover.where((c) => c.userId != uid).toList();
      _openTeammates = teammates;
      _myPosts = myPosts;
      _myTeams = myTeams;
      _myApps = myApps;
      _invites = invites;
      _responseCounts = counts;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CAppTheme.backgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createProject,
        icon: const Icon(Icons.add),
        label: const Text('Post project'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Discover'),
                Tab(text: 'Open Teammates'),
                Tab(text: 'My Posts'),
                Tab(text: 'My Projects teams'),
                Tab(text: 'My Applications'),
              ],
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: CAppTheme.primaryColor))
                  : RefreshIndicator(
                      onRefresh: _loadAll,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _discoverTab(),
                          _teammatesTab(),
                          _myPostsTab(),
                          _myTeamsTab(),
                          _myApplicationsTab(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Projects',
                    style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700)),
                Text('Find teammates. Build projects.',
                    style: GoogleFonts.poppins(fontSize: 13, color: CAppTheme.textSecondary)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CollaborationJoinScreen())),
            icon: const Icon(Icons.qr_code_rounded),
            tooltip: 'Join with code',
            style: IconButton.styleFrom(
              backgroundColor: CAppTheme.primaryColor.withValues(alpha: 0.1),
              foregroundColor: CAppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 4),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: _openProjectNotifications,
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Project notifications',
                style: IconButton.styleFrom(
                  backgroundColor: CAppTheme.primaryColor.withValues(alpha: 0.1),
                  foregroundColor: CAppTheme.primaryColor,
                ),
              ),
              if (_unreadProjectNotifications > 0)
                Positioned(
                  right: 6,
                  top: 6,
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
                      _unreadProjectNotifications > 9
                          ? '9+'
                          : '$_unreadProjectNotifications',
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
        ],
      ),
    );
  }

  // ---------------------------------------------------------- Discover
  Widget _discoverTab() {
    final query = _search.toLowerCase();
    var filtered = query.isEmpty
        ? _discover
        : _discover.where((c) {
            return c.title.toLowerCase().contains(query) ||
                c.description.toLowerCase().contains(query) ||
                c.requiredSkills.any((s) => s.toLowerCase().contains(query));
          }).toList();

    if (_discoverCategory != 'All') {
      filtered = filtered
          .where((c) => c.projectType == _discoverCategory)
          .toList();
    }

    final recruitingCount =
        filtered.where((c) => c.status == 'recruiting').length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search projects or skills...',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: CAppTheme.surfaceColor,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _discoverCategories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final cat = _discoverCategories[i];
              final active = _discoverCategory == cat;
              return FilterChip(
                label: Text(cat),
                selected: active,
                onSelected: (_) => setState(() => _discoverCategory = cat),
                labelStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : CAppTheme.textSecondary,
                ),
                selectedColor: CAppTheme.primaryColor,
                backgroundColor: CAppTheme.surfaceColor,
                showCheckmark: false,
                side: BorderSide(
                  color: active
                      ? CAppTheme.primaryColor
                      : CAppTheme.borderColor,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              );
            },
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? EmptyState(
                  icon: Icons.explore_rounded,
                  title: 'No open projects',
                  subtitle: _discoverCategory != 'All'
                      ? 'Try another category or post your own project.'
                      : 'Be the first to post a project and build a team.',
                  action: ElevatedButton.icon(
                    onPressed: _createProject,
                    icon: const Icon(Icons.add),
                    label: const Text('Post a project'),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                  children: [
                    if (_invites.isNotEmpty) _invitesBanner(),
                    _discoverHeroBanner(
                      total: filtered.length,
                      recruiting: recruitingCount,
                    ),
                    const SizedBox(height: 14),
                    ...filtered.map(_discoverCard),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _discoverHeroBanner({required int total, required int recruiting}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: CAppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        boxShadow: CAppTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.explore_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Discover projects',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$total open · $recruiting recruiting now',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(CAppTheme.radiusRound),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.campaign_rounded, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Join a team',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _discoverCard(CollaborationModel p) {
    final responseCount = _responseCounts[p.id] ?? 0;
    final hasCover = p.coverImageUrl != null && p.coverImageUrl!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: SectionCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  CollaborationDetailScreen(collaborationId: p.id),
            ),
          ).then((_) => _loadAll()),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(CAppTheme.radiusLarge),
                    ),
                    child: hasCover
                        ? Image.network(
                            p.coverImageUrl!,
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            height: 140,
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              gradient: CAppTheme.coolGradient,
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  right: -20,
                                  top: -20,
                                  child: Icon(
                                    Icons.hub_rounded,
                                    size: 100,
                                    color: Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                Center(
                                  child: Icon(
                                    Icons.rocket_launch_rounded,
                                    size: 44,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: StatusBadge(status: p.status),
                  ),
                  if (p.projectType != null)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius:
                              BorderRadius.circular(CAppTheme.radiusRound),
                        ),
                        child: Text(
                          p.projectType!,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      p.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: CAppTheme.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    if (p.requiredSkills.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: p.requiredSkills
                            .take(4)
                            .map((s) => SkillChip(label: s))
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: CAppTheme.primaryColor.withValues(alpha: 0.06),
                        borderRadius:
                            BorderRadius.circular(CAppTheme.radiusMedium),
                      ),
                      child: Row(
                        children: [
                          UserAvatar(
                            name: p.userName,
                            imageUrl: p.userProfileImage,
                            size: 34,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.userName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  _timeAgo(p.createdAt),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.5,
                                    color: CAppTheme.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (responseCount > 0) ...[
                            Icon(
                              Icons.people_alt_rounded,
                              size: 15,
                              color: CAppTheme.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$responseCount',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: CAppTheme.textTertiary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: CAppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(
                                CAppTheme.radiusRound,
                              ),
                            ),
                            child: Text(
                              'View & apply',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
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

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays >= 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  Widget _invitesBanner() {
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.mail_rounded, size: 18, color: CAppTheme.primaryColor),
            const SizedBox(width: 8),
            Text('Project invitations',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 10),
        ..._invites.map((inv) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: CAppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(inv.collaborationTitle ?? 'A project',
                      style: GoogleFonts.poppins(
                          fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(
                    '${inv.invitedByName ?? 'Someone'} invited you${inv.roleTitle != null ? ' as ${inv.roleTitle}' : ''}',
                    style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.white70),
                  ),
                  if (inv.message != null && inv.message!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('"${inv.message!}"',
                        style: GoogleFonts.poppins(
                            fontSize: 12.5, fontStyle: FontStyle.italic, color: Colors.white)),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: CAppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () => _respondInvite(inv, true),
                          child: const Text('Accept'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        onPressed: () => _respondInvite(inv, false),
                        child: const Text('Decline'),
                      ),
                    ],
                  ),
                ],
              ),
            )),
        const Divider(height: 24),
      ],
    );
  }

  Future<void> _respondInvite(CollaborationInvite inv, bool accept) async {
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;
    if (accept) {
      await _hub.acceptInvite(
        invite: inv,
        userId: user.id,
        userName: user.name,
        userEmail: user.email,
        userImage: user.profileImageUrl,
        userSkills: user.skills ?? [],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Joined "${inv.collaborationTitle ?? 'project'}"'),
            backgroundColor: CAppTheme.successColor),
      );
    } else {
      await _hub.respondToInvite(inv, false);
    }
    _loadAll();
  }

  // ---------------------------------------------------- Open Teammates
  Widget _teammatesTab() {
    if (_openTeammates.isEmpty) {
      return const EmptyState(
        icon: Icons.groups_rounded,
        title: 'No open teammates yet',
        subtitle: 'People who turn on "Open to Collaborate" will show up here.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      itemCount: _openTeammates.length,
      itemBuilder: (_, i) {
        final u = _openTeammates[i];
        final skills = (u['skills'] as List?)?.cast<String>() ?? [];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: SectionCard(
            padding: const EdgeInsets.all(14),
            child: InkWell(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: u['id']))),
              child: Row(
                children: [
                  UserAvatar(name: u['name'], imageUrl: u['profile_image_url'], size: 50),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u['name'] ?? 'User',
                            style: GoogleFonts.poppins(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        if (u['collaboration_headline'] != null)
                          Text(u['collaboration_headline'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                  fontSize: 12.5, color: CAppTheme.primaryColor)),
                        if (skills.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: skills.take(3).map((s) => SkillChip(label: s)).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: CAppTheme.textTertiary),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------- My Posts
  Widget _myPostsTab() {
    final user = context.watch<AuthController>().currentUser;
    final collabOff = user?.collaborationEnabled != true;

    if (_myPosts.isEmpty) {
      return EmptyState(
        icon: Icons.post_add_rounded,
        title: 'No projects yet',
        subtitle: 'Post your first project to start building a team.',
        action: ElevatedButton.icon(
          onPressed: _createProject,
          icon: const Icon(Icons.add),
          label: const Text('Post a project'),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      itemCount: _myPosts.length + (collabOff ? 1 : 0),
      itemBuilder: (_, i) {
        if (collabOff && i == 0) {
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: CAppTheme.warningColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
              border: Border.all(color: CAppTheme.warningColor.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: CAppTheme.warningColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Open to Collaborate is off — your projects are hidden from Discover until you turn it on.',
                    style: GoogleFonts.poppins(fontSize: 13, height: 1.45),
                  ),
                ),
              ],
            ),
          );
        }
        final index = collabOff ? i - 1 : i;
        return _projectCard(_myPosts[index], showStatus: true, isMyPost: true);
      },
    );
  }

  // ------------------------------------------------------------ My Teams
  Widget _myTeamsTab() {
    if (_myTeams.isEmpty) {
      return const EmptyState(
        icon: Icons.diversity_3_rounded,
        title: 'You are not on a team yet',
        subtitle: 'Apply to projects or accept an invite to join a team.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      itemCount: _myTeams.length,
      itemBuilder: (_, i) {
        final p = _myTeams[i];
        return _projectCard(p, showStatus: true, openRoom: p.isActive || p.isCompleted);
      },
    );
  }

  // ----------------------------------------------------- My Applications
  Widget _myApplicationsTab() {
    if (_myApps.isEmpty) {
      return const EmptyState(
        icon: Icons.assignment_rounded,
        title: 'No applications yet',
        subtitle: 'Applications you submit will appear here with their status.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      itemCount: _myApps.length,
      itemBuilder: (_, i) {
        final a = _myApps[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: SectionCard(
            padding: const EdgeInsets.all(14),
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => CollaborationDetailScreen(collaborationId: a.collaborationId)),
              ).then((_) => _loadAll()),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (a.roleTitle != null)
                          Text('Applied as ${a.roleTitle}',
                              style: GoogleFonts.poppins(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(a.pitchMessage,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                fontSize: 12.5, color: CAppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _appStatusChip(a.status),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _appStatusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case 'accepted':
        color = CAppTheme.successColor;
        label = 'Accepted';
        break;
      case 'shortlisted':
        color = CAppTheme.warningColor;
        label = 'Shortlisted';
        break;
      case 'rejected':
        color = CAppTheme.errorColor;
        label = 'Not selected';
        break;
      default:
        color = CAppTheme.infoColor;
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(CAppTheme.radiusRound),
      ),
      child: Text(label,
          style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
    );
  }

  // ----------------------------------------------------------- shared card
  Widget _projectCard(
    CollaborationModel p, {
    bool showStatus = false,
    bool openRoom = false,
    bool isMyPost = false,
  }) {
    final responseCount = _responseCounts[p.id] ?? 0;
    final canToggleListing = isMyPost && (p.isRecruiting || p.isInactive);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: SectionCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
          onTap: () {
            if (openRoom) {
              Navigator.push(context,
                      MaterialPageRoute(builder: (_) => CollaborationProjectScreen(collaborationId: p.id)))
                  .then((_) => _loadAll());
            } else {
              Navigator.push(context,
                      MaterialPageRoute(builder: (_) => CollaborationDetailScreen(collaborationId: p.id)))
                  .then((_) => _loadAll());
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (p.coverImageUrl != null && p.coverImageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(CAppTheme.radiusLarge)),
                  child: Image.network(p.coverImageUrl!,
                      height: 120, width: double.infinity, fit: BoxFit.cover),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(p.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                        if (showStatus) StatusBadge(status: p.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(p.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: CAppTheme.textSecondary, height: 1.4)),
                    if (p.requiredSkills.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            p.requiredSkills.take(4).map((s) => SkillChip(label: s)).toList(),
                      ),
                    ],
                    if (canToggleListing) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: !p.isRecruiting
                                  ? () => _setProjectListing(p, true)
                                  : null,
                              icon: const Icon(Icons.campaign_rounded, size: 18),
                              label: const Text('Active'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: p.isRecruiting
                                    ? CAppTheme.successColor
                                    : CAppTheme.textTertiary,
                                side: BorderSide(
                                  color: p.isRecruiting
                                      ? CAppTheme.successColor
                                      : CAppTheme.borderColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: !p.isInactive
                                  ? () => _setProjectListing(p, false)
                                  : null,
                              icon: const Icon(Icons.pause_circle_outline_rounded, size: 18),
                              label: const Text('Inactive'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: p.isInactive
                                    ? CAppTheme.textSecondary
                                    : CAppTheme.textTertiary,
                                side: BorderSide(
                                  color: p.isInactive
                                      ? CAppTheme.textSecondary
                                      : CAppTheme.borderColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        UserAvatar(name: p.userName, imageUrl: p.userProfileImage, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(p.userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                  fontSize: 12.5, color: CAppTheme.textSecondary)),
                        ),
                        if (!showStatus && responseCount > 0) ...[
                          const Icon(Icons.people_alt_rounded,
                              size: 14, color: CAppTheme.textTertiary),
                          const SizedBox(width: 4),
                          Text('$responseCount',
                              style: GoogleFonts.poppins(
                                  fontSize: 12.5, color: CAppTheme.textTertiary)),
                        ],
                        if (openRoom)
                          Text('Open room →',
                              style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: CAppTheme.primaryColor)),
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

  Future<void> _createProject() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CollaborationCreateScreen()),
    );
    if (created == true) _loadAll();
  }

  Future<void> _setProjectListing(CollaborationModel project, bool active) async {
    try {
      await _collab.setProjectListingActive(project.id, active);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(active
              ? '"${project.title}" is now active in Discover'
              : '"${project.title}" is now inactive'),
          backgroundColor: CAppTheme.successColor,
        ),
      );
      _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }
}
