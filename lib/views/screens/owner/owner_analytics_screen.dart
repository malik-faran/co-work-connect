import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/controllers/workspace_controller.dart';
import 'package:cwc/services/booking_service.dart';
import 'package:cwc/utils/constants/app_constants.dart';
import 'package:cwc/utils/themes/theme.dart';

class OwnerAnalyticsScreen extends StatefulWidget {
  const OwnerAnalyticsScreen({super.key});

  @override
  State<OwnerAnalyticsScreen> createState() => _OwnerAnalyticsScreenState();
}

class _OwnerAnalyticsScreenState extends State<OwnerAnalyticsScreen> {
  final BookingService _bookingService = BookingService();
  int _totalBookings = 0;
  double _totalRevenue = 0.0;
  bool _isLoadingBookings = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBookingStats();
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _loadBookingStats();
    });
  }

  Future<void> _loadBookingStats() async {
    if (!mounted) return;

    final authController = Provider.of<AuthController>(context, listen: false);
    final workspaceController = Provider.of<WorkspaceController>(
      context,
      listen: false,
    );
    final ownerId = authController.currentUser?.id;

    if (ownerId == null) {
      if (mounted) {
        setState(() {
          _isLoadingBookings = false;
        });
      }
      return;
    }

    try {
      await workspaceController.loadOwnerWorkspaces(ownerId);
      final workspaces = workspaceController.workspaces;

      int totalBookings = 0;
      double totalRevenue = 0.0;

      for (var workspace in workspaces) {
        final bookings = await _bookingService.getBookingsByWorkspaceId(
          workspace.id,
        );
        totalBookings = totalBookings + bookings.length;
        totalRevenue += bookings
            .where(
              (b) =>
                  b.status == AppConstants.bookingStatusConfirmed ||
                  b.status == AppConstants.bookingStatusCompleted,
            )
            .fold(0.0, (sum, booking) => sum + booking.totalPrice);
      }

      if (mounted) {
        setState(() {
          _totalBookings = totalBookings;
          _totalRevenue = totalRevenue;
          _isLoadingBookings = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingBookings = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthController, WorkspaceController>(
      builder: (context, authController, workspaceController, child) {
        final ownerId = authController.currentUser?.id;
        if (ownerId == null) {
          return Center(
            child: Text(
              'User not found',
              style: GoogleFonts.poppins(color: CAppTheme.textSecondary),
            ),
          );
        }

        final ownerWorkspaces = workspaceController.workspaces;

        final totalWorkspaces = ownerWorkspaces.length;
        final availableWorkspaces = ownerWorkspaces
            .where((w) => w.isAvailable)
            .length;

        return RefreshIndicator(
          color: CAppTheme.primaryColor,
          onRefresh: _loadBookingStats,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analytics Dashboard',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: CAppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Track your workspace performance',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: CAppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 600;
                    final crossAxisCount = isMobile ? 2 : 3;
                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: isMobile ? 1.15 : 1.3,
                      children: [
                        _StatCard(
                          title: 'Total Workspaces',
                          value: totalWorkspaces.toString(),
                          icon: Icons.workspaces_outlined,
                          color: CAppTheme.primaryColor,
                        ),
                        _StatCard(
                          title: 'Available',
                          value: availableWorkspaces.toString(),
                          icon: Icons.check_circle_outline,
                          color: CAppTheme.successColor,
                        ),
                        _StatCard(
                          title: 'Total Bookings',
                          value: _isLoadingBookings
                              ? '...'
                              : _totalBookings.toString(),
                          icon: Icons.book_outlined,
                          color: CAppTheme.infoColor,
                        ),
                        _StatCard(
                          title: 'Total Revenue',
                          value: _isLoadingBookings
                              ? '...'
                              : '\$${_totalRevenue.toStringAsFixed(2)}',
                          icon: Icons.attach_money,
                          color: CAppTheme.successColor,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Workspace Performance',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: CAppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                if (ownerWorkspaces.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: CAppTheme.primaryColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.analytics_outlined,
                              size: 48,
                              color: CAppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No workspaces yet',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: CAppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add your first workspace to see analytics',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: CAppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...ownerWorkspaces.map((workspace) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                        boxShadow: CAppTheme.softShadow,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: CAppTheme.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                              ),
                              child: Icon(
                                Icons.workspaces_rounded,
                                color: CAppTheme.primaryColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    workspace.name,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: CAppTheme.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '\$${workspace.pricePerDay.toStringAsFixed(0)}/day',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: CAppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: workspace.isAvailable
                                    ? CAppTheme.successColor.withValues(alpha: 0.1)
                                    : CAppTheme.errorColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(CAppTheme.radiusRound),
                              ),
                              child: Text(
                                workspace.isAvailable ? 'Active' : 'Inactive',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: workspace.isAvailable
                                      ? CAppTheme.successColor
                                      : CAppTheme.errorColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

/// Stat Card Widget
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        boxShadow: CAppTheme.softShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(CAppTheme.radiusSmall),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
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
            const SizedBox(height: 2),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: CAppTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
