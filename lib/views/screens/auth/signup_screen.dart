import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/utils/constants/app_constants.dart';
import 'package:cwc/utils/helpers/snackbar_helper.dart';
import 'package:cwc/utils/helpers/error_handler.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/services/storage_service.dart';
import 'package:cwc/views/screens/auth/login_screen.dart';

class SignupScreen extends StatefulWidget {
  final String role;

  const SignupScreen({super.key, required this.role});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _businessNameController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  XFile? _cnicImage;
  Uint8List? _cnicImageBytes;
  final ImagePicker _imagePicker = ImagePicker();
  final StorageService _storageService = StorageService();

  Future<void> _pickCNICImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _cnicImage = image;
          _cnicImageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Error picking image: ${e.toString()}');
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _businessNameController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authController = context.read<AuthController>();
    final isOwner = widget.role == AppConstants.roleOwner;
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      showErrorSnackBar(context, 'Please enter your email address');
      setState(() => _isLoading = false);
      return;
    }

    if (_cnicImage == null || _cnicImageBytes == null) {
      showErrorSnackBar(context, 'Please upload your CNIC image');
      setState(() => _isLoading = false);
      return;
    }

    final success = await authController.signUp(
      email: email,
      password: _passwordController.text.trim(),
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      role: widget.role,
      city: null,
      businessName: isOwner ? _businessNameController.text.trim() : null,
      businessAddress: null,
      cnicImageUrl: null,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      try {
        final uploadIdentifier = authController.currentUser?.id ?? email;
        String? cnicImageUrl;
        if (kIsWeb && _cnicImageBytes != null) {
          cnicImageUrl = await _storageService.uploadCNICImageBytes(
            _cnicImageBytes!,
            uploadIdentifier,
          );
        } else if (_cnicImage != null) {
          cnicImageUrl = await _storageService.uploadCNICImage(
            _cnicImage!,
            uploadIdentifier,
          );
        }

        if (cnicImageUrl != null && authController.currentUser != null) {
          await authController.updateProfile(
            authController.currentUser!.copyUser(cnicImageUrl: cnicImageUrl),
          );
        }
      } catch (e) {
        if (mounted) {
          showErrorSnackBar(
            context,
            'Account created, but CNIC upload failed. Please retry from profile after login.',
          );
        }
      }

      await authController.signOut();
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CAppTheme.radiusXL),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CAppTheme.successColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle,
                    color: CAppTheme.successColor, size: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Request Sent')),
            ],
          ),
          content: const Text(
            'Your registration request has been sent to admin for approval. '
            'You will receive a notification once your account is approved.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => LoginScreen(role: widget.role)),
      );
    } else {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        cleanErrorMessage(authController.errorMessage) ??
            'Signup failed. Please try again.',
        duration: const Duration(seconds: 4),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.role.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Invalid role. Please go back.')),
      );
    }

    final isOwner = widget.role == AppConstants.roleOwner;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Blue header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              decoration: const BoxDecoration(
                gradient: CAppTheme.heroGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Create\nAccount',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isOwner
                        ? 'List your workspace in minutes'
                        : 'Find your next favorite workspace',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),

            // Form area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sectionTitle('Personal Information'),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your name';
                          }
                          final t = value.trim();
                          if (t.isEmpty) return 'Name cannot be only spaces';
                          if (t.length < 2) return 'Name must be at least 2 characters';
                          if (t.length > 50) return 'Name must be less than 50 characters';
                          if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(t)) {
                            return 'Name can only contain letters and spaces';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          final regex = RegExp(
                              r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                          if (!regex.hasMatch(value.trim())) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(Icons.phone_outlined),
                          hintText: '+92XXXXXXXXXX',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your phone number';
                          }
                          final cleaned = value.replaceAll(RegExp(r'[\s-]'), '');
                          if (!RegExp(r'^\+?[0-9]{10,13}$').hasMatch(cleaned)) {
                            return 'Please enter a valid phone number';
                          }
                          return null;
                        },
                      ),
                      if (isOwner) ...[
                        const SizedBox(height: 24),
                        _sectionTitle('Business Details'),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _businessNameController,
                          decoration: const InputDecoration(
                            labelText: 'Business Name',
                            prefixIcon: Icon(Icons.business_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Business name is required';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                      _sectionTitle('Identity Verification'),
                      const SizedBox(height: 6),
                      Text(
                        'Upload a clear photo of your CNIC (National ID Card)',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: CAppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: _pickCNICImage,
                        child: Container(
                          height: 180,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _cnicImageBytes == null
                                  ? CAppTheme.borderColor
                                  : CAppTheme.successColor,
                              width: 1.5,
                            ),
                            borderRadius:
                                BorderRadius.circular(CAppTheme.radiusLarge),
                            color: CAppTheme.backgroundColor,
                          ),
                          child: _cnicImageBytes == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: CAppTheme.primaryColor
                                            .withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.add_photo_alternate_outlined,
                                        size: 32,
                                        color: CAppTheme.primaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Tap to upload CNIC',
                                      style: GoogleFonts.poppins(
                                        color: CAppTheme.textSecondary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                )
                              : Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                          CAppTheme.radiusLarge - 1),
                                      child: Image.memory(
                                        _cnicImageBytes!,
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: IconButton(
                                        icon: const Icon(Icons.close,
                                            color: Colors.white, size: 20),
                                        onPressed: () => setState(() {
                                          _cnicImage = null;
                                          _cnicImageBytes = null;
                                        }),
                                        style: IconButton.styleFrom(
                                          backgroundColor: CAppTheme.errorColor,
                                          padding: const EdgeInsets.all(6),
                                          minimumSize: const Size(32, 32),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _sectionTitle('Security'),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () => setState(() =>
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSignup,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  CAppTheme.radiusLarge),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Create Account',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) =>
                                    LoginScreen(role: widget.role),
                              ),
                            );
                          },
                          child: Text(
                            'Already have an account? Login',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: CAppTheme.textPrimary,
      ),
    );
  }
}
