import 'package:cwc/models/workspace_model.dart';

class WorkspaceRecommendation {
  final WorkspaceModel workspace;
  final double score;
  /// Short label for the card badge.
  final String reason;
  /// Detailed bullets for the "Why recommended?" sheet.
  final List<String> reasons;
  /// Road or straight-line distance from user, when location is available.
  final double? distanceKm;

  const WorkspaceRecommendation({
    required this.workspace,
    required this.score,
    required this.reason,
    this.reasons = const [],
    this.distanceKm,
  });
}
