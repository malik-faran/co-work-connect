/// Workspace Management Screen
/// Allows owners to edit and manage their workspace
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cwc/controllers/workspace_controller.dart';
import 'package:cwc/models/workspace_model.dart';
import 'package:cwc/views/screens/owner/add_workspace_screen.dart';
import 'package:cwc/utils/themes/theme.dart';

class WorkspaceManagementScreen extends StatefulWidget {
  final String workspaceId;

  const WorkspaceManagementScreen({super.key, required this.workspaceId});

  @override
  State<WorkspaceManagementScreen> createState() =>
      _WorkspaceManagementScreenState();
}

class _WorkspaceManagementScreenState extends State<WorkspaceManagementScreen> {
  WorkspaceModel? _workspace;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkspace();
  }

  Future<void> _loadWorkspace() async {
    final controller = Provider.of<WorkspaceController>(context, listen: false);
    final workspace = await controller.getWorkspaceById(widget.workspaceId);
    setState(() {
      _workspace = workspace;
      _isLoading = false;
    });
  }

  Future<void> _deleteWorkspace() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        ),
        title: Text(
          'Delete Workspace',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: CAppTheme.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this workspace? This action cannot be undone.',
          style: GoogleFonts.poppins(
            color: CAppTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: CAppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: CAppTheme.errorColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
              ),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final controller = Provider.of<WorkspaceController>(
        context,
        listen: false,
      );
      final success = await controller.deleteWorkspace(widget.workspaceId, ownerId: _workspace?.ownerId);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Workspace deleted successfully',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: CAppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: CAppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'Workspace Management',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              color: CAppTheme.textPrimary,
            ),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(color: CAppTheme.primaryColor),
        ),
      );
    }

    if (_workspace == null) {
      return Scaffold(
        backgroundColor: CAppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'Workspace Management',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              color: CAppTheme.textPrimary,
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 48,
                color: CAppTheme.textTertiary,
              ),
              const SizedBox(height: 12),
              Text(
                'Workspace not found',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: CAppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: CAppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: CAppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Manage Workspace',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: CAppTheme.textPrimary,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: CAppTheme.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(CAppTheme.radiusSmall),
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                color: CAppTheme.errorColor,
                size: 20,
              ),
            ),
            onPressed: _deleteWorkspace,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Workspace Image
            ClipRRect(
              borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
              child: Container(
                height: 200,
                width: double.infinity,
                color: CAppTheme.borderColor,
                child: _workspace!.imageUrls.isNotEmpty
                    ? RepaintBoundary(
                        child: Image.network(
                          _workspace!.imageUrls.first,
                          fit: BoxFit.cover,
                          cacheWidth: 800,
                          cacheHeight: 600,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Icon(
                                Icons.workspaces_outlined,
                                size: 48,
                                color: CAppTheme.textTertiary,
                              ),
                            );
                          },
                        ),
                      )
                    : Center(
                        child: Icon(
                          Icons.workspaces_outlined,
                          size: 48,
                          color: CAppTheme.textTertiary,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Name
            Text(
              _workspace!.name,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: CAppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // Location
            Row(
              children: [
                Icon(Icons.location_on_outlined, color: CAppTheme.textTertiary, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    [_workspace!.address, _workspace!.city, if (_workspace!.state != null) _workspace!.state!].join(', '),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: CAppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Status Toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _workspace!.isAvailable
                    ? CAppTheme.successColor.withValues(alpha: 0.08)
                    : CAppTheme.errorColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                border: Border.all(
                  color: _workspace!.isAvailable
                      ? CAppTheme.successColor.withValues(alpha: 0.3)
                      : CAppTheme.errorColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _workspace!.isAvailable
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: _workspace!.isAvailable
                            ? CAppTheme.successColor
                            : CAppTheme.errorColor,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _workspace!.isAvailable ? 'Available' : 'Unavailable',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: CAppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _workspace!.isAvailable,
                    activeTrackColor: CAppTheme.successColor,
                    onChanged: (value) async {
                      final updatedWorkspace = _workspace!.copyWorkspace(
                        isAvailable: value,
                      );
                      final controller = Provider.of<WorkspaceController>(
                        context,
                        listen: false,
                      );
                      await controller.updateWorkspace(updatedWorkspace);
                      setState(() {
                        _workspace = updatedWorkspace;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Description Section
            _buildSectionTitle('Description'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                boxShadow: CAppTheme.softShadow,
              ),
              child: Text(
                _workspace!.description,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  height: 1.6,
                  color: CAppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Pricing Section
            _buildSectionTitle('Pricing'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InfoCard(
                    title: 'Per Day',
                    value: 'PKR ${_workspace!.pricePerDay.toStringAsFixed(0)}',
                    icon: Icons.calendar_today_outlined,
                    color: CAppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoCard(
                    title: 'Per Hour',
                    value: 'PKR ${_workspace!.pricePerHour.toStringAsFixed(0)}',
                    icon: Icons.access_time_outlined,
                    color: CAppTheme.infoColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Capacity Section
            _buildSectionTitle('Capacity'),
            const SizedBox(height: 12),
            _InfoCard(
              title: 'People',
              value: '${_workspace!.capacity}',
              icon: Icons.people_outline_rounded,
              color: CAppTheme.warningColor,
            ),
            const SizedBox(height: 24),

            // Amenities Section
            _buildSectionTitle('Amenities'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _workspace!.amenities.map((amenity) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: CAppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: CAppTheme.primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        amenity,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: CAppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // Edit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AddWorkspaceScreen(workspaceToEdit: _workspace),
                    ),
                  ).then((_) {
                    _loadWorkspace();
                  });
                },
                icon: const Icon(Icons.edit_outlined),
                label: Text(
                  'Edit Workspace',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CAppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: CAppTheme.textPrimary,
      ),
    );
  }
}

/// Info Card Widget
class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _InfoCard({
    required this.title,
    required this.value,
    this.icon = Icons.info_outline,
    this.color = const Color(0xFF4A6CF7),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
        boxShadow: CAppTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(CAppTheme.radiusSmall),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: CAppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: CAppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
