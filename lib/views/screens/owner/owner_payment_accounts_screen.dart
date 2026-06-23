import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/models/owner_payment_account_model.dart';
import 'package:cwc/services/owner_payment_account_service.dart';
import 'package:cwc/utils/constants/app_constants.dart';
import 'package:cwc/utils/helpers/snackbar_helper.dart';
import 'package:cwc/utils/themes/theme.dart';

/// Owner manages bank / EasyPaisa / JazzCash accounts in one place.
class OwnerPaymentAccountsScreen extends StatefulWidget {
  const OwnerPaymentAccountsScreen({super.key});

  @override
  State<OwnerPaymentAccountsScreen> createState() =>
      _OwnerPaymentAccountsScreenState();
}

class _OwnerPaymentAccountsScreenState extends State<OwnerPaymentAccountsScreen> {
  final OwnerPaymentAccountService _service = OwnerPaymentAccountService();
  List<OwnerPaymentAccountModel> _accounts = [];
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
      final list = await _service.getOwnerAccounts(ownerId);
      if (mounted) setState(() { _accounts = list; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showErrorSnackBar(context, 'Failed to load accounts');
      }
    }
  }

  Future<void> _showAddDialog() async {
    final ownerId = context.read<AuthController>().currentUser?.id;
    if (ownerId == null) return;

    String type = AppConstants.accountTypeBank;
    final titleCtrl = TextEditingController();
    final numberCtrl = TextEditingController();
    final bankCtrl = TextEditingController();
  bool isDefault = _accounts.isEmpty;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
          ),
          title: Text('Add Payment Account', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Account Type'),
                  items: const [
                    DropdownMenuItem(value: 'bank', child: Text('Bank')),
                    DropdownMenuItem(value: 'easypaisa', child: Text('EasyPaisa')),
                    DropdownMenuItem(value: 'jazzcash', child: Text('JazzCash')),
                  ],
                  onChanged: (v) => setDlg(() => type = v ?? 'bank'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Account Title *'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: numberCtrl,
                  decoration: InputDecoration(
                    labelText: type == 'bank' ? 'IBAN / Account No. *' : 'Mobile / Account No. *',
                  ),
                  keyboardType: TextInputType.text,
                ),
                if (type == 'bank') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: bankCtrl,
                    decoration: const InputDecoration(labelText: 'Bank Name *'),
                  ),
                ],
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Default account', style: GoogleFonts.poppins(fontSize: 14)),
                  value: isDefault,
                  onChanged: (v) => setDlg(() => isDefault = v ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (ok != true) return;
    if (titleCtrl.text.trim().isEmpty || numberCtrl.text.trim().isEmpty) {
      showErrorSnackBar(context, 'Please fill all required fields');
      return;
    }
    if (type == 'bank' && bankCtrl.text.trim().isEmpty) {
      showErrorSnackBar(context, 'Bank name is required');
      return;
    }

    try {
      await _service.createAccount(
        ownerId: ownerId,
        accountType: type,
        accountTitle: titleCtrl.text.trim(),
        accountNumber: numberCtrl.text.trim(),
        bankName: type == 'bank' ? bankCtrl.text.trim() : null,
        isDefault: isDefault,
      );
      if (mounted) {
        showSuccessSnackBar(context, 'Account added');
        _load();
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Failed to add account');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CAppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Payment Accounts', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: CAppTheme.primaryColor,
        icon: const Icon(Icons.add),
        label: Text('Add Account', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: CAppTheme.primaryColor))
          : _accounts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.account_balance_wallet_outlined,
                            size: 64, color: CAppTheme.primaryColor.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'No payment accounts yet',
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your bank, EasyPaisa or JazzCash account so users can pay you directly.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(color: CAppTheme.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _accounts.length,
                    itemBuilder: (_, i) {
                      final a = _accounts[i];
                      return _AccountCard(
                        account: a,
                        onCopy: () {
                          Clipboard.setData(ClipboardData(text: a.accountNumber));
                          showSuccessSnackBar(context, 'Account number copied');
                        },
                        onDelete: () async {
                          await _service.deleteAccount(a.id);
                          _load();
                        },
                        onSetDefault: () async {
                          final ownerId = context.read<AuthController>().currentUser!.id;
                          await _service.setDefault(ownerId, a.id);
                          _load();
                        },
                      );
                    },
                  ),
                ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final OwnerPaymentAccountModel account;
  final VoidCallback onCopy;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

  const _AccountCard({
    required this.account,
    required this.onCopy,
    required this.onDelete,
    required this.onSetDefault,
  });

  IconData get _icon {
    switch (account.accountType) {
      case 'easypaisa':
        return Icons.phone_android_outlined;
      case 'jazzcash':
        return Icons.mobile_friendly_outlined;
      default:
        return Icons.account_balance_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        boxShadow: CAppTheme.softShadow,
        border: account.isDefault
            ? Border.all(color: CAppTheme.primaryColor.withValues(alpha: 0.4))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: CAppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon, color: CAppTheme.primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(account.displayLabel,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(account.accountTitle,
                        style: GoogleFonts.poppins(fontSize: 13, color: CAppTheme.textSecondary)),
                  ],
                ),
              ),
              if (account.isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: CAppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(CAppTheme.radiusRound),
                  ),
                  child: Text('Default',
                      style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: CAppTheme.primaryColor)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(account.accountNumber,
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              ),
              IconButton(onPressed: onCopy, icon: const Icon(Icons.copy_rounded, size: 20)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!account.isDefault)
                TextButton(onPressed: onSetDefault, child: const Text('Set Default')),
              TextButton(
                onPressed: onDelete,
                child: Text('Delete', style: GoogleFonts.poppins(color: CAppTheme.errorColor)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
