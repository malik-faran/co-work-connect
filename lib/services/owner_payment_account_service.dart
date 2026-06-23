import 'package:cwc/models/owner_payment_account_model.dart';
import 'package:cwc/services/supabase_service.dart';
import 'package:uuid/uuid.dart';

class OwnerPaymentAccountService {
  final _supabase = SupabaseService.client;
  final _uuid = const Uuid();

  Future<List<OwnerPaymentAccountModel>> getOwnerAccounts(String ownerId) async {
    final rows = await _supabase
        .from('owner_payment_accounts')
        .select()
        .eq('owner_id', ownerId)
        .eq('is_active', true)
        .order('is_default', ascending: false)
        .order('created_at', ascending: false);

    return rows.map((r) => OwnerPaymentAccountModel.fromMap(r)).toList();
  }

  /// Accounts visible to user when paying for a workspace booking.
  Future<List<OwnerPaymentAccountModel>> getAccountsForWorkspace(
    String workspaceId,
  ) async {
    final ws = await _supabase
        .from('workspaces')
        .select('owner_id')
        .eq('id', workspaceId)
        .maybeSingle();

    if (ws == null) return [];
    final ownerId = ws['owner_id'] as String;

    final rows = await _supabase
        .from('owner_payment_accounts')
        .select()
        .eq('owner_id', ownerId)
        .eq('is_active', true)
        .or('workspace_id.is.null,workspace_id.eq.$workspaceId')
        .order('is_default', ascending: false);

    return rows.map((r) => OwnerPaymentAccountModel.fromMap(r)).toList();
  }

  Future<OwnerPaymentAccountModel> createAccount({
    required String ownerId,
    required String accountType,
    required String accountTitle,
    required String accountNumber,
    String? bankName,
    String? workspaceId,
    bool isDefault = false,
  }) async {
    if (isDefault) {
      await _supabase
          .from('owner_payment_accounts')
          .update({'is_default': false})
          .eq('owner_id', ownerId);
    }

    final account = OwnerPaymentAccountModel(
      id: _uuid.v4(),
      ownerId: ownerId,
      workspaceId: workspaceId,
      accountType: accountType,
      accountTitle: accountTitle,
      accountNumber: accountNumber,
      bankName: bankName,
      isDefault: isDefault,
      createdAt: DateTime.now(),
    );

    final data = account.toMap()..removeWhere((_, v) => v == null);
    await _supabase.from('owner_payment_accounts').insert(data);
    return account;
  }

  Future<void> deleteAccount(String accountId) async {
    await _supabase.from('owner_payment_accounts').delete().eq('id', accountId);
  }

  Future<void> setDefault(String ownerId, String accountId) async {
    await _supabase
        .from('owner_payment_accounts')
        .update({'is_default': false})
        .eq('owner_id', ownerId);
    await _supabase
        .from('owner_payment_accounts')
        .update({
          'is_default': true,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', accountId);
  }
}
