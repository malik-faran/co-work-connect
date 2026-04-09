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
  final String collaborationType; // 'need_help' or 'offering_help'
  final String? projectType; // e.g., 'web_dev', 'mobile_app', 'design', etc.
  final String? budget; // Optional budget range
  final String? timeline; // Expected timeline
  final String status; // 'open', 'in_progress', 'completed', 'cancelled'
  final List<String> responses; // List of user IDs who responded
  final String? acceptedUserId; // User ID whose response was accepted
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deadline; // Optional deadline

  CollaborationModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.userProfileImage,
    required this.title,
    required this.description,
    required this.requiredSkills,
    required this.collaborationType,
    this.projectType,
    this.budget,
    this.timeline,
    this.status = 'open',
    this.responses = const [],
    this.acceptedUserId,
    required this.createdAt,
    this.updatedAt,
    this.deadline,
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

    if (userProfileImage != null) map['user_profile_image'] = userProfileImage;
    if (projectType != null) map['project_type'] = projectType;
    if (budget != null) map['budget'] = budget;
    if (timeline != null) map['timeline'] = timeline;
    if (acceptedUserId != null) map['accepted_user_id'] = acceptedUserId;
    if (updatedAt != null) map['updated_at'] = updatedAt!.toIso8601String();
    if (deadline != null) map['deadline'] = deadline!.toIso8601String();

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
      status: getStringFromMap(map, 'status', 'status') ?? 'open',
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
    );
  }

  /// Check if collaboration is still open
  bool get isOpen => status == 'open';
  
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
