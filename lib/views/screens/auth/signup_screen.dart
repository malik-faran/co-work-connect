import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/services/storage_service.dart';
import 'package:cwc/utils/constants/app_constants.dart';
import 'package:cwc/utils/helpers/snackbar_helper.dart';
import 'package:cwc/utils/helpers/error_handler.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/utils/validators/password_validator.dart';
import 'package:cwc/utils/validators/form_validators.dart';
import 'package:cwc/views/widgets/password_strength_indicator.dart';
import 'package:cwc/views/widgets/terms_dialog.dart';
import 'package:cwc/views/screens/auth/login_screen.dart';
import 'package:cwc/views/screens/auth/email_verification_screen.dart';

class SignupScreen extends StatefulWidget {
  final String role;
  const SignupScreen({super.key, this.role = AppConstants.roleUser});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _businessAddressController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;
  bool _isLoading = false;
  String _passwordValue = '';
  XFile? _cnicImage;

  bool get _isOwner => widget.role == AppConstants.roleOwner;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(
        () => setState(() => _passwordValue = _passwordController.text));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _businessNameController.dispose();
    _businessAddressController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final pwd = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    return _acceptedTerms &&
        FormValidators.name(name) == null &&
        FormValidators.email(email) == null &&
        PasswordValidator.isStrong(pwd) &&
        pwd == confirm &&
        (!_isOwner || (_cnicImage != null && _phoneController.text.trim().isNotEmpty)) &&
        !_isLoading;
  }

  Future<void> _pickCnic() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file != null) setState(() => _cnicImage = file);
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      showErrorSnackBar(context, 'Please accept the Workspace Usage and Platform Terms');
      return;
    }
    if (_isOwner && _cnicImage == null) {
      showErrorSnackBar(context, 'CNIC upload is required for owner registration');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    final authController = context.read<AuthController>();
    final email = _emailController.text.trim();

    final success = await authController.signUp(
      email: email,
      password: _passwordController.text,
      name: _nameController.text.trim(),
      role: widget.role,
      phone: _phoneController.text.trim(),
      businessName: _isOwner ? _businessNameController.text.trim() : null,
      businessAddress: _isOwner ? _businessAddressController.text.trim() : null,
    );

    if (success && _isOwner && _cnicImage != null) {
      try {
        final cnicUrl = await StorageService().uploadCNICImage(_cnicImage!, email);
        await authController.completeOwnerRegistration(cnicImageUrl: cnicUrl);
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        showErrorSnackBar(context, 'CNIC upload failed: ${e.toString()}');
        return;
      }
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      showSuccessSnackBar(context, 'Account created. Please verify your email.');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EmailVerificationScreen(email: email),
        ),
      );
    } else {
      showErrorSnackBar(
        context,
        cleanErrorMessage(authController.errorMessage),
        duration: const Duration(seconds: 4),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
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
                  const SizedBox(height: 16),
                  Text(
                    _isOwner ? 'Create\nOwner Account' : 'Create\nAccount',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isOwner
                        ? 'Upload your CNIC — admin will verify before you can list workspaces'
                        : 'Join Co-Work Connect in seconds',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  onChanged: () => setState(() {}),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: FormValidators.name,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: FormValidators.email,
                      ),
                      if (_isOwner) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Phone is required for owners';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _businessNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Business Name',
                            prefixIcon: Icon(Icons.business_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _businessAddressController,
                          decoration: const InputDecoration(
                            labelText: 'Business Address',
                            prefixIcon: Icon(Icons.location_on_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildCnicUpload(),
                      ],
                      const SizedBox(height: 14),
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
                        validator: PasswordValidator.validate,
                      ),
                      const SizedBox(height: 12),
                      PasswordStrengthIndicator(password: _passwordValue),
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
                                _obscureConfirmPassword = !_obscureConfirmPassword),
                          ),
                        ),
                        validator: (v) => FormValidators.confirmPassword(
                              v,
                              _passwordController.text,
                            ),
                      ),
                      const SizedBox(height: 20),
                      _buildTermsRow(),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _canSubmit ? _handleSignup : null,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                            ),
                            disabledBackgroundColor:
                                CAppTheme.primaryColor.withValues(alpha: 0.4),
                            disabledForegroundColor: Colors.white,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5, color: Colors.white),
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
                                builder: (_) => LoginScreen(role: widget.role),
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

  Widget _buildCnicUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'CNIC Upload (Required)',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: CAppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _isLoading ? null : _pickCnic,
          icon: const Icon(Icons.upload_file_rounded),
          label: Text(
            _cnicImage == null ? 'Upload CNIC Photo' : 'CNIC Selected — Change',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
            ),
          ),
        ),
        if (_cnicImage == null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Clear photo of your CNIC is mandatory. Admin approval is required.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: CAppTheme.errorColor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTermsRow() {
    return InkWell(
      borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
      onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _acceptedTerms,
                onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                activeColor: CAppTheme.primaryColor,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: CAppTheme.textPrimary,
                    height: 1.4,
                  ),
                  children: [
                    const TextSpan(text: 'I agree to the '),
                    TextSpan(
                      text: 'Workspace Usage and Platform Terms',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: CAppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: _termsTapRecognizer(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TapGestureRecognizer _termsTapRecognizer() {
    final r = TapGestureRecognizer();
    r.onTap = () => showTermsDialog(context);
    return r;
  }
}
