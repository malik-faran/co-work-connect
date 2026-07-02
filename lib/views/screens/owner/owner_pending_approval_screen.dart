import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/views/screens/role_selection_screen.dart';
import 'package:cwc/utils/helpers/owner_navigation.dart';

class OwnerPendingApprovalScreen extends StatefulWidget {
  final bool rejected;

  const OwnerPendingApprovalScreen({super.key, this.rejected = false});

  @override
  State<OwnerPendingApprovalScreen> createState() =>
      _OwnerPendingApprovalScreenState();
}

class _OwnerPendingApprovalScreenState extends State<OwnerPendingApprovalScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkApproval());
  }

  Future<void> _checkApproval() async {
    final auth = context.read<AuthController>();
    await auth.refreshCurrentUser();
    if (!mounted) return;
    final user = auth.currentUser;
    if (user != null && user.ownerApproved == true) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ownerDestinationFor(user)),
      );
    }
  }

  Future<void> _logout() async {
    await context.read<AuthController>().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rejected = widget.rejected;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: rejected
                      ? CAppTheme.errorColor.withValues(alpha: 0.1)
                      : CAppTheme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  rejected ? Icons.cancel_outlined : Icons.hourglass_top_rounded,
                  size: 44,
                  color: rejected
                      ? CAppTheme.errorColor
                      : CAppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                rejected ? 'Application Rejected' : 'Verification Pending',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: CAppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                rejected
                    ? 'Your owner application was not approved. Please contact support or sign up again with a clear CNIC photo.'
                    : 'Your CNIC has been submitted. An admin will review your owner application. You can access workspace management after approval.',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: CAppTheme.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              if (!rejected)
                OutlinedButton.icon(
                  onPressed: _checkApproval,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(
                    'Check Status',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _logout,
                child: Text(
                  'Logout',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: CAppTheme.textSecondary,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
