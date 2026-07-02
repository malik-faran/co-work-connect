class ReportFollowupModel {
  final String id;
  final String reportId;
  final String authorId;
  final String authorRole;
  final String message;
  final DateTime createdAt;

  ReportFollowupModel({
    required this.id,
    required this.reportId,
    required this.authorId,
    required this.authorRole,
    required this.message,
    required this.createdAt,
  });

  factory ReportFollowupModel.fromMap(Map<String, dynamic> map) {
    return ReportFollowupModel(
      id: map['id'] ?? '',
      reportId: map['report_id'] ?? '',
      authorId: map['author_id'] ?? '',
      authorRole: map['author_role'] ?? 'reporter',
      message: map['message'] ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  bool get isReporter => authorRole == 'reporter';
  bool get isStaff => authorRole == 'staff';
}
