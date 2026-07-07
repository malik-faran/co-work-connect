import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;

import 'package:cwc/models/platform_payment_account_model.dart';
import 'package:cwc/services/payment_service.dart';
import 'package:cwc/services/platform_payment_account_service.dart';
import 'package:cwc/services/storage_service.dart';
import 'package:cwc/services/wallet_service.dart';
import 'package:cwc/services/supabase_service.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/utils/helpers/snackbar_helper.dart';

class WalletTopUpScreen extends StatefulWidget {
  final double amount;
  const WalletTopUpScreen({super.key, required this.amount});

  @override
  State<WalletTopUpScreen> createState() => _WalletTopUpScreenState();
}

class _WalletTopUpScreenState extends State<WalletTopUpScreen> {
  final _accountService = PlatformPaymentAccountService();
  final _storageService = StorageService();
  final _walletService = WalletService();
  final _imagePicker = ImagePicker();
  final _refController = TextEditingController();

  List<PlatformPaymentAccountModel> _platformAccounts = [];
  PlatformPaymentAccountModel? _selectedAccount;
  String? _selectedMethod; // 'stripe' | 'manual'
  XFile? _receiptFile;
  bool _isLoading = true;
  bool _isProcessing = false;

  String get _userId =>
      SupabaseService.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _refController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final accounts = await _accountService.getActiveAccounts();
      if (!mounted) return;
      setState(() {
        _platformAccounts = accounts;
        _selectedAccount = accounts.isNotEmpty
            ? accounts.firstWhere((a) => a.isDefault, orElse: () => accounts.first)
            : null;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _processStripeTopUp() async {
    setState(() => _isProcessing = true);
    try {
      const pkrPerUsd = 280.0;
      final usdCents = ((widget.amount / pkrPerUsd) * 100).round().clamp(50, 99999999);

      final intent = await _createStripeIntent(usdCents);
      final clientSecret = intent['client_secret'] as String?;
      if (clientSecret == null) throw Exception('Failed to create payment');

      if (kIsWeb) {
        await _walletService.topUpWallet(userId: _userId, amount: widget.amount);
      } else {
        Stripe.publishableKey = PaymentService.stripePublishableKey;
        await Stripe.instance.applySettings();
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: clientSecret,
            merchantDisplayName: 'CWC Wallet Top-Up',
            style: ThemeMode.light,
          ),
        );
        await Stripe.instance.presentPaymentSheet();
        await _walletService.topUpWallet(userId: _userId, amount: widget.amount);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
      showSuccessSnackBar(context, 'Rs. ${widget.amount.toStringAsFixed(0)} added to wallet!');
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (!msg.contains('canceled') && !msg.contains('Canceled')) {
        showErrorSnackBar(context, msg.replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<Map<String, dynamic>> _createStripeIntent(int amountCents) async {
    final response = await PaymentService.createStripeTopUpIntent(amountCents);
    return response;
  }

  Future<void> _pickReceipt() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _receiptFile = picked);
  }

  Future<void> _submitManualTopUp() async {
    if (_selectedAccount == null) {
      showErrorSnackBar(context, 'Please select a CWC payment account');
      return;
    }
    if (_receiptFile == null) {
      showErrorSnackBar(context, 'Please upload payment receipt screenshot');
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final bytes = await _receiptFile!.readAsBytes();
      final receiptUrl = await _storageService.uploadWalletTopUpReceipt(
        userId: _userId,
        bytes: bytes,
        fileName: _receiptFile!.name,
      );

      await _walletService.requestTopUp(
        userId: _userId,
        amount: widget.amount,
        platformAccountId: _selectedAccount!.id,
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
            'Your top-up receipt for Rs. ${widget.amount.toStringAsFixed(0)} has been submitted. '
            'CWC team will verify your payment and credit your wallet.',
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
        showErrorSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CAppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Top Up Wallet', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAmountCard(),
                  const SizedBox(height: 20),
                  _buildMethodSelector(),
                  const SizedBox(height: 20),
                  if (_selectedMethod == 'stripe')
                    _buildStripeSection()
                  else if (_selectedMethod == 'manual')
                    _buildManualSection()
                  else
                    _buildPickMethodHint(),
                  const SizedBox(height: 24),
                  _buildActionButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildAmountCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [CAppTheme.primaryColor, CAppTheme.primaryDark],
        ),
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Top-up amount',
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  'Rs. ${widget.amount.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
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
        const SizedBox(height: 6),
        Text('Choose how you want to add money',
            style: GoogleFonts.poppins(fontSize: 12.5, color: CAppTheme.textSecondary)),
        const SizedBox(height: 14),
        _methodTile(
          method: 'manual',
          icon: Icons.account_balance_outlined,
          title: 'Bank / EasyPaisa / JazzCash',
          subtitle: 'Transfer to CWC account & upload receipt',
        ),
        const SizedBox(height: 10),
        _methodTile(
          method: 'stripe',
          icon: Icons.credit_card_rounded,
          title: 'Pay by Card',
          subtitle: 'Stripe secure checkout — instant credit',
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
      onTap: _isProcessing ? null : () => setState(() => _selectedMethod = method),
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
            if (selected)
              const Icon(Icons.check_circle, color: CAppTheme.primaryColor),
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

  Widget _buildStripeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        boxShadow: CAppTheme.softShadow,
      ),
      child: Column(
        children: [
          const Icon(Icons.credit_card_rounded, size: 40, color: CAppTheme.primaryColor),
          const SizedBox(height: 12),
          Text('Secure Card Payment',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 6),
          Text(
            'You will be redirected to Stripe to complete the payment. '
            'Your wallet will be credited instantly after successful payment.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 13, color: CAppTheme.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildManualSection() {
    if (_platformAccounts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        ),
        child: Text(
          'CWC payment accounts are not configured yet. Please use card payment.',
          style: GoogleFonts.poppins(color: CAppTheme.textSecondary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Transfer to CWC account',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 10),
        ..._platformAccounts.map(_accountOption),
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
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: CAppTheme.successColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_receiptFile!.name,
                      style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.successColor)),
                ),
              ],
            ),
          ),
      ],
    );
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
              if (selected)
                const Icon(Icons.check_circle, color: CAppTheme.primaryColor, size: 20),
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
          Text('Send Rs. ${widget.amount.toStringAsFixed(0)} to:',
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
            Text(a.bankName!,
                style: GoogleFonts.poppins(fontSize: 13, color: CAppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    if (_selectedMethod == null) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isProcessing
            ? null
            : (_selectedMethod == 'stripe' ? _processStripeTopUp : _submitManualTopUp),
        child: _isProcessing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Text(
                _selectedMethod == 'stripe' ? 'Pay by Card' : 'Submit Receipt',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}
