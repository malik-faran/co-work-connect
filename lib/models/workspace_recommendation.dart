import 'package:cwc/models/workspace_model.dart';

class WorkspaceRecommendation {
  final WorkspaceModel workspace;
  final double score;
  final String reason;

  const WorkspaceRecommendation({
    required this.workspace,
    required this.score,
    required this.reason,
  });
}
