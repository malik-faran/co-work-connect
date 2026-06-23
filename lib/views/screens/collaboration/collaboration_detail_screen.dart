import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/models/collaboration_hub_models.dart';
import 'package:cwc/models/collaboration_model.dart';
import 'package:cwc/services/chat_service.dart';
import 'package:cwc/services/collaboration_hub_service.dart';
import 'package:cwc/services/collaboration_service.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/views/screens/chat/chat_screen.dart';
import 'package:cwc/views/screens/collaboration/collaboration_apply_sheet.dart';
import 'package:cwc/views/screens/collaboration/collaboration_create_screen.dart';
import 'package:cwc/views/screens/collaboration/collaboration_invite_sheet.dart';
import 'package:cwc/views/screens/collaboration/collaboration_project_screen.dart';
import 'package:cwc/views/screens/profile/public_profile_screen.dart';
import 'package:cwc/views/widgets/collaboration_widgets.dart';

class CollaborationDetailScreen extends StatefulWidget {
  final String collaborationId;
  const CollaborationDetailScreen({super.key, required this.collaborationId});

  @override
  State<CollaborationDetailScreen> createState() => _CollaborationDetailScreenState();
}

class _CollaborationDetailScreenState extends State<CollaborationDetailScreen> {
  final _collab = CollaborationService();
  final _hub = CollaborationHubService();
  final _chat = ChatService();
  final _uuid = const Uuid();

