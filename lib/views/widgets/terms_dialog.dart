import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cwc/utils/themes/theme.dart';

/// Workspace Usage and Platform Terms
const String kTermsTitle = 'Workspace Usage and Platform Terms';

const String kTermsBody = '''
Welcome to Co-Work Connect. By creating an account you agree to the following terms and policies. Please read them carefully.

1. Account and Eligibility
You must be at least 18 years old and provide accurate, up-to-date information. You are responsible for keeping your login credentials secure and for all activity on your account.

2. Workspace Bookings
Bookings are subject to availability and the host's policies. You agree to follow the house rules, check-in/check-out times, capacity limits, and any workspace-specific rules disclosed on the listing. Payment is charged at the time of confirmation.

3. Cancellations and Refunds
Cancellation windows and refund eligibility are shown on each listing before booking. No-show bookings are non-refundable unless otherwise stated by the host.

4. Collaboration and Communication
When offering or requesting services, you agree to communicate respectfully, deliver work in good faith, and never share harmful, illegal, or unlawful content. Payments for collaborations (if any) are settled between parties unless routed through the platform.

5. Prohibited Use
You must not: (a) misuse the platform for spam or fraud, (b) harass, threaten, or discriminate against others, (c) list or request illegal services, (d) attempt to bypass the platform's security, or (e) impersonate another person.

6. Privacy
We collect only the minimum data required to operate the service (name, email, profile details, bookings, chats). Your data is stored on Supabase with Row Level Security, so only you and the counter-party of a booking/chat can see the relevant records.

7. Reviews and Content
Reviews must be truthful and based on actual experiences. We may remove content that violates these terms.

8. Liability
Co-Work Connect is a marketplace; we do not own or operate the workspaces listed. Use is at your own risk, within applicable law.

9. Changes
We may update these terms. Continued use of the app after an update means you accept the new terms.

By checking "I agree", you confirm that you have read and accepted these Workspace Usage and Platform Terms.
''';

Future<void> showTermsDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CAppTheme.radiusXL),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              decoration: const BoxDecoration(
                gradient: CAppTheme.heroGradient,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(CAppTheme.radiusXL),
                  topRight: Radius.circular(CAppTheme.radiusXL),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_outlined, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      kTermsTitle,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  kTermsBody,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    height: 1.55,
                    color: CAppTheme.textPrimary,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'Close',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
