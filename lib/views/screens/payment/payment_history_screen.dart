import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/services/payment_service.dart';
import 'package:cwc/models/payment_model.dart';
import 'package:cwc/utils/constants/app_constants.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/utils/helpers/snackbar_helper.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  final PaymentService _paymentService = PaymentService();
  List<PaymentModel> _payments = [];
  bool _isLoading = true;
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    final user = context.read<AuthController>().currentUser;
    if (user == null) { setState(() => _isLoading = false); return; }
    final isOwner = user.role == AppConstants.roleOwner;
    try {
      final payments = isOwner
          ? await _paymentService.getOwnerReceivedPayments(user.id)
          : await _paymentService.getUserPayments(user.id);
      setState(() {
        _payments = payments;
        _isOwner = isOwner;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) showErrorSnackBar(context, 'Failed to load payments');
    }
  }

  double get _totalEarnings => _payments
      .where((p) => p.status == 'completed')
      .fold(0.0, (sum, p) => sum + p.amount);

  Color _statusColor(String status) {
    switch (status) {
      case 'completed': return CAppTheme.successColor;
      case 'pending': case 'processing': return CAppTheme.warningColor;
      case 'failed': case 'expired': case 'cancelled': return CAppTheme.errorColor;
      default: return CAppTheme.textTertiary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'completed': return Icons.check_circle;
      case 'pending': case 'processing': return Icons.access_time;
      default: return Icons.error_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CAppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_isOwner ? 'Payments Received' : 'Payment History',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _payments.isEmpty
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.payment_outlined, size: 56, color: CAppTheme.textTertiary),
                    const SizedBox(height: 12),
                    Text(_isOwner ? 'No payments received yet' : 'No payments yet',
                        style: GoogleFonts.poppins(fontSize: 16, color: CAppTheme.textSecondary)),
                  ],
                ))
              : RefreshIndicator(
                  onRefresh: _loadPayments,
                  color: CAppTheme.primaryColor,
                  child: Column(
                    children: [
                      if (_isOwner) _buildEarningsCard(),
                      Expanded(child: _buildGroupedList()),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEarningsCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [CAppTheme.primaryColor, CAppTheme.primaryDark],
        ),
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        boxShadow: CAppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total earnings',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 6),
          Text('PKR ${_totalEarnings.toStringAsFixed(0)}',
              style: GoogleFonts.poppins(
                  fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text('${_payments.where((p) => p.status == 'completed').length} completed of ${_payments.length} payments',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildGroupedList() {
    final grouped = <String, List<PaymentModel>>{};
    for (var p in _payments) {
      final key = DateFormat('MMMM yyyy').format(p.createdAt);
      (grouped[key] ??= []).add(p);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: grouped.length,
      itemBuilder: (_, i) {
        final month = grouped.keys.elementAt(i);
        final items = grouped[month]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 12, left: 4),
              child: Text(month, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: CAppTheme.textPrimary)),
            ),
            ...items.map((p) => _PaymentCard(payment: p, statusColor: _statusColor(p.status), statusIcon: _statusIcon(p.status))),
          ],
        );
      },
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final PaymentModel payment;
  final Color statusColor;
  final IconData statusIcon;
  const _PaymentCard({required this.payment, required this.statusColor, required this.statusIcon});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        boxShadow: CAppTheme.softShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
              ),
              child: Icon(statusIcon, color: statusColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Payment #${payment.id.substring(0, 8)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(DateFormat('MMM dd, hh:mm a').format(payment.createdAt), style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.textSecondary)),
              ],
            )),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${payment.currency} ${payment.amount.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: CAppTheme.primaryColor)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(payment.status.toUpperCase(), style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
