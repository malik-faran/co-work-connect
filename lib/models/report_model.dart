class UserReportModel {
  final String id;
  final String reporterId;
  final String reporterRole;
  final String reportType;
  final String subject;
  final String description;
  final String? reportedUserId;
  final String? workspaceId;
  final String? bookingId;
  final List<String> evidenceUrls;
  final String status;
  final String? staffAction;
  final String? resolutionNote;
  final DateTime createdAt;

  UserReportModel({
    required this.id,
    required this.reporterId,
    required this.reporterRole,
    required this.reportType,
    required this.subject,
    required this.description,
    this.reportedUserId,
    this.workspaceId,
    this.bookingId,
    this.evidenceUrls = const [],
    required this.status,
    this.staffAction,
    this.resolutionNote,
    required this.createdAt,
  });

  factory UserReportModel.fromMap(Map<String, dynamic> map) {
    final evidence = map['evidence_urls'];
    return UserReportModel(
      id: map['id'] ?? '',
      reporterId: map['reporter_id'] ?? '',
      reporterRole: map['reporter_role'] ?? 'user',
      reportType: map['report_type'] ?? 'other',
      subject: map['subject'] ?? '',
      description: map['description'] ?? '',
      reportedUserId: map['reported_user_id'],
      workspaceId: map['workspace_id'],
      bookingId: map['booking_id'],
      evidenceUrls: evidence is List
          ? evidence.map((e) => e.toString()).toList()
          : const [],
      status: map['status'] ?? 'pending',
      staffAction: map['staff_action'],
      resolutionNote: map['resolution_note'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  static const Map<String, String> typeLabels = {
    'harassment': 'Harassment',
    'fraud': 'Fraud / Scam',
    'fake_listing': 'Fake Listing',
    'payment_issue': 'Payment Issue',
    'inappropriate_content': 'Inappropriate Content',
    'spam': 'Spam',
    'safety': 'Safety Concern',
    'other': 'Other',
  };

  static const Map<String, String> statusLabels = {
    'pending': 'Pending',
    'under_review': 'Under Review',
    'resolved': 'Resolved',
    'dismissed': 'Dismissed',
  };

  String get typeLabel => typeLabels[reportType] ?? reportType;
  String get statusLabel => statusLabels[status] ?? status;
}