  CollaborationModel? _project;
  List<CollaborationRole> _roles = [];
  List<CollaborationApplication> _applications = [];
  List<CollaborationInvite> _sentInvites = [];
  bool _loading = true;
  bool _isMember = false;
  bool _hasApplied = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _uid => context.read<AuthController>().currentUser?.id ?? '';
  bool get _isOwner => _project != null && _project!.userId == _uid;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final project = await _collab.getCollaborationById(widget.collaborationId);
      final roles = await _hub.getRoles(widget.collaborationId);
      final isMember = await _hub.isMember(widget.collaborationId, _uid);
      List<CollaborationApplication> apps = [];
      List<CollaborationInvite> sentInvites = [];
      bool hasApplied = false;
      if (project != null && project.userId == _uid) {
        apps = await _hub.getApplications(widget.collaborationId);
        try {
          sentInvites = await _hub.getSentInvites(widget.collaborationId);
        } catch (_) {}
      } else {
        hasApplied = await _hub.hasApplied(widget.collaborationId, _uid);
      }
      if (!mounted) return;
      setState(() {
        _project = project;
        _roles = roles;
        _applications = apps;
        _sentInvites = sentInvites;
        _isMember = isMember;
        _hasApplied = hasApplied;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('Failed to load: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: CAppTheme.backgroundColor,
        body: Center(child: CircularProgressIndicator(color: CAppTheme.primaryColor)),
      );
    }
    if (_project == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Project not found',
          subtitle: 'This project may have been removed.',
        ),
      );
    }
    final p = _project!;
    return Scaffold(
      backgroundColor: CAppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 180,
            foregroundColor: Colors.white,
            backgroundColor: CAppTheme.primaryColor,
            leading: _buildBackButton(context),
            actions: [
              if (_isOwner && p.isRecruiting)
                IconButton(
                  icon: const Icon(Icons.ios_share_rounded),
                  onPressed: _openInvite,
                ),
              if (_isOwner && p.isRecruiting)
                IconButton(
                  icon: const Icon(Icons.edit_rounded),
                  onPressed: _edit,
                ),
              if (_isOwner)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (v) {
                    if (v == 'delete') _confirmDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              color: CAppTheme.errorColor, size: 20),
                          SizedBox(width: 10),
                          Text('Delete project'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _coverHeader(p),
            ),
          ),
          SliverToBoxAdapter(child: _body(p)),
        ],
      ),
      bottomNavigationBar: _bottomCta(p),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 360;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => Navigator.maybePop(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: Colors.white),
                if (!compact) ...[
                  const SizedBox(width: 4),
                  Text(
                    'Back',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _coverHeader(CollaborationModel p) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (p.coverImageUrl != null && p.coverImageUrl!.isNotEmpty)
          Image.network(p.coverImageUrl!, fit: BoxFit.cover)
        else
          Container(decoration: const BoxDecoration(gradient: CAppTheme.primaryGradient)),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withValues(alpha: 0.1), Colors.black.withValues(alpha: 0.6)],
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusBadge(status: p.status, large: true),
              const SizedBox(height: 8),
              Text(p.title,
                  style: GoogleFonts.poppins(
                      fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _body(CollaborationModel p) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Owner row
          SectionCard(
            padding: const EdgeInsets.all(12),
            child: InkWell(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: p.userId))),
              child: Row(
                children: [
                  UserAvatar(name: p.userName, imageUrl: p.userProfileImage, size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.userName,
                            style: GoogleFonts.poppins(
                                fontSize: 14.5, fontWeight: FontWeight.w600)),
                        Text('Project owner',
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: CAppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: CAppTheme.textTertiary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(icon: Icons.description_rounded, title: 'About'),
                const SizedBox(height: 10),
                Text(p.description,
                    style: GoogleFonts.poppins(
                        fontSize: 14, height: 1.5, color: CAppTheme.textPrimary)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (p.projectType != null)
                      SkillChip(label: p.projectType!, icon: Icons.category_rounded),
                    if (p.timeline != null && p.timeline!.isNotEmpty)
                      SkillChip(label: p.timeline!, icon: Icons.schedule_rounded),
                    if (p.budget != null && p.budget!.isNotEmpty)
                      SkillChip(label: p.budget!, icon: Icons.payments_rounded),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_roles.isNotEmpty) _rolesSection(),
          if (!_isOwner && !_isMember && p.isRecruiting) ...[
            const SizedBox(height: 14),
            _howItWorksCard(),
          ],
          if (_isOwner && p.isRecruiting) ...[
            const SizedBox(height: 14),
            _applicantInbox(),
            if (_pendingInvites.isNotEmpty) ...[
              const SizedBox(height: 14),
              _pendingInvitesSection(),
            ],
          ],
          const SizedBox(height: 90),
        ],
      ),
    );
  }

  Widget _rolesSection() {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
              icon: Icons.work_outline_rounded, title: 'Open roles (${_roles.length})'),
          const SizedBox(height: 12),
          ..._roles.map((r) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CAppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.title,
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    if (r.requiredSkills.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: r.requiredSkills.map((s) => SkillChip(label: s)).toList(),
                      ),
                    ],
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _howItWorksCard() {
    final steps = [
      ('Apply for a role', 'Pick a role that fits you and send a short pitch.', Icons.assignment_ind_rounded),
      ('Owner reviews', 'The project owner reviews applicants and builds the team.', Icons.fact_check_rounded),
      ('Get on the team', 'Once accepted, you join the team when the project starts.', Icons.groups_rounded),
      ('Work together', 'Use the Project Room: chat, milestones, files & meetings.', Icons.rocket_launch_rounded),
    ];
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(icon: Icons.route_rounded, title: 'How this works'),
          const SizedBox(height: 12),
          ...List.generate(steps.length, (i) {
            final s = steps[i];
            final isLast = i == steps.length - 1;
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: CAppTheme.primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(s.$3, size: 17, color: CAppTheme.primaryColor),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: CAppTheme.borderColor,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${i + 1}. ${s.$1}',
                              style: GoogleFonts.poppins(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(s.$2,
                              style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  color: CAppTheme.textSecondary,
                                  height: 1.4)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  List<CollaborationInvite> get _pendingInvites =>
      _sentInvites.where((i) => i.status == 'pending').toList();

  Widget _pendingInvitesSection() {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.mail_outline_rounded,
            title: 'Invited (${_pendingInvites.length})',
          ),
          const SizedBox(height: 4),
          Text('Waiting for these people to respond to your invite.',
              style: GoogleFonts.poppins(fontSize: 12.5, color: CAppTheme.textSecondary)),
          const SizedBox(height: 12),
          ..._pendingInvites.map((inv) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: CAppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.hourglass_top_rounded,
                        size: 18, color: CAppTheme.warningColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            inv.roleTitle != null
                                ? 'Invited as ${inv.roleTitle}'
                                : 'Project invitation',
                            style: GoogleFonts.poppins(
                                fontSize: 13.5, fontWeight: FontWeight.w600),
                          ),
                          Text('Pending response',
                              style: GoogleFonts.poppins(
                                  fontSize: 11.5, color: CAppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _applicantInbox() {
    final accepted = _applications.where((a) => a.isAccepted).length;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            icon: Icons.inbox_rounded,
            title: 'Applicants (${_applications.length})',
            trailing: accepted > 0
                ? Text('$accepted on team',
                    style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w600, color: CAppTheme.successColor))
                : null,
          ),
          const SizedBox(height: 8),
          if (_applications.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('No applicants yet. Share your invite link to get teammates faster.',
                  style: GoogleFonts.poppins(fontSize: 13, color: CAppTheme.textSecondary)),
            )
          else
            ..._applications.map(_applicantCard),
        ],
      ),
    );
  }

  Widget _applicantCard(CollaborationApplication app) {
    final match = skillMatchPercent(
      app.userSkills,
      _roles.firstWhere((r) => r.id == app.roleId,
          orElse: () => CollaborationRole(
              id: '', collaborationId: '', title: '', createdAt: DateTime.now())).requiredSkills,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CAppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
        border: app.isAccepted
            ? Border.all(color: CAppTheme.successColor.withValues(alpha: 0.4))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: app.userId))),
                child: UserAvatar(name: app.userName, imageUrl: app.userProfileImage, size: 40),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app.userName,
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    if (app.roleTitle != null)
                      Text('for ${app.roleTitle}',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: CAppTheme.textSecondary)),
                  ],
                ),
              ),
              if (app.userSkills.isNotEmpty && app.roleId != null) MatchBadge(percent: match),
            ],
          ),
          const SizedBox(height: 10),
          Text(app.pitchMessage,
              style: GoogleFonts.poppins(
                  fontSize: 13, height: 1.4, color: CAppTheme.textPrimary)),
          if (app.availability != null || app.proposedRate != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (app.availability != null)
                  SkillChip(label: app.availability!, icon: Icons.schedule_rounded),
                if (app.proposedRate != null)
                  SkillChip(label: app.proposedRate!, icon: Icons.payments_rounded),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _applicantActions(app),
        ],
      ),
    );
  }

  Widget _applicantActions(CollaborationApplication app) {
    if (app.isRejected) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text('Rejected',
            style: GoogleFonts.poppins(fontSize: 12.5, color: CAppTheme.errorColor)),
      );
    }
    return Row(
      children: [
        if (app.isAccepted)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: CAppTheme.successColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(CAppTheme.radiusSmall),
              ),
              child: Text('On the team',
                  style: GoogleFonts.poppins(
                      fontSize: 12.5, fontWeight: FontWeight.w600, color: CAppTheme.successColor)),
            ),
          )
        else ...[
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                backgroundColor: CAppTheme.successColor,
              ),
              onPressed: () => _setStatus(app, 'accepted'),
              child: Text('Add to team', style: GoogleFonts.poppins(fontSize: 12.5)),
            ),
          ),
          const SizedBox(width: 8),
          if (!app.isShortlisted)
            _iconBtn(Icons.star_outline_rounded, CAppTheme.warningColor,
                () => _setStatus(app, 'shortlisted')),
        ],
        const SizedBox(width: 8),
        _iconBtn(Icons.chat_bubble_outline_rounded, CAppTheme.primaryColor,
            () => _messageApplicant(app)),
        if (!app.isAccepted) ...[
          const SizedBox(width: 8),
          _iconBtn(Icons.close_rounded, CAppTheme.errorColor, () => _setStatus(app, 'rejected')),
        ],
      ],
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CAppTheme.radiusSmall),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(CAppTheme.radiusSmall),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  Widget? _bottomCta(CollaborationModel p) {
    final user = context.read<AuthController>().currentUser;
    if (user == null) return null;

    // Member or owner of an active/completed project -> open the room.
    if ((_isMember || _isOwner) && (p.isActive || p.isCompleted)) {
      return _ctaBar(
        icon: Icons.meeting_room_rounded,
        label: 'Open Project Room',
        onTap: () => Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => CollaborationProjectScreen(collaborationId: p.id))),
      );
    }

    // Owner recruiting -> Start Project.
    if (_isOwner && p.isRecruiting) {
      final acceptedCount = _applications.where((a) => a.isAccepted).length;
      return _ctaBar(
        icon: Icons.rocket_launch_rounded,
        label: acceptedCount == 0
            ? 'Add teammates to start'
            : 'Start Project ($acceptedCount)',
        color: CAppTheme.successColor,
        enabled: acceptedCount > 0 && !_busy,
        onTap: _launch,
      );
    }

    // Visitor on a recruiting project -> apply.
    if (!_isOwner && p.isRecruiting) {
      if (_hasApplied) {
        return _ctaBar(
          icon: Icons.check_circle_rounded,
          label: 'Application submitted',
          enabled: false,
          onTap: () {},
        );
      }
      return _ctaBar(
        icon: Icons.assignment_ind_rounded,
        label: 'Apply for a role',
        enabled: !_busy,
        onTap: _apply,
      );
    }

    // Visitor on an active project (e.g. via link) -> request join.
    if (!_isOwner && !_isMember && p.isActive) {
      return _ctaBar(
        icon: Icons.group_add_rounded,
        label: 'Request to join',
        enabled: !_busy,
        onTap: _requestJoinActive,
      );
    }

    return null;
  }

  Widget _ctaBar({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
    bool enabled = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, boxShadow: CAppTheme.softShadow),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: color),
            onPressed: enabled ? onTap : null,
            icon: Icon(icon),
            label: Text(label),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ actions
  Future<void> _setStatus(CollaborationApplication app, String status) async {
    String? reason;
    if (status == 'rejected') {
      reason = await _askReason();
      if (reason == null) return; // cancelled
    }
    await _hub.setApplicationStatus(app,
        status: status, rejectReason: reason, projectTitle: _project!.title);
    _load();
  }

  Future<String?> _askReason() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CAppTheme.radiusXL)),
        title: const Text('Reject applicant?'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Reason (optional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: CAppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _messageApplicant(CollaborationApplication app) async {
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;
    final room = await _chat.getOrCreateChatRoom(
      user1Id: user.id,
      user2Id: app.userId,
      collaborationId: _project!.id,
    );
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatRoomId: room.id)));
  }

  Future<void> _launch() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CAppTheme.radiusXL)),
        title: const Text('Start project?'),
        content: const Text(
            'This builds your team, opens the group chat and moves the project to Active. You can still invite more people later.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: CAppTheme.successColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Start'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      final accepted = _applications.where((a) => a.isAccepted).toList();
      await _hub.launchProject(collaboration: _project!, acceptedApplications: accepted);
      if (!mounted) return;
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => CollaborationProjectScreen(collaborationId: _project!.id)));
    } catch (e) {
      setState(() => _busy = false);
      _toast('Failed to start: $e', isError: true);
    }
  }

  Future<void> _apply() async {
    final user = context.read<AuthController>().currentUser;
    if (user == null || _project == null) return;
    final result = await showModalBottomSheet<ApplyResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CollaborationApplySheet(roles: _roles, userSkills: user.skills ?? []),
    );
    if (result == null) return;
    setState(() => _busy = true);
    try {
      await _hub.apply(
        CollaborationApplication(
          id: _uuid.v4(),
          collaborationId: _project!.id,
          roleId: result.role?.id,
          roleTitle: result.role?.title,
          userId: user.id,
          userName: user.name,
          userEmail: user.email,
          userProfileImage: user.profileImageUrl,
          userSkills: user.skills ?? [],
          pitchMessage: result.pitch,
          availability: result.availability,
          proposedRate: result.proposedRate,
          createdAt: DateTime.now(),
        ),
        _project!.userId,
        _project!.title,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _hasApplied = true;
      });
      _toast('Application submitted!');
    } catch (e) {
      setState(() => _busy = false);
      _toast('Failed to apply: $e', isError: true);
    }
  }

  Future<void> _requestJoinActive() async {
    final user = context.read<AuthController>().currentUser;
    if (user == null || _project == null) return;
    setState(() => _busy = true);
    try {
      await _hub.joinActiveProject(
        collaboration: _project!,
        userId: user.id,
        userName: user.name,
        userImage: user.profileImageUrl,
        joinedVia: 'link',
      );
      if (!mounted) return;
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => CollaborationProjectScreen(collaborationId: _project!.id)));
    } catch (e) {
      setState(() => _busy = false);
      _toast('Failed to join: $e', isError: true);
    }
  }

  Future<void> _openInvite() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CollaborationInviteSheet(project: _project!),
    );
  }

  Future<void> _confirmDelete() async {
    if (_project == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CAppTheme.radiusXL)),
        title: const Text('Delete project?'),
        content: const Text(
            'This permanently removes the project, its roles, applications and invites. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: CAppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _collab.deleteCollaboration(_project!.id);
      if (!mounted) return;
      Navigator.pop(context, true);
      _toast('Project deleted');
    } catch (e) {
      _toast('Failed to delete: $e', isError: true);
    }
  }

  Future<void> _edit() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CollaborationCreateScreen(collaboration: _project)),
    );
    if (changed == true) _load();
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? CAppTheme.errorColor : CAppTheme.successColor,
    ));
  }
}
