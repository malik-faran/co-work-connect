import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/models/collaboration_model.dart';
import 'package:cwc/services/collaboration_service.dart';
import 'package:cwc/utils/helpers/model_helpers.dart';
import 'package:cwc/services/chat_service.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/views/screens/collaboration/collaboration_create_screen.dart';
import 'package:cwc/views/screens/chat/chat_screen.dart';

/// Collaboration Detail Screen
/// Shows full collaboration details and allows users to respond
class CollaborationDetailScreen extends StatefulWidget {
  final String collaborationId;

  const CollaborationDetailScreen({
    super.key,
    required this.collaborationId,
  });

  @override
  State<CollaborationDetailScreen> createState() => _CollaborationDetailScreenState();
}

class _CollaborationDetailScreenState extends State<CollaborationDetailScreen> {
  final CollaborationService _collaborationService = CollaborationService();
  final ChatService _chatService = ChatService();
  final _uuid = const Uuid();

  CollaborationModel? _collaboration;
  List<CollaborationResponseModel> _responses = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _showResponseForm = false;
  bool _isSubmitting = false;

  final _responseController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadCollaboration();
  }

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  Future<void> _loadCollaboration() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final collaboration = await _collaborationService.getCollaborationById(
        widget.collaborationId,
      );

      if (collaboration == null) {
        setState(() {
          _errorMessage = 'Collaboration not found';
          _isLoading = false;
        });
        return;
      }

      final responses = await _collaborationService.getCollaborationResponses(
        widget.collaborationId,
      );

      setState(() {
        _collaboration = collaboration;
        _responses = responses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _submitResponse() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    final authController = context.read<AuthController>();
    final user = authController.currentUser;
    if (user == null || _collaboration == null) return;

    if (_collaboration!.hasUserResponded(user.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have already responded to this collaboration')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final response = CollaborationResponseModel(
        id: _uuid.v4(),
        collaborationId: _collaboration!.id,
        userId: user.id,
        userName: user.name,
        userEmail: user.email,
        userProfileImage: user.profileImageUrl,
        message: _responseController.text.trim(),
        userSkills: user.skills,
        createdAt: DateTime.now(),
      );

      await _collaborationService.addResponse(response);

      _responseController.clear();
      setState(() {
        _showResponseForm = false;
        _isSubmitting = false;
      });
      _loadCollaboration();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Response submitted successfully!'),
          backgroundColor: CAppTheme.successColor,
        ),
      );
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: CAppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _startChat(String otherUserId, String otherUserName) async {
    try {
      final authController = context.read<AuthController>();
      final currentUser = authController.currentUser;
      if (currentUser == null) return;

      final chatRoom = await _chatService.getOrCreateChatRoom(
        user1Id: currentUser.id,
        user2Id: otherUserId,
        collaborationId: _collaboration?.id,
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(chatRoomId: chatRoom.id),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting chat: ${e.toString()}'),
          backgroundColor: CAppTheme.errorColor,
        ),
      );
    }
  }

  bool get _isNeedHelp => _collaboration?.collaborationType == 'need_help';
  Color get _typeColor => _isNeedHelp
      ? const Color(0xFFEF8B2C)
      : CAppTheme.successColor;

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final currentUser = authController.currentUser;
    final isOwner = currentUser?.id == _collaboration?.userId;

    return Scaffold(
      backgroundColor: CAppTheme.backgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: CAppTheme.primaryColor))
          : _errorMessage != null
              ? _buildErrorState()
              : _collaboration == null
                  ? _buildEmptyState()
                  : _buildContent(isOwner, currentUser),
    );
  }

  Widget _buildContent(bool isOwner, currentUser) {
    return CustomScrollView(
      slivers: [
        _buildGradientHeader(isOwner),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCollaborationCard(),
              if (!isOwner &&
                  currentUser != null &&
                  !_collaboration!.hasUserResponded(currentUser.id) &&
                  _collaboration!.isOpen) ...[
                _buildResponseForm(),
              ],
              _buildResponsesSection(isOwner, currentUser),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGradientHeader(bool isOwner) {
    return SliverAppBar(
      expandedHeight: 170,
      pinned: true,
      backgroundColor: CAppTheme.primaryColor,
      surfaceTintColor: Colors.transparent,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      actions: isOwner
          ? [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                ),
                child: IconButton(
                  icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CollaborationCreateScreen(
                          collaboration: _collaboration,
                        ),
                      ),
                    ).then((_) => _loadCollaboration());
                  },
                ),
              ),
            ]
          : null,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: CAppTheme.primaryGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(CAppTheme.radiusXL),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isNeedHelp ? Icons.help_outline_rounded : Icons.handshake_outlined,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _isNeedHelp ? 'Need Help' : 'Offering Help',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _collaboration!.title,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollaborationCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // User info card
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
            boxShadow: CAppTheme.softShadow,
          ),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: CAppTheme.primaryColor.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: CAppTheme.primaryColor.withValues(alpha: 0.1),
                  backgroundImage: _collaboration!.userProfileImage != null
                      ? NetworkImage(_collaboration!.userProfileImage!)
                      : null,
                  child: _collaboration!.userProfileImage == null
                      ? Text(
                          safeInitial(_collaboration!.userName),
                          style: GoogleFonts.poppins(
                            color: CAppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _collaboration!.userName,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: CAppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _collaboration!.userEmail,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: CAppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time_rounded, size: 13, color: CAppTheme.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(_collaboration!.createdAt),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: CAppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Description section
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                      Icons.description_outlined,
                      size: 18,
                      color: CAppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Description',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: CAppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _collaboration!.description,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: CAppTheme.textSecondary,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),

        // Skills section
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: CAppTheme.secondaryColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Required Skills',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: CAppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _collaboration!.requiredSkills.map((skill) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          CAppTheme.primaryColor.withValues(alpha: 0.1),
                          CAppTheme.secondaryColor.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(CAppTheme.radiusXL),
                      border: Border.all(
                        color: CAppTheme.primaryColor.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      skill,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: CAppTheme.primaryColor,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        // Project details section
        if (_collaboration!.projectType != null ||
            _collaboration!.budget != null ||
            _collaboration!.timeline != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                        Icons.info_outline_rounded,
                        size: 18,
                        color: CAppTheme.infoColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Project Details',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: CAppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_collaboration!.projectType != null)
                  _buildInfoRow(Icons.category_rounded, 'Project Type', _collaboration!.projectType!),
                if (_collaboration!.budget != null)
                  _buildInfoRow(Icons.attach_money_rounded, 'Budget', _collaboration!.budget!),
                if (_collaboration!.timeline != null)
                  _buildInfoRow(Icons.schedule_rounded, 'Timeline', _collaboration!.timeline!),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CAppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: CAppTheme.primaryColor),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: CAppTheme.textSecondary,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CAppTheme.textPrimary,
              ),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponseForm() {
    if (!_showResponseForm) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => setState(() => _showResponseForm = true),
          icon: const Icon(Icons.reply_rounded, size: 20),
          label: Text(
            'Respond to Collaboration',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        boxShadow: CAppTheme.cardShadow,
        border: Border.all(
          color: CAppTheme.primaryColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    CAppTheme.primaryColor.withValues(alpha: 0.06),
                    CAppTheme.secondaryColor.withValues(alpha: 0.03),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(CAppTheme.radiusLarge),
                  topRight: Radius.circular(CAppTheme.radiusLarge),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CAppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(CAppTheme.radiusSmall),
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      size: 18,
                      color: CAppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Your Response',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: CAppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _responseController,
                    decoration: InputDecoration(
                      hintText: 'Tell them why you\'re interested and how you can help...',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 13,
                        color: CAppTheme.textTertiary,
                      ),
                      filled: true,
                      fillColor: CAppTheme.backgroundColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                        borderSide: const BorderSide(color: CAppTheme.primaryColor, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    maxLines: 5,
                    style: GoogleFonts.poppins(fontSize: 14, color: CAppTheme.textPrimary),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your response';
                      }
                      if (value.trim().length < 20) {
                        return 'Response must be at least 20 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => _showResponseForm = false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitResponse,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 18),
                          label: Text(
                            _isSubmitting ? 'Submitting...' : 'Submit',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsesSection(bool isOwner, currentUser) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
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
                  Icons.forum_rounded,
                  size: 18,
                  color: CAppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Responses',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: CAppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  gradient: CAppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(CAppTheme.radiusXL),
                ),
                child: Text(
                  '${_responses.length}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_responses.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                boxShadow: CAppTheme.softShadow,
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CAppTheme.primaryColor.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.forum_outlined,
                      size: 32,
                      color: CAppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No responses yet',
                    style: GoogleFonts.poppins(
                      color: CAppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Be the first one to respond!',
                    style: GoogleFonts.poppins(
                      color: CAppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          else
            ..._responses.map((response) => _buildResponseCard(response, isOwner, currentUser)),
        ],
      ),
    );
  }

  Widget _buildResponseCard(CollaborationResponseModel response, bool isOwner, currentUser) {
    final isAccepted = response.status == 'accepted';
    final isRejected = response.status == 'rejected';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isRejected ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        boxShadow: CAppTheme.softShadow,
        border: isAccepted
            ? Border.all(color: CAppTheme.successColor.withValues(alpha: 0.4), width: 2)
            : isRejected
                ? Border.all(color: CAppTheme.errorColor.withValues(alpha: 0.2), width: 1)
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAccepted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: CAppTheme.successColor.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(CAppTheme.radiusLarge),
                  topRight: Radius.circular(CAppTheme.radiusLarge),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 16, color: CAppTheme.successColor),
                  const SizedBox(width: 6),
                  Text(
                    'Accepted Collaborator',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: CAppTheme.successColor,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isAccepted
                              ? CAppTheme.successColor.withValues(alpha: 0.3)
                              : CAppTheme.primaryColor.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: CAppTheme.primaryColor.withValues(alpha: 0.1),
                        backgroundImage: response.userProfileImage != null
                            ? NetworkImage(response.userProfileImage!)
                            : null,
                        child: response.userProfileImage == null
                            ? Text(
                                safeInitial(response.userName),
                                style: GoogleFonts.poppins(
                                  color: CAppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            response.userName,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: CAppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 12, color: CAppTheme.textTertiary),
                              const SizedBox(width: 3),
                              Text(
                                _formatTime(response.createdAt),
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: CAppTheme.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: CAppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                  ),
                  child: Text(
                    response.message,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: CAppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
                if (response.userSkills != null && response.userSkills!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Skills',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: CAppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: response.userSkills!.take(6).map((skill) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              CAppTheme.primaryColor.withValues(alpha: 0.1),
                              CAppTheme.secondaryColor.withValues(alpha: 0.06),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(CAppTheme.radiusXL),
                        ),
                        child: Text(
                          skill,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: CAppTheme.primaryColor,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 14),
                if (isOwner && response.status == 'pending')
                  Row(
                    children: [
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: () => _showConfirmDialog(
                          title: 'Reject Response',
                          message: 'Are you sure you want to reject ${response.userName}\'s response?',
                          confirmText: 'Reject',
                          confirmColor: CAppTheme.errorColor,
                          onConfirm: () async {
                            try {
                              await _collaborationService.rejectResponse(
                                _collaboration!.id,
                                response.id,
                                response.userId,
                              );
                              _loadCollaboration();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Response rejected'),
                                  backgroundColor: CAppTheme.warningColor,
                                ),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString()}'),
                                  backgroundColor: CAppTheme.errorColor,
                                ),
                              );
                            }
                          },
                        ),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: Text(
                          'Reject',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: CAppTheme.errorColor,
                          side: const BorderSide(color: CAppTheme.errorColor),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () => _showConfirmDialog(
                          title: 'Accept Response',
                          message: 'Are you sure you want to accept ${response.userName}\'s response? This will change the collaboration status to In Progress.',
                          confirmText: 'Accept',
                          confirmColor: CAppTheme.successColor,
                          onConfirm: () async {
                            try {
                              await _collaborationService.acceptResponse(
                                _collaboration!.id,
                                response.id,
                                response.userId,
                              );
                              _loadCollaboration();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Response accepted!'),
                                  backgroundColor: CAppTheme.successColor,
                                ),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString()}'),
                                  backgroundColor: CAppTheme.errorColor,
                                ),
                              );
                            }
                          },
                        ),
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                        label: Text(
                          'Accept',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CAppTheme.successColor,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                          ),
                        ),
                      ),
                    ],
                  )
                else if (response.status == 'rejected')
                  Row(
                    children: [
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: CAppTheme.errorColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cancel_rounded, size: 16, color: CAppTheme.errorColor),
                            const SizedBox(width: 6),
                            Text(
                              'Rejected',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: CAppTheme.errorColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                else if (currentUser != null &&
                    currentUser.id != response.userId &&
                    response.status == 'accepted')
                  Row(
                    children: [
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () => _startChat(response.userId, response.userName),
                        icon: const Icon(Icons.chat_rounded, size: 18),
                        label: Text(
                          'Start Chat',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CAppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: CAppTheme.errorColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 36, color: CAppTheme.errorColor),
            ),
            const SizedBox(height: 20),
            Text(
              'Something went wrong',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: CAppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              style: GoogleFonts.poppins(color: CAppTheme.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadCollaboration,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'Collaboration not found',
        style: GoogleFonts.poppins(
          color: CAppTheme.textSecondary,
          fontSize: 16,
        ),
      ),
    );
  }

  void _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
    required Future<void> Function() onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: CAppTheme.textPrimary,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: CAppTheme.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: CAppTheme.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
              ),
            ),
            child: Text(
              confirmText,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
