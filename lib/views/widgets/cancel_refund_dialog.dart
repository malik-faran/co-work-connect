import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cwc/models/booking_model.dart';
import 'package:cwc/utils/refund_policy.dart';
import 'package:cwc/utils/themes/theme.dart';

/// Dialog to collect cancellation reason before submitting a refund request.
class CancelRefundDialog extends StatefulWidget {
  final BookingModel booking;

  const CancelRefundDialog({super.key, required this.booking});

  @override
  State<CancelRefundDialog> createState() => _CancelRefundDialogState();
}

class _CancelRefundDialogState extends State<CancelRefundDialog> {
  final _reasonController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reasonController.text.trim();
    if (reason.length < 5) {
      setState(() => _error = 'Please enter a reason (at least 5 characters).');
      return;
    }
    Navigator.pop(context, reason);
  }

  @override
  Widget build(BuildContext context) {
    final lead = widget.booking.refundNoticeLabel;
    final left = RefundPolicy.formatHumanDuration(widget.booking.refundWindowRemaining);

    return AlertDialog(
      title: Text(
        'Cancel Booking',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Refund amount: Rs. ${widget.booking.totalPrice.toStringAsFixed(0)}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: CAppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'For this booking, cancel at least $lead before start ($left left). '
              'CWC team will review your request. You can undo before approval if this was a mistake. '
              'Approved refunds are credited to your CWC wallet.',
              style: GoogleFonts.poppins(fontSize: 13, color: CAppTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              maxLength: 300,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                labelText: 'Why are you cancelling? *',
                hintText: 'e.g. Schedule changed, no longer needed...',
                errorText: _error,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Back', style: GoogleFonts.poppins()),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text('Request Cancellation', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
