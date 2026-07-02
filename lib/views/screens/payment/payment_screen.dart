import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cwc/models/booking_model.dart';
import 'package:cwc/models/platform_payment_account_model.dart';
import 'package:cwc/models/payment_model.dart';
import 'package:cwc/services/platform_payment_account_service.dart';
import 'package:cwc/services/wallet_service.dart';
import 'package:cwc/services/payment_service.dart';
import 'package:cwc/services/storage_service.dart';
import 'package:cwc/services/supabase_service.dart';
import 'package:cwc/utils/constants/app_constants.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/utils/helpers/snackbar_helper.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:cwc/views/screens/booking/booking_confirmation_screen.dart';

class PaymentScreen extends StatefulWidget {
  final BookingModel booking;
  final List<String> groupBookingIds;

  const PaymentScreen({
    super.key,
    required this.booking,
    this.groupBookingIds = const [],
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final PaymentService _paymentService = PaymentService();
  final PlatformPaymentAccountService _accountService = PlatformPaymentAccountService();
  final WalletService _walletService = WalletService();
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();
  final _refController = TextEditingController();

  PaymentModel? _payment;
  List<PlatformPaymentAccountModel> _platformAccounts = [];
  PlatformPaymentAccountModel? _selectedAccount;
  double _walletBalance = 0;
  XFile? _receiptFile;
  String? _selectedMethod; // stripe | manual | wallet | split
  double _walletPortion = 0;
  bool _splitWalletDebited = false;
  bool _isLoading = true;
  bool _isProcessing = false;
  Timer? _timer;
  int? _remainingSeconds;
  bool _expiryHandled = false;

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
        if (existing.paymentMethod == AppConstants.paymentMethodWallet) {
          method = AppConstants.paymentMethodWallet;
        } else if (existing.paymentMethod == AppConstants.paymentMethodSplit) {
          method = AppConstants.paymentMethodSplit;
        } else if (existing.isManual) {
          method = AppConstants.paymentMethodManual;
        } else {
          method = AppConstants.paymentMethodStripe;
        }
      }

      final accounts = await _accountService.getActiveAccounts();
      final userId = _payerUserId;
      double walletBal = 0;
      if (userId.isNotEmpty) {
        walletBal = (await _walletService.getWallet(userId)).balance;
      }

      if (!mounted) return;
      setState(() {
        _payment = existing;
        _selectedMethod = method;
        _platformAccounts = accounts;
        _walletBalance = walletBal;
        _walletPortion = _defaultSplitWalletPortion();
        if (existing?.isSplit == true && existing!.walletAmount > 0) {
          _splitWalletDebited = true;
          _walletPortion = existing.walletAmount;
        }
        _selectedAccount = accounts.isNotEmpty
            ? accounts.firstWhere((a) => a.isDefault, orElse: () => accounts.first)
            : null;
        _isLoading = false;
      });

      if (method == AppConstants.paymentMethodStripe) {
        Stripe.publishableKey = PaymentService.stripePublishableKey;
        await Stripe.instance.applySettings();
      }
      _updateTime();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _updateTime();
      if (_remainingSeconds != null && _remainingSeconds! <= 0 && !_expiryHandled) {
        _handleExpired();
      }
    });
  }

  void _updateTime() {
    if (_payment?.expiresAt == null) return;
    final total = _payment!.expiresAt!.difference(DateTime.now()).inSeconds;
    setState(() {
      _remainingSeconds = total <= 0 ? 0 : total;
    });
  }

  String _formatTimer() {
    final s = _remainingSeconds;
    if (s == null) return '--:--';
    if (s <= 0) return 'Expired';
    if (s >= 3600) {
      final h = s ~/ 3600;
      final m = (s % 3600) ~/ 60;
      final sec = s % 60;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  bool get _isExpired => _remainingSeconds != null && _remainingSeconds! <= 0;

  /// Max wallet amount allowed in a split (must leave at least Rs 1 for bank).
  double get _splitWalletMax {
    final total = widget.booking.totalPrice;
    if (total <= 1 || _walletBalance <= 0) return 0;
    final cap = total - 1;
    final max = _walletBalance < cap ? _walletBalance : cap;
    return max.clamp(1, cap).toDouble();
  }

  bool get _canSplit => _splitWalletMax >= 1;

  double _defaultSplitWalletPortion() {
    final max = _splitWalletMax;
    if (max <= 0) return 0;
    final half = (widget.booking.totalPrice / 2).floorToDouble();
    return half.clamp(1, max);
  }

  Future<void> _handleExpired() async {
    if (_payment == null || _expiryHandled) return;
    _expiryHandled = true;
    _timer?.cancel();
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
    final previousMethod = _selectedMethod;
    setState(() {
      _selectedMethod = method;
      _isProcessing = true;
    });

    try {
      PaymentModel payment;
      final existing = _payment;

      if (existing != null && existing.paymentMethod == method) {
        payment = existing;
      } else if (method == AppConstants.paymentMethodWallet) {
        setState(() {
          _selectedMethod = method;
          _isProcessing = false;
        });
        return;
      } else if (method == AppConstants.paymentMethodSplit) {
        setState(() {
          _selectedMethod = method;
          _isProcessing = false;
          _splitWalletDebited = false;
          _walletPortion = _defaultSplitWalletPortion();
        });
        return;
      } else if (method == AppConstants.paymentMethodStripe) {
        payment = await _paymentService.createPayment(
          bookingId: widget.booking.id,
          userId: _payerUserId,
          amount: widget.booking.totalPrice,
        );
        Stripe.publishableKey = PaymentService.stripePublishableKey;
        await Stripe.instance.applySettings();
      } else {
        payment = await _paymentService.createManualPayment(
          bookingId: widget.booking.id,
          userId: _payerUserId,
          amount: widget.booking.totalPrice,
        );
      }

      if (mounted) {
        setState(() {
          _payment = payment;
          _isProcessing = false;
          _expiryHandled = false;
        });
        _updateTime();
        if (_remainingSeconds != null && _remainingSeconds! > 0) {
          _timer?.cancel();
          _startTimer();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _selectedMethod = previousMethod;
        });
        final message = e.toString().replaceFirst('Exception: ', '');
        showErrorSnackBar(context, message.isEmpty ? 'Failed to switch payment method' : message);
      }
    }
  }

  String _stripeErrorMessage(Object e) {
    final raw = e.toString();
    if (raw.contains('canceled') || raw.contains('Canceled')) {
      return 'Payment cancelled';
    }
    if (raw.contains('FailureCode')) {
      return 'Card payment failed. Please check your card details or try bank transfer.';
    }
    final message = raw.replaceFirst('Exception: ', '').replaceFirst('StripeException: ', '');
    return message.isEmpty ? 'Payment failed' : message;
  }

  String get _payerUserId =>
      SupabaseService.client.auth.currentUser?.id ?? widget.booking.userId;

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
          additionalBookingIds: widget.groupBookingIds,
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
          additionalBookingIds: widget.groupBookingIds,
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
      if (mounted) {
        final refreshed = await _paymentService.getPaymentByBookingId(widget.booking.id);
        setState(() => _payment = refreshed ?? _payment);
        showErrorSnackBar(context, _stripeErrorMessage(e));
      }
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
      showErrorSnackBar(context, 'Please select a CWC payment account');
      return;
    }
    if (_receiptFile == null && _payment?.receiptUrl == null) {
      showErrorSnackBar(context, 'Please upload payment receipt screenshot');
      return;
    }

    if (_payment == null || (!_payment!.isManual && !_payment!.isSplit)) {
      if (_selectedMethod == AppConstants.paymentMethodSplit) {
        if (!_splitWalletDebited) {
          showErrorSnackBar(context, 'Apply wallet portion first');
          return;
        }
      } else {
        await _selectMethod(AppConstants.paymentMethodManual);
      }
    }
    if (_payment == null) return;

    setState(() => _isProcessing = true);
    try {
      String receiptUrl = _payment!.receiptUrl ?? '';
      if (_receiptFile != null) {
        final bytes = await _receiptFile!.readAsBytes();
        receiptUrl = await _storageService.uploadPaymentReceipt(
          userId: _payerUserId,
          bookingId: widget.booking.id,
          bytes: bytes,
          fileName: _receiptFile!.name,
        );
      }

      await _paymentService.submitManualReceipt(
        paymentId: _payment!.id,
        platformAccountId: _selectedAccount!.id,
        receiptUrl: receiptUrl,
        transferReference: _refController.text.trim().isEmpty
            ? null
            : _refController.text.trim(),
      );

      if (!mounted) return;
      final updated = await _paymentService.getPaymentById(_payment!.id);
      if (updated != null) setState(() => _payment = updated);
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
          ),
          title: Text('Receipt Submitted', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          content: Text(
            'Your receipt has been sent to CWC team. You will be notified once they verify your payment and confirm the booking.',
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

  double get _externalDue {
    if (_selectedMethod == AppConstants.paymentMethodSplit) {
      return (widget.booking.totalPrice - _walletPortion).clamp(0, widget.booking.totalPrice);
    }
    return widget.booking.totalPrice;
  }

  Future<void> _applySplitWalletPortion() async {
    final portion = _walletPortion.roundToDouble();
    if (portion <= 0 || portion >= widget.booking.totalPrice) {
      showErrorSnackBar(context, 'Choose a wallet amount less than the total');
      return;
    }
    if (portion > _splitWalletMax) {
      showErrorSnackBar(context, 'Wallet portion exceeds available balance');
      return;
    }
    setState(() => _isProcessing = true);
    try {
      final payment = await _paymentService.startSplitPayment(
        bookingId: widget.booking.id,
        userId: _payerUserId,
        totalAmount: widget.booking.totalPrice,
        walletAmount: portion,
      );
      if (!mounted) return;
      setState(() {
        _payment = payment;
        _splitWalletDebited = true;
        _walletPortion = portion;
      });
      showSuccessSnackBar(
        context,
        'Rs. ${portion.toStringAsFixed(0)} deducted from wallet. Transfer the remainder via bank.',
      );
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _buildWalletSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CAppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        border: Border.all(color: CAppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Wallet balance: Rs. ${_walletBalance.toStringAsFixed(0)}',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            'Pay Rs. ${widget.booking.totalPrice.toStringAsFixed(0)} entirely from your wallet. Booking confirms instantly.',
            style: GoogleFonts.poppins(fontSize: 13, color: CAppTheme.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitSection() {
    final maxWallet = _splitWalletMax;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
            boxShadow: CAppTheme.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Wallet portion',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 4),
              Text('Rs. ${_walletPortion.toStringAsFixed(0)} from wallet · Rs. ${_externalDue.toStringAsFixed(0)} via bank',
                  style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.textSecondary)),
              Slider(
                value: _walletPortion.clamp(1, maxWallet > 0 ? maxWallet : 1),
                min: 1,
                max: maxWallet > 0 ? maxWallet : 1,
                divisions: maxWallet > 1 ? (maxWallet - 1).round().clamp(1, 100) : 1,
                label: 'Rs. ${_walletPortion.toStringAsFixed(0)}',
                onChanged: _splitWalletDebited
                    ? null
                    : (v) => setState(() => _walletPortion = v.roundToDouble()),
              ),
              if (!_splitWalletDebited)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _applySplitWalletPortion,
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                    label: const Text('Apply Wallet Portion'),
                  ),
                )
              else
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: CAppTheme.successColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Wallet portion applied. Transfer Rs. ${_externalDue.toStringAsFixed(0)} and upload receipt below.',
                        style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.successColor),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        if (_splitWalletDebited) ...[
          const SizedBox(height: 16),
          _buildManualTransferSection(),
        ],
      ],
    );
  }

  Widget _buildManualTransferSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Transfer to CWC account',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 10),
        ..._platformAccounts.map((a) => _accountOption(a)),
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
                  else if (_selectedMethod == AppConstants.paymentMethodWallet)
                    _buildWalletSection()
                  else if (_selectedMethod == AppConstants.paymentMethodSplit)
                    _buildSplitSection()
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isExpired
              ? [CAppTheme.errorColor, CAppTheme.errorColor.withValues(alpha: 0.8)]
              : [CAppTheme.primaryColor, CAppTheme.primaryDark],
        ),
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatTimer(),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!_isExpired && _payment != null)
                  Text(
                    _selectedMethod == AppConstants.paymentMethodStripe
                        ? '30 min to complete card payment'
                        : '24 hours to upload receipt',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                    ),
                  ),
              ],
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
    final canPayFullWallet = _walletBalance >= widget.booking.totalPrice;
    final canSplit = _canSplit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payment Method',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          'Works for hourly, daily & monthly bookings',
          style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.textSecondary),
        ),
        const SizedBox(height: 12),
        if (canSplit) ...[
          _methodTile(
            method: AppConstants.paymentMethodSplit,
            icon: Icons.call_split_rounded,
            title: 'Split Payment',
            subtitle:
                'Rs. from wallet + remainder via Bank / EasyPaisa (balance: Rs. ${_walletBalance.toStringAsFixed(0)})',
          ),
          const SizedBox(height: 10),
        ] else if (widget.booking.totalPrice > 1) ...[
          _methodTile(
            method: AppConstants.paymentMethodSplit,
            icon: Icons.call_split_rounded,
            title: 'Split Payment',
            subtitle: 'Top up your wallet to pay partly from wallet & partly via bank',
            enabled: false,
          ),
          const SizedBox(height: 10),
        ],
        if (canPayFullWallet) ...[
          _methodTile(
            method: AppConstants.paymentMethodWallet,
            icon: Icons.account_balance_wallet_outlined,
            title: 'Pay from Wallet',
            subtitle: 'Balance: Rs. ${_walletBalance.toStringAsFixed(0)}',
          ),
          const SizedBox(height: 10),
        ],
        _methodTile(
          method: AppConstants.paymentMethodManual,
          icon: Icons.account_balance_outlined,
          title: 'Bank / EasyPaisa / JazzCash',
          subtitle: 'Transfer to CWC & upload receipt',
        ),
        const SizedBox(height: 10),
        _methodTile(
          method: AppConstants.paymentMethodStripe,
          icon: Icons.credit_card,
          title: 'Pay by Card',
          subtitle: 'Stripe secure checkout',
        ),
      ],
    );
  }

  Widget _methodTile({
    required String method,
    required IconData icon,
    required String title,
    required String subtitle,
    bool enabled = true,
  }) {
    final selected = _selectedMethod == method;
    return InkWell(
      onTap: !enabled || _isProcessing ? null : () => _selectMethod(method),
      borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
          border: Border.all(
            color: selected
                ? CAppTheme.primaryColor
                : (enabled ? CAppTheme.borderColor : Colors.grey.shade300),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? CAppTheme.softShadow : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: enabled ? CAppTheme.primaryColor : CAppTheme.textSecondary),
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
            Text('Awaiting CWC Verification',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'Your receipt has been submitted. CWC team will verify and confirm your booking.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: CAppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_platformAccounts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        ),
        child: Text(
          'CWC payment accounts are not configured yet. Please use card payment or contact support.',
          style: GoogleFonts.poppins(color: CAppTheme.textSecondary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildManualTransferSection(),
      ],
    );
  }

  Future<void> _payWithWallet() async {
    setState(() => _isProcessing = true);
    try {
      await _paymentService.payWithWallet(
        bookingId: widget.booking.id,
        userId: _payerUserId,
        amount: widget.booking.totalPrice,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BookingConfirmationScreen(booking: widget.booking),
        ),
      );
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _accountOption(PlatformPaymentAccountModel a) {
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

  Widget _selectedAccountDetails(PlatformPaymentAccountModel a) {
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
          Text('Send Rs. ${_externalDue.toStringAsFixed(0)} to:',
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

    if (_selectedMethod == AppConstants.paymentMethodWallet) {
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _isProcessing ? null : _payWithWallet,
          child: _isProcessing
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : Text('Pay from Wallet',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      );
    }

    final isManual = _selectedMethod == AppConstants.paymentMethodManual ||
        _selectedMethod == AppConstants.paymentMethodSplit;

    if (_selectedMethod == AppConstants.paymentMethodSplit && !_splitWalletDebited) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isProcessing || _isExpired
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
