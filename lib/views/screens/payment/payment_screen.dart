import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cwc/models/booking_model.dart';
import 'package:cwc/models/owner_payment_account_model.dart';
import 'package:cwc/models/payment_model.dart';
import 'package:cwc/services/owner_payment_account_service.dart';
import 'package:cwc/services/payment_service.dart';
import 'package:cwc/services/storage_service.dart';
import 'package:cwc/utils/constants/app_constants.dart';
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
  final OwnerPaymentAccountService _accountService = OwnerPaymentAccountService();
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();
  final _refController = TextEditingController();

  PaymentModel? _payment;
  List<OwnerPaymentAccountModel> _ownerAccounts = [];
  OwnerPaymentAccountModel? _selectedAccount;
  XFile? _receiptFile;
  String? _selectedMethod; // stripe | manual
  bool _isLoading = true;
  bool _isProcessing = false;
  Timer? _timer;
  int? _remainingMinutes;
  int? _remainingSeconds;

  @override
  void initState() {
    super.initState();
    _initialize();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _refController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final existing = await _paymentService.getPaymentByBookingId(widget.booking.id);

      if (existing != null && existing.status == 'completed') {
        if (mounted) {
          Navigator.of(context).pop(true);
          showSuccessSnackBar(context, 'Payment already completed!');
        }
        return;
      }

      String? method;
      if (existing != null) {
        method = existing.isManual
            ? AppConstants.paymentMethodManual
            : AppConstants.paymentMethodStripe;
      }

      final accounts = await _accountService.getAccountsForWorkspace(
        widget.booking.workspaceId,
      );

      if (!mounted) return;
      setState(() {
        _payment = existing;
        _selectedMethod = method;
        _ownerAccounts = accounts;
        _selectedAccount = accounts.isNotEmpty
            ? accounts.firstWhere((a) => a.isDefault, orElse: () => accounts.first)
            : null;
        _isLoading = false;
      });

      if (method == AppConstants.paymentMethodStripe) {
        Stripe.publishableKey = PaymentService.stripePublishableKey;
      }
      _updateTime();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _updateTime();
        if (_remainingMinutes != null &&
            _remainingMinutes! <= 0 &&
            _remainingSeconds != null &&
            _remainingSeconds! <= 0) {
          _handleExpired();
        }
      }
    });
  }

  void _updateTime() {
    if (_payment?.expiresAt == null) return;
    final diff = _payment!.expiresAt!.difference(DateTime.now());
    if (diff.isNegative) {
      setState(() { _remainingMinutes = 0; _remainingSeconds = 0; });
      return;
    }
    setState(() {
      _remainingMinutes = diff.inMinutes;
      _remainingSeconds = diff.inSeconds % 60;
    });
  }

  Future<void> _handleExpired() async {
    if (_payment == null) return;
    try {
      await _paymentService.cancelPayment(_payment!.id, reason: 'Expired');
    } catch (_) {}
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Payment Expired'),
        content: const Text('Please create a new booking.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(ctx).pop(false);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectMethod(String method) async {
    if (_selectedMethod == method) return;
    setState(() {
      _selectedMethod = method;
      _isProcessing = true;
    });

    try {
      PaymentModel payment;
      final existing = _payment;

      if (existing != null && existing.paymentMethod == method) {
        payment = existing;
      } else if (method == AppConstants.paymentMethodStripe) {
        payment = await _paymentService.createPayment(
          bookingId: widget.booking.id,
          userId: widget.booking.userId,
          amount: widget.booking.totalPrice,
        );
        Stripe.publishableKey = PaymentService.stripePublishableKey;
      } else {
        payment = await _paymentService.createManualPayment(
          bookingId: widget.booking.id,
          userId: widget.booking.userId,
          amount: widget.booking.totalPrice,
        );
      }

      if (mounted) {
        setState(() {
          _payment = payment;
          _isProcessing = false;
        });
        _updateTime();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        showErrorSnackBar(context, 'Failed to switch payment method');
      }
    }
  }

  Future<void> _processCardPayment() async {
    if (_payment == null || _payment!.stripeClientSecret == null) {
      if (_selectedMethod != AppConstants.paymentMethodStripe) {
        await _selectMethod(AppConstants.paymentMethodStripe);
      }
      if (_payment?.stripeClientSecret == null) {
        showErrorSnackBar(context, 'Payment not initialized');
        return;
      }
    }

    setState(() => _isProcessing = true);
    final bId = widget.booking.id;
    try {
      if (kIsWeb) {
        await _paymentService.confirmPayment(
          _payment!.id,
          _payment!.stripePaymentIntentId ?? '',
          isDummyPayment: true,
          bookingId: bId,
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
          _payment!.id,
          _payment!.stripePaymentIntentId ?? '',
          bookingId: bId,
        );
      }
      if (mounted) {
        _timer?.cancel();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => BookingConfirmationScreen(booking: widget.booking),
          ),
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Payment failed');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickReceipt() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _receiptFile = picked);
  }

  Future<void> _submitManualPayment() async {
    if (_selectedAccount == null) {
      showErrorSnackBar(context, 'Please select an owner account');
      return;
    }
    if (_receiptFile == null && _payment?.receiptUrl == null) {
      showErrorSnackBar(context, 'Please upload payment receipt screenshot');
      return;
    }

    if (_payment == null || !_payment!.isManual) {
      await _selectMethod(AppConstants.paymentMethodManual);
    }
    if (_payment == null) return;

    setState(() => _isProcessing = true);
    try {
      String receiptUrl = _payment!.receiptUrl ?? '';
      if (_receiptFile != null) {
        final bytes = await _receiptFile!.readAsBytes();
        receiptUrl = await _storageService.uploadPaymentReceipt(
          userId: widget.booking.userId,
          bookingId: widget.booking.id,
          bytes: bytes,
          fileName: _receiptFile!.name,
        );
      }

      await _paymentService.submitManualReceipt(
        paymentId: _payment!.id,
        ownerAccountId: _selectedAccount!.id,
        receiptUrl: receiptUrl,
        transferReference: _refController.text.trim().isEmpty
            ? null
            : _refController.text.trim(),
      );

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
          ),
          title: Text('Receipt Submitted', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          content: Text(
            'Your receipt has been sent to the workspace owner. You will be notified once they verify your payment and confirm the booking.',
            style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(false);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  bool get _awaitingVerification =>
      _payment?.receiptStatus == AppConstants.receiptAwaitingVerification;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CAppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Payment', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (_payment?.expiresAt != null) ...[
                    _buildTimerCard(),
                    const SizedBox(height: 16),
                  ],
                  _buildBookingSummary(),
                  const SizedBox(height: 20),
                  _buildMethodSelector(),
                  const SizedBox(height: 20),
                  if (_selectedMethod == AppConstants.paymentMethodStripe)
                    _buildCardSection()
                  else if (_selectedMethod == AppConstants.paymentMethodManual)
                    _buildManualSection()
                  else
                    _buildPickMethodHint(),
                  const SizedBox(height: 20),
                  _buildTotalCard(),
                  const SizedBox(height: 24),
                  _buildActionButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildTimerCard() {
    final expired = _remainingMinutes != null && _remainingMinutes! <= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: expired
              ? [CAppTheme.errorColor, CAppTheme.errorColor.withValues(alpha: 0.8)]
              : [CAppTheme.primaryColor, CAppTheme.primaryDark],
        ),
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Text(
            expired
                ? 'Expired'
                : '${_remainingMinutes?.toString().padLeft(2, '0') ?? '00'}:${_remainingSeconds?.toString().padLeft(2, '0') ?? '00'}',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        boxShadow: CAppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Booking Summary',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _row('Workspace', widget.booking.workspaceName),
          _row('Date', DateFormat('MMM dd, yyyy').format(widget.booking.startDate)),
          _row('Amount', 'Rs. ${widget.booking.totalPrice.toStringAsFixed(0)}'),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 13, color: CAppTheme.textSecondary)),
          Flexible(
            child: Text(value,
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payment Method',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        _methodTile(
          method: AppConstants.paymentMethodStripe,
          icon: Icons.credit_card,
          title: 'Pay by Card',
          subtitle: 'Stripe secure checkout',
        ),
        const SizedBox(height: 10),
        _methodTile(
          method: AppConstants.paymentMethodManual,
          icon: Icons.account_balance_wallet_outlined,
          title: 'Bank / EasyPaisa / JazzCash',
          subtitle: 'Transfer to owner account & upload receipt',
        ),
      ],
    );
  }

  Widget _methodTile({
    required String method,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _selectedMethod == method;
    return InkWell(
      onTap: _isProcessing ? null : () => _selectMethod(method),
      borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
          border: Border.all(
            color: selected ? CAppTheme.primaryColor : CAppTheme.borderColor,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? CAppTheme.softShadow : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: CAppTheme.primaryColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.textSecondary)),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle, color: CAppTheme.primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildPickMethodHint() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CAppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
      ),
      child: Text(
        'Select a payment method above to continue.',
        style: GoogleFonts.poppins(color: CAppTheme.textSecondary),
      ),
    );
  }

  Widget _buildCardSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        boxShadow: CAppTheme.softShadow,
      ),
      child: Text(
        'You will be redirected to secure card payment via Stripe.',
        style: GoogleFonts.poppins(fontSize: 14, color: CAppTheme.textSecondary),
      ),
    );
  }

  Widget _buildManualSection() {
    if (_awaitingVerification) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: CAppTheme.warningColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
          border: Border.all(color: CAppTheme.warningColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            const Icon(Icons.hourglass_top_rounded, color: CAppTheme.warningColor, size: 40),
            const SizedBox(height: 12),
            Text('Awaiting Owner Verification',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'Your receipt has been submitted. The owner will verify and confirm your booking.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: CAppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_ownerAccounts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        ),
        child: Text(
          'Owner has not added any bank/EasyPaisa accounts yet. Please use card payment or contact the workspace owner.',
          style: GoogleFonts.poppins(color: CAppTheme.textSecondary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Transfer to this account',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 10),
        ..._ownerAccounts.map((a) => _accountOption(a)),
        const SizedBox(height: 16),
        if (_selectedAccount != null) _selectedAccountDetails(_selectedAccount!),
        const SizedBox(height: 16),
        TextField(
          controller: _refController,
          decoration: const InputDecoration(
            labelText: 'Transaction reference (optional)',
            hintText: 'e.g. last 4 digits or TID',
          ),
        ),
        const SizedBox(height: 16),
        Text('Upload payment receipt',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _pickReceipt,
          icon: const Icon(Icons.upload_file_rounded),
          label: Text(_receiptFile != null ? 'Change receipt' : 'Choose screenshot'),
        ),
        if (_receiptFile != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_receiptFile!.name,
                style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.successColor)),
          ),
        if (_payment?.isReceiptRejected == true)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Previous receipt was rejected. Please upload a new one.',
              style: GoogleFonts.poppins(fontSize: 13, color: CAppTheme.errorColor),
            ),
          ),
      ],
    );
  }

  Widget _accountOption(OwnerPaymentAccountModel a) {
    final selected = _selectedAccount?.id == a.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedAccount = a),
        borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
            border: Border.all(
              color: selected ? CAppTheme.primaryColor : CAppTheme.borderColor,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.displayLabel,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    Text(a.accountTitle,
                        style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.textSecondary)),
                  ],
                ),
              ),
              if (selected) const Icon(Icons.check_circle, color: CAppTheme.primaryColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectedAccountDetails(OwnerPaymentAccountModel a) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CAppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        border: Border.all(color: CAppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Send Rs. ${widget.booking.totalPrice.toStringAsFixed(0)} to:',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(a.accountTitle, style: GoogleFonts.poppins(fontSize: 14)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(a.accountNumber,
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: a.accountNumber));
                  showSuccessSnackBar(context, 'Copied to clipboard');
                },
                icon: const Icon(Icons.copy_rounded, size: 20),
              ),
            ],
          ),
          if (a.bankName != null)
            Text(a.bankName!, style: GoogleFonts.poppins(fontSize: 13, color: CAppTheme.textSecondary)),
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
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Total', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          Text('PKR ${widget.booking.totalPrice.toStringAsFixed(0)}',
              style: GoogleFonts.poppins(
                  fontSize: 22, fontWeight: FontWeight.bold, color: CAppTheme.primaryColor)),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    if (_selectedMethod == null) return const SizedBox.shrink();
    if (_awaitingVerification) return const SizedBox.shrink();

    final isManual = _selectedMethod == AppConstants.paymentMethodManual;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isProcessing
            ? null
            : (isManual ? _submitManualPayment : _processCardPayment),
        child: _isProcessing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Text(
                isManual ? 'Submit Receipt' : 'Pay by Card',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}
