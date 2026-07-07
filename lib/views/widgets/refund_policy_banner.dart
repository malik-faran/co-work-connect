import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cwc/utils/refund_policy.dart';
import 'package:cwc/utils/themes/theme.dart';

/// Shows the refund/cancellation rule for the app or a specific booking.
class RefundPolicyBanner extends StatelessWidget {
  final bool compact;
  final DateTime? bookingStart;
  final DateTime? bookedAt;

  const RefundPolicyBanner({
    super.key,
    this.compact = false,
    this.bookingStart,
    this.bookedAt,
  });

  @override
  Widget build(BuildContext context) {
    final start = bookingStart;
    final booked = bookedAt ?? DateTime.now();
    final status = start != null
        ? RefundPolicy.eligibility(startDate: start, bookedAt: booked)
        : null;
    final ineligibleSoon =
        status == RefundEligibility.tooLate || status == RefundEligibility.started;

    final Color accent =
        ineligibleSoon ? CAppTheme.warningColor : CAppTheme.primaryColor;
    final Color bg = accent.withValues(alpha: 0.08);
    final String text = start != null
        ? RefundPolicy.messageForBooking(startDate: start, bookedAt: booked)
        : (compact ? RefundPolicy.compactSummary : RefundPolicy.userSummary);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 8 : 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ineligibleSoon ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
            size: compact ? 16 : 18,
            color: accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: compact ? 11 : 12,
                height: 1.4,
                color: CAppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
