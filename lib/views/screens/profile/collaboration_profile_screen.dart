import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/views/screens/profile/portfolio_editor_screen.dart';
import 'package:cwc/views/widgets/collaboration_widgets.dart';

/// Lets a user manage their "Open to Collaborate" profile: toggle, headline,
/// bio, availability and skills.
class CollaborationProfileScreen extends StatefulWidget {
  const CollaborationProfileScreen({super.key});

  @override
  State<CollaborationProfileScreen> createState() => _CollaborationProfileScreenState();
}

class _CollaborationProfileScreenState extends State<CollaborationProfileScreen> {
  final _headline = TextEditingController();
  final _bio = TextEditingController();
  final _availability = TextEditingController();
  final _skillInput = TextEditingController();
  final List<String> _skills = [];
  bool _open = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = context.read<AuthController>().currentUser;
    if (u != null) {
      _open = u.collaborationEnabled ?? false;
      _headline.text = u.collaborationHeadline ?? '';
      _bio.text = u.bio ?? '';
      _availability.text = u.availability ?? '';
      _skills.addAll(u.skills ?? []);
    }
  }

  @override
  void dispose() {
    _headline.dispose();
    _bio.dispose();
    _availability.dispose();
    _skillInput.dispose();
    super.dispose();
  }

  void _addSkill(String s) {
    final v = s.trim();
    if (v.isNotEmpty && !_skills.contains(v)) {
      setState(() {
        _skills.add(v);
        _skillInput.clear();
      });
    }
  }

  Future<void> _save() async {
    final auth = context.read<AuthController>();
    final u = auth.currentUser;
    if (u == null) return;
    setState(() => _saving = true);
    final updated = u.copyUser(
      collaborationEnabled: _open,
      collaborationHeadline: _headline.text.trim(),
      bio: _bio.text.trim(),
      availability: _availability.text.trim(),
      skills: _skills,
    );
    await auth.updateProfile(updated);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Collaboration profile saved'), backgroundColor: CAppTheme.successColor),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CAppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Collaboration profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _open,
                  onChanged: (v) => setState(() => _open = v),
                  title: Text('Open to Collaborate',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
                  subtitle: Text('Show up in "Open Teammates" so owners can invite you',
                      style: GoogleFonts.poppins(fontSize: 12.5, color: CAppTheme.textSecondary)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(icon: Icons.badge_rounded, title: 'Profile details'),
                const SizedBox(height: 14),
                TextField(
                  controller: _headline,
                  decoration: const InputDecoration(
                    labelText: 'Headline',
                    hintText: 'e.g. Flutter dev open for FYP teams',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bio,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    hintText: 'A short intro about you...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _availability,
                  decoration: const InputDecoration(
                    labelText: 'Availability',
                    hintText: 'e.g. 10 hrs/week, weekends',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(icon: Icons.psychology_rounded, title: 'Skills'),
                const SizedBox(height: 12),
                TextField(
                  controller: _skillInput,
                  decoration: InputDecoration(
                    labelText: 'Add a skill',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => _addSkill(_skillInput.text),
                    ),
                  ),
                  onSubmitted: _addSkill,
                ),
                if (_skills.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _skills
                        .map((s) => Chip(
                              label: Text(s),
                              onDeleted: () => setState(() => _skills.remove(s)),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            padding: const EdgeInsets.all(6),
            child: ListTile(
              leading: const Icon(Icons.work_rounded, color: CAppTheme.primaryColor),
              title: Text('My Portfolio',
                  style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w600)),
              subtitle: Text('Showcase your best work',
                  style: GoogleFonts.poppins(fontSize: 12.5, color: CAppTheme.textSecondary)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PortfolioEditorScreen())),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save profile'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
