import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cwc/models/collaboration_hub_models.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/utils/validators/form_validators.dart';
import 'package:cwc/views/widgets/collaboration_widgets.dart';

class ApplyResult {
  final CollaborationRole? role;
  final String pitch;
  final String? availability;
  final String? proposedRate;
  ApplyResult(this.role, this.pitch, this.availability, this.proposedRate);
}

/// Bottom sheet to apply for a role on a project.
class CollaborationApplySheet extends StatefulWidget {
  final List<CollaborationRole> roles;
  final List<String> userSkills;
  const CollaborationApplySheet({super.key, required this.roles, this.userSkills = const []});

  @override
  State<CollaborationApplySheet> createState() => _CollaborationApplySheetState();
}

class _CollaborationApplySheetState extends State<CollaborationApplySheet> {
  final _formKey = GlobalKey<FormState>();
  final _pitch = TextEditingController();
  final _availability = TextEditingController();
  final _rate = TextEditingController();
  CollaborationRole? _role;

  @override
  void initState() {
    super.initState();
    if (widget.roles.isNotEmpty) _role = widget.roles.first;
  }

  @override
  void dispose() {
    _pitch.dispose();
    _availability.dispose();
    _rate.dispose();
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
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
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
                Text('Apply to join',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Tell the team why you are a great fit.',
                    style: GoogleFonts.poppins(fontSize: 13, color: CAppTheme.textSecondary)),
                const SizedBox(height: 16),
                if (widget.roles.isNotEmpty) ...[
                  Text('Role',
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w600, color: CAppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  ...widget.roles.map(_roleTile),
                  const SizedBox(height: 8),
                ],
                TextFormField(
                  controller: _pitch,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Your pitch',
                    hintText: 'Share your experience and what you can contribute...',
                    alignLabelWithHint: true,
                  ),
                  validator: FormValidators.collabResponse,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _availability,
                  decoration: const InputDecoration(
                    labelText: 'Availability (optional)',
                    hintText: 'e.g. 10 hrs/week',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _rate,
                  decoration: const InputDecoration(
                    labelText: 'Expected rate (optional)',
                    hintText: 'e.g. Volunteer / 20k PKR',
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!_formKey.currentState!.validate()) return;
                      Navigator.pop(
                        context,
                        ApplyResult(
                          _role,
                          _pitch.text.trim(),
                          _availability.text.trim().isEmpty ? null : _availability.text.trim(),
                          _rate.text.trim().isEmpty ? null : _rate.text.trim(),
                        ),
                      );
                    },
                    child: const Text('Submit application'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleTile(CollaborationRole role) {
    final selected = _role?.id == role.id;
    final match = skillMatchPercent(widget.userSkills, role.requiredSkills);
    return GestureDetector(
      onTap: () => setState(() => _role = role),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? CAppTheme.primaryColor.withValues(alpha: 0.07) : CAppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
          border: Border.all(
            color: selected ? CAppTheme.primaryColor : CAppTheme.borderColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: selected ? CAppTheme.primaryColor : CAppTheme.textTertiary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(role.title,
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                  if (role.requiredSkills.isNotEmpty)
                    Text(role.requiredSkills.join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.textSecondary)),
                ],
              ),
            ),
            if (role.requiredSkills.isNotEmpty) MatchBadge(percent: match),
          ],
        ),
      ),
    );
  }
}
