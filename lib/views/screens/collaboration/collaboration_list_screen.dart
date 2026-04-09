import 'dart:math' show max;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/models/collaboration_model.dart';
import 'package:cwc/utils/helpers/model_helpers.dart';
import 'package:cwc/services/collaboration_service.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/views/screens/collaboration/collaboration_create_screen.dart';
import 'package:cwc/views/screens/collaboration/collaboration_detail_screen.dart';

/// Collaboration List Screen
/// Displays all available collaboration requests
class CollaborationListScreen extends StatefulWidget {
  const CollaborationListScreen({super.key});

  @override
  State<CollaborationListScreen> createState() => _CollaborationListScreenState();
}

class _CollaborationListScreenState extends State<CollaborationListScreen> {
  final CollaborationService _collaborationService = CollaborationService();
  final TextEditingController _searchController = TextEditingController();
  List<CollaborationModel> _collaborations = [];
  List<CollaborationModel> _allCollaborations = [];
  Map<String, int> _responseCounts = {};
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'all';
  String _searchQuery = '';
  final Set<String> _selectedSkills = {};
  List<String> _availableSkills = [];

  static const List<String> _defaultSkills = [
    'Flutter', 'React', 'Python', 'JavaScript', 'UI/UX',
    'Node.js', 'Firebase', 'Java', 'Swift', 'Kotlin',
    'PHP', 'Laravel', 'Django', 'Machine Learning', 'DevOps',
    'Graphic Design', 'Video Editing', 'Content Writing',
  ];

