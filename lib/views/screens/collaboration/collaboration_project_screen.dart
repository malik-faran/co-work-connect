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
import 'package:cwc/views/screens/collaboration/collaboration_invite_sheet.dart';

/// The Project Room — the collaboration hub for an active project.
class CollaborationProjectScreen extends StatefulWidget {
  final String collaborationId;
  const CollaborationProjectScreen({super.key, required this.collaborationId});

  @override
  State<CollaborationProjectScreen> createState() => _CollaborationProjectScreenState();
}

class _CollaborationProjectScreenState extends State<CollaborationProjectScreen>
    with SingleTickerProviderStateMixin {
  final _hub = CollaborationHubService();
  final _collabService = CollaborationService();
  late final TabController _tabController;

  CollaborationModel? _project;
  List<CollaborationMember> _members = [];
  List<CollaborationMilestone> _milestones = [];
  List<CollaborationFile> _files = [];
  List<CollaborationActivity> _activity = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _uid => context.read<AuthController>().currentUser?.id ?? '';
  bool get _isOwner => _project != null && _project!.userId == _uid;

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final project = await _collabService.getCollaborationById(widget.collaborationId);
      final members = await _hub.getMembers(widget.collaborationId);
      final milestones = await _hub.getMilestones(widget.collaborationId);
      final files = await _hub.getFiles(widget.collaborationId);
      final activity = await _hub.getActivity(widget.collaborationId);
      if (!mounted) return;
      setState(() {
        _project = project;
        _members = members;
        _milestones = milestones;
        _files = files;
        _activity = activity;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _toast('Failed to load project: $e', isError: true);
    }
  }

  double get _progress {
    if (_milestones.isEmpty) return 0;
    final done = _milestones.where((m) => m.isDone).length;
    return done / _milestones.length;
  }

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
              memberCount: _members.length,
              milestoneCount: _milestones.length,
              isOwner: _isOwner,
              onMarkComplete: _confirmComplete,
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
              onAdd: _addMilestone,
              onToggle: _toggleMilestone,
              onDelete: _isOwner ? _deleteMilestone : null,
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
            _ActivityTab(activity: _activity),
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
              Container(
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
                    Text('${_members.length} members',
                        style: GoogleFonts.poppins(
                            fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                  ],
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
      await _hub.removeMember(_project!.id, member.userId);
      if (!mounted) return;
      _toast('${member.userName} removed from team');
      _loadAll();
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
      await _hub.removeMember(_project!.id, user.id);
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
    await _hub.completeProject(_project!, user.name);
    _toast('Project marked as completed!');
    _loadAll();
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
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;
    final result = await showModalBottomSheet<_MilestoneDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMilestoneSheet(members: _members),
    );
    if (result == null) return;
    await _hub.addMilestone(CollaborationMilestone(
      id: const Uuid().v4(),
      collaborationId: widget.collaborationId,
      title: result.title,
      description: result.description,
      dueDate: result.dueDate,
      assignedTo: result.assignedTo?.userId,
      assignedToName: result.assignedTo?.userName,
      sortOrder: _milestones.length,
      createdAt: DateTime.now(),
    ));
    _loadAll();
  }

  Future<void> _toggleMilestone(CollaborationMilestone m) async {
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;
    await _hub.toggleMilestone(m, user.id, user.name);
    _loadAll();
  }

  Future<void> _deleteMilestone(CollaborationMilestone m) async {
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
  final int memberCount;
  final int milestoneCount;
  final bool isOwner;
  final VoidCallback onMarkComplete;
  final VoidCallback onEditMeetingLink;
  final VoidCallback onOpenMeeting;

  const _OverviewTab({
    required this.project,
    required this.progress,
    required this.memberCount,
    required this.milestoneCount,
    required this.isOwner,
    required this.onMarkComplete,
    required this.onEditMeetingLink,
    required this.onOpenMeeting,
  });

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
              if ((project.timeline != null && project.timeline!.isNotEmpty) ||
                  (project.budget != null && project.budget!.isNotEmpty)) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (project.timeline != null && project.timeline!.isNotEmpty)
                      _infoPill(Icons.schedule_rounded, project.timeline!),
                    if (project.budget != null && project.budget!.isNotEmpty)
                      _infoPill(Icons.payments_rounded, project.budget!),
                  ],
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
        // Cross-link to workspaces (secondary feature)
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: CAppTheme.successColor),
              onPressed: onMarkComplete,
              icon: const Icon(Icons.verified_rounded),
              label: const Text('Mark project complete'),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _infoPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: CAppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: CAppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(text, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w500)),
        ],
      ),
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (isOwner) ...[
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onAddTeammate,
                  icon: const Icon(Icons.person_add_alt_rounded, size: 18),
                  label: const Text('Add teammate'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onInvite,
                  icon: const Icon(Icons.link_rounded, size: 18),
                  label: const Text('Share link'),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
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
  final VoidCallback onAdd;
  final ValueChanged<CollaborationMilestone> onToggle;
  final ValueChanged<CollaborationMilestone>? onDelete;

  const _MilestonesTab({
    required this.milestones,
    required this.members,
    required this.progress,
    required this.onAdd,
    required this.onToggle,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        milestones.isEmpty
            ? EmptyState(
                icon: Icons.flag_rounded,
                title: 'No milestones yet',
                subtitle: 'Break the project into clear, trackable milestones.',
                action: ElevatedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Add milestone'),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                children: [
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

  Widget _milestoneCard(BuildContext context, CollaborationMilestone m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: SectionCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => onToggle(m),
              child: Container(
                margin: const EdgeInsets.only(top: 2),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: m.isDone ? CAppTheme.successColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: m.isDone ? CAppTheme.successColor : CAppTheme.borderColor,
                    width: 2,
                  ),
                ),
                child: m.isDone
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.title,
                    style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      decoration: m.isDone ? TextDecoration.lineThrough : null,
                      color: m.isDone ? CAppTheme.textTertiary : CAppTheme.textPrimary,
                    ),
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
                        _tag(Icons.event_rounded, DateFormat('MMM d').format(m.dueDate!)),
                    ],
                  ),
                ],
              ),
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
  const _ActivityTab({required this.activity});

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
                        style: GoogleFonts.poppins(fontSize: 13.5, color: CAppTheme.textPrimary),
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
                        style: GoogleFonts.poppins(fontSize: 11.5, color: CAppTheme.textTertiary)),
                  ],
                ),
              ),
            ],
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
  _MilestoneDraft(this.title, this.description, this.dueDate, this.assignedTo);
}

