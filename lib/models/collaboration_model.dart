import 'package:cwc/utils/helpers/model_helpers.dart';

/// Collaboration Request Model
/// Represents a collaboration request posted by users
class CollaborationModel {
  final String id;
  final String userId; // User who created the request
  final String userName; // Cached name for quick access
  final String userEmail; // Cached email
  final String? userProfileImage; // Cached profile image
  final String title; // Project/Request title
  final String description; // Detailed description
  final List<String> requiredSkills; // Skills needed for collaboration
  final String collaborationType; // legacy: 'need_help' or 'offering_help'
  final String? projectType; // e.g., 'web_dev', 'mobile_app', 'design', etc.
  final String? budget; // Optional budget range
  final String? timeline; // Expected timeline
  final String status; // 'draft','recruiting','active','completed','cancelled'
  final List<String> responses; // List of user IDs who responded
  final String? acceptedUserId; // legacy single accepted user
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deadline; // Optional deadline

  // Collaboration Hub v2 fields
  final String projectMode; // 'team_project'
  final String? coverImageUrl;
  final String visibility; // 'public' | 'invite_only'
  final String? meetingLink;
  final String? inviteCode;
  final bool inviteLinkEnabled;
  final DateTime? launchedAt;

  CollaborationModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.userProfileImage,
    required this.title,
    required this.description,
    required this.requiredSkills,
    this.collaborationType = 'need_help',
    this.projectType,
    this.budget,
    this.timeline,
    this.status = 'recruiting',
    this.responses = const [],
    this.acceptedUserId,
    required this.createdAt,
    this.updatedAt,
    this.deadline,
    this.projectMode = 'team_project',
    this.coverImageUrl,
    this.visibility = 'public',
    this.meetingLink,
    this.inviteCode,
    this.inviteLinkEnabled = true,
    this.launchedAt,
  });

  /// Convert model to map for database storage
  Map<String, dynamic> toCollaborationMap() {
    final map = <String, dynamic>{
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'user_email': userEmail,
      'title': title,
      'description': description,
      'required_skills': requiredSkills,
      'collaboration_type': collaborationType,
      'status': status,
      'responses': responses,
      'created_at': createdAt.toIso8601String(),
    };

    map['project_mode'] = projectMode;
    map['visibility'] = visibility;
    map['invite_link_enabled'] = inviteLinkEnabled;

    if (userProfileImage != null) map['user_profile_image'] = userProfileImage;
    if (projectType != null) map['project_type'] = projectType;
    if (budget != null) map['budget'] = budget;
    if (timeline != null) map['timeline'] = timeline;
    if (acceptedUserId != null) map['accepted_user_id'] = acceptedUserId;
    if (updatedAt != null) map['updated_at'] = updatedAt!.toIso8601String();
    if (deadline != null) map['deadline'] = deadline!.toIso8601String();
    if (coverImageUrl != null) map['cover_image_url'] = coverImageUrl;
    if (meetingLink != null) map['meeting_link'] = meetingLink;
    if (inviteCode != null) map['invite_code'] = inviteCode;
    if (launchedAt != null) map['launched_at'] = launchedAt!.toIso8601String();

    return map;
  }

  /// Create model from database map
  factory CollaborationModel.fromCollaborationMap(Map<String, dynamic> map) {
    return CollaborationModel(
      id: map['id'] ?? '',
      userId: getStringFromMap(map, 'user_id', 'userId') ?? '',
      userName: getStringFromMap(map, 'user_name', 'userName') ?? '',
      userEmail: getStringFromMap(map, 'user_email', 'userEmail') ?? '',
      userProfileImage: getStringFromMap(map, 'user_profile_image', 'userProfileImage'),
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      requiredSkills: getListFromMap(map, 'required_skills', 'requiredSkills') != null
          ? List<String>.from(getListFromMap(map, 'required_skills', 'requiredSkills') ?? [])
          : [],
      collaborationType: getStringFromMap(map, 'collaboration_type', 'collaborationType') ?? 'need_help',
      projectType: getStringFromMap(map, 'project_type', 'projectType'),
      budget: getStringFromMap(map, 'budget', 'budget'),
      timeline: getStringFromMap(map, 'timeline', 'timeline'),
      status: getStringFromMap(map, 'status', 'status') ?? 'recruiting',
      responses: getListFromMap(map, 'responses', 'responses') != null
          ? List<String>.from(getListFromMap(map, 'responses', 'responses') ?? [])
          : [],
      acceptedUserId: getStringFromMap(map, 'accepted_user_id', 'acceptedUserId'),
      createdAt: getStringFromMap(map, 'created_at', 'createdAt') != null
          ? DateTime.parse(getStringFromMap(map, 'created_at', 'createdAt')!)
          : DateTime.now(),
      updatedAt: getStringFromMap(map, 'updated_at', 'updatedAt') != null
          ? DateTime.parse(getStringFromMap(map, 'updated_at', 'updatedAt')!)
          : null,
      deadline: getStringFromMap(map, 'deadline', 'deadline') != null
          ? DateTime.parse(getStringFromMap(map, 'deadline', 'deadline')!)
          : null,
      projectMode: getStringFromMap(map, 'project_mode', 'projectMode') ?? 'team_project',
      coverImageUrl: getStringFromMap(map, 'cover_image_url', 'coverImageUrl'),
      visibility: getStringFromMap(map, 'visibility', 'visibility') ?? 'public',
      meetingLink: getStringFromMap(map, 'meeting_link', 'meetingLink'),
      inviteCode: getStringFromMap(map, 'invite_code', 'inviteCode'),
      inviteLinkEnabled:
          (getValueFromMap(map, 'invite_link_enabled', 'inviteLinkEnabled', true) as bool?) ?? true,
      launchedAt: getStringFromMap(map, 'launched_at', 'launchedAt') != null
          ? DateTime.parse(getStringFromMap(map, 'launched_at', 'launchedAt')!)
          : null,
    );
  }

  /// Create a copy with updated fields
  CollaborationModel copyCollaboration({
    String? id,
    String? userId,
    String? userName,
    String? userEmail,
    String? userProfileImage,
    String? title,
    String? description,
    List<String>? requiredSkills,
    String? collaborationType,
    String? projectType,
    String? budget,
    String? timeline,
    String? status,
    List<String>? responses,
    String? acceptedUserId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deadline,
    String? projectMode,
    String? coverImageUrl,
    String? visibility,
    String? meetingLink,
    String? inviteCode,
    bool? inviteLinkEnabled,
    DateTime? launchedAt,
  }) {
    return CollaborationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userProfileImage: userProfileImage ?? this.userProfileImage,
      title: title ?? this.title,
      description: description ?? this.description,
      requiredSkills: requiredSkills ?? this.requiredSkills,
      collaborationType: collaborationType ?? this.collaborationType,
      projectType: projectType ?? this.projectType,
      budget: budget ?? this.budget,
      timeline: timeline ?? this.timeline,
      status: status ?? this.status,
      responses: responses ?? this.responses,
      acceptedUserId: acceptedUserId ?? this.acceptedUserId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deadline: deadline ?? this.deadline,
      projectMode: projectMode ?? this.projectMode,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      visibility: visibility ?? this.visibility,
      meetingLink: meetingLink ?? this.meetingLink,
      inviteCode: inviteCode ?? this.inviteCode,
      inviteLinkEnabled: inviteLinkEnabled ?? this.inviteLinkEnabled,
      launchedAt: launchedAt ?? this.launchedAt,
    );
  }

  /// Lifecycle helpers
  bool get isDraft => status == 'draft';
  bool get isRecruiting => status == 'recruiting';
  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  /// Back-compat: treat recruiting as "open"
  bool get isOpen => status == 'recruiting';

  String get inviteLink =>
      inviteCode == null ? '' : 'coworkconnect://project/join/$inviteCode';

  /// Check if user has already responded
  bool hasUserResponded(String userId) => responses.contains(userId);
}

