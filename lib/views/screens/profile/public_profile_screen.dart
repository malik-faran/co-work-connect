import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/models/collaboration_hub_models.dart';
import 'package:cwc/models/collaboration_model.dart';
import 'package:cwc/models/user_model.dart';
import 'package:cwc/services/auth_service.dart';
import 'package:cwc/services/collaboration_hub_service.dart';
import 'package:cwc/services/collaboration_service.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/views/widgets/collaboration_widgets.dart';

/// Read-only public profile with skills + portfolio + invite action.
class PublicProfileScreen extends StatefulWidget {
  final String userId;
  const PublicProfileScreen({super.key, required this.userId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final _auth = AuthService();
  final _hub = CollaborationHubService();
  final _collab = CollaborationService();

  UserModel? _user;
  List<PortfolioItem> _portfolio = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await _auth.getUserById(widget.userId);
      final portfolio = await _hub.getPortfolio(widget.userId);
      if (!mounted) return;
      setState(() {
        _user = user;
        _portfolio = portfolio;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewerId = context.read<AuthController>().currentUser?.id;
    final isSelf = viewerId == widget.userId;
    return Scaffold(
      backgroundColor: CAppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: CAppTheme.primaryColor))
          : _user == null
              ? const EmptyState(
                  icon: Icons.person_off_rounded,
                  title: 'User not found',
                  subtitle: 'This profile is unavailable.',
                )
              : _buildBody(isSelf),
      bottomNavigationBar: (!_loading && _user != null && !isSelf)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: _inviteToProject,
                  icon: const Icon(Icons.group_add_rounded),
                  label: const Text('Invite to a project'),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody(bool isSelf) {
    final u = _user!;
    final openToCollab = u.collaborationEnabled == true;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          child: Column(
            children: [
              UserAvatar(name: u.name, imageUrl: u.profileImageUrl, size: 84),
              const SizedBox(height: 12),
              Text(u.name,
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
              if (u.profession != null && u.profession!.isNotEmpty)
                Text(u.profession!,
                    style: GoogleFonts.poppins(fontSize: 13.5, color: CAppTheme.textSecondary)),
              if (u.collaborationHeadline != null && u.collaborationHeadline!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(u.collaborationHeadline!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontStyle: FontStyle.italic, color: CAppTheme.primaryColor)),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  if (openToCollab)
                    const SkillChip(
                        label: 'Open to Collaborate',
                        highlighted: true,
                        icon: Icons.handshake_rounded),
                  if (u.city != null && u.city!.isNotEmpty)
                    SkillChip(label: u.city!, icon: Icons.location_on_rounded),
                  if (u.availability != null && u.availability!.isNotEmpty)
                    SkillChip(label: u.availability!, icon: Icons.schedule_rounded),
                ],
              ),
            ],
          ),
        ),
        if (u.bio != null && u.bio!.isNotEmpty) ...[
          const SizedBox(height: 14),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(icon: Icons.info_outline_rounded, title: 'About'),
                const SizedBox(height: 10),
                Text(u.bio!,
                    style: GoogleFonts.poppins(
                        fontSize: 14, height: 1.5, color: CAppTheme.textPrimary)),
              ],
            ),
          ),
        ],
        if (u.skills != null && u.skills!.isNotEmpty) ...[
          const SizedBox(height: 14),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(icon: Icons.psychology_rounded, title: 'Skills'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: u.skills!.map((s) => SkillChip(label: s)).toList(),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(icon: Icons.work_rounded, title: 'Portfolio'),
              const SizedBox(height: 12),
              if (u.resumeUrl != null && u.resumeUrl!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CAppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: CAppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(CAppTheme.radiusSmall),
                        ),
                        child: const Icon(Icons.description_rounded, color: CAppTheme.primaryColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Resume / CV',
                                style: GoogleFonts.poppins(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                            Text(
                              u.resumeFileName ?? 'Download resume',
                              style: GoogleFonts.poppins(
                                  fontSize: 12.5, color: CAppTheme.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final uri = Uri.tryParse(u.resumeUrl!);
                          if (uri != null && await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('View'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_portfolio.isEmpty && (u.resumeUrl == null || u.resumeUrl!.isEmpty))
                Text('No portfolio items yet.',
                    style: GoogleFonts.poppins(fontSize: 13, color: CAppTheme.textSecondary))
              else if (_portfolio.isEmpty)
                Text('No work items yet.',
                    style: GoogleFonts.poppins(fontSize: 13, color: CAppTheme.textSecondary))
              else
                ..._portfolio.map(_portfolioCard),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _portfolioCard(PortfolioItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: CAppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(item.imageUrl!,
                  height: 140, width: double.infinity, fit: BoxFit.cover),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w600)),
                if (item.description != null && item.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(item.description!,
                      style: GoogleFonts.poppins(fontSize: 12.5, color: CAppTheme.textSecondary)),
                ],
                if (item.skills.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: item.skills.map((s) => SkillChip(label: s)).toList(),
                  ),
                ],
                if (item.projectUrl != null && item.projectUrl!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () async {
                      final uri = Uri.tryParse(item.projectUrl!);
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('View project'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _inviteToProject() async {
    final viewer = context.read<AuthController>().currentUser;
    if (viewer == null || _user == null) return;
    final myProjects = await _collab.getUserCollaborations(viewer.id);
    final recruiting = myProjects.where((p) => p.isRecruiting || p.isActive).toList();
    if (!mounted) return;
    if (recruiting.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post a project first to invite people.')),
      );
      return;
    }

    CollaborationModel? selected = recruiting.first;
    final messageController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CAppTheme.radiusXL)),
          title: Text('Invite ${_user!.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<CollaborationModel>(
                value: selected,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Project'),
                items: recruiting
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.title, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setLocal(() => selected = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                decoration: const InputDecoration(labelText: 'Message (optional)'),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send invite')),
          ],
        ),
      ),
    );

    if (confirmed != true || selected == null) return;
    await _hub.sendInvite(CollaborationInvite(
      id: const Uuid().v4(),
      collaborationId: selected!.id,
      collaborationTitle: selected!.title,
      invitedBy: viewer.id,
      invitedByName: viewer.name,
      invitedUser: _user!.id,
      message: messageController.text.trim().isEmpty ? null : messageController.text.trim(),
      createdAt: DateTime.now(),
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invite sent to ${_user!.name}'), backgroundColor: CAppTheme.successColor),
    );
  }
}
