import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/models/collaboration_model.dart';
import 'package:cwc/services/collaboration_service.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:uuid/uuid.dart';

/// Collaboration Create Screen
/// Allows users to create new collaboration requests
class CollaborationCreateScreen extends StatefulWidget {
  final CollaborationModel? collaboration;

  const CollaborationCreateScreen({super.key, this.collaboration});

  @override
  State<CollaborationCreateScreen> createState() => _CollaborationCreateScreenState();
}

class _CollaborationCreateScreenState extends State<CollaborationCreateScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController();
  final _timelineController = TextEditingController();
  final _skillController = TextEditingController();

  final CollaborationService _collaborationService = CollaborationService();
  final _uuid = const Uuid();

  String _collaborationType = 'need_help';
  String? _projectType;
  List<String> _requiredSkills = [];
  bool _isLoading = false;
  int _currentStep = 0;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;

  final List<String> _commonSkills = [
    'Flutter Development',
    'React Development',
    'UI/UX Design',
    'Backend Development',
    'Mobile App Development',
    'Web Development',
    'Graphic Design',
    'Content Writing',
    'Marketing',
    'Data Analysis',
    'Project Management',
    'Video Editing',
    'Photography',
    'Business Strategy',
    'Accounting',
  ];

  final List<String> _projectTypes = [
    'Web Development',
    'Mobile App',
    'Design',
    'Marketing',
    'Content Creation',
    'Business',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    if (widget.collaboration != null) {
      final collab = widget.collaboration!;
      _titleController.text = collab.title;
      _descriptionController.text = collab.description;
      _budgetController.text = collab.budget ?? '';
      _timelineController.text = collab.timeline ?? '';
      _collaborationType = collab.collaborationType;
      _projectType = collab.projectType;
      _requiredSkills = List.from(collab.requiredSkills);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    _timelineController.dispose();
    _skillController.dispose();
    super.dispose();
  }

  void _addSkill(String skill) {
    if (skill.trim().isNotEmpty && !_requiredSkills.contains(skill.trim())) {
      setState(() {
        _requiredSkills.add(skill.trim());
        _skillController.clear();
      });
    }
  }

  void _removeSkill(String skill) {
    setState(() {
      _requiredSkills.remove(skill);
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_requiredSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one required skill')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authController = context.read<AuthController>();
      final user = authController.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final collaboration = CollaborationModel(
        id: widget.collaboration?.id ?? _uuid.v4(),
        userId: user.id,
        userName: user.name,
        userEmail: user.email,
        userProfileImage: user.profileImageUrl,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        requiredSkills: _requiredSkills,
        collaborationType: _collaborationType,
        projectType: _projectType,
        budget: _budgetController.text.trim().isEmpty
            ? null
            : _budgetController.text.trim(),
        timeline: _timelineController.text.trim().isEmpty
            ? null
            : _timelineController.text.trim(),
        createdAt: widget.collaboration?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.collaboration != null) {
        await _collaborationService.updateCollaboration(collaboration);
      } else {
        await _collaborationService.createCollaboration(collaboration);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.collaboration != null
                ? 'Collaboration updated successfully!'
                : 'Collaboration created successfully!',
          ),
          backgroundColor: CAppTheme.successColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: CAppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _updateStep() {
    int step = 0;
    if (_collaborationType.isNotEmpty) step = 1;
    if (_titleController.text.isNotEmpty && _descriptionController.text.isNotEmpty) step = 2;
    if (_requiredSkills.isNotEmpty) step = 3;
    if (_currentStep != step) {
      setState(() => _currentStep = step);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CAppTheme.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.collaboration != null ? 'Edit Collaboration' : 'Create Collaboration',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: CAppTheme.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: CAppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStepIndicator(),
                const SizedBox(height: 20),
                _buildTypeSelection(),
                const SizedBox(height: 16),
                _buildDetailsCard(),
                const SizedBox(height: 16),
                _buildSkillsCard(),
                const SizedBox(height: 16),
                _buildAdditionalDetailsCard(),
                const SizedBox(height: 24),
                _buildSubmitButton(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = [
      _StepData('Type', Icons.category_rounded),
      _StepData('Details', Icons.edit_note_rounded),
      _StepData('Skills', Icons.auto_awesome_rounded),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Row(
        children: List.generate(steps.length, (index) {
          final isActive = index <= _currentStep;
          final isCompleted = index < _currentStep;
          return Expanded(
            child: Row(
              children: [
                if (index > 0)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 3,
                      decoration: BoxDecoration(
                        color: isActive
                            ? CAppTheme.primaryColor
                            : CAppTheme.borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: isActive ? CAppTheme.primaryGradient : null,
                        color: isActive ? null : CAppTheme.borderColor.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: CAppTheme.primaryColor.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        isCompleted ? Icons.check_rounded : steps[index].icon,
                        size: 20,
                        color: isActive ? Colors.white : CAppTheme.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      steps[index].label,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        color: isActive ? CAppTheme.primaryColor : CAppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTypeSelection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        boxShadow: CAppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CAppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(CAppTheme.radiusSmall),
                ),
                child: const Icon(
                  Icons.category_rounded,
                  size: 18,
                  color: CAppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'I want to:',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CAppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTypeOption(
                  'Need Help',
                  'need_help',
                  Icons.help_outline_rounded,
                  const Color(0xFFEF8B2C),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTypeOption(
                  'Offer Help',
                  'offering_help',
                  Icons.handshake_outlined,
                  CAppTheme.successColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        boxShadow: CAppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CAppTheme.secondaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(CAppTheme.radiusSmall),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  size: 18,
                  color: CAppTheme.secondaryColor,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Details',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CAppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title *',
              hintText: 'e.g., Need Flutter Developer for Mobile App',
            ),
            onChanged: (_) => _updateStep(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a title';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description *',
              hintText: 'Describe your project or what you need...',
            ),
            maxLines: 5,
            onChanged: (_) => _updateStep(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a description';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _projectType,
            decoration: const InputDecoration(
              labelText: 'Project Type',
              hintText: 'Select project type',
            ),
            items: _projectTypes.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _projectType = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        boxShadow: CAppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CAppTheme.infoColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(CAppTheme.radiusSmall),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: CAppTheme.infoColor,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Required Skills *',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CAppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _skillController,
                  decoration: InputDecoration(
                    hintText: 'Add a custom skill',
                    isDense: true,
                    hintStyle: GoogleFonts.poppins(color: CAppTheme.textTertiary, fontSize: 14),
                  ),
                  style: GoogleFonts.poppins(fontSize: 14),
                  onSubmitted: (value) {
                    _addSkill(value);
                    _updateStep();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  gradient: CAppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                ),
                child: IconButton(
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  onPressed: () {
                    _addSkill(_skillController.text);
                    _updateStep();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Popular Skills',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: CAppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _commonSkills.map((skill) {
              final isSelected = _requiredSkills.contains(skill);
              return GestureDetector(
                onTap: () {
                  if (isSelected) {
                    _removeSkill(skill);
                  } else {
                    _addSkill(skill);
                  }
                  _updateStep();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSelected ? CAppTheme.primaryGradient : null,
                    color: isSelected ? null : CAppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(CAppTheme.radiusXL),
                    border: isSelected
                        ? null
                        : Border.all(color: CAppTheme.borderColor, width: 1),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: CAppTheme.primaryColor.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        skill,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isSelected ? Colors.white : CAppTheme.textPrimary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (_requiredSkills.isNotEmpty) ...[
            const SizedBox(height: 20),
            Divider(color: CAppTheme.borderColor.withValues(alpha: 0.5), height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  'Selected Skills',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CAppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: CAppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(CAppTheme.radiusXL),
                  ),
                  child: Text(
                    '${_requiredSkills.length}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _requiredSkills.map((skill) {
                return Container(
                  padding: const EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
                  decoration: BoxDecoration(
                    color: CAppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(CAppTheme.radiusXL),
                    border: Border.all(
                      color: CAppTheme.primaryColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        skill,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: CAppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      InkWell(
                        onTap: () {
                          _removeSkill(skill);
                          _updateStep();
                        },
                        borderRadius: BorderRadius.circular(CAppTheme.radiusXL),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: CAppTheme.primaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: CAppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdditionalDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        boxShadow: CAppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CAppTheme.warningColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(CAppTheme.radiusSmall),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: CAppTheme.warningColor.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Additional Details',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CAppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: CAppTheme.textTertiary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(CAppTheme.radiusSmall),
                ),
                child: Text(
                  'Optional',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: CAppTheme.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _budgetController,
            decoration: const InputDecoration(
              labelText: 'Budget',
              hintText: 'e.g., \$500-\$1000',
              prefixIcon: Icon(Icons.attach_money_rounded),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _timelineController,
            decoration: const InputDecoration(
              labelText: 'Timeline',
              hintText: 'e.g., 2-3 weeks',
              prefixIcon: Icon(Icons.schedule_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: CAppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: CAppTheme.primaryColor.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.collaboration != null ? Icons.save_rounded : Icons.rocket_launch_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.collaboration != null ? 'Update Collaboration' : 'Create Collaboration',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTypeOption(String label, String value, IconData icon, Color accentColor) {
    final isSelected = _collaborationType == value;
    return GestureDetector(
      onTap: () {
        setState(() => _collaborationType = value);
        _updateStep();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accentColor,
                    accentColor.withValues(alpha: 0.8),
                  ],
                )
              : null,
          color: isSelected ? null : CAppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
          border: isSelected
              ? null
              : Border.all(color: CAppTheme.borderColor, width: 1.5),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.2)
                    : accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : accentColor,
                size: 26,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isSelected ? Colors.white : CAppTheme.textPrimary,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Container(
                width: 20,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepData {
  final String label;
  final IconData icon;
  const _StepData(this.label, this.icon);
}
