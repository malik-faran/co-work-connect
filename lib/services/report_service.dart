import 'package:cwc/models/report_model.dart';
import 'package:cwc/models/report_followup_model.dart';
import 'package:cwc/services/supabase_service.dart';
import 'package:uuid/uuid.dart';

class ReportService {
  final _supabase = SupabaseService.client;
  final _uuid = const Uuid();

  Future<List<UserReportModel>> getMyReports(String userId) async {
    final rows = await _supabase
        .from('user_reports')
        .select()
        .eq('reporter_id', userId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((r) => UserReportModel.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<UserReportModel?> getReportById(String reportId, String userId) async {
    final row = await _supabase
        .from('user_reports')
        .select()
        .eq('id', reportId)
        .eq('reporter_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return UserReportModel.fromMap(Map<String, dynamic>.from(row));
  }

  Future<List<ReportFollowupModel>> getFollowups(String reportId) async {
    final rows = await _supabase
        .from('user_report_followups')
        .select()
        .eq('report_id', reportId)
        .order('created_at', ascending: true);
    return (rows as List)
        .map((r) => ReportFollowupModel.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<void> submitObjection({
    required String reportId,
    required String message,
  }) async {
    if (message.trim().length < 10) {
      throw Exception('Please explain your objection in at least 10 characters.');
    }
    await _supabase.rpc('submit_report_objection', params: {
      'p_report_id': reportId,
      'p_message': message.trim(),
    });
  }

  Future<void> submitReport({
    required String reporterId,
    required String reporterRole,
    required String reportType,
    required String subject,
    required String description,
    String? reportedUserId,
    String? workspaceId,
    String? bookingId,
    List<String> evidenceUrls = const [],
  }) async {
    if (description.trim().length < 10) {
      throw Exception('Please describe the issue in at least 10 characters.');
    }

    final baseQuery = _supabase
        .from('user_reports')
        .select('id')
        .eq('reporter_id', reporterId)
        .eq('report_type', reportType)
        .eq('status', 'pending');

    final pendingQuery = reportedUserId != null
        ? baseQuery.eq('reported_user_id', reportedUserId)
        : workspaceId != null
            ? baseQuery.eq('workspace_id', workspaceId)
            : bookingId != null
                ? baseQuery.eq('booking_id', bookingId)
                : baseQuery;

    final existing = await pendingQuery.maybeSingle();
    if (existing != null) {
      throw Exception('You already have a pending report for this issue.');
    }

    await _supabase.from('user_reports').insert({
      'id': _uuid.v4(),
      'reporter_id': reporterId,
      'reporter_role': reporterRole,
      'report_type': reportType,
      'subject': subject.trim(),
      'description': description.trim(),
      'reported_user_id': reportedUserId,
      'workspace_id': workspaceId,
      'booking_id': bookingId,
      'evidence_urls': evidenceUrls,
      'status': 'pending',
    });
  }
}
