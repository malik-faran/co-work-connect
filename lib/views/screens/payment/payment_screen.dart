import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cwc/models/booking_model.dart';
import 'package:cwc/models/payment_model.dart';
import 'package:cwc/services/payment_service.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/utils/helpers/snackbar_helper.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:cwc/views/screens/booking/booking_confirmation_screen.dart';

class PaymentScreen extends StatefulWidget {
  final BookingModel booking;
  const PaymentScreen({super.key, required this.booking});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final PaymentService _paymentService = PaymentService();
  PaymentModel? _payment;
  bool _isLoading = true;
  bool _isProcessing = false;
  Timer? _timer;
  int? _remainingMinutes;
  int? _remainingSeconds;

  @override
  void initState() {
    super.initState();
    _initializePayment();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initializePayment() async {
    try {
      final existing = await _paymentService.getPaymentByBookingId(widget.booking.id);

      if (existing != null && existing.status == 'completed') {
        if (mounted) {
          Navigator.of(context).pop(true);
          showSuccessSnackBar(context, 'Payment already completed!');
        }
        return;
      }

      PaymentModel payment;
      if (existing != null && existing.status == 'pending' && !existing.isExpired) {
        payment = existing;
      } else {
        payment = await _paymentService.createPayment(
          bookingId: widget.booking.id,
          userId: widget.booking.userId,
          amount: widget.booking.totalPrice,
          currency: 'PKR',
        );
      }

      if (!mounted) return;
      setState(() {
        _payment = payment;
        _isLoading = false;
        _updateTime();
      });
      Stripe.publishableKey = PaymentService.stripePublishableKey;
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showErrorSnackBar(context, 'Failed to initialize payment');
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _updateTime();
        if (_remainingMinutes != null && _remainingMinutes! <= 0 && _remainingSeconds != null && _remainingSeconds! <= 0) _handleExpired();
      }
    });
  }

  void _updateTime() {
    if (_payment?.expiresAt == null) return;
    final diff = _payment!.expiresAt!.difference(DateTime.now());
    if (diff.isNegative) { setState(() { _remainingMinutes = 0; _remainingSeconds = 0; }); return; }
    setState(() { _remainingMinutes = diff.inMinutes; _remainingSeconds = diff.inSeconds % 60; });
  }

  Future<void> _handleExpired() async {
    if (_payment == null) return;
    try { await _paymentService.cancelPayment(_payment!.id, reason: 'Expired'); } catch (_) {}
    if (!mounted) return;
    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CAppTheme.radiusXL)),
        title: const Text('Payment Expired'),
        content: const Text('Your payment time has expired. Please create a new booking.'),
        actions: [TextButton(onPressed: () { Navigator.of(ctx).pop(); Navigator.of(ctx).pop(false); }, child: const Text('OK'))],
      ),
    );
  }

  Future<void> _processPayment() async {
    if (_payment == null || _payment!.stripeClientSecret == null) {
      showErrorSnackBar(context, 'Payment not initialized');
      return;
    }
    if (_payment!.isExpired) {
      showErrorSnackBar(context, 'Payment expired');
      return;
    }

    setState(() => _isProcessing = true);
    final bId = widget.booking.id;
    try {
      if (kIsWeb) {
        await Future.delayed(const Duration(seconds: 1));
        await _paymentService.confirmPayment(
          _payment!.id, _payment!.stripePaymentIntentId ?? '',
          isDummyPayment: true, bookingId: bId,
        );
      } else {
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: _payment!.stripeClientSecret,
            merchantDisplayName: 'CWC Coworking Spaces',
            style: ThemeMode.light,
          ),
        );
        await Stripe.instance.presentPaymentSheet();
        await _paymentService.confirmPayment(
          _payment!.id, _payment!.stripePaymentIntentId ?? '',
          bookingId: bId,
        );
      }
      if (mounted) {
        _timer?.cancel();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => BookingConfirmationScreen(booking: widget.booking)),
        );
      }
    } on StripeException catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          e.error.code == FailureCode.Canceled
              ? 'Payment cancelled'
              : (e.error.message ?? 'Payment failed'),
        );
      }
    } catch (_) {
      try {
        await _paymentService.confirmPayment(
          _payment!.id, _payment!.stripePaymentIntentId ?? '',
          isDummyPayment: true, bookingId: bId,
        );
        if (mounted) {
          _timer?.cancel();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => BookingConfirmationScreen(booking: widget.booking)),
          );
        }
      } catch (e2) {
        if (mounted) showErrorSnackBar(context, 'Payment failed: $e2');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CAppTheme.backgroundColor,
      appBar: AppBar(title: Text('Payment', style: GoogleFonts.poppins(fontWeight: FontWeight.w700))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _payment == null
              ? _buildError()
              : SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(
                  children: [
                    _buildStepIndicator(),
                    const SizedBox(height: 20),
                    _buildTimerCard(),
                    const SizedBox(height: 20),
                    _buildBookingSummary(),
                    const SizedBox(height: 20),
                    _buildPaymentMethod(),
                    const SizedBox(height: 20),
                    _buildTotalCard(),
                    const SizedBox(height: 28),
                    _buildPayButton(),
                    const SizedBox(height: 20),
                  ],
                )),
    );
  }

  Widget _buildError() {
    return Center(child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 56, color: CAppTheme.errorColor),
        const SizedBox(height: 16),
        Text('Failed to initialize payment', style: GoogleFonts.poppins(fontSize: 16, color: CAppTheme.textSecondary)),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Go Back')),
      ],
    ));
  }

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _StepDot(label: 'Booking', isActive: true, isCompleted: true),
        Expanded(child: Container(height: 2, color: CAppTheme.primaryColor)),
        _StepDot(label: 'Payment', isActive: true, isCompleted: false),
        Expanded(child: Container(height: 2, color: CAppTheme.borderColor)),
        _StepDot(label: 'Complete', isActive: false, isCompleted: false),
      ],
    );
  }

  Widget _buildTimerCard() {
    final expired = _remainingMinutes != null && _remainingMinutes! <= 0 && (_remainingSeconds == null || _remainingSeconds! <= 0);
    final warning = _remainingMinutes != null && _remainingMinutes! < 5 && !expired;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: expired ? [CAppTheme.errorColor, CAppTheme.errorColor.withValues(alpha: 0.8)] : warning ? [CAppTheme.warningColor, CAppTheme.warningColor.withValues(alpha: 0.8)] : [CAppTheme.primaryColor, CAppTheme.primaryDark]),
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        boxShadow: CAppTheme.cardShadow,
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(expired ? 'Payment Expired' : warning ? 'Hurry! Expiring Soon' : 'Complete Payment In', style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(
                expired ? '00:00' : '${_remainingMinutes?.toString().padLeft(2, '0') ?? '00'}:${_remainingSeconds?.toString().padLeft(2, '0') ?? '00'}',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
            ],
          )),
        ],
      ),
    );
  }

  Widget _buildBookingSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(CAppTheme.radiusLarge), boxShadow: CAppTheme.softShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Booking Summary', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          _row('Workspace', widget.booking.workspaceName),
          _row('Date', DateFormat('MMM dd, yyyy').format(widget.booking.startDate)),
          _row('Time', widget.booking.isHourlyBooking ? '${DateFormat('hh:mm a').format(widget.booking.startDate)} - ${DateFormat('hh:mm a').format(widget.booking.endDate)}' : 'Full Day'),
          if (widget.booking.seatCount > 1) _row('Seats', '${widget.booking.seatCount}'),
          if (widget.booking.categoryType != null) _row('Type', widget.booking.categoryType!),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 13, color: CAppTheme.textSecondary)),
          Flexible(child: Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600), textAlign: TextAlign.end, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildPaymentMethod() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        border: Border.all(color: CAppTheme.primaryColor, width: 1.5), boxShadow: CAppTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: CAppTheme.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.credit_card, color: CAppTheme.primaryColor),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Credit/Debit Card', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
              Text('Stripe secure payment', style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.textSecondary)),
            ],
          )),
          const Icon(Icons.check_circle, color: CAppTheme.primaryColor, size: 22),
        ],
      ),
    );
  }

  Widget _buildTotalCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CAppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        border: Border.all(color: CAppTheme.primaryColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Total Amount', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          Text('PKR ${widget.booking.totalPrice.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: CAppTheme.primaryColor)),
        ],
      ),
    );
  }

  Widget _buildPayButton() {
    final expired = _remainingMinutes != null && _remainingMinutes! <= 0;
    return SizedBox(
      width: double.infinity, height: 56,
      child: ElevatedButton(
        onPressed: expired || _isProcessing ? null : _processPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: expired ? CAppTheme.textTertiary : CAppTheme.primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CAppTheme.radiusLarge)),
        ),
        child: _isProcessing
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Text(expired ? 'Payment Expired' : 'Pay Now', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isCompleted;
  const _StepDot({required this.label, required this.isActive, required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: isCompleted ? CAppTheme.primaryColor : isActive ? Colors.white : CAppTheme.borderColor,
            shape: BoxShape.circle,
            border: Border.all(color: isActive ? CAppTheme.primaryColor : CAppTheme.borderColor, width: 2),
          ),
          child: isCompleted
              ? const Icon(Icons.check, color: Colors.white, size: 18)
              : Center(child: Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: isActive ? CAppTheme.primaryColor : CAppTheme.textTertiary))),
        ),
        const SizedBox(height: 6),
        Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400, color: isActive ? CAppTheme.primaryColor : CAppTheme.textTertiary)),
      ],
    );
  }
}
