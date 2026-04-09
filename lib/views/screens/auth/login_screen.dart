import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/utils/constants/app_constants.dart';
import 'package:cwc/utils/helpers/snackbar_helper.dart';
import 'package:cwc/utils/helpers/error_handler.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/views/screens/auth/signup_screen.dart';
import 'package:cwc/views/screens/user/user_home_screen.dart';
import 'package:cwc/views/screens/owner/owner_home_screen.dart';

class LoginScreen extends StatefulWidget {
  final String role;

  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    final authController = context.read<AuthController>();

    final success = await authController.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success && authController.currentUser != null) {
      final user = authController.currentUser!;
      if (user.role == widget.role) {
        if (user.role == AppConstants.roleUser) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const UserHomeScreen()),
            (route) => false,
          );
        } else if (user.role == AppConstants.roleOwner) {
          if (user.ownerApproved != true) {
            showErrorSnackBar(context,
                'Your owner account is pending approval. Please wait for admin approval.');
            await authController.signOut();
            return;
          }
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const OwnerHomeScreen()),
            (route) => false,
          );
        }
      } else {
        if (user.role == AppConstants.roleOwner && user.ownerApproved != true) {
          showErrorSnackBar(context,
              'Your owner account is pending approval. Please wait for admin approval.');
          await authController.signOut();
          return;
        }
        showErrorSnackBar(context,
            'This account is registered as ${user.role}. Please select the correct role.');
      }
    } else {
      showErrorSnackBar(
        context,
        cleanErrorMessage(authController.errorMessage) ??
            'Login failed. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.role == AppConstants.roleUser;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Blue header area
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
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
                    const SizedBox(height: 24),
                    Text(
                      'Welcome\nBack',
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isUser
                          ? 'Find your perfect workspace'
                          : 'Manage your coworking empire',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),

              // Form area
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Login to Continue',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: CAppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 24),
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
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
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
                      const SizedBox(height: 32),
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
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
                                  'Login',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account?",
                            style: GoogleFonts.poppins(
                              color: CAppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      SignupScreen(role: widget.role),
                                ),
                              );
                            },
                            child: Text(
                              'Create one',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
