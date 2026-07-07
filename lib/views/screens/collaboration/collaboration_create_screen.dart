import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/models/collaboration_hub_models.dart';
import 'package:cwc/models/collaboration_model.dart';
import 'package:cwc/services/collaboration_hub_service.dart';
import 'package:cwc/services/collaboration_service.dart';
import 'package:cwc/services/storage_service.dart';
import 'package:cwc/services/wallet_service.dart';
import 'package:cwc/utils/constants/app_constants.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/utils/validators/form_validators.dart';
import 'package:cwc/views/widgets/collaboration_widgets.dart';

/// Professional, role-based "Build a Team" project creator.
class CollaborationCreateScreen extends StatefulWidget {
  final CollaborationModel? collaboration; // edit mode
  const CollaborationCreateScreen({super.key, this.collaboration});

  @override
  State<CollaborationCreateScreen> createState() => _CollaborationCreateScreenState();
}

class _RoleDraft {
  String title;
  List<String> skills;
  _RoleDraft(this.title, this.skills);
}

class _CollaborationCreateScreenState extends State<CollaborationCreateScreen> {
  final _collab = CollaborationService();
  final _hub = CollaborationHubService();
  final _walletService = WalletService();
  final _uuid = const Uuid();

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _budgetController = TextEditingController();
  final _timelineController = TextEditingController();

  int _step = 0;
  bool _isLoading = false;

  List<String> _categories = [];
  String _visibility = 'public';
  String _paymentMode = 'escrow';
  String? _coverImageUrl;
  bool _uploadingCover = false;

  final List<_RoleDraft> _roles = [];

  static const _allCategories = AppConstants.projectCategories;

  static const _suggestedSkills = [
    'Flutter', 'React', 'Node.js', 'Python', 'UI/UX', 'Firebase',
    'Java', 'Kotlin', 'Django', 'Figma', 'Machine Learning', 'Content Writing',
  ];

  bool get _isEdit => widget.collaboration != null;

