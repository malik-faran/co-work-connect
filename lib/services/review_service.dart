import 'package:cwc/models/review_model.dart';
import 'package:cwc/services/supabase_service.dart';
/// Review Service
/// Handles all review-related database operations
class ReviewService {
  final _supabase = SupabaseService.client;

  /// Create a new review
  Future<String> createReview(ReviewModel review) async {
    try {
      final reviewData = review.toReviewMap();
      reviewData.removeWhere((key, value) => value == null);

      await _supabase
          .from('reviews')
          .insert(reviewData);

      await _updateWorkspaceRating(review.workspaceId);

      return review.id;
    } catch (e) {
      throw Exception('Failed to create review: ${e.toString()}');
    }
  }

  /// Update workspace rating based on all reviews
  Future<void> _updateWorkspaceRating(String workspaceId) async {
    try {
      final reviews = await getWorkspaceReviews(workspaceId);
      
      if (reviews.isEmpty) return;

      final totalRating = reviews.fold<double>(0.0, (sum, review) => sum + review.rating);
      final averageRating = totalRating / reviews.length;

      await _supabase
          .from('workspaces')
          .update({
            'rating': averageRating,
            'total_reviews': reviews.length,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', workspaceId);
    } catch (e) {
      // Ignore errors in rating update
    }
  }

  /// Get all reviews for a workspace
  Future<List<ReviewModel>> getWorkspaceReviews(String workspaceId) async {
    try {
      final rows = await _supabase
          .from('reviews')
          .select()
          .eq('workspace_id', workspaceId)
          .order('created_at', ascending: false);

      return rows.map((r) => ReviewModel.fromReviewMap(r)).toList();
    } catch (e) {
      throw Exception('Failed to fetch reviews: ${e.toString()}');
    }
  }

  /// Get review by booking ID
  Future<ReviewModel?> getReviewByBookingId(String bookingId) async {
    try {
      final result = await _supabase
          .from('reviews')
          .select()
          .eq('booking_id', bookingId)
          .maybeSingle();

      if (result == null) return null;
      return ReviewModel.fromReviewMap(result);
    } catch (e) {
      throw Exception('Failed to fetch review: ${e.toString()}');
    }
  }

  /// Check if user has already reviewed a booking
  Future<bool> hasUserReviewedBooking(String bookingId) async {
    try {
      final review = await getReviewByBookingId(bookingId);
      return review != null;
    } catch (e) {
      return false;
    }
  }

  /// Update a review
  Future<void> updateReview(ReviewModel review) async {
    try {
      final updateData = review
          .copyReview(updatedAt: DateTime.now())
          .toReviewMap();
      updateData.removeWhere((key, value) => value == null);

      await _supabase
          .from('reviews')
          .update(updateData)
          .eq('id', review.id);

      // Update workspace rating
      await _updateWorkspaceRating(review.workspaceId);
    } catch (e) {
      throw Exception('Failed to update review: ${e.toString()}');
    }
  }

  /// Delete a review
  Future<void> deleteReview(String reviewId, String workspaceId) async {
    try {
      await _supabase
          .from('reviews')
          .delete()
          .eq('id', reviewId);

      // Update workspace rating
      await _updateWorkspaceRating(workspaceId);
    } catch (e) {
      throw Exception('Failed to delete review: ${e.toString()}');
    }
  }

  /// Get stream of reviews for real-time updates
  Stream<List<ReviewModel>> getWorkspaceReviewsStream(String workspaceId) {
    return _supabase
        .from('reviews')
        .stream(primaryKey: ['id'])
        .eq('workspace_id', workspaceId)
        .order('created_at', ascending: false)
        .map((data) => data.map((r) => ReviewModel.fromReviewMap(r)).toList());
  }
}
