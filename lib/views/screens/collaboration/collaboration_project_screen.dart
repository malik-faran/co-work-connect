import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';

import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/models/chat_model.dart';
import 'package:cwc/models/collaboration_model.dart';
import 'package:cwc/models/collaboration_hub_models.dart';
import 'package:cwc/services/chat_service.dart';
import 'package:cwc/services/collaboration_hub_service.dart';
import 'package:cwc/services/collaboration_service.dart';
import 'package:cwc/services/storage_service.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/views/screens/profile/public_profile_screen.dart';
import 'package:cwc/views/screens/user/user_home_screen.dart';
import 'package:cwc/views/widgets/collaboration_widgets.dart';
import 'package:cwc/services/collaboration_payment_service.dart';
import 'package:cwc/views/screens/collaboration/collaboration_milestone_payment_sheet.dart';
import 'package:cwc/views/screens/collaboration/collaboration_invite_sheet.dart';

/// The Project Room — the collaboration hub for an active project.
class CollaborationProjectScreen extends StatefulWidget {
  final String collaborationId;
  final int initialTab;
  const CollaborationProjectScreen({
    super.key,
    required this.collaborationId,
    this.initialTab = 0,
  });

  @override
  State<CollaborationProjectScreen> createState() => _CollaborationProjectScreenState();
}