/// Collaboration Response Model
/// Represents a user's response to a collaboration request
class CollaborationResponseModel {
  final String id;
  final String collaborationId;
  final String userId; // User who responded
  final String userName; // Cached name
  final String userEmail; // Cached email
  final String? userProfileImage; // Cached profile image
  final String message; // Response message
  final List<String>? userSkills; // Skills the user has
  final String status; // 'pending', 'accepted', 'rejected'
  final DateTime createdAt;
  final DateTime? updatedAt;

  CollaborationResponseModel({
    required this.id,
    required this.collaborationId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.userProfileImage,
    required this.message,
    this.userSkills,
    this.status = 'pending',
    required this.createdAt,
    this.updatedAt,
  });

  /// Convert to map for database
  Map<String, dynamic> toResponseMap() {
    final map = <String, dynamic>{
      'id': id,
      'collaboration_id': collaborationId,
      'user_id': userId,
      'user_name': userName,
      'user_email': userEmail,
      'message': message,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };

    if (userProfileImage != null) map['user_profile_image'] = userProfileImage;
    if (userSkills != null) map['user_skills'] = userSkills;
    if (updatedAt != null) map['updated_at'] = updatedAt!.toIso8601String();

    return map;
  }

  /// Create from database map
  factory CollaborationResponseModel.fromResponseMap(Map<String, dynamic> map) {
    return CollaborationResponseModel(
      id: map['id'] ?? '',
      collaborationId: getStringFromMap(map, 'collaboration_id', 'collaborationId') ?? '',
      userId: getStringFromMap(map, 'user_id', 'userId') ?? '',
      userName: getStringFromMap(map, 'user_name', 'userName') ?? '',
      userEmail: getStringFromMap(map, 'user_email', 'userEmail') ?? '',
      userProfileImage: getStringFromMap(map, 'user_profile_image', 'userProfileImage'),
      message: map['message'] ?? '',
      userSkills: getListFromMap(map, 'user_skills', 'userSkills') != null
          ? List<String>.from(getListFromMap(map, 'user_skills', 'userSkills') ?? [])
          : null,
      status: getStringFromMap(map, 'status', 'status') ?? 'pending',
      createdAt: getStringFromMap(map, 'created_at', 'createdAt') != null
          ? DateTime.parse(getStringFromMap(map, 'created_at', 'createdAt')!)
          : DateTime.now(),
      updatedAt: getStringFromMap(map, 'updated_at', 'updatedAt') != null
          ? DateTime.parse(getStringFromMap(map, 'updated_at', 'updatedAt')!)
          : null,
    );
  }
}