  @override
  void initState() {
    super.initState();
    final c = widget.collaboration;
    if (c != null) {
      _titleController.text = c.title;
      _descController.text = c.description;
      _budgetController.text = c.budget ?? '';
      _timelineController.text = c.timeline ?? '';
      if (c.projectType != null && c.projectType!.isNotEmpty) {
        _categories = c.projectType!.split(', ').where((s) => s.isNotEmpty).toList();
      }
      _visibility = c.visibility;
      _paymentMode = c.paymentMode;
      _coverImageUrl = c.coverImageUrl;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _budgetController.dispose();
    _timelineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CAppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(_isEdit ? 'Edit project' : 'Post a project'),
      ),
      body: Column(
        children: [
          _stepIndicator(),
          Expanded(
            child: Form(
              key: _formKey,
              child: IndexedStack(
                index: _step,
                children: [
                  _basicsStep(),
                  _rolesStep(),
                  _detailsStep(),
                ],
              ),
            ),
          ),
          _bottomBar(),
        ],
      ),
    );
  }

  Widget _stepIndicator() {
    final labels = ['Basics', 'Roles', 'Details'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = i <= _step;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: active ? CAppTheme.primaryColor : CAppTheme.borderColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text('${i + 1}',
                      style: GoogleFonts.poppins(
                          color: active ? Colors.white : CAppTheme.textTertiary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 6),
                Text(labels[i],
                    style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                        color: active ? CAppTheme.textPrimary : CAppTheme.textTertiary)),
                if (i < labels.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      color: i < _step ? CAppTheme.primaryColor : CAppTheme.borderColor,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ----------------------------------------------------------- step 1
  Widget _basicsStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GestureDetector(
          onTap: _uploadingCover ? null : _pickCover,
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
              border: Border.all(color: CAppTheme.borderColor),
              image: _coverImageUrl != null && _coverImageUrl!.isNotEmpty
                  ? DecorationImage(image: NetworkImage(_coverImageUrl!), fit: BoxFit.cover)
                  : null,
            ),
            child: _uploadingCover
                ? const Center(child: CircularProgressIndicator())
                : (_coverImageUrl == null || _coverImageUrl!.isEmpty)
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_photo_alternate_rounded,
                              size: 34, color: CAppTheme.textTertiary),
                          const SizedBox(height: 8),
                          Text('Add a cover image (optional)',
                              style: GoogleFonts.poppins(
                                  fontSize: 13, color: CAppTheme.textSecondary)),
                        ],
                      )
                    : null,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Project title',
            hintText: 'e.g. Flutter FYP App - need a team',
          ),
          validator: FormValidators.collabTitle,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _descController,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'Description',
            hintText: 'Describe the project, goals and what you need...',
            alignLabelWithHint: true,
          ),
          validator: FormValidators.collabDescription,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text('Category',
                style: GoogleFonts.poppins(
                    fontSize: 13.5, fontWeight: FontWeight.w600, color: CAppTheme.textSecondary)),
            const Spacer(),
            if (_categories.isNotEmpty)
              Text('${_categories.length} selected',
                  style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w600, color: CAppTheme.primaryColor)),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _allCategories.map((c) {
            final selected = _categories.contains(c);
            return GestureDetector(
              onTap: () => setState(() {
                if (selected) {
                  _categories.remove(c);
                } else {
                  _categories.add(c);
                }
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? CAppTheme.primaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(CAppTheme.radiusRound),
                  border: Border.all(
                      color: selected ? CAppTheme.primaryColor : CAppTheme.borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected) ...[
                      const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                    ],
                    Text(c,
                        style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: selected ? Colors.white : CAppTheme.textPrimary)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ----------------------------------------------------------- step 2
  Widget _rolesStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: CAppTheme.infoColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: CAppTheme.infoColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Add the open roles you are recruiting for. Each role can have its own skills. There is no limit on team size.',
                  style: GoogleFonts.poppins(fontSize: 12.5, color: CAppTheme.textSecondary, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ..._roles.asMap().entries.map((e) => _roleCard(e.key, e.value)),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: _addRole,
          icon: const Icon(Icons.add),
          label: const Text('Add a role'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _roleCard(int index, _RoleDraft role) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(role.title,
                      style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 20, color: CAppTheme.textTertiary),
                  onPressed: () => setState(() => _roles.removeAt(index)),
                ),
              ],
            ),
            if (role.skills.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: role.skills.map((s) => SkillChip(label: s)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------- step 3
  Widget _detailsStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextFormField(
          controller: _timelineController,
          decoration: const InputDecoration(
            labelText: 'Timeline (optional)',
            hintText: 'e.g. 2 months',
          ),
          validator: (v) => FormValidators.optionalShortText(v, label: 'Timeline'),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _budgetController,
          enabled: _paymentMode == 'escrow',
          decoration: const InputDecoration(
            labelText: 'Budget (optional)',
            hintText: 'e.g. Volunteer / 50k PKR',
          ),
          validator: (v) => FormValidators.optionalShortText(v, label: 'Budget'),
        ),
        const SizedBox(height: 20),
        Text('Collaboration type',
            style: GoogleFonts.poppins(
                fontSize: 13.5, fontWeight: FontWeight.w600, color: CAppTheme.textSecondary)),
        const SizedBox(height: 10),
        _paymentModeTile(
          'escrow',
          Icons.account_balance_wallet_outlined,
          'Paid collaboration',
          'Use milestone payments and wallet escrow',
        ),
        _paymentModeTile(
          'none',
          Icons.groups_rounded,
          'Non-paid collaboration',
          'Team collaboration only (no payment flow, like Zoom teamwork)',
        ),
        if (_paymentMode == 'none') ...[
          const SizedBox(height: 8),
          Text(
            'Payment sections and funding actions will stay hidden for this project.',
            style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.textSecondary),
          ),
        ],
        const SizedBox(height: 20),
        Text('Visibility',
            style: GoogleFonts.poppins(
                fontSize: 13.5, fontWeight: FontWeight.w600, color: CAppTheme.textSecondary)),
        const SizedBox(height: 10),
        _visibilityTile('public', Icons.public_rounded, 'Public',
            'Anyone can discover and apply to this project'),
        _visibilityTile('invite_only', Icons.lock_rounded, 'Invite only',
            'Only people with the invite link can apply'),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _visibilityTile(String value, IconData icon, String title, String subtitle) {
    final selected = _visibility == value;
    return GestureDetector(
      onTap: () => setState(() => _visibility = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? CAppTheme.primaryColor.withValues(alpha: 0.07) : Colors.white,
          borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
          border: Border.all(
            color: selected ? CAppTheme.primaryColor : CAppTheme.borderColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? CAppTheme.primaryColor : CAppTheme.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.textSecondary)),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: CAppTheme.primaryColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _paymentModeTile(String value, IconData icon, String title, String subtitle) {
    final selected = _paymentMode == value;
    return GestureDetector(
      onTap: () => setState(() {
        _paymentMode = value;
        if (_paymentMode == 'none') {
          _budgetController.clear();
        }
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? CAppTheme.primaryColor.withValues(alpha: 0.07) : Colors.white,
          borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
          border: Border.all(
            color: selected ? CAppTheme.primaryColor : CAppTheme.borderColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? CAppTheme.primaryColor : CAppTheme.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.textSecondary)),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: CAppTheme.primaryColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar() {
    const buttonHeight = 52.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(color: Colors.white, boxShadow: CAppTheme.softShadow),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (_step > 0) ...[
              Expanded(
                child: SizedBox(
                  height: buttonHeight,
                  child: OutlinedButton(
                    onPressed: () => setState(() => _step--),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('Back'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: _step > 0 ? 2 : 1,
              child: SizedBox(
                height: buttonHeight,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _next,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_step < 2 ? 'Continue' : (_isEdit ? 'Save changes' : 'Publish project')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ actions
  void _next() {
    if (_step == 0) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
      if (_categories.isEmpty) {
        _toast('Please pick at least one category', isError: true);
        return;
      }
      setState(() => _step = 1);
    } else if (_step == 1) {
      if (_roles.isEmpty && !_isEdit) {
        _toast('Add at least one role', isError: true);
        return;
      }
      setState(() => _step = 2);
    } else {
      _submit();
    }
  }

  Future<void> _addRole() async {
    final result = await showModalBottomSheet<_RoleDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddRoleSheet(suggestedSkills: _suggestedSkills),
    );
    if (result != null) setState(() => _roles.add(result));
  }

  Future<void> _pickCover() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked == null) return;
      setState(() => _uploadingCover = true);
      final bytes = await picked.readAsBytes();
      final id = widget.collaboration?.id ?? 'draft_${DateTime.now().millisecondsSinceEpoch}';
      final url = await StorageService().uploadProjectCover(
        collaborationId: id,
        bytes: bytes,
        fileName: picked.name,
      );
      setState(() {
        _coverImageUrl = url;
        _uploadingCover = false;
      });
    } catch (e) {
      setState(() => _uploadingCover = false);
      _toast('Cover upload failed: $e', isError: true);
    }
  }

  Future<void> _submit() async {
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);
    try {
      final budgetAmount = _paymentMode == 'escrow'
          ? CollaborationModel.parseBudgetAmount(_budgetController.text)
          : null;

      if (!_isEdit && _paymentMode == 'escrow') {
        if (budgetAmount == null || budgetAmount <= 0) {
          throw Exception('Escrow projects require a valid budget amount before posting.');
        }
        final wallet = await _walletService.getWallet(user.id);
        if (wallet.balance < budgetAmount) {
          throw Exception(
            'Insufficient wallet balance. Add at least Rs. ${budgetAmount.toStringAsFixed(0)} to post this escrow project.',
          );
        }
      }

      final allSkills = <String>{};
      for (final r in _roles) {
        allSkills.addAll(r.skills);
      }

      final collaboration = CollaborationModel(
        id: widget.collaboration?.id ?? _uuid.v4(),
        userId: user.id,
        userName: user.name,
        userEmail: user.email,
        userProfileImage: user.profileImageUrl,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        requiredSkills: allSkills.toList(),
        collaborationType: 'need_help',
        projectMode: 'team_project',
        projectType: _categories.join(', '),
        budget: _paymentMode == 'escrow' && _budgetController.text.trim().isNotEmpty
            ? _budgetController.text.trim()
            : null,
        budgetAmount: budgetAmount,
        timeline: _timelineController.text.trim().isEmpty ? null : _timelineController.text.trim(),
        status: 'recruiting',
        visibility: _visibility,
        paymentMode: _paymentMode,
        coverImageUrl: _coverImageUrl,
        createdAt: widget.collaboration?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (_isEdit) {
        await _collab.updateCollaboration(collaboration);
      } else {
        await _collab.createCollaboration(collaboration);
        for (var i = 0; i < _roles.length; i++) {
          await _hub.addRole(CollaborationRole(
            id: _uuid.v4(),
            collaborationId: collaboration.id,
            title: _roles[i].title,
            requiredSkills: _roles[i].skills,
            sortOrder: i,
            createdAt: DateTime.now(),
          ));
        }
      }

      if (!mounted) return;
      Navigator.pop(context, true);
      _toast(_isEdit ? 'Project updated!' : 'Project published! Start reviewing applicants.');
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '').trim();
      _toast(msg.isEmpty ? 'Something went wrong. Please try again.' : msg, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
// Add role bottom sheet
// =========================================================================
class _AddRoleSheet extends StatefulWidget {
  final List<String> suggestedSkills;
  const _AddRoleSheet({required this.suggestedSkills});

  @override
  State<_AddRoleSheet> createState() => _AddRoleSheetState();
}

class _AddRoleSheetState extends State<_AddRoleSheet> {
  final _title = TextEditingController();
  final _skillInput = TextEditingController();
  final List<String> _skills = [];

  @override
  void dispose() {
    _title.dispose();
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
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
              Text('Add a role',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Define the position and skills you need on your team.',
                  style: GoogleFonts.poppins(fontSize: 12.5, color: CAppTheme.textSecondary)),
              const SizedBox(height: 18),
              TextField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Role title',
                  hintText: 'e.g. Flutter Developer',
                  prefixIcon: Icon(Icons.work_outline_rounded),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text('Required skills',
                      style: GoogleFonts.poppins(
                          fontSize: 13.5, fontWeight: FontWeight.w600, color: CAppTheme.textPrimary)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _skills.isEmpty
                          ? CAppTheme.warningColor.withValues(alpha: 0.12)
                          : CAppTheme.successColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(CAppTheme.radiusRound),
                    ),
                    child: Text(
                      _skills.isEmpty ? 'Add at least 1' : '${_skills.length} selected',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _skills.isEmpty ? CAppTheme.warningColor : CAppTheme.successColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _skillInput,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Type a skill and tap Add',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: IconButton(
                    tooltip: 'Add skill',
                    icon: const Icon(Icons.add_circle_rounded, color: CAppTheme.primaryColor),
                    onPressed: () => _addSkill(_skillInput.text),
                  ),
                ),
                onSubmitted: _addSkill,
              ),
              if (_skills.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Selected skills',
                    style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _skills
                      .map((s) => InputChip(
                            label: Text(s, style: GoogleFonts.poppins(fontSize: 12.5)),
                            deleteIcon: const Icon(Icons.close_rounded, size: 16),
                            onDeleted: () => setState(() => _skills.remove(s)),
                            backgroundColor: CAppTheme.primaryColor.withValues(alpha: 0.1),
                            side: BorderSide(color: CAppTheme.primaryColor.withValues(alpha: 0.25)),
                            labelStyle: GoogleFonts.poppins(
                              color: CAppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 14),
              Text('Suggested skills',
                  style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.textSecondary)),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final chipWidth = screenWidth < 360 ? constraints.maxWidth : (constraints.maxWidth - 8) / 2;
                  final available = widget.suggestedSkills.where((s) => !_skills.contains(s)).toList();
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: available.map((s) {
                      return SizedBox(
                        width: screenWidth < 360 ? null : chipWidth,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _addSkill(s),
                            borderRadius: BorderRadius.circular(CAppTheme.radiusSmall),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: CAppTheme.backgroundColor,
                                borderRadius: BorderRadius.circular(CAppTheme.radiusSmall),
                                border: Border.all(color: CAppTheme.borderColor),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add_rounded, size: 16, color: CAppTheme.primaryColor),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      s,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: CAppTheme.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_title.text.trim().isEmpty) return;
                    if (_skills.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Please add at least one required skill'),
                          backgroundColor: CAppTheme.warningColor,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(context, _RoleDraft(_title.text.trim(), List.from(_skills)));
                  },
                  child: const Text('Add role'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
