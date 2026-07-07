import 'package:cwc/utils/helpers/model_helpers.dart';

List<String> _stringList(Map<String, dynamic> map, String snake, String camel) {
  final raw = getListFromMap(map, snake, camel);
  if (raw == null) return const [];
  return List<String>.from(raw);
}

DateTime? _date(Map<String, dynamic> map, String snake, String camel) {
  final raw = getStringFromMap(map, snake, camel);
  return raw == null ? null : DateTime.tryParse(raw);
}

/// An open position on a project.
class CollaborationRole {
  final String id;
  final String collaborationId;
  final String title;
  final String? description;
  final List<String> requiredSkills;
  final int? slots; // null = unlimited
  final int sortOrder;
  final DateTime createdAt;

  CollaborationRole({
    required this.id,
    required this.collaborationId,
    required this.title,
    this.description,
    this.requiredSkills = const [],
    this.slots,
    this.sortOrder = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'collaboration_id': collaborationId,
        'title': title,
        if (description != null) 'description': description,
        'required_skills': requiredSkills,
        if (slots != null) 'slots': slots,
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
      };

  factory CollaborationRole.fromMap(Map<String, dynamic> map) => CollaborationRole(
        id: map['id'] ?? '',
        collaborationId: getStringFromMap(map, 'collaboration_id', 'collaborationId') ?? '',
        title: map['title'] ?? '',
        description: getStringFromMap(map, 'description', 'description'),
        requiredSkills: _stringList(map, 'required_skills', 'requiredSkills'),
        slots: convertToIntNullable(map['slots']),
        sortOrder: convertToInt(map['sort_order'] ?? map['sortOrder'], 0),
        createdAt: _date(map, 'created_at', 'createdAt') ?? DateTime.now(),
      );
}

/// An active team member after launch.
class CollaborationMember {
  final String id;
  final String collaborationId;
  final String userId;
  final String userName;
  final String? userProfileImage;
  final String role; // 'owner' | 'member'
  final String? roleTitle;
  final String joinedVia;
  final DateTime joinedAt;
  final DateTime? contractAcceptedAt;

  CollaborationMember({
    required this.id,
    required this.collaborationId,
    required this.userId,
    required this.userName,
    this.userProfileImage,
    this.role = 'member',
    this.roleTitle,
    this.joinedVia = 'discover',
    required this.joinedAt,
    this.contractAcceptedAt,
  });

  bool get isOwner => role == 'owner';
  bool get hasAcceptedContract => contractAcceptedAt != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CollaborationMember && userId == other.userId;

  @override
  int get hashCode => userId.hashCode;

  Map<String, dynamic> toMap() => {
        'id': id,
        'collaboration_id': collaborationId,
        'user_id': userId,
        'user_name': userName,
        if (userProfileImage != null) 'user_profile_image': userProfileImage,
        'role': role,
        if (roleTitle != null) 'role_title': roleTitle,
        'joined_via': joinedVia,
        'joined_at': joinedAt.toIso8601String(),
        if (contractAcceptedAt != null)
          'contract_accepted_at': contractAcceptedAt!.toIso8601String(),
      };

  factory CollaborationMember.fromMap(Map<String, dynamic> map) => CollaborationMember(
        id: map['id'] ?? '',
        collaborationId: getStringFromMap(map, 'collaboration_id', 'collaborationId') ?? '',
        userId: getStringFromMap(map, 'user_id', 'userId') ?? '',
        userName: getStringFromMap(map, 'user_name', 'userName') ?? 'User',
        userProfileImage: getStringFromMap(map, 'user_profile_image', 'userProfileImage'),
        role: getStringFromMap(map, 'role', 'role') ?? 'member',
        roleTitle: getStringFromMap(map, 'role_title', 'roleTitle'),
        joinedVia: getStringFromMap(map, 'joined_via', 'joinedVia') ?? 'discover',
        joinedAt: _date(map, 'joined_at', 'joinedAt') ?? DateTime.now(),
        contractAcceptedAt: _date(map, 'contract_accepted_at', 'contractAcceptedAt'),
      );
}

/// A role-based application to a project.
class CollaborationApplication {
  final String id;
  final String collaborationId;
  final String? roleId;
  final String? roleTitle;
  final String userId;
  final String userName;
  final String userEmail;
  final String? userProfileImage;
  final List<String> userSkills;
  final String pitchMessage;
  final String? availability;
  final String? proposedRate;
  final List<String> portfolioItemIds;
  final String status; // pending | shortlisted | accepted | rejected
  final String? rejectReason;
  final DateTime createdAt;

