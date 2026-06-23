import 'package:cwc/utils/constants/app_constants.dart';

/// Min/max limits used by form validators across the app.
class ValidationLimits {
  ValidationLimits._();

  // Person names
  static const int nameMin = 3;
  static const int nameMax = 60;

  // Business / workspace names
  static const int businessNameMin = 2;
  static const int businessNameMax = 100;
  static const int workspaceNameMin = 3;
  static const int workspaceNameMax = 100;

  // Text lengths
  static const int descriptionMin = 20;
  static const int descriptionMax = 2000;
  static const int addressMin = 10;
  static const int addressMax = 300;

  // Collaboration
  static const int collabTitleMin = 5;
  static const int collabTitleMax = 120;
  static const int collabDescriptionMin = 30;
  static const int collabDescriptionMax = 2000;
  static const int collabResponseMin = 20;
  static const int collabResponseMax = 2000;
  static const int collabOptionalTextMax = 80;

  // Review
  static const int reviewCommentMin = 10;
  static const int reviewCommentMax = 500;

  // Chat
  static const int chatMessageMin = 1;
  static const int chatMessageMax = 2000;
}

/// Category-specific workspace capacity and pricing bounds (PKR).
class WorkspaceCategoryLimits {
  final int officesMin;
  final int officesMax;
  final int desksMin;
  final int desksMax;
  final double pricePerDayMin;
  final double pricePerDayMax;
  final double pricePerHourMin;
  final double pricePerHourMax;

  const WorkspaceCategoryLimits({
    required this.officesMin,
    required this.officesMax,
    required this.desksMin,
    required this.desksMax,
    required this.pricePerDayMin,
    required this.pricePerDayMax,
    required this.pricePerHourMin,
    required this.pricePerHourMax,
  });

  static WorkspaceCategoryLimits forType(String type) {
    switch (type) {
      case AppConstants.workspaceTypePrivate:
        return const WorkspaceCategoryLimits(
          officesMin: 1,
          officesMax: 20,
          desksMin: 1,
          desksMax: 1,
          pricePerDayMin: 500,
          pricePerDayMax: 500000,
          pricePerHourMin: 100,
          pricePerHourMax: 50000,
        );
      case AppConstants.workspaceTypeShared:
        return const WorkspaceCategoryLimits(
          officesMin: 1,
          officesMax: 30,
          desksMin: 2,
          desksMax: 50,
          pricePerDayMin: 200,
          pricePerDayMax: 50000,
          pricePerHourMin: 50,
          pricePerHourMax: 5000,
        );
      case AppConstants.workspaceTypeMeetingRoom:
        return const WorkspaceCategoryLimits(
          officesMin: 1,
          officesMax: 15,
          desksMin: 2,
          desksMax: 100,
          pricePerDayMin: 1000,
          pricePerDayMax: 200000,
          pricePerHourMin: 200,
          pricePerHourMax: 25000,
        );
      default:
        return const WorkspaceCategoryLimits(
          officesMin: 1,
          officesMax: 50,
          desksMin: 1,
          desksMax: 100,
          pricePerDayMin: 100,
          pricePerDayMax: 500000,
          pricePerHourMin: 50,
          pricePerHourMax: 50000,
        );
    }
  }
}
