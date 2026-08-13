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
          ? evidence.map<String>((e) => e.toString()).toList()
          : const <String>[],
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

  /// Context-specific reason lists shown when reporting.
  static List<MapEntry<String, String>> reasonsFor({
    String? reportedUserId,
    String? workspaceId,
    String? bookingId,
  }) {
    if (bookingId != null) {
      return const [
        MapEntry('payment_issue', 'Payment / refund problem'),
        MapEntry('fraud', 'Fraud or misleading booking'),
        MapEntry('harassment', 'Harassment by host'),
        MapEntry('safety', 'Safety concern at visit'),
        MapEntry('inappropriate_content', 'Misleading listing details'),
        MapEntry('other', 'Other'),
      ];
    }
    if (workspaceId != null) {
      return const [
        MapEntry('fake_listing', 'Fake or misleading listing'),
        MapEntry('payment_issue', 'Pricing / payment issue'),
        MapEntry('inappropriate_content', 'Inappropriate photos or description'),
        MapEntry('safety', 'Safety concern'),
        MapEntry('fraud', 'Scam / fraud'),
        MapEntry('spam', 'Spam listing'),
        MapEntry('other', 'Other'),
      ];
    }
    if (reportedUserId != null) {
      return const [
        MapEntry('harassment', 'Harassment or bullying'),
        MapEntry('fraud', 'Fraud / scam behaviour'),
        MapEntry('spam', 'Spam messages'),
        MapEntry('inappropriate_content', 'Inappropriate content'),
        MapEntry('safety', 'Safety concern'),
        MapEntry('other', 'Other'),
      ];
    }
    return typeLabels.entries.toList();
  }

  static String contextLabel({
    String? reportedUserId,
    String? workspaceId,
    String? bookingId,
  }) {
    if (bookingId != null) return 'Booking issue';
    if (workspaceId != null) return 'Workspace listing';
    if (reportedUserId != null) return 'User behaviour';
    return 'General issue';
  }

  static const Map<String, String> statusLabels = {
    'pending': 'Pending',
    'under_review': 'Under Review',
    'resolved': 'Resolved',
    'dismissed': 'Dismissed',
  };

  String get typeLabel => typeLabels[reportType] ?? reportType;
  String get statusLabel => statusLabels[status] ?? status;
}
