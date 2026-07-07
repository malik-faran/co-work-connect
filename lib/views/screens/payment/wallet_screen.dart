import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/services/wallet_service.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/views/screens/payment/wallet_topup_screen.dart';


class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final WalletService _walletService = WalletService();
  WalletModel? _wallet;
  List<WalletTransactionModel> _transactions = [];
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
      final wallet = await _walletService.getWallet(userId);
      final txns = await _walletService.getTransactions(userId);
      if (mounted) {
        setState(() {
          _wallet = wallet;
          _transactions = txns;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showTopUp() async {
    final amountController = TextEditingController();
    final presets = [100, 500, 1000, 2000, 5000];
    final selectedAmount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) => Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: CAppTheme.borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Top Up Wallet',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Choose amount to add',
                      style: GoogleFonts.poppins(fontSize: 12.5, color: CAppTheme.textSecondary)),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: presets.map((p) {
                      return GestureDetector(
                        onTap: () {
                          amountController.text = p.toString();
                          setLocal(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: amountController.text == p.toString()
                                ? CAppTheme.primaryColor
                                : CAppTheme.backgroundColor,
                            borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                            border: Border.all(
                              color: amountController.text == p.toString()
                                  ? CAppTheme.primaryColor
                                  : CAppTheme.borderColor,
                            ),
                          ),
                          child: Text(
                            'Rs. $p',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: amountController.text == p.toString()
                                  ? Colors.white
                                  : CAppTheme.textPrimary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount (PKR)',
                      hintText: 'Enter amount',
                      prefixText: 'Rs. ',
                    ),
                    onChanged: (_) => setLocal(() {}),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final amt = double.tryParse(amountController.text.trim());
                        if (amt != null && amt > 0) {
                          Navigator.pop(ctx, amt);
                        }
                      },
                      child: const Text('Continue to Payment'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (selectedAmount == null || !mounted) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WalletTopUpScreen(amount: selectedAmount),
      ),
    );
    if (result == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CAppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('My Wallet', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
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
                        colors: [CAppTheme.primaryColor, CAppTheme.primaryDark],
                      ),
                      borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Available Balance',
                            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 8),
                        Text(
                          'Rs. ${(_wallet?.balance ?? 0).toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Refunds from approved booking cancellations are credited here.',
                          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: CAppTheme.primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                              ),
                            ),
                            onPressed: _showTopUp,
                            icon: const Icon(Icons.add_rounded, size: 20),
                            label: Text('Top Up', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Transaction History',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 12),
                  if (_transactions.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                      ),
                      child: Text(
                        'No transactions yet.',
                        style: GoogleFonts.poppins(color: CAppTheme.textSecondary),
                      ),
                    )
                  else
                    ..._transactions.map((t) => Container(
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
                                t.txnType == 'credit'
                                    ? Icons.arrow_downward_rounded
                                    : Icons.arrow_upward_rounded,
                                color: t.txnType == 'credit'
                                    ? CAppTheme.successColor
                                    : CAppTheme.errorColor,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(t.reason,
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                                    Text(
                                      DateFormat('MMM dd, yyyy · HH:mm').format(t.createdAt),
                                      style: GoogleFonts.poppins(
                                          fontSize: 12, color: CAppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${t.txnType == 'credit' ? '+' : '-'}Rs. ${t.amount.toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  color: t.txnType == 'credit'
                                      ? CAppTheme.successColor
                                      : CAppTheme.errorColor,
                                ),
                              ),
                            ],
                          ),
                        )),
                ],
              ),
            ),
    );
  }
}
