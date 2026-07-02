import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/services/wallet_service.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/utils/helpers/snackbar_helper.dart';

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
                          'Use wallet balance when paying for bookings. Refunds from cancellations are credited here.',
                          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, height: 1.4),
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