class _AddMilestoneSheet extends StatefulWidget {
  final List<CollaborationMember> members;
  const _AddMilestoneSheet({required this.members});

  @override
  State<_AddMilestoneSheet> createState() => _AddMilestoneSheetState();
}

class _AddMilestoneSheetState extends State<_AddMilestoneSheet> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  DateTime? _due;
  CollaborationMember? _assignee;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(20),
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
            Text('New milestone',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Build login screen'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                      );
                      if (picked != null) setState(() => _due = picked);
                    },
                    icon: const Icon(Icons.event_rounded, size: 18),
                    label: Text(_due == null ? 'Due date' : DateFormat('MMM d, yyyy').format(_due!)),
                  ),
                ),
              ],
            ),
            if (widget.members.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<CollaborationMember>(
                value: _assignee,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Assign to (optional)'),
                items: widget.members
                    .map((m) => DropdownMenuItem(value: m, child: Text(m.userName)))
                    .toList(),
                onChanged: (v) => setState(() => _assignee = v),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_title.text.trim().isEmpty) return;
                  Navigator.pop(
                    context,
                    _MilestoneDraft(
                      _title.text.trim(),
                      _desc.text.trim().isEmpty ? null : _desc.text.trim(),
                      _due,
                      _assignee,
                    ),
                  );
                },
                child: const Text('Add milestone'),
              ),
            ),
            const SizedBox(height: 8),
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
