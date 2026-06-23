import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/models/collaboration_model.dart';
import 'package:cwc/services/collaboration_hub_service.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/views/screens/collaboration/collaboration_detail_screen.dart';
import 'package:cwc/views/screens/collaboration/collaboration_project_screen.dart';
import 'package:cwc/views/widgets/collaboration_widgets.dart';

/// Resolves an invite link / code and routes the user to apply or join.
class CollaborationJoinScreen extends StatefulWidget {
  /// Optional pre-filled code (e.g. from a deep link).
  final String? initialCode;
  const CollaborationJoinScreen({super.key, this.initialCode});

  @override
  State<CollaborationJoinScreen> createState() => _CollaborationJoinScreenState();
}

class _CollaborationJoinScreenState extends State<CollaborationJoinScreen> {
  final _hub = CollaborationHubService();
  final _controller = TextEditingController();
  bool _searching = false;
  bool _joining = false;
  CollaborationModel? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      _controller.text = widget.initialCode!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
      _result = null;
    });
    try {
      final project = await _hub.resolveInvite(input);
      if (!mounted) return;
      setState(() {
        _result = project;
        _searching = false;
        if (project == null) _error = 'No project found for this code.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = 'Could not resolve this invite.';
      });
    }
  }

  Future<void> _act() async {
    final project = _result;
    final user = context.read<AuthController>().currentUser;
    if (project == null || user == null) return;

    if (!project.inviteLinkEnabled) {
      setState(() => _error = 'Invites are closed for this project.');
      return;
    }

    // Already a member -> open the room.
    if (await _hub.isMember(project.id, user.id)) {
      _goToRoom(project.id);
      return;
    }

    if (project.isRecruiting) {
      // Go to detail screen to apply for a role.
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CollaborationDetailScreen(collaborationId: project.id),
        ),
      );
    } else if (project.isActive) {
      // Join active project directly via link.
      setState(() => _joining = true);
      await _hub.joinActiveProject(
        collaboration: project,
        userId: user.id,
        userName: user.name,
        userImage: user.profileImageUrl,
        joinedVia: 'link',
      );
      await _hub.recordLinkJoin(project.id, user.id);
      if (!mounted) return;
      setState(() => _joining = false);
      _goToRoom(project.id);
    } else {
      setState(() => _error = 'This project is no longer accepting members.');
    }
  }

  void _goToRoom(String id) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => CollaborationProjectScreen(collaborationId: id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CAppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Join a project')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: CAppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
            ),
            child: Row(
              children: [
                const Icon(Icons.link_rounded, color: Colors.white, size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Got an invite code or link? Paste it below to join a project team.',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 13.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Invite code or link',
              hintText: 'e.g. FYP8X2K9',
              suffixIcon: IconButton(
                icon: const Icon(Icons.search_rounded),
                onPressed: _resolve,
              ),
            ),
            onSubmitted: (_) => _resolve(),
          ),
          const SizedBox(height: 16),
          if (_searching) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CAppTheme.errorColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: CAppTheme.errorColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_error!,
                        style: GoogleFonts.poppins(fontSize: 13, color: CAppTheme.errorColor)),
                  ),
                ],
              ),
            ),
          if (_result != null) _projectPreview(_result!),
        ],
      ),
    );
  }

  Widget _projectPreview(CollaborationModel p) {
    final canJoin = p.inviteLinkEnabled && (p.isRecruiting || p.isActive);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(p.title,
                    style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              StatusBadge(status: p.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(p.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontSize: 13.5, color: CAppTheme.textSecondary, height: 1.4)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canJoin && !_joining ? _act : null,
              icon: _joining
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(p.isRecruiting ? Icons.assignment_ind_rounded : Icons.group_add_rounded),
              label: Text(p.isRecruiting
                  ? 'Apply to join'
                  : p.isActive
                      ? 'Request to join team'
                      : 'Not accepting members'),
            ),
          ),
        ],
      ),
    );
  }
}
