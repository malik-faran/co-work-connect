import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/models/owner_payment_account_model.dart';
import 'package:cwc/services/owner_payment_account_service.dart';
import 'package:cwc/services/wallet_service.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/utils/helpers/snackbar_helper.dart';
import 'package:cwc/views/screens/owner/owner_payment_accounts_screen.dart';

class OwnerWalletScreen extends StatefulWidget {
  const OwnerWalletScreen({super.key});

  @override
  State<OwnerWalletScreen> createState() => _OwnerWalletScreenState();
}

class _OwnerWalletScreenState extends State<OwnerWalletScreen> {
  final WalletService _walletService = WalletService();
  final OwnerPaymentAccountService _accountService = OwnerPaymentAccountService();
  WalletModel? _wallet;
  List<WalletTransactionModel> _transactions = [];
  List<OwnerPaymentAccountModel> _accounts = [];
  double _feePercent = 5;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = context.read<AuthController>().currentUser?.id;
    if (userId == null) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _walletService.getWallet(userId),
        _walletService.getTransactions(userId),
        _accountService.getOwnerAccounts(userId),
        _walletService.getPlatformFeePercent(),
      ]);
      if (mounted) {
        setState(() {
          _wallet = results[0] as WalletModel;
          _transactions = results[1] as List<WalletTransactionModel>;
          _accounts = results[2] as List<OwnerPaymentAccountModel>;
          _feePercent = results[3] as double;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestPayout() async {
    final userId = context.read<AuthController>().currentUser?.id;
    if (userId == null || _wallet == null) return;

    if (_accounts.isEmpty) {
      final goAdd = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Add payment account'),
          content: const Text(
            'Add a bank, JazzCash, or EasyPaisa account first to receive payouts.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add account')),
          ],
        ),
      );
      if (goAdd == true && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OwnerPaymentAccountsScreen()),
        );
        _load();
      }
      return;
    }

    final amountController = TextEditingController();
    OwnerPaymentAccountModel selected = _accounts.firstWhere(
      (a) => a.isDefault,
      orElse: () => _accounts.first,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Withdraw to account', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Available: Rs. ${_wallet!.balance.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(color: CAppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (PKR)',
                  prefixText: 'Rs. ',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<OwnerPaymentAccountModel>(
                initialValue: selected,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Payout account'),
                items: _accounts
                    .map((a) => DropdownMenuItem(
                          value: a,
                          child: Text('${a.displayLabel} · ${a.accountNumber}',
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) => setLocal(() => selected = v ?? selected),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) {
      showErrorSnackBar(context, 'Enter a valid amount');
      return;
    }
    if (amount > _wallet!.balance) {
      showErrorSnackBar(context, 'Amount exceeds wallet balance');
      return;
    }

    try {
      await _walletService.requestOwnerPayout(
        amount: amount,
        ownerAccountId: selected.id,
      );
      if (mounted) {
        showSuccessSnackBar(
          context,
          'Payout request submitted. CWC team will transfer after approval.',
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: 'Rs. ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: CAppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Owner Wallet', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      floatingActionButton: _wallet != null && _wallet!.balance > 0
          ? FloatingActionButton.extended(
              onPressed: _requestPayout,
              icon: const Icon(Icons.account_balance_outlined),
              label: const Text('Withdraw'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [CAppTheme.successColor, const Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Earnings Balance',
                            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 8),
                        Text(
                          fmt.format(_wallet?.balance ?? 0),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Booking payments are credited here automatically after CWC verifies payment (${_feePercent.toStringAsFixed(0)}% platform fee deducted).',
                          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Transactions',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 12),
                  if (_transactions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No earnings yet. You will be credited when bookings are paid & verified.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(color: CAppTheme.textSecondary),
                        ),
                      ),
                    )
                  else
                    ..._transactions.map((t) {
                      final isCredit = t.txnType == 'credit';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                          boxShadow: CAppTheme.softShadow,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                              color: isCredit ? CAppTheme.successColor : CAppTheme.errorColor,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.reason,
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                                  Text(
                                    DateFormat('MMM d, yyyy · HH:mm').format(t.createdAt),
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: CAppTheme.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${isCredit ? '+' : '-'}${fmt.format(t.amount)}',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                color: isCredit ? CAppTheme.successColor : CAppTheme.errorColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
