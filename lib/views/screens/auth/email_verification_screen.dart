import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/utils/helpers/error_handler.dart';
import 'package:cwc/utils/helpers/snackbar_helper.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/views/screens/auth/login_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  Timer? _poll;
  int _cooldown = 0;
  Timer? _cooldownTimer;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _silentCheck());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _silentCheck() async {
    if (!mounted) return;
    final auth = context.read<AuthController>();
    final verified = await auth.refreshVerificationState();
    if (verified && mounted) {
      _poll?.cancel();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (r) => false,
      );
    }
  }

  Future<void> _checkNow() async {
    if (_checking) return;
    setState(() => _checking = true);
    final auth = context.read<AuthController>();
    final verified = await auth.refreshVerificationState();
    if (!mounted) return;
    setState(() => _checking = false);

    if (verified) {
      await auth.signOut();
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(const SnackBar(
        content: Text('Email verified. Please login.'),
      ));
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (r) => false,
      );
    } else {
      showInfoSnackBar(context, 'Not verified yet. Check your inbox.');
    }
  }

  Future<void> _resend() async {
    if (_cooldown > 0) return;
    final auth = context.read<AuthController>();
    final ok = await auth.resendConfirmationEmail(widget.email);
    if (!mounted) return;
    if (ok) {
      showSuccessSnackBar(context, 'Verification email sent to ${widget.email}');
      setState(() => _cooldown = 45);
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        setState(() => _cooldown--);
        if (_cooldown <= 0) t.cancel();
      });
    } else {
      showErrorSnackBar(context, cleanErrorMessage(auth.errorMessage));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    await context.read<AuthController>().signOut();
                    if (!mounted) return;
                    navigator.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (r) => false,
                    );
                  },
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                ),
              ),
              const Spacer(),
              Center(
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: CAppTheme.heroGradient,
                    boxShadow: CAppTheme.cardShadow,
                  ),
                  child: const Icon(Icons.mark_email_read_outlined,
                      color: Colors.white, size: 52),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Verify your email',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: CAppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text.rich(
                textAlign: TextAlign.center,
                TextSpan(
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: CAppTheme.textSecondary,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(text: "We've sent a confirmation link to\n"),
                    TextSpan(
                      text: widget.email,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: CAppTheme.textPrimary,
                      ),
                    ),
                    const TextSpan(
                      text:
                          '.\nClick the link in that email, then tap "I\'ve verified" below.',
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _checking ? null : _checkNow,
                  child: _checking
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text(
                          "I've verified — continue",
                          style: GoogleFonts.poppins(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: _cooldown > 0 ? null : _resend,
                  child: Text(
                    _cooldown > 0
                        ? 'Resend email in ${_cooldown}s'
                        : 'Resend verification email',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