class _CollaborationProjectScreenState extends State<CollaborationProjectScreen>
    with SingleTickerProviderStateMixin {
  final _hub = CollaborationHubService();
  final _collabService = CollaborationService();
  final _paymentService = CollaborationPaymentService();
  late final TabController _tabController;

  CollaborationModel? _project;
  List<CollaborationMember> _members = [];
  List<CollaborationMilestone> _milestones = [];
  List<CollaborationPayment> _payments = [];
  List<CollaborationRole> _roles = [];
  List<CollaborationFile> _files = [];
  List<CollaborationActivity> _activity = [];
  bool _isLoading = true;
  Timer? _autoRefreshTimer;
  bool _refreshInFlight = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 6,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 5),
    );
    _loadAll();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || _refreshInFlight) return;
      _refreshInFlight = true;
      _loadAll(showLoading: false).whenComplete(() => _refreshInFlight = false);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  String get _uid => context.read<AuthController>().currentUser?.id ?? '';
  bool get _isOwner => _project != null && _project!.userId == _uid;
  bool get _isContractFullySigned =>
      (_project?.isPaymentEnabled == false) ||
      (_members.isNotEmpty && _members.every((m) => m.hasAcceptedContract));
  String? get _milestoneLockReason {
    if (_isContractFullySigned) return null;
    final pending = _members.where((m) => !m.hasAcceptedContract).length;
    if (pending <= 0) return 'All team members must sign the project contract first.';
    return pending == 1
        ? '1 team member still needs to sign the project contract first.'
        : '$pending team members still need to sign the project contract first.';
  }

  Future<T?> _loadWithRetry<T>(
    Future<T> Function() loader, {
    int attempts = 2,
  }) async {
    Object? lastError;
    for (var i = 0; i < attempts; i++) {
      try {
        return await loader();
      } catch (e) {
        lastError = e;
        if (i < attempts - 1) {
          await Future.delayed(Duration(milliseconds: 400 * (i + 1)));
        }
      }
    }
    throw lastError ?? Exception('Request failed');
  }

  Future<void> _loadAll({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    final warnings = <String>[];
    CollaborationModel? project;
    try {
      project = await _loadWithRetry<CollaborationModel?>(
        () => _collabService.getCollaborationById(widget.collaborationId),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _toast('Failed to load project: $e', isError: true);
      return;
    }

    Future<T?> safeLoad<T>(Future<T> Function() loader, String label) async {
      try {
        return await _loadWithRetry(loader);
      } catch (e) {
        warnings.add(label);
        return null;
      }
    }

    final members = await safeLoad(
      () => _hub.getMembers(widget.collaborationId),
      'team members',
    );
    final milestones = await safeLoad(
      () => _hub.getMilestones(widget.collaborationId),
      'milestones',
    );
    final payments = await safeLoad(
      () => _paymentService.getPayments(widget.collaborationId),
      'payments',
    );
    final roles = await safeLoad(
      () => _hub.getRoles(widget.collaborationId),
      'roles',
    );
    final files = await safeLoad(
      () => _hub.getFiles(widget.collaborationId),
      'files',
    );
    final activity = await safeLoad(
      () => _hub.getActivity(widget.collaborationId),
      'activity',
    );
    try {
      await _hub.notifyOverdueMilestones(widget.collaborationId);
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _project = project;
      if (members != null) _members = members;
      if (milestones != null) _milestones = milestones;
      if (payments != null) _payments = payments;
      if (roles != null) _roles = roles;
      if (files != null) _files = files;
      if (activity != null) _activity = activity;
      _isLoading = false;
    });
    if (warnings.isNotEmpty) {
      _toast(
        'Some sections could not refresh (${warnings.join(', ')}). Pull to retry.',
        isError: true,
      );
    }
  }

  double get _progress {
    if (_milestones.isEmpty) return 0;
    final done = _milestones.where((m) => m.isDone).length;
    return done / _milestones.length;
  }

  String? get _projectCompleteBlockReason =>
      CollaborationMilestoneRules.projectCompleteBlockReason(_milestones);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 156,
            backgroundColor: CAppTheme.primaryColor,
            foregroundColor: Colors.white,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: Text(
              p.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                  fontSize: 16.5, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            actions: [
              if (_isOwner)
                IconButton(
                  icon: const Icon(Icons.ios_share_rounded),
                  tooltip: 'Invite',
                  onPressed: _openInviteSheet,
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (v) {
                  if (v == 'delete') _confirmDelete();
                  if (v == 'leave') _confirmLeave();
                },
                itemBuilder: (_) => [
                  if (_isOwner)
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
                  if (!_isOwner)
                    const PopupMenuItem(
                      value: 'leave',
                      child: Row(
                        children: [
                          Icon(Icons.logout_rounded,
                              color: CAppTheme.errorColor, size: 20),
                          SizedBox(width: 10),
                          Text('Leave team'),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeaderBackground(p),
              collapseMode: CollapseMode.parallax,
            ),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Team'),
                Tab(text: 'Milestones'),
                Tab(text: 'Files'),
                Tab(text: 'Chat'),
                Tab(text: 'Activity'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _OverviewTab(
              project: p,
              progress: _progress,
              members: _members,
              milestones: _milestones,
              payments: _payments,
              roles: _roles,
              milestoneCount: _milestones.length,
              isOwner: _isOwner,
              currentUserId: _uid,
              onRefresh: () => _loadAll(showLoading: false),
              onMarkComplete: _confirmComplete,
              projectCompleteBlockReason: _projectCompleteBlockReason,
              onEditMeetingLink: _editMeetingLink,
              onOpenMeeting: _openMeeting,
            ),
            _TeamTab(
              members: _members,
              isOwner: _isOwner,
              onInvite: _openInviteSheet,
              onTapMember: (m) => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: m.userId)),
              ),
              onRemoveMember: _confirmRemoveMember,
              onAddTeammate: _addTeammate,
            ),
            _MilestonesTab(
              milestones: _milestones,
              members: _members,
              progress: _progress,
              currentUserId: _uid,
              isOwner: _isOwner,
              canManageMilestones: _isOwner && _isContractFullySigned,
              lockReason: _milestoneLockReason,
              onAdd: _isOwner && _isContractFullySigned ? _addMilestone : null,
              onSubmit: _submitMilestone,
              onApprove: _approveMilestone,
              onReject: _isOwner ? _rejectMilestoneRequest : null,
              onEdit: _isOwner && _isContractFullySigned ? _editMilestone : null,
              onDelete: _isOwner && _isContractFullySigned ? _deleteMilestone : null,
            ),
            _FilesTab(
              files: _files,
              onUpload: _uploadFile,
              onOpen: _openFile,
              currentUserId: _uid,
              isOwner: _isOwner,
              onDelete: _deleteFile,
            ),
            _GroupChatTab(collaborationId: p.id, projectTitle: p.title),
            _ActivityTab(
              activity: _activity,
              onOpen: _openFromActivity,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBackground(CollaborationModel p) {
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
              colors: [Colors.black.withValues(alpha: 0.15), Colors.black.withValues(alpha: 0.55)],
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 58,
          child: Row(
            children: [
              StatusBadge(status: p.status, large: true),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(CAppTheme.radiusRound),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.group_rounded, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text('${_members.length} members',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------- actions
  Future<void> _openInviteSheet() async {
    if (_project == null) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CollaborationInviteSheet(project: _project!),
    );
  }

  Future<void> _addTeammate() async {
    if (_project == null) return;
    final viewer = context.read<AuthController>().currentUser;
    if (viewer == null) return;
    final existingIds = _members.map((m) => m.userId).toSet();
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddTeammateSheet(hub: _hub, excludeIds: existingIds),
    );
    if (selected == null) return;
    try {
      await _hub.sendInvite(CollaborationInvite(
        id: const Uuid().v4(),
        collaborationId: _project!.id,
        collaborationTitle: _project!.title,
        invitedBy: viewer.id,
        invitedByName: viewer.name,
        invitedUser: selected['id'] as String,
        createdAt: DateTime.now(),
      ));
      if (!mounted) return;
      _toast('Invite sent to ${selected['name'] ?? 'teammate'}. They join when they accept.');
      _loadAll(showLoading: false);
    } catch (e) {
      _toast('Failed to invite: $e', isError: true);
    }
  }

  Future<void> _confirmDelete() async {
    if (_project == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CAppTheme.radiusXL)),
        title: const Text('Delete project?'),
        content: const Text(
            'This permanently removes the project, its team, milestones, files and group chat. This cannot be undone.'),
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
      await _collabService.deleteCollaboration(_project!.id);
      if (!mounted) return;
      Navigator.pop(context, true);
      _toast('Project deleted');
    } catch (e) {
      _toast('Failed to delete: $e', isError: true);
    }
  }

  Future<void> _confirmRemoveMember(CollaborationMember member) async {
    if (_project == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CAppTheme.radiusXL)),
        title: Text('Remove ${member.userName}?'),
        content: const Text(
            'They will be removed from the team and the group chat. You can invite them again later.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: CAppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _hub.removeMember(_project!.id, member.userId, _project!.title);
      if (!mounted) return;
      _toast('${member.userName} removed from team');
      _loadAll(showLoading: false);
    } catch (e) {
      _toast('Failed to remove: $e', isError: true);
    }
  }

  Future<void> _confirmLeave() async {
    if (_project == null) return;
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CAppTheme.radiusXL)),
        title: const Text('Leave team?'),
        content: const Text(
            'You will be removed from this project and its group chat. You can re-join later if invited again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: CAppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _hub.removeMember(_project!.id, user.id, null);
      if (!mounted) return;
      Navigator.pop(context, true);
      _toast('You left the team');
    } catch (e) {
      _toast('Failed to leave: $e', isError: true);
    }
  }

  Future<void> _confirmComplete() async {
    final user = context.read<AuthController>().currentUser;
    if (user == null || _project == null) return;

    final blockReason = _projectCompleteBlockReason;
    if (blockReason != null) {
      _toast(blockReason, isError: true);
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CAppTheme.radiusXL)),
        title: const Text('Mark project complete?'),
        content: const Text('This marks the project as completed for the whole team.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: CAppTheme.successColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _hub.completeProject(_project!, user.name);
      _toast('Project marked as completed!');
      _loadAll();
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _editMeetingLink() async {
    final controller = TextEditingController(text: _project?.meetingLink ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CAppTheme.radiusXL)),
        title: const Text('Meeting link'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'https://meet.google.com/...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null) return;
    await _hub.updateMeetingLink(widget.collaborationId, result.isEmpty ? null : result);
    _loadAll();
  }

  Future<void> _openMeeting() async {
    final link = _project?.meetingLink;
    if (link == null || link.isEmpty) return;
    final uri = Uri.tryParse(link);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _toast('Could not open the link', isError: true);
    }
  }

  Future<void> _addMilestone() async {
    if (!_isOwner) {
      _toast('Only the project owner can create milestones.', isError: true);
      return;
    }
    if (!_isContractFullySigned) {
      _toast(_milestoneLockReason ?? 'Project contract must be signed first.', isError: true);
      return;
    }
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;
    final result = await showModalBottomSheet<_MilestoneDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMilestoneSheet(
        members: _members,
        enablePayments: _project?.isPaymentEnabled ?? true,
      ),
    );
    if (result == null) return;
    if (result.assignedTo == null) {
      _toast('Please assign the milestone to a teammate.', isError: true);
      return;
    }
    if (result.dueDate == null) {
      _toast('Please set a due date for the milestone.', isError: true);
      return;
    }
    await _hub.addMilestone(
      CollaborationMilestone(
      id: const Uuid().v4(),
      collaborationId: widget.collaborationId,
      title: result.title,
      description: result.description,
      dueDate: result.dueDate,
      assignedTo: result.assignedTo?.userId,
      assignedToName: result.assignedTo?.userName,
      amount: (_project?.isPaymentEnabled ?? true) ? result.amount : null,
      sortOrder: _milestones.length,
      createdAt: DateTime.now(),
    ),
      actorId: user.id,
      actorName: user.name,
    );
    _loadAll();
  }

  Future<void> _submitMilestone(CollaborationMilestone m) async {
    if (!_isContractFullySigned) {
      _toast(_milestoneLockReason ?? 'Project contract must be signed first.', isError: true);
      return;
    }
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;
    if (m.isMissed) {
      _toast('This milestone was missed. Ask the project owner to update the due date.', isError: true);
      return;
    }
    if (m.assignedTo != user.id || !m.isPending) {
      _toast('Only the assigned teammate can submit this milestone.', isError: true);
      return;
    }
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CAppTheme.radiusLarge)),
        title: Text('Submit milestone', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'What did you complete?',
            hintText: 'Describe the work, deliverables, or links...',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (note == null || note.isEmpty) {
      _toast('Please describe what you completed.', isError: true);
      return;
    }
    try {
      await _hub.submitMilestoneCompletion(
        m,
        user.id,
        user.name,
        submissionNote: note,
      );
      _loadAll();
      _toast('Milestone submitted for owner review.');
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _approveMilestone(CollaborationMilestone m) async {
    if (!_isOwner || !m.isSubmitted) return;
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CAppTheme.radiusLarge)),
        title: Text('Approve milestone?', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'Mark "${m.title}" as completed? The assignee will be notified.',
          style: GoogleFonts.poppins(fontSize: 14, color: CAppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: CAppTheme.successColor),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _hub.approveMilestoneCompletion(m, user.id, user.name);
      _loadAll();
      _toast('Milestone approved.');
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _rejectMilestoneRequest(CollaborationMilestone m) async {
    final user = context.read<AuthController>().currentUser;
    if (user == null || !_isOwner || !m.isSubmitted) return;
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject milestone request'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Tell collaborator what needs to be fixed...',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) {
      _toast('Please add a reason for rejection.', isError: true);
      return;
    }
    try {
      await _hub.rejectMilestoneCompletion(m, user.id, user.name, reason);
      _loadAll();
      _toast('Request rejected with feedback.');
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _editMilestone(CollaborationMilestone m) async {
    if (!_isOwner) {
      _toast('Only the project owner can edit milestones.', isError: true);
      return;
    }
    if (!_isContractFullySigned) {
      _toast(_milestoneLockReason ?? 'Project contract must be signed first.', isError: true);
      return;
    }
    final result = await showModalBottomSheet<_MilestoneDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMilestoneSheet(
        members: _members,
        initial: m,
        isEditing: true,
        enablePayments: _project?.isPaymentEnabled ?? true,
      ),
    );
    if (result == null) return;
    if (result.assignedTo == null || result.dueDate == null) {
      _toast('Assignee and due date are required.', isError: true);
      return;
    }
    final user = context.read<AuthController>().currentUser;
    await _hub.updateMilestone(
      m.copyWith(
        title: result.title,
        description: result.description,
        dueDate: result.dueDate,
        assignedTo: result.assignedTo!.userId,
        assignedToName: result.assignedTo!.userName,
        amount: (_project?.isPaymentEnabled ?? true) ? result.amount : null,
      ),
      actorId: user?.id,
      actorName: user?.name,
      previous: m,
    );
    _loadAll();
  }

  Future<void> _deleteMilestone(CollaborationMilestone m) async {
    if (!_isOwner) {
      _toast('Only the project owner can delete milestones.', isError: true);
      return;
    }
    if (!_isContractFullySigned) {
      _toast(_milestoneLockReason ?? 'Project contract must be signed first.', isError: true);
      return;
    }
    await _hub.deleteMilestone(m.id);
    _loadAll();
  }

  Future<void> _uploadFile() async {
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;
      _toast('Uploading...');
      final bytes = await picked.readAsBytes();
      final url = await StorageService().uploadCollaborationFile(
        collaborationId: widget.collaborationId,
        bytes: bytes,
        fileName: picked.name,
      );
      await _hub.addFile(
        CollaborationFile(
          id: const Uuid().v4(),
          collaborationId: widget.collaborationId,
          uploadedBy: user.id,
          uploaderName: user.name,
          fileName: picked.name,
          fileUrl: url,
          fileType: 'image',
          fileSize: bytes.length,
          createdAt: DateTime.now(),
        ),
        user.name,
      );
      _toast('File uploaded');
      _loadAll();
    } catch (e) {
      _toast('Upload failed: $e', isError: true);
    }
  }

  Future<void> _openFile(CollaborationFile f) async {
    final uri = Uri.tryParse(f.fileUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openFromActivity(CollaborationActivity activity) {
    switch (activity.action) {
      case 'milestone_done':
        _tabController.animateTo(2);
        final match = _milestones
            .where((m) => activity.detail != null && m.title == activity.detail)
            .toList();
        if (match.isNotEmpty) _showMilestoneDetail(match.first);
        break;
      case 'milestone_assigned':
        _tabController.animateTo(2);
        break;
      case 'milestone_missed':
        _tabController.animateTo(2);
        break;
      case 'file_uploaded':
        _tabController.animateTo(3);
        final match = _files
            .where((f) => activity.detail != null && f.fileName == activity.detail)
            .toList();
        if (match.isNotEmpty) _openFile(match.first);
        break;
      case 'joined':
        _tabController.animateTo(1);
        break;
      case 'launched':
      case 'completed':
        _tabController.animateTo(0);
        break;
    }
  }

  void _showMilestoneDetail(CollaborationMilestone milestone) {
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
            Text(milestone.title,
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
            if (milestone.description != null && milestone.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(milestone.description!,
                  style: GoogleFonts.poppins(fontSize: 14, color: CAppTheme.textSecondary)),
            ],
            const SizedBox(height: 12),
            if (milestone.assignedToName != null)
              Text('Assigned to: ${milestone.assignedToName}',
                  style: GoogleFonts.poppins(fontSize: 13)),
            if (milestone.dueDate != null)
              Text('Due: ${DateFormat('MMM d, yyyy').format(milestone.dueDate!)}',
                  style: GoogleFonts.poppins(fontSize: 13)),
            Text(
              milestone.isDone
                  ? 'Status: Completed'
                  : milestone.isMissed
                      ? 'Status: Missed'
                      : milestone.isOverdue
                          ? 'Status: Overdue'
                          : 'Status: Pending',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: milestone.isDone
                    ? CAppTheme.successColor
                    : milestone.isMissed
                        ? CAppTheme.errorColor
                        : milestone.isOverdue
                            ? CAppTheme.warningColor
                            : CAppTheme.warningColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteFile(CollaborationFile f) async {
    await _hub.deleteFile(f.id);
    _loadAll();
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? CAppTheme.errorColor : CAppTheme.successColor,
    ));
  }
}

// =========================================================================
// OVERVIEW TAB
// =========================================================================
class _OverviewTab extends StatelessWidget {
  final CollaborationModel project;
  final double progress;
  final List<CollaborationMember> members;
  final List<CollaborationMilestone> milestones;
  final List<CollaborationPayment> payments;
  final List<CollaborationRole> roles;
  final int milestoneCount;
  final bool isOwner;
  final String currentUserId;
  final VoidCallback onRefresh;
  final VoidCallback onMarkComplete;
  final String? projectCompleteBlockReason;
  final VoidCallback onEditMeetingLink;
  final VoidCallback onOpenMeeting;

  const _OverviewTab({
    required this.project,
    required this.progress,
    required this.members,
    required this.milestones,
    required this.payments,
    required this.roles,
    required this.milestoneCount,
    required this.isOwner,
    required this.currentUserId,
    required this.onRefresh,
    required this.onMarkComplete,
    this.projectCompleteBlockReason,
    required this.onEditMeetingLink,
    required this.onOpenMeeting,
  });

  int get memberCount => members.length;

  @override
  Widget build(BuildContext context) {
    final hasMeeting = project.meetingLink != null && project.meetingLink!.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ProgressRing(percent: progress, size: 72),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Project progress',
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: CAppTheme.textSecondary)),
                        const SizedBox(height: 4),
                        Text(
                          milestoneCount == 0
                              ? 'No milestones yet'
                              : '${(progress * 100).round()}% complete',
                          style: GoogleFonts.poppins(
                              fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text('$memberCount teammates · $milestoneCount milestones',
                            style: GoogleFonts.poppins(
                                fontSize: 12.5, color: CAppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(icon: Icons.description_rounded, title: 'About this project'),
              const SizedBox(height: 12),
              Text(project.description,
                  style: GoogleFonts.poppins(
                      fontSize: 14, height: 1.5, color: CAppTheme.textPrimary)),
              if (project.requiredSkills.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: project.requiredSkills.map((s) => SkillChip(label: s)).toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                icon: Icons.videocam_rounded,
                title: 'Meeting',
                trailing: isOwner
                    ? TextButton(
                        onPressed: onEditMeetingLink,
                        child: Text(hasMeeting ? 'Edit' : 'Add link'),
                      )
                    : null,
              ),
              const SizedBox(height: 8),
              if (hasMeeting)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onOpenMeeting,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Join meeting'),
                  ),
                )
              else
                Text('No meeting link yet. The owner can add a Google Meet / Zoom link.',
                    style: GoogleFonts.poppins(fontSize: 13, color: CAppTheme.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (project.isPaymentEnabled) ...[
          _ProjectContractCard(
            project: project,
            members: members,
            milestones: milestones,
            payments: payments,
            roles: roles,
            isOwner: isOwner,
            currentUserId: currentUserId,
            onRefresh: onRefresh,
          ),
          const SizedBox(height: 14),
        ],
        SectionCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: CAppTheme.infoColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                ),
                child: const Icon(Icons.meeting_room_rounded, color: CAppTheme.infoColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Need a place to meet?',
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    Text('Book a coworking space for your team',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: CAppTheme.textSecondary)),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => UserHomeScreen.goToTab(context, 1),
                child: const Text('Browse'),
              ),
            ],
          ),
        ),
        if (isOwner && !project.isCompleted) ...[
          const SizedBox(height: 18),
          if (projectCompleteBlockReason != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CAppTheme.warningColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                border: Border.all(color: CAppTheme.warningColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: CAppTheme.warningColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      projectCompleteBlockReason!,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: CAppTheme.warningColor,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: CAppTheme.successColor,
                disabledBackgroundColor: CAppTheme.successColor.withValues(alpha: 0.4),
              ),
              onPressed: projectCompleteBlockReason == null ? onMarkComplete : null,
              icon: const Icon(Icons.verified_rounded),
              label: const Text('Mark project complete'),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

// =========================================================================
// TEAM TAB
// =========================================================================
class _TeamTab extends StatelessWidget {
  final List<CollaborationMember> members;
  final bool isOwner;
  final VoidCallback onInvite;
  final VoidCallback onAddTeammate;
  final ValueChanged<CollaborationMember> onTapMember;
  final ValueChanged<CollaborationMember> onRemoveMember;

  const _TeamTab({
    required this.members,
    required this.isOwner,
    required this.onInvite,
    required this.onAddTeammate,
    required this.onTapMember,
    required this.onRemoveMember,
  });

  @override
  Widget build(BuildContext context) {
    final compactBtn = ButtonStyle(
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      minimumSize: WidgetStateProperty.all(Size.zero),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      textStyle: WidgetStateProperty.all(
        GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (isOwner) ...[
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom().merge(compactBtn),
                  onPressed: onInvite,
                  icon: const Icon(Icons.link_rounded, size: 16),
                  label: const Text('Share link'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom().merge(compactBtn),
                  onPressed: onAddTeammate,
                  icon: const Icon(Icons.person_add_alt_rounded, size: 16),
                  label: const Text('Add teammate'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        ...members.map((m) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: SectionCard(
                padding: const EdgeInsets.all(12),
                child: InkWell(
                  onTap: () => onTapMember(m),
                  borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                  child: Row(
                    children: [
                      UserAvatar(
                        name: m.userName,
                        imageUrl: m.userProfileImage,
                        size: 46,
                        ringColor: m.isOwner ? CAppTheme.primaryColor : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.userName,
                                style: GoogleFonts.poppins(
                                    fontSize: 14.5, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              m.isOwner ? 'Project Lead' : (m.roleTitle ?? 'Member'),
                              style: GoogleFonts.poppins(
                                  fontSize: 12.5, color: CAppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (m.isOwner)
                        const Icon(Icons.workspace_premium_rounded,
                            color: CAppTheme.primaryColor, size: 20)
                      else if (isOwner)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded,
                              color: CAppTheme.textTertiary),
                          onSelected: (v) {
                            if (v == 'remove') onRemoveMember(m);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'remove',
                              child: Row(
                                children: [
                                  Icon(Icons.person_remove_rounded,
                                      color: CAppTheme.errorColor, size: 20),
                                  SizedBox(width: 10),
                                  Text('Remove from team'),
                                ],
                              ),
                            ),
                          ],
                        )
                      else
                        const Icon(Icons.chevron_right_rounded, color: CAppTheme.textTertiary),
                    ],
                  ),
                ),
              ),
            )),
      ],
    );
  }
}

// =========================================================================
// MILESTONES TAB
// =========================================================================
class _MilestonesTab extends StatelessWidget {
  final List<CollaborationMilestone> milestones;
  final List<CollaborationMember> members;
  final double progress;
  final String currentUserId;
  final bool isOwner;
  final bool canManageMilestones;
  final String? lockReason;
  final VoidCallback? onAdd;
  final ValueChanged<CollaborationMilestone> onSubmit;
  final ValueChanged<CollaborationMilestone> onApprove;
  final ValueChanged<CollaborationMilestone>? onReject;
  final ValueChanged<CollaborationMilestone>? onEdit;
  final ValueChanged<CollaborationMilestone>? onDelete;

  const _MilestonesTab({
    required this.milestones,
    required this.members,
    required this.progress,
    required this.currentUserId,
    required this.isOwner,
    required this.canManageMilestones,
    this.lockReason,
    this.onAdd,
    required this.onSubmit,
    required this.onApprove,
    this.onReject,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final lockCard = (!canManageMilestones && lockReason != null)
        ? Container(
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: SectionCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_outline_rounded,
                      size: 18, color: CAppTheme.warningColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Contract signing required: $lockReason',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: CAppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        : const SizedBox.shrink();

    return Stack(
      children: [
        milestones.isEmpty
            ? Column(
                children: [
                  lockCard,
                  Expanded(
                    child: EmptyState(
                      icon: Icons.flag_rounded,
                      title: 'No milestones yet',
                      subtitle: canManageMilestones
                          ? 'Break the project into clear, trackable milestones.'
                          : isOwner
                              ? 'Sign the project contract first, then set milestones.'
                              : 'Milestones will appear here once the owner adds them.',
                      action: canManageMilestones
                          ? ElevatedButton.icon(
                              onPressed: onAdd,
                              icon: const Icon(Icons.add),
                              label: const Text('Add milestone'),
                            )
                          : null,
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                children: [
                  if (!canManageMilestones && lockReason != null) ...[
                    SectionCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lock_outline_rounded,
                              size: 18, color: CAppTheme.warningColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Contract signing required: $lockReason',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: CAppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _teamMilestoneSummary(),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                    backgroundColor: CAppTheme.borderColor,
                    color: progress >= 1 ? CAppTheme.successColor : CAppTheme.primaryColor,
                  ),
                  const SizedBox(height: 16),
                  ...milestones.map((m) => _milestoneCard(context, m)),
                ],
              ),
        if (canManageMilestones)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Milestone'),
            ),
          ),
      ],
    );
  }

  Widget _teamMilestoneSummary() {
    final grouped = <String, List<CollaborationMilestone>>{};
    for (final m in milestones) {
      final key = m.assignedToName ?? 'Unassigned';
      grouped.putIfAbsent(key, () => []).add(m);
    }
    return SectionCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Team milestones',
              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Pending and completed work across all members',
              style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.textSecondary)),
          const SizedBox(height: 12),
          ...grouped.entries.map((entry) {
            final done = entry.value.where((m) => m.isDone).length;
            final missed = entry.value.where((m) => m.isMissed).length;
            final total = entry.value.length;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CAppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(entry.key,
                            style: GoogleFonts.poppins(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                      Text(
                        missed > 0 ? '$done/$total done · $missed missed' : '$done/$total done',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: missed > 0
                                  ? CAppTheme.errorColor
                                  : done == total
                                      ? CAppTheme.successColor
                                      : CAppTheme.primaryColor)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...entry.value.map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(
                            m.isDone
                                ? Icons.check_circle_rounded
                                : m.isMissed
                                    ? Icons.cancel_rounded
                                    : Icons.radio_button_unchecked,
                            size: 16,
                            color: m.isDone
                                ? CAppTheme.successColor
                                : m.isMissed
                                    ? CAppTheme.errorColor
                                    : CAppTheme.textTertiary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              m.title,
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                decoration: m.isDone ? TextDecoration.lineThrough : null,
                                color: m.isDone ? CAppTheme.textTertiary : CAppTheme.textPrimary,
                              ),
                            ),
                          ),
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

  Widget _milestoneCard(BuildContext context, CollaborationMilestone m) {
    final isAssignee = m.assignedTo == currentUserId;
    final canSubmit = isAssignee && m.isPending && !m.isMissed;
    final canApprove = isOwner && m.isSubmitted;
    final canReject = isOwner && m.isSubmitted && onReject != null;
    final borderColor = m.isMissed
        ? CAppTheme.errorColor.withValues(alpha: 0.35)
        : m.isOverdue
            ? CAppTheme.warningColor.withValues(alpha: 0.35)
            : m.isDone
                ? CAppTheme.successColor.withValues(alpha: 0.2)
                : m.isSubmitted
                    ? CAppTheme.infoColor.withValues(alpha: 0.25)
                    : CAppTheme.borderColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: SectionCard(
        padding: const EdgeInsets.all(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
            border: Border.all(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: m.isDone
                        ? CAppTheme.successColor
                        : m.isSubmitted
                            ? CAppTheme.infoColor.withValues(alpha: 0.15)
                            : m.isMissed
                                ? CAppTheme.errorColor.withValues(alpha: 0.15)
                                : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: m.isDone
                          ? CAppTheme.successColor
                          : m.isSubmitted
                              ? CAppTheme.infoColor
                              : m.isMissed
                                  ? CAppTheme.errorColor
                                  : CAppTheme.borderColor,
                      width: 2,
                    ),
                  ),
                  child: m.isDone
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : m.isSubmitted
                          ? const Icon(Icons.hourglass_top_rounded, size: 14, color: CAppTheme.infoColor)
                          : m.isMissed
                              ? const Icon(Icons.close, size: 14, color: CAppTheme.errorColor)
                              : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              m.title,
                              style: GoogleFonts.poppins(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                decoration: m.isDone ? TextDecoration.lineThrough : null,
                                color: m.isDone
                                    ? CAppTheme.textTertiary
                                    : m.isMissed
                                        ? CAppTheme.errorColor
                                        : CAppTheme.textPrimary,
                              ),
                            ),
                          ),
                          _milestoneStatusChip(m),
                        ],
                      ),
                      if (m.description != null && m.description!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(m.description!,
                            style: GoogleFonts.poppins(
                                fontSize: 12.5, color: CAppTheme.textSecondary)),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (m.assignedToName != null)
                            _tag(Icons.person_rounded, m.assignedToName!),
                          if (m.dueDate != null)
                            _tag(
                              Icons.event_rounded,
                              DateFormat('MMM d, yyyy · h:mm a').format(m.dueDate!),
                            ),
                        ],
                      ),
                      if (m.submissionNote != null && m.submissionNote!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: CAppTheme.infoColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(CAppTheme.radiusSmall),
                            border: Border.all(
                              color: CAppTheme.infoColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Submitted work',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: CAppTheme.infoColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                m.submissionNote!,
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  color: CAppTheme.textPrimary,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (m.reviewReason != null && m.reviewReason!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: CAppTheme.errorColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(CAppTheme.radiusSmall),
                            border: Border.all(
                              color: CAppTheme.errorColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Owner feedback',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: CAppTheme.errorColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                m.reviewReason!,
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  color: CAppTheme.textPrimary,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (canSubmit) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => onSubmit(m),
                            icon: const Icon(Icons.upload_file_rounded, size: 18),
                            label: const Text('Submit work'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: CAppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                      if (canApprove || canReject) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            if (canApprove)
                              Expanded(
                                child: SizedBox(
                                  height: 42,
                                  child: ElevatedButton(
                                    onPressed: () => onApprove(m),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: CAppTheme.successColor,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          CAppTheme.radiusMedium,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      'Approve',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (canApprove && canReject) const SizedBox(width: 10),
                            if (canReject)
                              Expanded(
                                child: SizedBox(
                                  height: 42,
                                  child: OutlinedButton(
                                    onPressed: () => onReject!(m),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: CAppTheme.errorColor,
                                      side: BorderSide(
                                        color: CAppTheme.errorColor.withValues(alpha: 0.55),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          CAppTheme.radiusMedium,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      'Reject',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                      if (m.isMissed) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Not completed on time. Owner can extend the due date to reopen.',
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            color: CAppTheme.errorColor,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        size: 20, color: CAppTheme.textTertiary),
                    onPressed: () => onEdit!(m),
                    tooltip: 'Edit milestone',
                  ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 20, color: CAppTheme.textTertiary),
                    onPressed: () => onDelete!(m),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _milestoneStatusChip(CollaborationMilestone m) {
    final Color color;
    final String label;
    if (m.isDone) {
      color = CAppTheme.successColor;
      label = 'Done';
    } else if (m.isSubmitted) {
      color = CAppTheme.infoColor;
      label = 'Awaiting approval';
    } else if (m.isMissed) {
      color = CAppTheme.errorColor;
      label = 'Missed';
    } else if (m.isOverdue) {
      color = CAppTheme.warningColor;
      label = 'Overdue';
    } else {
      color = CAppTheme.textSecondary;
      label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(CAppTheme.radiusRound),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _tag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: CAppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(CAppTheme.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: CAppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(text, style: GoogleFonts.poppins(fontSize: 11.5, color: CAppTheme.textSecondary)),
        ],
      ),
    );
  }
}

// =========================================================================
// FILES TAB
// =========================================================================
class _FilesTab extends StatelessWidget {
  final List<CollaborationFile> files;
  final VoidCallback onUpload;
  final ValueChanged<CollaborationFile> onOpen;
  final ValueChanged<CollaborationFile> onDelete;
  final String currentUserId;
  final bool isOwner;

  const _FilesTab({
    required this.files,
    required this.onUpload,
    required this.onOpen,
    required this.onDelete,
    required this.currentUserId,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        files.isEmpty
            ? EmptyState(
                icon: Icons.folder_open_rounded,
                title: 'No shared files',
                subtitle: 'Upload designs, screenshots and resources for your team.',
                action: ElevatedButton.icon(
                  onPressed: onUpload,
                  icon: const Icon(Icons.upload_rounded),
                  label: const Text('Upload file'),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                children: files.map((f) => _fileCard(context, f)).toList(),
              ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: onUpload,
            icon: const Icon(Icons.upload_rounded),
            label: const Text('Upload'),
          ),
        ),
      ],
    );
  }

  Widget _fileCard(BuildContext context, CollaborationFile f) {
    final canDelete = isOwner || f.uploadedBy == currentUserId;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: SectionCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: CAppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
              ),
              child: const Icon(Icons.insert_drive_file_rounded, color: CAppTheme.primaryColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    '${f.uploaderName ?? 'Someone'} · ${_size(f.fileSize)}',
                    style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_new_rounded, size: 20),
              color: CAppTheme.primaryColor,
              onPressed: () => onOpen(f),
            ),
            if (canDelete)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: CAppTheme.textTertiary,
                onPressed: () => onDelete(f),
              ),
          ],
        ),
      ),
    );
  }

  String _size(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// =========================================================================
// GROUP CHAT TAB
// =========================================================================
class _GroupChatTab extends StatefulWidget {
  final String collaborationId;
  final String projectTitle;
  const _GroupChatTab({required this.collaborationId, required this.projectTitle});

  @override
  State<_GroupChatTab> createState() => _GroupChatTabState();
}

class _GroupChatTabState extends State<_GroupChatTab> {
  final _chat = ChatService();
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  ChatRoomModel? _room;
  List<ChatMessageModel> _messages = [];
  StreamSubscription? _sub;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final room = await _chat.getGroupRoomForCollaboration(widget.collaborationId);
    if (!mounted) return;
    setState(() {
      _room = room;
      _loading = false;
    });
    if (room != null) {
      _sub = _chat.getMessagesStream(room.id).listen((msgs) {
        if (mounted) {
          setState(() => _messages = msgs);
          WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());
        }
      });
    }
  }

  void _toBottom() {
    if (_scroll.hasClients) {
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _room == null) return;
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;
    _controller.clear();
    await _chat.sendMessage(ChatMessageModel(
      id: const Uuid().v4(),
      chatRoomId: _room!.id,
      senderId: user.id,
      senderName: user.name,
      senderProfileImage: user.profileImageUrl,
      message: text,
      createdAt: DateTime.now(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: CAppTheme.primaryColor));
    }
    if (_room == null) {
      return const EmptyState(
        icon: Icons.forum_rounded,
        title: 'Group chat not ready',
        subtitle: 'The team chat opens once the project is launched.',
      );
    }
    final uid = context.read<AuthController>().currentUser?.id ?? '';
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? const EmptyState(
                  icon: Icons.forum_rounded,
                  title: 'Say hello to your team',
                  subtitle: 'This is the start of your project conversation.',
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final m = _messages[i];
                    final mine = m.senderId == uid;
                    return _bubble(m, mine);
                  },
                ),
        ),
        _composer(),
      ],
    );
  }

  Widget _bubble(ChatMessageModel m, bool mine) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mine) ...[
            UserAvatar(name: m.senderName, imageUrl: m.senderProfileImage, size: 32),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: mine ? CAppTheme.primaryColor : CAppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(CAppTheme.radiusLarge).copyWith(
                  bottomRight: mine ? const Radius.circular(4) : null,
                  bottomLeft: !mine ? const Radius.circular(4) : null,
                ),
                boxShadow: CAppTheme.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!mine)
                    Text(m.senderName.split(' ').first,
                        style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: CAppTheme.primaryColor)),
                  Text(
                    m.message,
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: mine ? Colors.white : CAppTheme.textPrimary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _composer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: CAppTheme.surfaceColor,
        boxShadow: CAppTheme.softShadow,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Message your team...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  filled: true,
                  fillColor: CAppTheme.backgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(CAppTheme.radiusRound),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 24,
              backgroundColor: CAppTheme.primaryColor,
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: _send,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// ACTIVITY TAB
// =========================================================================
class _ActivityTab extends StatelessWidget {
  final List<CollaborationActivity> activity;
  final ValueChanged<CollaborationActivity>? onOpen;
  const _ActivityTab({required this.activity, this.onOpen});

  @override
  Widget build(BuildContext context) {
    if (activity.isEmpty) {
      return const EmptyState(
        icon: Icons.history_rounded,
        title: 'No activity yet',
        subtitle: 'Team actions like milestones and uploads appear here.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: activity.length,
      itemBuilder: (_, i) {
        final a = activity[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
            child: InkWell(
              borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
              onTap: onOpen == null ? null : () => onOpen!(a),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _color(a.action).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_icon(a.action), size: 18, color: _color(a.action)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.poppins(
                                  fontSize: 13.5, color: CAppTheme.textPrimary),
                              children: [
                                TextSpan(
                                    text: a.actorName ?? 'Someone',
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                TextSpan(text: ' ${_label(a.action)}'),
                                if (a.detail != null)
                                  TextSpan(
                                      text: ' "${a.detail}"',
                                      style: TextStyle(color: CAppTheme.textSecondary)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(DateFormat('MMM d, h:mm a').format(a.createdAt),
                              style: GoogleFonts.poppins(
                                  fontSize: 11.5, color: CAppTheme.textTertiary)),
                          if (onOpen != null) ...[
                            const SizedBox(height: 4),
                            Text('Tap to open',
                                style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: CAppTheme.primaryColor)),
                          ],
                        ],
                      ),
                    ),
                    if (onOpen != null)
                      const Icon(Icons.chevron_right_rounded, color: CAppTheme.textTertiary),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _label(String action) {
    switch (action) {
      case 'joined':
        return 'joined the team';
      case 'milestone_done':
        return 'completed milestone';
      case 'milestone_assigned':
        return 'assigned milestone';
      case 'milestone_missed':
        return 'missed milestone';
      case 'file_uploaded':
        return 'uploaded';
      case 'launched':
        return 'launched the project';
      case 'completed':
        return 'completed the project';
      default:
        return action;
    }
  }

  IconData _icon(String action) {
    switch (action) {
      case 'joined':
        return Icons.person_add_rounded;
      case 'milestone_done':
        return Icons.check_circle_rounded;
      case 'milestone_assigned':
        return Icons.assignment_ind_rounded;
      case 'milestone_missed':
        return Icons.warning_amber_rounded;
      case 'file_uploaded':
        return Icons.upload_file_rounded;
      case 'launched':
        return Icons.rocket_launch_rounded;
      case 'completed':
        return Icons.verified_rounded;
      default:
        return Icons.circle_notifications_rounded;
    }
  }

  Color _color(String action) {
    switch (action) {
      case 'milestone_done':
      case 'completed':
        return CAppTheme.successColor;
      case 'milestone_assigned':
        return CAppTheme.infoColor;
      case 'milestone_missed':
        return CAppTheme.errorColor;
      case 'launched':
        return CAppTheme.primaryColor;
      case 'file_uploaded':
        return CAppTheme.infoColor;
      default:
        return CAppTheme.secondaryColor;
    }
  }
}

// =========================================================================
// Add milestone bottom sheet
// =========================================================================
class _MilestoneDraft {
  final String title;
  final String? description;
  final DateTime? dueDate;
  final CollaborationMember? assignedTo;
  final double? amount;
  _MilestoneDraft(this.title, this.description, this.dueDate, this.assignedTo, this.amount);
}

class _AddMilestoneSheet extends StatefulWidget {
  final List<CollaborationMember> members;
  final CollaborationMilestone? initial;
  final bool isEditing;
  final bool enablePayments;

  const _AddMilestoneSheet({
    required this.members,
    this.initial,
    this.isEditing = false,
    this.enablePayments = true,
  });

  @override
  State<_AddMilestoneSheet> createState() => _AddMilestoneSheetState();
}

class _AddMilestoneSheetState extends State<_AddMilestoneSheet> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _amount = TextEditingController();
  DateTime? _due;
  CollaborationMember? _assignee;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _title.text = initial.title;
      _desc.text = initial.description ?? '';
      if (initial.amount != null && initial.amount! > 0) {
        _amount.text = initial.amount!.toStringAsFixed(0);
      }
      _due = initial.dueDate;
      if (initial.assignedTo != null) {
        for (final m in widget.members) {
          if (m.userId == initial.assignedTo) {
            _assignee = m;
            break;
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDueDateTime() async {
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _due ?? todayOnly,
      firstDate: todayOnly,
      lastDate: todayOnly.add(const Duration(days: 365 * 2)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_due ?? now.add(const Duration(hours: 1))),
    );
    if (pickedTime == null) return;

    setState(() {
      _due = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final members = widget.members;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;
    final canSubmit =
        _title.text.trim().isNotEmpty && _due != null && _assignee != null;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottomInset),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
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
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.isEditing ? 'Edit milestone' : 'New milestone',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _title,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Title *',
                        hintText: 'e.g. Build login screen',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _desc,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Description (optional)'),
                    ),
                    if (widget.enablePayments) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _amount,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Payment amount (PKR)',
                          hintText: 'e.g. 5000',
                          prefixText: 'Rs. ',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _pickDueDateTime,
                        icon: const Icon(Icons.event_rounded, size: 18),
                        label: Text(
                          _due == null
                              ? 'Due date & time *'
                              : DateFormat('MMM d, yyyy · h:mm a').format(_due!),
                        ),
                      ),
                    ),
                    if (members.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<CollaborationMember>(
                        value: _assignee != null &&
                                members.any((m) => m.userId == _assignee!.userId)
                            ? members.firstWhere((m) => m.userId == _assignee!.userId)
                            : null,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Assign to *'),
                        items: members
                            .map((m) => DropdownMenuItem(
                                  value: m,
                                  child: Text('${m.userName}${m.isOwner ? ' (Owner)' : ''}'),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _assignee = v),
                      ),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Add teammates before creating milestones.',
                          style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.errorColor),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (!canSubmit)
                      Text(
                        'Title, due date, and assignee are required.',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          color: CAppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: canSubmit
                        ? [
                            BoxShadow(
                              color: CAppTheme.primaryColor.withValues(alpha: 0.22),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : const [],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: canSubmit
                          ? () {
                              final parsedAmount = widget.enablePayments
                                  ? double.tryParse(_amount.text.replaceAll(',', '').trim())
                                  : null;
                              Navigator.pop(
                                context,
                                _MilestoneDraft(
                                  _title.text.trim(),
                                  _desc.text.trim().isEmpty ? null : _desc.text.trim(),
                                  _due,
                                  _assignee,
                                  parsedAmount != null && parsedAmount > 0 ? parsedAmount : null,
                                ),
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: CAppTheme.primaryColor,
                        disabledBackgroundColor: CAppTheme.borderColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        widget.isEditing ? 'Save changes' : 'Add milestone',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet to pick an open-to-collaborate user and invite them to the
/// project. Works for active projects too — the user joins on accepting.
class _AddTeammateSheet extends StatefulWidget {
  final CollaborationHubService hub;
  final Set<String> excludeIds;
  const _AddTeammateSheet({required this.hub, required this.excludeIds});

  @override
  State<_AddTeammateSheet> createState() => _AddTeammateSheetState();
}

class _AddTeammateSheetState extends State<_AddTeammateSheet> {
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await widget.hub.getOpenTeammates();
      list.removeWhere((u) => widget.excludeIds.contains(u['id']));
      if (mounted) setState(() {
        _all = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _q.isEmpty
        ? _all
        : _all
            .where((u) => (u['name'] ?? '')
                .toString()
                .toLowerCase()
                .contains(_q.toLowerCase()))
            .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
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
            const SizedBox(height: 16),
            Text('Add a teammate',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
                'Invite someone who is open to collaborate. They join once they accept.',
                style: GoogleFonts.poppins(
                    fontSize: 12.5, color: CAppTheme.textSecondary)),
            const SizedBox(height: 14),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search people...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: CAppTheme.primaryColor)),
                    )
                  : filtered.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text('No open teammates found.',
                                style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: CAppTheme.textSecondary)),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final u = filtered[i];
                            final skills =
                                (u['skills'] as List?)?.cast<String>() ?? [];
                            final subtitle = skills.isEmpty
                                ? (u['collaboration_headline'] ?? '')
                                    .toString()
                                : skills.take(3).join(' · ');
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: UserAvatar(
                                name: u['name'],
                                imageUrl: u['profile_image_url'],
                                size: 44,
                              ),
                              title: Text(u['name'] ?? 'User',
                                  style: GoogleFonts.poppins(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600)),
                              subtitle: subtitle.isEmpty
                                  ? null
                                  : Text(subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: CAppTheme.textSecondary)),
                              trailing: ElevatedButton(
                                onPressed: () => Navigator.pop(context, u),
                                style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8)),
                                child: const Text('Invite'),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// PROJECT CONTRACT
// =========================================================================
class _ProjectContractCard extends StatefulWidget {
  final CollaborationModel project;
  final List<CollaborationMember> members;
  final List<CollaborationMilestone> milestones;
  final List<CollaborationPayment> payments;
  final List<CollaborationRole> roles;
  final bool isOwner;
  final String currentUserId;
  final VoidCallback onRefresh;

  const _ProjectContractCard({
    required this.project,
    required this.members,
    required this.milestones,
    required this.payments,
    required this.roles,
    required this.isOwner,
    required this.currentUserId,
    required this.onRefresh,
  });

  @override
  State<_ProjectContractCard> createState() => _ProjectContractCardState();
}

class _ProjectContractCardState extends State<_ProjectContractCard> {
  final _hub = CollaborationHubService();
  final _payService = CollaborationPaymentService();
  bool _busy = false;
  bool _agreedToTerms = false;

  static const Color _fiverrGreen = Color(0xFF1DBF73);

  String _fmt(double v) => NumberFormat('#,##0').format(v);

  CollaborationPayment? _paymentFor(String milestoneId) =>
      _payService.paymentForMilestone(widget.payments, milestoneId);

  CollaborationMember? get _myMembership {
    for (final m in widget.members) {
      if (m.userId == widget.currentUserId) return m;
    }
    return null;
  }

  int get _acceptedCount =>
      widget.members.where((m) => m.hasAcceptedContract).length;

  String get _contractRef =>
      widget.project.id.replaceAll('-', '').substring(0, 8).toUpperCase();

  String get _defaultTerms =>
      '• All members commit to honest communication and timely updates.\n'
      '• Work shared in the project room stays confidential to the team.\n'
      '• Disputes should be raised with the project lead first.\n'
      '• Either party may leave with notice via the project room.';

  Future<void> _editTerms() async {
    final controller = TextEditingController(text: widget.project.contractTerms ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CAppTheme.radiusLarge)),
        title: Text('Custom contract terms', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            minLines: 5,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: 'Add payment rules, deliverables, IP ownership, etc.',
              alignLabelWithHint: true,
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) return;
    setState(() => _busy = true);
    try {
      await _hub.updateContractTerms(widget.project.id, controller.text.trim());
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contract terms updated'), backgroundColor: CAppTheme.successColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: CAppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _acceptContract() async {
    if (widget.currentUserId.isEmpty) return;
    if (_myMembership == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be on the project team before signing the contract.'),
            backgroundColor: CAppTheme.errorColor,
          ),
        );
      }
      return;
    }
    setState(() => _busy = true);
    try {
      await _hub.acceptProjectContract(widget.project.id, widget.currentUserId);
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contract accepted'), backgroundColor: CAppTheme.successColor),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst(RegExp(r'^PostgrestException:\s*'), '')
            .replaceFirst(RegExp(r'^.*message:\s*'), '')
            .replaceAll(RegExp(r', code:.*'), '')
            .trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg.isEmpty ? 'Could not sign contract' : msg),
            backgroundColor: CAppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fundMilestone(CollaborationMilestone m) async {
    final pay = _paymentFor(m.id);
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CollaborationMilestonePaymentSheet(
        milestone: m,
        existingPayment: pay,
      ),
    );
    if (result == true) widget.onRefresh();
  }

  String _paymentErrorMessage(Object e) {
    final raw = e.toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst(RegExp(r'^PostgrestException:\s*'), '')
        .replaceFirst(RegExp(r'^.*message:\s*'), '')
        .replaceAll(RegExp(r', code:.*'), '')
        .trim();
    if (raw.contains('No held payment found')) {
      return 'No escrow payment is held for this milestone. Fund it first, or refresh if it was already released.';
    }
    if (raw.contains('Complete the milestone before releasing payment')) {
      return 'Approve the milestone before releasing payment.';
    }
    return raw.isEmpty ? 'Could not release payment' : raw;
  }

  Future<void> _releasePayment(CollaborationMilestone m) async {
    setState(() => _busy = true);
    try {
      final freshPay = await _payService.getPaymentForMilestone(m.id);
      if (freshPay == null) {
        throw Exception('No escrow payment is held for this milestone. Fund it first.');
      }
      if (freshPay.isReleased) {
        widget.onRefresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment was already released'),
              backgroundColor: CAppTheme.successColor,
            ),
          );
        }
        return;
      }
      if (!freshPay.isHeld) {
        throw Exception('This milestone payment is not in escrow (${freshPay.status}).');
      }
      if (!m.isDone) {
        throw Exception('Approve the milestone before releasing payment.');
      }
      await _payService.releaseMilestonePayment(m.id);
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment released to collaborator'),
            backgroundColor: CAppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_paymentErrorMessage(e)),
            backgroundColor: CAppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.project;
    final isPaymentEnabled = p.isPaymentEnabled;
    final effectiveDate = p.launchedAt ?? p.createdAt;
    final terms = (p.contractTerms != null && p.contractTerms!.trim().isNotEmpty)
        ? p.contractTerms!.trim()
        : _defaultTerms;
    final me = _myMembership;
    final canAccept = me != null && !me.hasAcceptedContract;
    final milestoneTotal = widget.milestones.fold<double>(
      0,
      (sum, m) => sum + (m.amount ?? 0),
    );
    final heldTotal = widget.payments
        .where((pay) => pay.isHeld)
        .fold<double>(0, (sum, pay) => sum + pay.amount);
    final releasedTotal = widget.payments
        .where((pay) => pay.isReleased)
        .fold<double>(0, (sum, pay) => sum + pay.amount);
    final hasTimeline = p.timeline != null && p.timeline!.trim().isNotEmpty;
    final signProgress = widget.members.isEmpty
        ? 0.0
        : _acceptedCount / widget.members.length;

    return SectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // —— Order header (Fiverr-style) ——
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPaymentEnabled
                                ? 'ORDER #CWC-$_contractRef'
                                : 'PROJECT AGREEMENT #CWC-$_contractRef',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: CAppTheme.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            p.title,
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: CAppTheme.textPrimary,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Started ${DateFormat('MMM d, yyyy').format(effectiveDate)}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: CAppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(status: p.status),
                  ],
                ),
                if (widget.isOwner) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _busy ? null : _editTerms,
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: const Text('Edit agreement terms'),
                      style: TextButton.styleFrom(
                        foregroundColor: CAppTheme.primaryColor,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // —— Payment / collaboration summary ——
                _orderSummaryCard(
                  displayBudget: p.displayBudget,
                  milestoneTotal: milestoneTotal,
                  heldTotal: heldTotal,
                  releasedTotal: releasedTotal,
                  timeline: hasTimeline ? p.timeline!.trim() : null,
                  milestoneCount: widget.milestones.length,
                  isPaymentEnabled: isPaymentEnabled,
                ),
                const SizedBox(height: 18),

                if (isPaymentEnabled && widget.milestones.isNotEmpty) ...[
                  _fiverrSectionTitle('MILESTONE PAYMENTS'),
                  const SizedBox(height: 10),
                  ...widget.milestones.map((m) => _milestonePaymentRow(m)),
                  const SizedBox(height: 18),
                ],

                // —— Signature progress ——
                _fiverrSectionTitle('AGREEMENT STATUS'),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: signProgress,
                    minHeight: 6,
                    backgroundColor: CAppTheme.borderColor,
                    color: _fiverrGreen,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$_acceptedCount of ${widget.members.length} members signed',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: CAppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),

                // —— Client & team ——
                _fiverrSectionTitle('CLIENT & TEAM'),
                const SizedBox(height: 10),
                _partyRow(
                  name: p.userName,
                  role: 'Client · Project Lead',
                  imageUrl: p.userProfileImage,
                  accepted: widget.members.any((m) => m.isOwner && m.hasAcceptedContract),
                ),
                ...widget.members.where((m) => !m.isOwner).map(
                      (m) => _partyRow(
                        name: m.userName,
                        role: 'Collaborator · ${m.roleTitle ?? 'Team Member'}',
                        imageUrl: m.userProfileImage,
                        accepted: m.hasAcceptedContract,
                      ),
                    ),
                const SizedBox(height: 18),

                // —— Project scope ——
                _fiverrSectionTitle('PROJECT SCOPE'),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: CAppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                    border: Border.all(color: CAppTheme.borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.description,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          height: 1.45,
                          color: CAppTheme.textPrimary,
                        ),
                      ),
                      if (p.projectCategories.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: p.projectCategories
                              .map((c) => SkillChip(label: c))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),

                // —— Milestone deliverables (Fiverr order steps) ——
                if (widget.milestones.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _fiverrSectionTitle('DELIVERABLES & MILESTONES'),
                  const SizedBox(height: 10),
                  ...widget.milestones.asMap().entries.map(
                        (e) => _deliverableStep(e.key + 1, e.value, _paymentFor(e.value.id)),
                      ),
                ],

                if (widget.roles.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _fiverrSectionTitle('OPEN ROLES'),
                  const SizedBox(height: 8),
                  ...widget.roles.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.work_outline_rounded,
                              size: 16, color: CAppTheme.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.title,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (r.requiredSkills.isNotEmpty)
                                  Text(
                                    r.requiredSkills.join(' · '),
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
                  ),
                ],

                const SizedBox(height: 18),
                _fiverrSectionTitle('TERMS OF SERVICE'),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                    border: Border.all(color: CAppTheme.borderColor),
                  ),
                  child: Text(
                    terms,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      height: 1.55,
                      color: CAppTheme.textPrimary,
                    ),
                  ),
                ),

                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                    border: Border.all(color: _fiverrGreen.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined, size: 18, color: _fiverrGreen),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Payments and deliverables are tracked through milestones. '
                          'Complete work on time to receive agreed compensation.',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            height: 1.4,
                            color: CAppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (canAccept) ...[
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                    borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: Checkbox(
                              value: _agreedToTerms,
                              onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                              activeColor: _fiverrGreen,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'I have read and agree to the project scope, payment terms, '
                              'and collaboration agreement.',
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                height: 1.4,
                                color: CAppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (_busy || !_agreedToTerms) ? null : _acceptContract,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _fiverrGreen,
                        disabledBackgroundColor: _fiverrGreen.withValues(alpha: 0.4),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                        ),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Approve & Sign Agreement',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ] else if (me?.hasAcceptedContract == true) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                      border: Border.all(color: _fiverrGreen.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_rounded, color: _fiverrGreen, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Agreement signed',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _fiverrGreen,
                                ),
                              ),
                              Text(
                                'Signed on ${DateFormat('MMM d, yyyy · h:mm a').format(me!.contractAcceptedAt!)}',
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
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fiverrSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: CAppTheme.textTertiary,
      ),
    );
  }

  Widget _orderSummaryCard({
    required String displayBudget,
    required double milestoneTotal,
    required double heldTotal,
    required double releasedTotal,
    String? timeline,
    required int milestoneCount,
    required bool isPaymentEnabled,
  }) {
    final escrowShown = heldTotal > 0 ? heldTotal : milestoneTotal;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
        border: Border.all(color: CAppTheme.borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ORDER SUMMARY',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: CAppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPaymentEnabled ? 'Total compensation' : 'Project type',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: CAppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPaymentEnabled ? displayBudget : 'Non-paid collaboration',
                      style: GoogleFonts.poppins(
                        fontSize: isPaymentEnabled ? 22 : 17,
                        fontWeight: FontWeight.w700,
                        color: CAppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _fiverrGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPaymentEnabled ? Icons.payments_rounded : Icons.groups_rounded,
                  color: _fiverrGreen,
                  size: 24,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),
          _summaryRow(Icons.schedule_rounded, 'Delivery timeline', timeline ?? 'Not specified'),
          const SizedBox(height: 8),
          _summaryRow(
            Icons.flag_rounded,
            'Milestones',
            milestoneCount == 0
                ? 'No milestones set yet'
                : '$milestoneCount deliverable${milestoneCount == 1 ? '' : 's'}',
          ),
          const SizedBox(height: 8),
          if (isPaymentEnabled) ...[
            _summaryRow(
              Icons.account_balance_wallet_outlined,
              'In escrow',
              escrowShown > 0 ? 'Rs. ${_fmt(escrowShown)}' : '—',
            ),
            if (heldTotal <= 0 && milestoneTotal > 0) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Text(
                  'Escrow target from order summary. Owner funds milestone-wise.',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: CAppTheme.textSecondary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            _summaryRow(
              Icons.payments_rounded,
              'Released to team',
              releasedTotal > 0 ? 'Rs. ${_fmt(releasedTotal)}' : 'Rs. 0',
            ),
          ],
          if (isPaymentEnabled && milestoneTotal > 0) ...[
            const SizedBox(height: 8),
            _summaryRow(
              Icons.calculate_outlined,
              'Milestone total',
              'Rs. ${_fmt(milestoneTotal)}',
            ),
          ],
          const SizedBox(height: 8),
          _summaryRow(
            isPaymentEnabled ? Icons.account_balance_wallet_outlined : Icons.groups_rounded,
            isPaymentEnabled ? 'Payment release' : 'Collaboration mode',
            isPaymentEnabled
                ? (milestoneCount > 0
                    ? 'Wallet escrow — release after milestone done'
                    : 'As per agreed terms')
                : 'Team collaboration only (no payment flow)',
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: CAppTheme.textTertiary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(fontSize: 11.5, color: CAppTheme.textTertiary),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: CAppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _milestonePaymentRow(CollaborationMilestone m) {
    final pay = _paymentFor(m.id);
    final amount = m.amount ?? 0;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    if (pay?.isReleased == true) {
      statusColor = _fiverrGreen;
      statusLabel = 'Released';
      statusIcon = Icons.check_circle_rounded;
    } else if (pay?.isHeld == true) {
      statusColor = CAppTheme.infoColor;
      statusLabel = 'In escrow';
      statusIcon = Icons.lock_clock_rounded;
    } else if (amount > 0) {
      statusColor = CAppTheme.warningColor;
      statusLabel = 'Unpaid';
      statusIcon = Icons.pending_outlined;
    } else {
      statusColor = CAppTheme.textTertiary;
      statusLabel = 'No amount set';
      statusIcon = Icons.money_off_outlined;
    }

    final canFund = widget.isOwner &&
        pay == null &&
        amount > 0 &&
        m.assignedTo != null &&
        !_busy;
    final canRelease = widget.isOwner &&
        pay?.isHeld == true &&
        m.isDone &&
        !_busy;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
        border: Border.all(color: CAppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (m.assignedToName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Payee: ${m.assignedToName}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: CAppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amount > 0 ? 'Rs. ${_fmt(amount)}' : '—',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(CAppTheme.radiusRound),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (canFund || canRelease) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (canFund)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _fundMilestone(m),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _fiverrGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                        ),
                      ),
                      child: Text(
                        'Fund milestone',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (canFund && canRelease) const SizedBox(width: 8),
                if (canRelease)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _releasePayment(m),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _fiverrGreen,
                        side: const BorderSide(color: _fiverrGreen),
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                        ),
                      ),
                      child: Text(
                        'Release payment',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _deliverableStep(int step, CollaborationMilestone m, CollaborationPayment? pay) {
    final Color statusColor;
    final String statusLabel;
    if (m.isDone) {
      statusColor = _fiverrGreen;
      statusLabel = 'Completed';
    } else if (m.isMissed) {
      statusColor = CAppTheme.errorColor;
      statusLabel = 'Missed';
    } else if (m.isOverdue) {
      statusColor = CAppTheme.warningColor;
      statusLabel = 'Overdue';
    } else {
      statusColor = CAppTheme.textTertiary;
      statusLabel = 'In progress';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
        border: Border.all(
          color: m.isDone
              ? _fiverrGreen.withValues(alpha: 0.35)
              : CAppTheme.borderColor,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: m.isDone
                  ? _fiverrGreen
                  : CAppTheme.backgroundColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: m.isDone ? _fiverrGreen : CAppTheme.borderColor,
              ),
            ),
            child: m.isDone
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    '$step',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: CAppTheme.textSecondary,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        m.title,
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(CAppTheme.radiusRound),
                      ),
                      child: Text(
                        statusLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                if (m.assignedToName != null || m.dueDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (m.assignedToName != null) 'Assigned to ${m.assignedToName}',
                      if (m.dueDate != null)
                        'Due ${DateFormat('MMM d, yyyy').format(m.dueDate!)}',
                    ].join(' · '),
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: CAppTheme.textSecondary,
                    ),
                  ),
                ],
                if ((m.amount ?? 0) > 0 || pay != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      if ((m.amount ?? 0) > 0) 'Rs. ${_fmt(m.amount!)}',
                      if (pay?.isHeld == true) 'In escrow',
                      if (pay?.isReleased == true) 'Paid',
                    ].join(' · '),
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: pay?.isReleased == true
                          ? _fiverrGreen
                          : pay?.isHeld == true
                              ? CAppTheme.infoColor
                              : CAppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _partyRow({
    required String name,
    required String role,
    String? imageUrl,
    required bool accepted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          UserAvatar(name: name, imageUrl: imageUrl, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600)),
                Text(role,
                    style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accepted
                  ? _fiverrGreen.withValues(alpha: 0.12)
                  : CAppTheme.warningColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(CAppTheme.radiusRound),
            ),
            child: Text(
              accepted ? 'Signed' : 'Pending',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: accepted ? _fiverrGreen : CAppTheme.warningColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