  @override
  void initState() {
    super.initState();
    _loadCollaborations();
    _searchController.addListener(() {
      if (_searchQuery != _searchController.text) {
        _searchQuery = _searchController.text;
        _applyLocalFilters();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCollaborations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Always fetch ALL collaborations to build the complete skills list
      final allResults = await _collaborationService.getAllCollaborations();

      // Fetch actual response counts from collaboration_responses table
      final ids = allResults.map((c) => c.id).toList();
      _responseCounts = await _collaborationService.getResponseCounts(ids);

      // Merge default skills with skills from existing collaborations
      final skillSet = <String>{..._defaultSkills};
      for (final c in allResults) {
        for (final s in c.requiredSkills) {
          if (s.trim().isNotEmpty) skillSet.add(s.trim());
        }
      }
      _availableSkills = skillSet.toList()..sort();

      // Apply type filter locally
      List<CollaborationModel> collaborations;
      if (_selectedFilter == 'all') {
        collaborations = allResults;
      } else {
        collaborations = allResults
            .where((c) => c.collaborationType == _selectedFilter)
            .toList();
      }

      _allCollaborations = List.from(collaborations);
      _applyLocalFilters(collaborations);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyLocalFilters([List<CollaborationModel>? source]) {
    var collaborations = source ?? List.from(_allCollaborations);

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      collaborations.removeWhere((collab) {
        return !collab.title.toLowerCase().contains(query) &&
            !collab.description.toLowerCase().contains(query) &&
            !collab.requiredSkills.any((skill) =>
                skill.toLowerCase().contains(query));
      });
    }

    // Apply skill filter
    if (_selectedSkills.isNotEmpty) {
      collaborations.removeWhere((collab) {
        return !_selectedSkills.any((skill) =>
            collab.requiredSkills.any((rs) =>
                rs.toLowerCase() == skill.toLowerCase()));
      });
    }

    setState(() {
      _collaborations = collaborations;
      _isLoading = false;
    });
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
          'Collaborations',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: CAppTheme.textPrimary,
          ),
        ),
        automaticallyImplyLeading: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              gradient: CAppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
              boxShadow: [
                BoxShadow(
                  color: CAppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CollaborationCreateScreen(),
                  ),
                ).then((_) => _loadCollaborations());
              },
              tooltip: 'Create Collaboration',
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: CAppTheme.primaryColor,
        onRefresh: _loadCollaborations,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeroHeader()),
            SliverToBoxAdapter(child: _buildFloatingSearchBar()),
            SliverToBoxAdapter(child: _buildFilterChips()),
            SliverToBoxAdapter(child: _buildSkillFilters()),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: CAppTheme.primaryColor),
                ),
              )
            else if (_errorMessage != null)
              SliverFillRemaining(hasScrollBody: false, child: _buildErrorState())
            else if (_collaborations.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final collab = _collaborations[index];
                      return _CollaborationCard(
                        collaboration: collab,
                        responseCount: max(_responseCounts[collab.id] ?? 0, collab.responses.length),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CollaborationDetailScreen(
                                collaborationId: collab.id,
                              ),
                            ),
                          ).then((_) => _loadCollaborations());
                        },
                      );
                    },
                    childCount: _collaborations.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: CAppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(CAppTheme.radiusXL),
        boxShadow: [
          BoxShadow(
            color: CAppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Find Collaborators',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Connect with talented people and bring your ideas to life',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
            ),
            child: const Icon(
              Icons.people_alt_rounded,
              size: 34,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        boxShadow: CAppTheme.cardShadow,
      ),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.poppins(fontSize: 14, color: CAppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search collaborations, skills...',
          hintStyle: GoogleFonts.poppins(color: CAppTheme.textTertiary, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: CAppTheme.primaryColor),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, color: CAppTheme.textSecondary),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
            borderSide: const BorderSide(color: CAppTheme.primaryColor, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('all', 'All', Icons.grid_view_rounded),
            const SizedBox(width: 10),
            _buildFilterChip('need_help', 'Need Help', Icons.help_outline_rounded),
            const SizedBox(width: 10),
            _buildFilterChip('offering_help', 'Offering Help', Icons.handshake_outlined),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, IconData icon) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = value);
        _loadCollaborations();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? CAppTheme.primaryGradient : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(CAppTheme.radiusXL),
          border: isSelected
              ? null
              : Border.all(color: CAppTheme.borderColor, width: 1.5),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: CAppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : CAppTheme.softShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : CAppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: isSelected ? Colors.white : CAppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 14, color: CAppTheme.primaryColor),
              const SizedBox(width: 6),
              Text(
                'Filter by Skills',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: CAppTheme.textSecondary,
                ),
              ),
              if (_selectedSkills.isNotEmpty) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    _selectedSkills.clear();
                    _applyLocalFilters();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: CAppTheme.errorColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(CAppTheme.radiusRound),
                    ),
                    child: Text(
                      'Clear',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: CAppTheme.errorColor,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _availableSkills.map((skill) {
                final isSelected = _selectedSkills.contains(skill);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      if (isSelected) {
                        _selectedSkills.remove(skill);
                      } else {
                        _selectedSkills.add(skill);
                      }
                      _applyLocalFilters();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? CAppTheme.primaryColor
                            : CAppTheme.primaryColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(CAppTheme.radiusRound),
                        border: Border.all(
                          color: isSelected
                              ? CAppTheme.primaryColor
                              : CAppTheme.primaryColor.withValues(alpha: 0.2),
                          width: 1,
                        ),
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
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : CAppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: CAppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                size: 36,
                color: CAppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No collaborations found',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: CAppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Be the first to create a collaboration request!',
              style: GoogleFonts.poppins(
                color: CAppTheme.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CollaborationCreateScreen(),
                  ),
                ).then((_) => _loadCollaborations());
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Collaboration'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
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
              child: const Icon(
                Icons.error_outline_rounded,
                size: 36,
                color: CAppTheme.errorColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Error loading collaborations',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: CAppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              style: GoogleFonts.poppins(
                color: CAppTheme.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadCollaborations,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Collaboration Card Widget
class _CollaborationCard extends StatelessWidget {
  final CollaborationModel collaboration;
  final VoidCallback onTap;
  final int responseCount;

  const _CollaborationCard({
    required this.collaboration,
    required this.onTap,
    required this.responseCount,
  });

  bool get _isNeedHelp => collaboration.collaborationType == 'need_help';
  Color get _typeColor => _isNeedHelp
      ? const Color(0xFFEF8B2C)
      : CAppTheme.successColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        boxShadow: CAppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopAccent(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 14),
                    Text(
                      collaboration.title,
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: CAppTheme.textPrimary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      collaboration.description,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: CAppTheme.textSecondary,
                        height: 1.5,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    _buildSkillChips(),
                    const SizedBox(height: 14),
                    Divider(
                      color: CAppTheme.borderColor.withValues(alpha: 0.5),
                      height: 1,
                    ),
                    const SizedBox(height: 12),
                    _buildFooter(),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'View Details →',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: CAppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopAccent() {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _typeColor,
            _typeColor.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(CAppTheme.radiusLarge),
          topRight: Radius.circular(CAppTheme.radiusLarge),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        _buildAvatar(),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  collaboration.userName,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: CAppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.circle,
                  size: 4,
                  color: CAppTheme.textTertiary,
                ),
              ),
              Text(
                _formatTime(collaboration.createdAt),
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: CAppTheme.textTertiary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildTypeBadge(),
      ],
    );
  }

  Widget _buildAvatar() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: _typeColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: CircleAvatar(
        radius: 22,
        backgroundColor: _typeColor.withValues(alpha: 0.1),
        backgroundImage: collaboration.userProfileImage != null
            ? NetworkImage(collaboration.userProfileImage!)
            : null,
        child: collaboration.userProfileImage == null
            ? Text(
                safeInitial(collaboration.userName),
                style: GoogleFonts.poppins(
                  color: _typeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildTypeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _typeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(CAppTheme.radiusXL),
        border: Border.all(
          color: _typeColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isNeedHelp ? Icons.help_outline_rounded : Icons.handshake_outlined,
            size: 13,
            color: _typeColor,
          ),
          const SizedBox(width: 4),
          Text(
            _isNeedHelp ? 'Need Help' : 'Offering',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _typeColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillChips() {
    final skills = collaboration.requiredSkills;
    final displaySkills = skills.take(4).toList();
    final remaining = skills.length - displaySkills.length;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ...displaySkills.map((skill) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(CAppTheme.radiusXL),
              border: Border.all(
                color: CAppTheme.primaryColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              skill,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: CAppTheme.primaryColor,
              ),
            ),
          );
        }),
        if (remaining > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(CAppTheme.radiusXL),
              border: Border.all(
                color: CAppTheme.textTertiary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              '+$remaining more',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: CAppTheme.textSecondary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: CAppTheme.primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(CAppTheme.radiusSmall),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.forum_outlined,
                size: 14,
                color: CAppTheme.primaryColor,
              ),
              const SizedBox(width: 4),
              Text(
                '$responseCount ${responseCount == 1 ? 'response' : 'responses'}',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: CAppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
        if (collaboration.projectType != null &&
            collaboration.projectType!.isNotEmpty) ...[
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: CAppTheme.textTertiary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(CAppTheme.radiusSmall),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 13,
                  color: CAppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  collaboration.projectType!,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: CAppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (collaboration.budget != null &&
            collaboration.budget!.isNotEmpty) ...[
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.payments_outlined,
                size: 13,
                color: CAppTheme.successColor,
              ),
              const SizedBox(width: 4),
              Text(
                collaboration.budget!,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: CAppTheme.successColor,
                ),
              ),
            ],
          ),
        ],
        if (collaboration.projectType == null && collaboration.budget == null)
          const Spacer(),
      ],
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
