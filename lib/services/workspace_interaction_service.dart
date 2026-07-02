import 'package:flutter/foundation.dart';
import 'package:cwc/services/supabase_service.dart';

class WorkspaceInteractionService {
  final _supabase = SupabaseService.client;

  static const actionView = 'view';
  static const actionClick = 'click';
  static const actionBook = 'book';

  Future<void> logInteraction({
    required String userId,
    required String workspaceId,
    required String action,
  }) async {
    try {
      await _supabase.from('workspace_interactions').insert({
        'user_id': userId,
        'workspace_id': workspaceId,
        'action': action,
      });
    } catch (e) {
      debugPrint('Workspace interaction log failed: $e');
    }
  }

  Future<Set<String>> getRecentlyViewedWorkspaceIds(
    String userId, {
    int limit = 30,
  }) async {
    try {
      final rows = await _supabase
          .from('workspace_interactions')
          .select('workspace_id')
          .eq('user_id', userId)
          .eq('action', actionView)
          .order('created_at', ascending: false)
          .limit(limit);

      return rows.map((r) => r['workspace_id'] as String).toSet();
    } catch (e) {
      debugPrint('Failed to load workspace interactions: $e');
      return {};
    }
  }

  /// How many times the user viewed each workspace (recent history).
  Future<Map<String, int>> getUserViewCounts(
    String userId, {
    int limit = 100,
  }) async {
    try {
      final rows = await _supabase
          .from('workspace_interactions')
          .select('workspace_id')
          .eq('user_id', userId)
          .eq('action', actionView)
          .order('created_at', ascending: false)
          .limit(limit);

      final counts = <String, int>{};
      for (final row in rows) {
        final id = row['workspace_id'] as String;
        counts[id] = (counts[id] ?? 0) + 1;
      }
      return counts;
    } catch (e) {
      debugPrint('Failed to load view counts: $e');
      return {};
    }
  }
}
