/// Profile Screen
/// Lets authenticated users view and update their account details
library;
import 'package:flutter/material.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/models/user_model.dart';
import 'package:cwc/services/storage_service.dart';
import 'package:cwc/utils/constants/app_constants.dart';
import 'package:cwc/utils/helpers/model_helpers.dart';
import 'package:cwc/utils/helpers/snackbar_helper.dart';
import 'package:cwc/utils/helpers/error_handler.dart';
import 'package:cwc/views/screens/payment/payment_history_screen.dart';
import 'package:cwc/views/screens/report/my_reports_screen.dart';
import 'package:cwc/views/screens/report/report_screen.dart';
import 'package:cwc/views/screens/role_selection_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _businessNameController;
  late TextEditingController _oldPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;
  late TextEditingController _cityController;
  bool _saving = false;
  bool _changingPassword = false;
  bool _showPasswordSection = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthController>().currentUser;
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _businessNameController =
        TextEditingController(text: user?.businessName ?? '');
    _oldPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _cityController = TextEditingController(text: user?.city ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _businessNameController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final authController = context.read<AuthController>();
    final user = authController.currentUser;
    if (user == null) return;

    setState(() => _saving = true);

    final updatedUser = user.copyUser(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      city: _cityController.text.trim().isEmpty
          ? null
          : _cityController.text.trim(),
      businessName: user.role == AppConstants.roleOwner
          ? _businessNameController.text.trim().isEmpty
              ? null
              : _businessNameController.text.trim()
          : null,
    );

    try {
      await authController.updateProfile(updatedUser);
      if (!mounted) return;
      showSuccessSnackBar(context, 'Profile updated successfully');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, cleanErrorMessage(e.toString()));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This will permanently remove your profile and hide your listings. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: CAppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final authController = context.read<AuthController>();
    final ok = await authController.deleteAccount();
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
        (_) => false,
      );
    } else {
      showErrorSnackBar(
        context,
        cleanErrorMessage(authController.errorMessage ?? 'Could not delete account'),
      );
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    final authController = context.read<AuthController>();
    setState(() => _changingPassword = true);

    try {
      final success = await authController.changePassword(
        oldPassword: _oldPasswordController.text.trim(),
        newPassword: _newPasswordController.text.trim(),
      );

      if (!mounted) return;

      if (success) {
        showSuccessSnackBar(context, 'Password changed successfully');
        setState(() {
          _showPasswordSection = false;
          _oldPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        });
      } else {
        showErrorSnackBar(
          context,
          cleanErrorMessage(authController.errorMessage ?? 'Failed to change password'),
        );
      }
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, cleanErrorMessage(e.toString()));
    } finally {
      if (mounted) {
        setState(() => _changingPassword = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;

    return Scaffold(
      backgroundColor: CAppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'My Profile',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: CAppTheme.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: CAppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator(color: CAppTheme.primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProfileHeader(user: user),
                  const SizedBox(height: 20),

                  // Profile form card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                      boxShadow: CAppTheme.softShadow,
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Personal Information',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: CAppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            enabled: false,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Phone is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _cityController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'City',
                              hintText: 'Enter your city',
                              prefixIcon: Icon(Icons.location_city_outlined),
                            ),
                          ),
                          if (user.role == AppConstants.roleOwner)
                            ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _businessNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Business Name',
                                  prefixIcon:
                                      Icon(Icons.business_center_outlined),
                                ),
                              ),
                            ],
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _saving ? null : _saveProfile,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save_rounded),
                              label: Text(
                                _saving ? 'Saving...' : 'Save Changes',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                      boxShadow: CAppTheme.softShadow,
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              _showPasswordSection = !_showPasswordSection;
                              if (!_showPasswordSection) {
                                _oldPasswordController.clear();
                                _newPasswordController.clear();
                                _confirmPasswordController.clear();
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: CAppTheme.warningColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                                  ),
                                  child: const Icon(
                                    Icons.lock_outline_rounded,
                                    color: CAppTheme.warningColor,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    'Change Password',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: CAppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                Icon(
                                  _showPasswordSection
                                      ? Icons.expand_less_rounded
                                      : Icons.expand_more_rounded,
                                  color: CAppTheme.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_showPasswordSection)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            child: Form(
                              key: _passwordFormKey,
                              child: Column(
                                children: [
                                  const Divider(color: CAppTheme.borderColor),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _oldPasswordController,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Old Password',
                                      prefixIcon: Icon(Icons.lock_outline),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Old password is required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _newPasswordController,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                      labelText: 'New Password',
                                      prefixIcon: Icon(Icons.lock_rounded),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'New password is required';
                                      }
                                      if (value.length < 6) {
                                        return 'Password must be at least 6 characters';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _confirmPasswordController,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Confirm New Password',
                                      prefixIcon: Icon(Icons.lock_clock),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Please confirm your password';
                                      }
                                      if (value != _newPasswordController.text) {
                                        return 'Passwords do not match';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _changingPassword ? null : _changePassword,
                                      icon: _changingPassword
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.lock_reset_rounded),
                                      label: Text(
                                        _changingPassword
                                            ? 'Changing...'
                                            : 'Change Password',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Payment History Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                      boxShadow: CAppTheme.softShadow,
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PaymentHistoryScreen(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: CAppTheme.infoColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                              ),
                              child: const Icon(
                                Icons.payment_rounded,
                                color: CAppTheme.infoColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Payment History',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: CAppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'View all your payment transactions',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: CAppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: CAppTheme.textTertiary),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _ProfileLinkCard(
                    icon: Icons.flag_outlined,
                    iconColor: CAppTheme.warningColor,
                    title: 'Report an Issue',
                    subtitle: 'Report a problem to our support team',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReportScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ProfileLinkCard(
                    icon: Icons.list_alt_rounded,
                    iconColor: CAppTheme.primaryColor,
                    title: 'My Reports',
                    subtitle: 'Track status and reply to decisions',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MyReportsScreen()),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _DeleteAccountCard(onDelete: _confirmDeleteAccount),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

class _ProfileHeader extends StatefulWidget {
  final UserModel user;

  const _ProfileHeader({required this.user});

  @override
  State<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<_ProfileHeader> {
  bool _uploading = false;
  final StorageService _storageService = StorageService();

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploading = true);

    try {
      final url = await _storageService.uploadProfileImage(
        picked,
        widget.user.id,
      );

      if (!mounted) return;

      final authController = context.read<AuthController>();
      final updatedUser = widget.user.copyUser(profileImageUrl: url);
      await authController.updateProfile(updatedUser);

      if (mounted) {
        showSuccessSnackBar(context, 'Profile picture updated');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, cleanErrorMessage(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final hasImage = user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: CAppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(CAppTheme.radiusXL),
        boxShadow: CAppTheme.cardShadow,
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _uploading ? null : _pickAndUploadImage,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: _uploading
                      ? const CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white,
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: CAppTheme.primaryColor,
                            ),
                          ),
                        )
                      : CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white,
                          backgroundImage: hasImage
                              ? NetworkImage(user.profileImageUrl!)
                              : null,
                          child: hasImage
                              ? null
                              : Text(
                                  safeInitial(user.name),
                                  style: GoogleFonts.poppins(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: CAppTheme.primaryColor,
                                  ),
                                ),
                        ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: CAppTheme.softShadow,
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      size: 16,
                      color: CAppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            user.name,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            user.email,
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(CAppTheme.radiusRound),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  user.role.toUpperCase(),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileLinkCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileLinkCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        boxShadow: CAppTheme.softShadow,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: CAppTheme.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: CAppTheme.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteAccountCard extends StatelessWidget {
  final VoidCallback onDelete;

  const _DeleteAccountCard({required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        boxShadow: CAppTheme.softShadow,
        border: Border.all(color: CAppTheme.errorColor.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Danger zone',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w700, color: CAppTheme.errorColor)),
          const SizedBox(height: 6),
          Text(
            'Delete your account permanently. Your profile will be removed and workspaces hidden.',
            style: GoogleFonts.poppins(fontSize: 13, color: CAppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onDelete,
              style: OutlinedButton.styleFrom(
                foregroundColor: CAppTheme.errorColor,
                side: const BorderSide(color: CAppTheme.errorColor),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('Delete my account',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
