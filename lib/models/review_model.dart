import 'package:cwc/utils/helpers/model_helpers.dart';

/// Review Model
/// Represents a review/rating for a workspace
class ReviewModel {
  final String id;
  final String bookingId; // Booking this review is for
  final String workspaceId;
  final String userId; // User who wrote the review
  final String userName; // Cached name
  final String? userProfileImage; // Cached profile image
  final double rating; // Rating from 1 to 5
  final String? comment; // Review comment/feedback
  final DateTime createdAt;
  final DateTime? updatedAt;

  ReviewModel({
    required this.id,
    required this.bookingId,
    required this.workspaceId,
    required this.userId,
    required this.userName,
    this.userProfileImage,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.updatedAt,
  });

  /// Convert to map for database
  Map<String, dynamic> toReviewMap() {
    final map = <String, dynamic>{
      'id': id,
      'booking_id': bookingId,
      'workspace_id': workspaceId,
      'user_id': userId,
      'user_name': userName,
      'rating': rating,
      'created_at': createdAt.toIso8601String(),
    };

    if (userProfileImage != null) map['user_profile_image'] = userProfileImage;
    if (comment != null) map['comment'] = comment;
    if (updatedAt != null) map['updated_at'] = updatedAt!.toIso8601String();

    return map;
  }

  /// Create from database map
  factory ReviewModel.fromReviewMap(Map<String, dynamic> map) {
    return ReviewModel(
      id: map['id'] ?? '',
      bookingId: getStringFromMap(map, 'booking_id', 'bookingId') ?? '',
      workspaceId: getStringFromMap(map, 'workspace_id', 'workspaceId') ?? '',
      userId: getStringFromMap(map, 'user_id', 'userId') ?? '',
      userName: getStringFromMap(map, 'user_name', 'userName') ?? '',
      userProfileImage: getStringFromMap(map, 'user_profile_image', 'userProfileImage'),
      rating: convertToDouble(map['rating'], 0.0),
      comment: getStringFromMap(map, 'comment', 'comment'),
      createdAt: getStringFromMap(map, 'created_at', 'createdAt') != null
          ? DateTime.parse(getStringFromMap(map, 'created_at', 'createdAt')!)
          : DateTime.now(),
      updatedAt: getStringFromMap(map, 'updated_at', 'updatedAt') != null
          ? DateTime.parse(getStringFromMap(map, 'updated_at', 'updatedAt')!)
          : null,
    );
  }

  ReviewModel copyReview({
    String? id,
    String? bookingId,
    String? workspaceId,
    String? userId,
    String? userName,
    String? userProfileImage,
    double? rating,
    String? comment,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReviewModel(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      workspaceId: workspaceId ?? this.workspaceId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userProfileImage: userProfileImage ?? this.userProfileImage,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