  CollaborationApplication({
    required this.id,
    required this.collaborationId,
    this.roleId,
    this.roleTitle,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.userProfileImage,
    this.userSkills = const [],
    required this.pitchMessage,
    this.availability,
    this.proposedRate,
    this.portfolioItemIds = const [],
    this.status = 'pending',
    this.rejectReason,
    required this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isShortlisted => status == 'shortlisted';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';

  Map<String, dynamic> toMap() => {
        'id': id,
        'collaboration_id': collaborationId,
        if (roleId != null) 'role_id': roleId,
        if (roleTitle != null) 'role_title': roleTitle,
        'user_id': userId,
        'user_name': userName,
        'user_email': userEmail,
        if (userProfileImage != null) 'user_profile_image': userProfileImage,
        'user_skills': userSkills,
        'pitch_message': pitchMessage,
        if (availability != null) 'availability': availability,
        if (proposedRate != null) 'proposed_rate': proposedRate,
        'portfolio_item_ids': portfolioItemIds,
        'status': status,
        if (rejectReason != null) 'reject_reason': rejectReason,
        'created_at': createdAt.toIso8601String(),
      };

  factory CollaborationApplication.fromMap(Map<String, dynamic> map) => CollaborationApplication(
        id: map['id'] ?? '',
        collaborationId: getStringFromMap(map, 'collaboration_id', 'collaborationId') ?? '',
        roleId: getStringFromMap(map, 'role_id', 'roleId'),
        roleTitle: getStringFromMap(map, 'role_title', 'roleTitle'),
        userId: getStringFromMap(map, 'user_id', 'userId') ?? '',
        userName: getStringFromMap(map, 'user_name', 'userName') ?? 'User',
        userEmail: getStringFromMap(map, 'user_email', 'userEmail') ?? '',
        userProfileImage: getStringFromMap(map, 'user_profile_image', 'userProfileImage'),
        userSkills: _stringList(map, 'user_skills', 'userSkills'),
        pitchMessage: getStringFromMap(map, 'pitch_message', 'pitchMessage') ?? '',
        availability: getStringFromMap(map, 'availability', 'availability'),
        proposedRate: getStringFromMap(map, 'proposed_rate', 'proposedRate'),
        portfolioItemIds: _stringList(map, 'portfolio_item_ids', 'portfolioItemIds'),
        status: getStringFromMap(map, 'status', 'status') ?? 'pending',
        rejectReason: getStringFromMap(map, 'reject_reason', 'rejectReason'),
        createdAt: _date(map, 'created_at', 'createdAt') ?? DateTime.now(),
      );
}

/// A project milestone / task.
class CollaborationMilestone {
  final String id;
  final String collaborationId;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final String status; // pending | submitted | done | missed
  final String? assignedTo;
  final String? assignedToName;
  final int sortOrder;
  final String? completedBy;
  final DateTime? completedAt;
  final DateTime? missedNotifiedAt;
  final String? completionRequestedBy;
  final DateTime? completionRequestedAt;
  final String? submissionNote;
  final String? reviewReason;
  final double? amount;
  final DateTime createdAt;

  CollaborationMilestone({
    required this.id,
    required this.collaborationId,
    required this.title,
    this.description,
    this.dueDate,
    this.status = 'pending',
    this.assignedTo,
    this.assignedToName,
    this.sortOrder = 0,
    this.completedBy,
    this.completedAt,
    this.missedNotifiedAt,
    this.completionRequestedBy,
    this.completionRequestedAt,
    this.submissionNote,
    this.reviewReason,
    this.amount,
    required this.createdAt,
  });

  bool get isDone => status == 'done';
  bool get isMissed => status == 'missed';
  bool get isPending => status == 'pending';
  bool get isSubmitted => status == 'submitted';

  bool get isOverdue =>
      (isPending || isSubmitted) && dueDate != null && DateTime.now().isAfter(dueDate!);

  bool canToggleBy(String userId, {required bool isProjectOwner}) {
    if (isMissed) return false;
    if (isDone) return isProjectOwner;
    if (isSubmitted) return isProjectOwner;
    return assignedTo == userId || isProjectOwner;
  }

  CollaborationMilestone copyWith({
    String? title,
    String? description,
    DateTime? dueDate,
    String? status,
    String? assignedTo,
    String? assignedToName,
    DateTime? missedNotifiedAt,
    String? completionRequestedBy,
    DateTime? completionRequestedAt,
    String? submissionNote,
    String? reviewReason,
    double? amount,
  }) =>
      CollaborationMilestone(
        id: id,
        collaborationId: collaborationId,
        title: title ?? this.title,
        description: description ?? this.description,
        dueDate: dueDate ?? this.dueDate,
        status: status ?? this.status,
        assignedTo: assignedTo ?? this.assignedTo,
        assignedToName: assignedToName ?? this.assignedToName,
        sortOrder: sortOrder,
        completedBy: completedBy,
        completedAt: completedAt,
        missedNotifiedAt: missedNotifiedAt ?? this.missedNotifiedAt,
        completionRequestedBy: completionRequestedBy ?? this.completionRequestedBy,
        completionRequestedAt: completionRequestedAt ?? this.completionRequestedAt,
        submissionNote: submissionNote ?? this.submissionNote,
        reviewReason: reviewReason ?? this.reviewReason,
        amount: amount ?? this.amount,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'collaboration_id': collaborationId,
        'title': title,
        if (description != null) 'description': description,
        if (dueDate != null) 'due_date': dueDate!.toIso8601String(),
        'status': status,
        if (assignedTo != null) 'assigned_to': assignedTo,
        if (assignedToName != null) 'assigned_to_name': assignedToName,
        'sort_order': sortOrder,
        if (completedBy != null) 'completed_by': completedBy,
        if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
        if (missedNotifiedAt != null)
          'missed_notified_at': missedNotifiedAt!.toIso8601String(),
        if (completionRequestedBy != null) 'completion_requested_by': completionRequestedBy,
        if (completionRequestedAt != null)
          'completion_requested_at': completionRequestedAt!.toIso8601String(),
        if (submissionNote != null) 'submission_note': submissionNote,
        if (reviewReason != null) 'review_reason': reviewReason,
        if (amount != null) 'amount': amount,
        'created_at': createdAt.toIso8601String(),
      };

  factory CollaborationMilestone.fromMap(Map<String, dynamic> map) => CollaborationMilestone(
        id: map['id'] ?? '',
        collaborationId: getStringFromMap(map, 'collaboration_id', 'collaborationId') ?? '',
        title: map['title'] ?? '',
        description: getStringFromMap(map, 'description', 'description'),
        dueDate: _date(map, 'due_date', 'dueDate'),
        status: getStringFromMap(map, 'status', 'status') ?? 'pending',
        assignedTo: getStringFromMap(map, 'assigned_to', 'assignedTo'),
        assignedToName: getStringFromMap(map, 'assigned_to_name', 'assignedToName'),
        sortOrder: convertToInt(map['sort_order'] ?? map['sortOrder'], 0),
        completedBy: getStringFromMap(map, 'completed_by', 'completedBy'),
        completedAt: _date(map, 'completed_at', 'completedAt'),
        missedNotifiedAt: _date(map, 'missed_notified_at', 'missedNotifiedAt'),
        completionRequestedBy:
            getStringFromMap(map, 'completion_requested_by', 'completionRequestedBy'),
        completionRequestedAt:
            _date(map, 'completion_requested_at', 'completionRequestedAt'),
        submissionNote: getStringFromMap(map, 'submission_note', 'submissionNote'),
        reviewReason: getStringFromMap(map, 'review_reason', 'reviewReason'),
        amount: () {
          final v = map['amount'];
          if (v == null) return null;
          final d = convertToDouble(v, 0);
          return d > 0 ? d : null;
        }(),
        createdAt: _date(map, 'created_at', 'createdAt') ?? DateTime.now(),
      );
}

/// Escrow payment for a project milestone (Fiverr-style).
class CollaborationPayment {
  final String id;
  final String collaborationId;
  final String milestoneId;
  final String payerId;
  final String? payeeId;
  final double amount;
  final String status; // pending | held | released | failed
  final String paymentMethod;
  final DateTime createdAt;
  final DateTime? releasedAt;

  CollaborationPayment({
    required this.id,
    required this.collaborationId,
    required this.milestoneId,
    required this.payerId,
    this.payeeId,
    required this.amount,
    required this.status,
    required this.paymentMethod,
    required this.createdAt,
    this.releasedAt,
  });

  bool get isHeld => status == 'held';
  bool get isReleased => status == 'released';
  bool get isPending => status == 'pending';

  factory CollaborationPayment.fromMap(Map<String, dynamic> map) => CollaborationPayment(
        id: map['id'] ?? '',
        collaborationId: getStringFromMap(map, 'collaboration_id', 'collaborationId') ?? '',
        milestoneId: getStringFromMap(map, 'milestone_id', 'milestoneId') ?? '',
        payerId: getStringFromMap(map, 'payer_id', 'payerId') ?? '',
        payeeId: getStringFromMap(map, 'payee_id', 'payeeId'),
        amount: convertToDouble(map['amount'], 0),
        status: getStringFromMap(map, 'status', 'status') ?? 'pending',
        paymentMethod: getStringFromMap(map, 'payment_method', 'paymentMethod') ?? 'wallet',
        createdAt: _date(map, 'created_at', 'createdAt') ?? DateTime.now(),
        releasedAt: _date(map, 'released_at', 'releasedAt'),
      );
}

/// Rules for when a project can be marked complete.
class CollaborationMilestoneRules {
  static bool canMarkProjectComplete(List<CollaborationMilestone> milestones) =>
      projectCompleteBlockReason(milestones) == null;

  static String? projectCompleteBlockReason(List<CollaborationMilestone> milestones) {
    if (milestones.isEmpty) {
      return 'Add milestones before marking the project complete.';
    }
    final missed = milestones.where((m) => m.isMissed).length;
    if (missed > 0) {
      return missed == 1
          ? '1 milestone was missed. Update or replace it before completing the project.'
          : '$missed milestones were missed. Resolve them before completing the project.';
    }
    final done = milestones.where((m) => m.isDone).length;
    final submitted = milestones.where((m) => m.isSubmitted).length;
    if (submitted > 0) {
      return submitted == 1
          ? '1 milestone completion request is waiting for owner approval.'
          : '$submitted milestone completion requests are waiting for owner approval.';
    }
    if (done < milestones.length) {
      return 'Complete all milestones first ($done/${milestones.length} done).';
    }
    return null;
  }
}

/// A shared file on a project.
class CollaborationFile {
  final String id;
  final String collaborationId;
  final String? uploadedBy;
  final String? uploaderName;
  final String fileName;
  final String fileUrl;
  final String? fileType;
  final int? fileSize;
  final DateTime createdAt;

  CollaborationFile({
    required this.id,
    required this.collaborationId,
    this.uploadedBy,
    this.uploaderName,
    required this.fileName,
    required this.fileUrl,
    this.fileType,
    this.fileSize,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'collaboration_id': collaborationId,
        if (uploadedBy != null) 'uploaded_by': uploadedBy,
        if (uploaderName != null) 'uploader_name': uploaderName,
        'file_name': fileName,
        'file_url': fileUrl,
        if (fileType != null) 'file_type': fileType,
        if (fileSize != null) 'file_size': fileSize,
        'created_at': createdAt.toIso8601String(),
      };

  factory CollaborationFile.fromMap(Map<String, dynamic> map) => CollaborationFile(
        id: map['id'] ?? '',
        collaborationId: getStringFromMap(map, 'collaboration_id', 'collaborationId') ?? '',
        uploadedBy: getStringFromMap(map, 'uploaded_by', 'uploadedBy'),
        uploaderName: getStringFromMap(map, 'uploader_name', 'uploaderName'),
        fileName: getStringFromMap(map, 'file_name', 'fileName') ?? 'file',
        fileUrl: getStringFromMap(map, 'file_url', 'fileUrl') ?? '',
        fileType: getStringFromMap(map, 'file_type', 'fileType'),
        fileSize: convertToIntNullable(map['file_size'] ?? map['fileSize']),
        createdAt: _date(map, 'created_at', 'createdAt') ?? DateTime.now(),
      );
}

/// An activity-feed event.
class CollaborationActivity {
  final String id;
  final String collaborationId;
  final String? actorId;
  final String? actorName;
  final String action;
  final String? detail;
  final DateTime createdAt;

  CollaborationActivity({
    required this.id,
    required this.collaborationId,
    this.actorId,
    this.actorName,
    required this.action,
    this.detail,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'collaboration_id': collaborationId,
        if (actorId != null) 'actor_id': actorId,
        if (actorName != null) 'actor_name': actorName,
        'action': action,
        if (detail != null) 'detail': detail,
        'created_at': createdAt.toIso8601String(),
      };

  factory CollaborationActivity.fromMap(Map<String, dynamic> map) => CollaborationActivity(
        id: map['id'] ?? '',
        collaborationId: getStringFromMap(map, 'collaboration_id', 'collaborationId') ?? '',
        actorId: getStringFromMap(map, 'actor_id', 'actorId'),
        actorName: getStringFromMap(map, 'actor_name', 'actorName'),
        action: getStringFromMap(map, 'action', 'action') ?? 'general',
        detail: getStringFromMap(map, 'detail', 'detail'),
        createdAt: _date(map, 'created_at', 'createdAt') ?? DateTime.now(),
      );
}

/// A profile-based invite (Mode B).
class CollaborationInvite {
  final String id;
  final String collaborationId;
  final String? collaborationTitle;
  final String? roleId;
  final String? roleTitle;
  final String invitedBy;
  final String? invitedByName;
  final String invitedUser;
  final String? message;
  final String status; // pending | accepted | declined
  final DateTime createdAt;

  CollaborationInvite({
    required this.id,
    required this.collaborationId,
    this.collaborationTitle,
    this.roleId,
    this.roleTitle,
    required this.invitedBy,
    this.invitedByName,
    required this.invitedUser,
    this.message,
    this.status = 'pending',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'collaboration_id': collaborationId,
        if (collaborationTitle != null) 'collaboration_title': collaborationTitle,
        if (roleId != null) 'role_id': roleId,
        if (roleTitle != null) 'role_title': roleTitle,
        'invited_by': invitedBy,
        if (invitedByName != null) 'invited_by_name': invitedByName,
        'invited_user': invitedUser,
        if (message != null) 'message': message,
        'status': status,
        'created_at': createdAt.toIso8601String(),
      };

  factory CollaborationInvite.fromMap(Map<String, dynamic> map) => CollaborationInvite(
        id: map['id'] ?? '',
        collaborationId: getStringFromMap(map, 'collaboration_id', 'collaborationId') ?? '',
        collaborationTitle: getStringFromMap(map, 'collaboration_title', 'collaborationTitle'),
        roleId: getStringFromMap(map, 'role_id', 'roleId'),
        roleTitle: getStringFromMap(map, 'role_title', 'roleTitle'),
        invitedBy: getStringFromMap(map, 'invited_by', 'invitedBy') ?? '',
        invitedByName: getStringFromMap(map, 'invited_by_name', 'invitedByName'),
        invitedUser: getStringFromMap(map, 'invited_user', 'invitedUser') ?? '',
        message: getStringFromMap(map, 'message', 'message'),
        status: getStringFromMap(map, 'status', 'status') ?? 'pending',
        createdAt: _date(map, 'created_at', 'createdAt') ?? DateTime.now(),
      );
}

/// A portfolio item on a user's public profile.
class PortfolioItem {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final String? imageUrl;
  final String? projectUrl;
  final List<String> skills;
  final int sortOrder;
  final DateTime createdAt;

  PortfolioItem({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.imageUrl,
    this.projectUrl,
    this.skills = const [],
    this.sortOrder = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'title': title,
        if (description != null) 'description': description,
        if (imageUrl != null) 'image_url': imageUrl,
        if (projectUrl != null) 'project_url': projectUrl,
        'skills': skills,
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
      };

  factory PortfolioItem.fromMap(Map<String, dynamic> map) => PortfolioItem(
        id: map['id'] ?? '',
        userId: getStringFromMap(map, 'user_id', 'userId') ?? '',
        title: map['title'] ?? '',
        description: getStringFromMap(map, 'description', 'description'),
        imageUrl: getStringFromMap(map, 'image_url', 'imageUrl'),
        projectUrl: getStringFromMap(map, 'project_url', 'projectUrl'),
        skills: _stringList(map, 'skills', 'skills'),
        sortOrder: convertToInt(map['sort_order'] ?? map['sortOrder'], 0),
        createdAt: _date(map, 'created_at', 'createdAt') ?? DateTime.now(),
      );
}

/// Utility: percent skill overlap between a user's skills and required skills.
int skillMatchPercent(List<String> userSkills, List<String> requiredSkills) {
  if (requiredSkills.isEmpty) return 0;
  final lowerUser = userSkills.map((s) => s.toLowerCase().trim()).toSet();
  var matched = 0;
  for (final req in requiredSkills) {
    final r = req.toLowerCase().trim();
    if (lowerUser.any((u) => u.contains(r) || r.contains(u))) matched++;
  }
  return ((matched / requiredSkills.length) * 100).round();
}
