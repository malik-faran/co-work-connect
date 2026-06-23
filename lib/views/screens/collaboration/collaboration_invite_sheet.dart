import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cwc/models/collaboration_model.dart';
import 'package:cwc/services/collaboration_hub_service.dart';
import 'package:cwc/utils/themes/theme.dart';

/// Bottom sheet to share a project's invite link / code.
class CollaborationInviteSheet extends StatefulWidget {
  final CollaborationModel project;
  const CollaborationInviteSheet({super.key, required this.project});

  @override
  State<CollaborationInviteSheet> createState() => _CollaborationInviteSheetState();
}

class _CollaborationInviteSheetState extends State<CollaborationInviteSheet> {
  final _hub = CollaborationHubService();
  late String? _code = widget.project.inviteCode;
  late bool _enabled = widget.project.inviteLinkEnabled;
  bool _busy = false;

  String get _link => _code == null ? '' : 'coworkconnect://project/join/$_code';

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard'), backgroundColor: CAppTheme.successColor),
    );
  }

  Future<void> _shareText() async {
    final text =
        'Join my project "${widget.project.title}" on Co-Work Connect.\nUse code: $_code\nor open: $_link';
    await _copy(text, 'Invite message');
  }

  Future<void> _regenerate() async {
    setState(() => _busy = true);
    final newCode = await _hub.regenerateInviteCode(widget.project.id);
    setState(() {
      _code = newCode;
      _busy = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New invite code generated. Old link is now invalid.')),
      );
    }
  }

  Future<void> _toggleEnabled(bool value) async {
    setState(() => _enabled = value);
    await _hub.setInviteLinkEnabled(widget.project.id, value);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: CAppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                ),
                child: const Icon(Icons.link_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Invite teammates',
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                    Text('Share this link or code to let people join',
                        style: GoogleFonts.poppins(
                            fontSize: 12.5, color: CAppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Code display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: CAppTheme.primaryColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
              border: Border.all(color: CAppTheme.primaryColor.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                Text('PROJECT CODE',
                    style: GoogleFonts.poppins(
                        fontSize: 11, fontWeight: FontWeight.w600, color: CAppTheme.textSecondary, letterSpacing: 1)),
                const SizedBox(height: 6),
                Text(
                  _code ?? '--------',
                  style: GoogleFonts.poppins(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 6,
                      color: CAppTheme.primaryColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _code == null ? null : () => _copy(_code!, 'Code'),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy code'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _code == null ? null : _shareText,
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _link.isEmpty ? null : () => _copy(_link, 'Invite link'),
              icon: const Icon(Icons.link_rounded, size: 18),
              label: const Text('Copy invite link'),
            ),
          ),
          const Divider(height: 32),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _enabled,
            onChanged: _busy ? null : _toggleEnabled,
            title: Text('Allow joining via link',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text('Turn off to stop new join requests',
                style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.textSecondary)),
          ),
          TextButton.icon(
            onPressed: _busy ? null : _regenerate,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Regenerate code (invalidates old link)'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
