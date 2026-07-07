import 'package:cwc/models/collaboration_hub_models.dart';
import 'package:cwc/services/supabase_service.dart';

class CollaborationPaymentService {
  final _supabase = SupabaseService.client;

  Future<List<CollaborationPayment>> getPayments(String collaborationId) async {
    final rows = await _supabase
        .from('collaboration_payments')
        .select()
        .eq('collaboration_id', collaborationId)
        .order('created_at', ascending: false);
    return rows.map((r) => CollaborationPayment.fromMap(r)).toList();
  }

  CollaborationPayment? paymentForMilestone(
    List<CollaborationPayment> payments,
    String milestoneId,
  ) {
    for (final p in payments) {
      if (p.milestoneId == milestoneId) return p;
    }
    return null;
  }

  Future<void> payMilestoneFromWallet(String milestoneId) async {
    await _supabase.rpc('pay_collaboration_milestone_from_wallet', params: {
      'p_milestone_id': milestoneId,
    });
  }

  Future<void> releaseMilestonePayment(String milestoneId) async {
    await _supabase.rpc('release_collaboration_milestone_payment', params: {
      'p_milestone_id': milestoneId,
    });
  }

  Future<CollaborationPayment?> getPaymentForMilestone(String milestoneId) async {
    final row = await _supabase
        .from('collaboration_payments')
        .select()
        .eq('milestone_id', milestoneId)
        .maybeSingle();
    if (row == null) return null;
    return CollaborationPayment.fromMap(row);
  }
}
