import 'package:cwc/utils/helpers/model_helpers.dart';

class UserModel {
  final String id;
  final String email;
  final String name;
  final String phone;
  final String role;
  final String? profileImageUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? city;
  final String? profession;
  final bool? collaborationEnabled;
  final List<String>? skills;
  final List<String>? collaborationRequests;
  final String? businessName;
  final String? businessAddress;
  final bool? ownerApproved;
  final String? cnicImageUrl; // CNIC image URL
  final bool? adminApproved; // Admin approval status
  final String? bio; // Short intro for collaboration profile
  final String? collaborationHeadline; // e.g. "Flutter dev open for FYP teams"
  final String? availability; // e.g. "10 hrs/week"
  final List<String>? preferredProjectTypes;
  final String? resumeUrl;
  final String? resumeFileName;
  final String? experience;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.phone,
    required this.role,
    this.profileImageUrl,
    required this.createdAt,
    this.updatedAt,
    this.city,
    this.profession,
    this.collaborationEnabled,
    this.skills,
    this.collaborationRequests,
    this.businessName,
    this.businessAddress,
    this.ownerApproved,
    this.cnicImageUrl,
    this.adminApproved,
    this.bio,
    this.collaborationHeadline,
    this.availability,
    this.preferredProjectTypes,
    this.resumeUrl,
    this.resumeFileName,
    this.experience,
  });

  Map<String, dynamic> toUserMap() {
    final map = <String, dynamic>{
      'id': id,
      'email': email,
      'name': name,
      'phone': phone,
      'role': role,
      'created_at': createdAt.toIso8601String(),
    };
    
    if (profileImageUrl != null) map['profile_image_url'] = profileImageUrl;
    if (updatedAt != null) map['updated_at'] = updatedAt!.toIso8601String();
    if (city != null) map['city'] = city;
    if (profession != null) map['profession'] = profession;
    if (collaborationEnabled != null) map['collaboration_enabled'] = collaborationEnabled;
    if (skills != null) map['skills'] = skills;
    if (collaborationRequests != null) map['collaboration_requests'] = collaborationRequests;
    if (businessName != null) map['business_name'] = businessName;
    if (businessAddress != null) map['business_address'] = businessAddress;
    if (ownerApproved != null) map['owner_approved'] = ownerApproved;
    if (cnicImageUrl != null) map['cnic_image_url'] = cnicImageUrl;
    if (adminApproved != null) map['admin_approved'] = adminApproved;
    if (bio != null) map['bio'] = bio;
    if (collaborationHeadline != null) map['collaboration_headline'] = collaborationHeadline;
    if (availability != null) map['availability'] = availability;
    if (preferredProjectTypes != null) map['preferred_project_types'] = preferredProjectTypes;
    if (resumeUrl != null) map['resume_url'] = resumeUrl;
    if (resumeFileName != null) map['resume_file_name'] = resumeFileName;
    if (experience != null) map['experience'] = experience;

    return map;
  }

  factory UserModel.fromUserMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      role: map['role'] ?? 'user',
      profileImageUrl: getStringFromMap(map, 'profile_image_url', 'profileImageUrl'),
      createdAt: getStringFromMap(map, 'created_at', 'createdAt') != null 
          ? DateTime.parse(getStringFromMap(map, 'created_at', 'createdAt')!) 
          : DateTime.now(),
      updatedAt: getStringFromMap(map, 'updated_at', 'updatedAt') != null 
          ? DateTime.parse(getStringFromMap(map, 'updated_at', 'updatedAt')!) 
          : null,
      city: map['city'],
      profession: map['profession'],
      collaborationEnabled: getNullableValueFromMap<bool>(map, 'collaboration_enabled', 'collaborationEnabled'),
      skills: getListFromMap(map, 'skills', 'skills') != null 
          ? List<String>.from(getListFromMap(map, 'skills', 'skills') ?? []) 
          : null,
      collaborationRequests: getListFromMap(map, 'collaboration_requests', 'collaborationRequests') != null 
          ? List<String>.from(getListFromMap(map, 'collaboration_requests', 'collaborationRequests') ?? []) 
          : null,
      businessName: getStringFromMap(map, 'business_name', 'businessName'),
      businessAddress: getStringFromMap(map, 'business_address', 'businessAddress'),
      ownerApproved: getNullableValueFromMap<bool>(map, 'owner_approved', 'ownerApproved'),
      cnicImageUrl: getStringFromMap(map, 'cnic_image_url', 'cnicImageUrl'),
      adminApproved: getNullableValueFromMap<bool>(map, 'admin_approved', 'adminApproved'),
      bio: getStringFromMap(map, 'bio', 'bio'),
      collaborationHeadline: getStringFromMap(map, 'collaboration_headline', 'collaborationHeadline'),
      availability: getStringFromMap(map, 'availability', 'availability'),
      preferredProjectTypes: getListFromMap(map, 'preferred_project_types', 'preferredProjectTypes') != null
          ? List<String>.from(getListFromMap(map, 'preferred_project_types', 'preferredProjectTypes') ?? [])
          : null,
      resumeUrl: getStringFromMap(map, 'resume_url', 'resumeUrl'),
      resumeFileName: getStringFromMap(map, 'resume_file_name', 'resumeFileName'),
      experience: getStringFromMap(map, 'experience', 'experience'),
    );
  }

  UserModel copyUser({
    String? id,
    String? email,
    String? name,
    String? phone,
    String? role,
    String? profileImageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? city,
    String? profession,
    bool? collaborationEnabled,
    List<String>? skills,
    List<String>? collaborationRequests,
    String? businessName,
    String? businessAddress,
    bool? ownerApproved,
    String? cnicImageUrl,
    bool? adminApproved,
    String? bio,
    String? collaborationHeadline,
    String? availability,
    List<String>? preferredProjectTypes,
    String? resumeUrl,
    String? resumeFileName,
    String? experience,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      city: city ?? this.city,
      profession: profession ?? this.profession,
      collaborationEnabled: collaborationEnabled ?? this.collaborationEnabled,
      skills: skills ?? this.skills,
      collaborationRequests: collaborationRequests ?? this.collaborationRequests,
      businessName: businessName ?? this.businessName,
      businessAddress: businessAddress ?? this.businessAddress,
      ownerApproved: ownerApproved ?? this.ownerApproved,
      cnicImageUrl: cnicImageUrl ?? this.cnicImageUrl,
      adminApproved: adminApproved ?? this.adminApproved,
      bio: bio ?? this.bio,
      collaborationHeadline: collaborationHeadline ?? this.collaborationHeadline,
      availability: availability ?? this.availability,
      preferredProjectTypes: preferredProjectTypes ?? this.preferredProjectTypes,
      resumeUrl: resumeUrl ?? this.resumeUrl,
      resumeFileName: resumeFileName ?? this.resumeFileName,
      experience: experience ?? this.experience,
    );
  }
}
