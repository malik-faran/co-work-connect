import 'package:cwc/models/platform_payment_account_model.dart';
import 'package:cwc/services/supabase_service.dart';

class PlatformPaymentAccountService {
  final _supabase = SupabaseService.client;

  Future<List<PlatformPaymentAccountModel>> getActiveAccounts() async {
    final rows = await _supabase
        .from('platform_payment_accounts')
        .select()
        .eq('is_active', true)
        .order('is_default', ascending: false);

    return rows.map((r) => PlatformPaymentAccountModel.fromMap(r)).toList();
  }
}
