import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/models/booking_model.dart';
import 'package:cwc/models/payment_model.dart';
import 'package:cwc/models/user_model.dart';
import 'package:cwc/services/auth_service.dart';
import 'package:cwc/services/booking_service.dart';
import 'package:cwc/services/payment_service.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/utils/helpers/snackbar_helper.dart';

/// Owner tab: review uploaded payment receipts and confirm bookings.
class OwnerReceiptsScreen extends StatefulWidget {
  const OwnerReceiptsScreen({super.key});

  @override
  State<OwnerReceiptsScreen> createState() => _OwnerReceiptsScreenState();
}

class _OwnerReceiptsScreenState extends State<OwnerReceiptsScreen> {
  final PaymentService _paymentService = PaymentService();
  final BookingService _bookingService = BookingService();
  final AuthService _authService = AuthService();
  List<PaymentModel> _receipts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ownerId = context.read<AuthController>().currentUser?.id;
    if (ownerId == null) return;
    setState(() => _loading = true);
    try {
      final list = await _paymentService.getPendingReceiptsForOwner(ownerId);
      if (mounted) setState(() { _receipts = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(PaymentModel payment) async {
    try {
      await _paymentService.approveManualPayment(payment.id);
      if (mounted) {
        showSuccessSnackBar(context, 'Payment approved — booking confirmed');
        _load();
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Failed to approve');
    }
  }

  Future<void> _reject(PaymentModel payment) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject Receipt', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(hintText: 'Reason (optional)'),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: CAppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _paymentService.rejectManualPayment(
        payment.id,
        reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
      );
      if (mounted) {
        showSuccessSnackBar(context, 'Receipt rejected — user notified');
        _load();
      }
    } catch (_) {
      if (mounted) showErrorSnackBar(context, 'Failed to reject');
    }
  }

  void _viewReceipt(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Stack(
          children: [
            InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: CAppTheme.primaryColor));
    }

    if (_receipts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 56, color: CAppTheme.textTertiary),
            const SizedBox(height: 12),
            Text('No receipts to verify',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('When users pay via bank/EasyPaisa, receipts appear here.',
                style: GoogleFonts.poppins(fontSize: 13, color: CAppTheme.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _receipts.length,
        itemBuilder: (_, i) => _ReceiptCard(
          payment: _receipts[i],
          bookingService: _bookingService,
          authService: _authService,
          onViewReceipt: _viewReceipt,
          onApprove: () => _approve(_receipts[i]),
          onReject: () => _reject(_receipts[i]),
        ),
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final PaymentModel payment;
  final BookingService bookingService;
  final AuthService authService;
  final void Function(String url) onViewReceipt;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ReceiptCard({
    required this.payment,
    required this.bookingService,
    required this.authService,
    required this.onViewReceipt,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({BookingModel? booking, UserModel? user})>(
      future: () async {
        final booking = await bookingService.getBookingById(payment.bookingId);
        final user = await authService.getUserById(payment.userId);
        return (booking: booking, user: user);
      }(),
      builder: (context, snap) {
        final booking = snap.data?.booking;
        final user = snap.data?.user;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
            boxShadow: CAppTheme.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(booking?.workspaceName ?? 'Booking',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 4),
              Text('${user?.name ?? 'User'} • Rs. ${payment.amount.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(fontSize: 13, color: CAppTheme.textSecondary)),
              if (payment.transferReference != null) ...[
                const SizedBox(height: 4),
                Text('Ref: ${payment.transferReference}',
                    style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.textTertiary)),
              ],
              if (payment.receiptUrl != null) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => onViewReceipt(payment.receiptUrl!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                    child: Image.network(
                      payment.receiptUrl!,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(foregroundColor: CAppTheme.errorColor),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onApprove,
                      child: const Text('Confirm Booking'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
