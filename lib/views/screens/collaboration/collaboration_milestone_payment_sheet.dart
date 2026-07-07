import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/models/collaboration_hub_models.dart';
import 'package:cwc/services/collaboration_payment_service.dart';
import 'package:cwc/services/wallet_service.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/views/screens/payment/wallet_topup_screen.dart';

/// Fiverr-style milestone payment sheet (wallet escrow).
class CollaborationMilestonePaymentSheet extends StatefulWidget {
  final CollaborationMilestone milestone;
  final CollaborationPayment? existingPayment;

  const CollaborationMilestonePaymentSheet({
    super.key,
    required this.milestone,
    this.existingPayment,
  });

  @override
  State<CollaborationMilestonePaymentSheet> createState() =>
      _CollaborationMilestonePaymentSheetState();
}

class _CollaborationMilestonePaymentSheetState
    extends State<CollaborationMilestonePaymentSheet> {
  static const Color _fiverrGreen = Color(0xFF1DBF73);

  final _paymentService = CollaborationPaymentService();
  final _walletService = WalletService();
  double _balance = 0;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = context.read<AuthController>().currentUser?.id;
    if (userId == null) return;
    try {
      final wallet = await _walletService.getWallet(userId);
      if (mounted) {
        setState(() {
          _balance = wallet.balance;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(double v) => NumberFormat('#,##0').format(v);

  Future<void> _payWithWallet() async {
    final amount = widget.milestone.amount ?? 0;
    if (amount <= 0) return;
    setState(() => _busy = true);
    try {
      await _paymentService.payMilestoneFromWallet(widget.milestone.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: CAppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.milestone;
    final amount = m.amount ?? 0;
    final canPay = amount > 0 && widget.existingPayment == null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: CAppTheme.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Fund milestone',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              m.title,
              style: GoogleFonts.poppins(fontSize: 13, color: CAppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: CAppTheme.borderColor, width: 1.5),
                borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ORDER SUMMARY',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: CAppTheme.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Milestone payment',
                        style: GoogleFonts.poppins(fontSize: 13),
                      ),
                      Text(
                        amount > 0 ? 'Rs. ${_fmt(amount)}' : '—',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (m.assignedToName != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Payee: ${m.assignedToName}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: CAppTheme.textSecondary,
                      ),
                    ),
                  ],
                  const Divider(height: 24),
                  Text(
                    'Funds are held in escrow until you release payment after the milestone is completed.',
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      height: 1.4,
                      color: CAppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else ...[
              _paymentMethodTile(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Pay with Wallet',
                subtitle: 'Balance: Rs. ${_fmt(_balance)}',
                selected: true,
                enabled: canPay && _balance >= amount,
              ),
              if (canPay && _balance < amount) ...[
                const SizedBox(height: 8),
                Text(
                  'Insufficient balance. Top up your wallet to fund this milestone.',
                  style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.errorColor),
                ),
                TextButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WalletTopUpScreen(amount: amount),
                      ),
                    );
                    _load();
                  },
                  child: const Text('Top up wallet'),
                ),
              ],
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: (!_busy && canPay && _balance >= amount) ? _payWithWallet : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _fiverrGreen,
                  disabledBackgroundColor: _fiverrGreen.withValues(alpha: 0.4),
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text(
                        'Pay Rs. ${_fmt(amount)}',
                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentMethodTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required bool enabled,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? _fiverrGreen.withValues(alpha: 0.08) : CAppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
          border: Border.all(
            color: selected ? _fiverrGreen : CAppTheme.borderColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? _fiverrGreen : CAppTheme.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.textSecondary)),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle_rounded, color: _fiverrGreen, size: 20),
          ],
        ),
      ),
    );
  }
}
