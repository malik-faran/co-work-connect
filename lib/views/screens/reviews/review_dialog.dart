import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/models/booking_model.dart';
import 'package:cwc/models/review_model.dart';
import 'package:cwc/services/review_service.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/utils/validators/form_validators.dart';
import 'package:uuid/uuid.dart';

/// Review Dialog
/// Allows users to submit reviews for completed bookings
class ReviewDialog extends StatefulWidget {
  final BookingModel booking;

  const ReviewDialog({
    super.key,
    required this.booking,
  });

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  final ReviewService _reviewService = ReviewService();
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  final _uuid = const Uuid();

  double _rating = 5.0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final authController = context.read<AuthController>();
      final currentUser = authController.currentUser;
      if (currentUser == null) return;

      final hasReviewed = await _reviewService.hasUserReviewedBooking(widget.booking.id);
      if (!mounted) return;
      if (hasReviewed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have already reviewed this booking'),
            backgroundColor: CAppTheme.errorColor,
          ),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      final review = ReviewModel(
        id: _uuid.v4(),
        bookingId: widget.booking.id,
        workspaceId: widget.booking.workspaceId,
        userId: currentUser.id,
        userName: currentUser.name,
        userProfileImage: currentUser.profileImageUrl,
        rating: _rating,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
        createdAt: DateTime.now(),
      );

      await _reviewService.createReview(review);

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Review submitted successfully!'),
          backgroundColor: CAppTheme.successColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: CAppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String get _ratingLabel {
    if (_rating == 1) return 'Poor';
    if (_rating == 2) return 'Fair';
    if (_rating == 3) return 'Good';
    if (_rating == 4) return 'Very Good';
    return 'Excellent';
  }

  bool get _requiresFeedback => _rating == 1 || _rating == 5;

  String get _feedbackLabel {
    if (_rating == 1) return 'Why did you give this rating? *';
    if (_rating == 5) return 'What did you like? *';
    return 'Your Feedback (Optional)';
  }

  String get _feedbackHint {
    if (_rating == 1) {
      return 'Please tell us what went wrong...';
    }
    if (_rating == 5) {
      return 'Tell us what made your experience excellent...';
    }
    return 'Share your experience...';
  }

  Color get _ratingColor {
    if (_rating <= 2) return CAppTheme.errorColor;
    if (_rating == 3) return CAppTheme.warningColor;
    return CAppTheme.successColor;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CAppTheme.radiusXL),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 500),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Write a Review',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: CAppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: CAppTheme.backgroundColor,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.close_rounded, size: 20, color: CAppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.booking.workspaceName,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: CAppTheme.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 24),

                // Rating section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: CAppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                  ),
                  child: Column(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final maxWidth = constraints.maxWidth - 40;
                          const starCount = 5;
                          const spacing = 4.0;
                          final starSize = ((maxWidth - (spacing * (starCount - 1) * 2)) / starCount).clamp(28.0, 40.0);
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(5, (index) {
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _rating = (index + 1).toDouble();
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Icon(
                                    index < _rating.floor()
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    color: CAppTheme.warningColor,
                                    size: starSize,
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: _ratingColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(CAppTheme.radiusXL),
                        ),
                        child: Text(
                          _ratingLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _ratingColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  _feedbackLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: CAppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _commentController,
                  validator: (value) => FormValidators.reviewComment(
                        value,
                        required: _requiresFeedback,
                      ),
                  decoration: InputDecoration(
                    hintText: _feedbackHint,
                    hintStyle: GoogleFonts.poppins(color: CAppTheme.textTertiary, fontSize: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                      borderSide: const BorderSide(color: CAppTheme.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                      borderSide: const BorderSide(color: CAppTheme.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                      borderSide: const BorderSide(color: CAppTheme.primaryColor, width: 2),
                    ),
                  ),
                  maxLines: 4,
                  maxLength: 500,
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitReview,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            'Submit Review',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
