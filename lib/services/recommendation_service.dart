import 'package:cwc/models/booking_model.dart';
import 'package:cwc/models/workspace_model.dart';
import 'package:cwc/models/workspace_recommendation.dart';
import 'package:cwc/services/booking_service.dart';
import 'package:cwc/services/workspace_interaction_service.dart';
import 'package:cwc/utils/constants/app_constants.dart';

class _UserTasteProfile {
  final Set<String> preferredCities;
  final Set<String> preferredTypes;
  final Set<String> preferredAmenities;
  final double avgPricePaid;
  final bool prefersAffordable;
  final bool prefersHourly;

  const _UserTasteProfile({
    required this.preferredCities,
    required this.preferredTypes,
    required this.preferredAmenities,
    required this.avgPricePaid,
    required this.prefersAffordable,
    required this.prefersHourly,
  });
}

class RecommendationService {
  final BookingService _bookingService = BookingService();
  final WorkspaceInteractionService _interactionService =
      WorkspaceInteractionService();

  Future<List<WorkspaceRecommendation>> getRecommendations({
    required String userId,
    required List<WorkspaceModel> workspaces,
    int limit = 6,
  }) async {
    final available =
        workspaces.where((w) => w.isAvailable).toList(growable: false);
    if (available.isEmpty) return [];

    final bookings = await _bookingService.getUserBookings(userId);
    final meaningful = bookings
        .where((b) =>
            b.status == AppConstants.bookingStatusConfirmed ||
            b.status == AppConstants.bookingStatusCompleted)
        .toList();

    final viewedIds =
        await _interactionService.getRecentlyViewedWorkspaceIds(userId);

    final scored = meaningful.isEmpty
        ? _scoreColdStart(available)
        : _scoreWarmStart(
            available,
            _buildTasteProfile(meaningful, available),
            viewedIds,
            meaningful,
          );

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).toList();
  }

  List<WorkspaceRecommendation> _scoreColdStart(List<WorkspaceModel> workspaces) {
    final maxPrice = workspaces
        .map((w) => w.pricePerDay)
        .reduce((a, b) => a > b ? a : b)
        .clamp(1.0, double.infinity);

    return workspaces.map((ws) {
      final rating = ((ws.rating ?? 3.5) / 5.0).clamp(0.0, 1.0);
      final reviewBoost =
          ((ws.totalReviews ?? 0) / 10.0).clamp(0.0, 1.0);
      final affordability = 1.0 - (ws.pricePerDay / maxPrice);

      final score =
          rating * 0.35 + affordability * 0.40 + reviewBoost * 0.25;

      String reason;
      if (affordability >= 0.7) {
        reason = 'Affordable';
      } else if (rating >= 0.8) {
        reason = 'Top rated';
      } else if ((ws.totalReviews ?? 0) >= 3) {
        reason = 'Popular';
      } else {
        reason = 'Great value';
      }

      return WorkspaceRecommendation(
        workspace: ws,
        score: score,
        reason: reason,
      );
    }).toList();
  }

  _UserTasteProfile _buildTasteProfile(
    List<BookingModel> bookings,
    List<WorkspaceModel> workspaces,
  ) {
    final byId = {for (final w in workspaces) w.id: w};

    final cities = <String, int>{};
    final types = <String, int>{};
    final amenities = <String, int>{};
    final prices = <double>[];
    var hourlyCount = 0;

    for (final b in bookings) {
      if (b.isHourlyBooking) hourlyCount++;
      if (b.categoryType != null && b.categoryType!.isNotEmpty) {
        types[b.categoryType!] = (types[b.categoryType!] ?? 0) + 1;
      }
      final ws = byId[b.workspaceId];
      if (ws != null) {
        cities[ws.city] = (cities[ws.city] ?? 0) + 1;
        types[ws.workspaceType] = (types[ws.workspaceType] ?? 0) + 1;
        prices.add(ws.pricePerDay);
        for (final a in ws.amenities) {
          amenities[a.toLowerCase()] = (amenities[a.toLowerCase()] ?? 0) + 1;
        }
      } else if (b.pricePerDay != null) {
        prices.add(b.pricePerDay!);
      }
    }

    final avgPrice = prices.isEmpty
        ? 0.0
        : prices.reduce((a, b) => a + b) / prices.length;

    final topAmenities = amenities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _UserTasteProfile(
      preferredCities: cities.entries
          .where((e) => e.value >= (bookings.length * 0.2).ceil())
          .map((e) => e.key)
          .toSet(),
      preferredTypes: types.entries
          .where((e) => e.value >= 2)
          .map((e) => e.key.toLowerCase())
          .toSet(),
      preferredAmenities: topAmenities.take(5).map((e) => e.key).toSet(),
      avgPricePaid: avgPrice,
      prefersAffordable: avgPrice > 0 &&
          avgPrice <=
              (prices.reduce((a, b) => a > b ? a : b) * 0.6 + avgPrice * 0.4),
      prefersHourly: hourlyCount > bookings.length / 2,
    );
  }

  List<WorkspaceRecommendation> _scoreWarmStart(
    List<WorkspaceModel> workspaces,
    _UserTasteProfile profile,
    Set<String> viewedIds,
    List<BookingModel> bookings,
  ) {
    final bookedIds = bookings.map((b) => b.workspaceId).toSet();
    final maxPrice = workspaces
        .map((w) => w.pricePerDay)
        .reduce((a, b) => a > b ? a : b)
        .clamp(1.0, double.infinity);

    return workspaces.map((ws) {
      final cityMatch = profile.preferredCities.isEmpty ||
              profile.preferredCities.contains(ws.city)
          ? 1.0
          : 0.35;

      final wsTypes = {
        ws.workspaceType.toLowerCase(),
        ...ws.categoryOptions.map((c) => c.type.toLowerCase()),
      };
      final typeMatch = profile.preferredTypes.isEmpty ||
              profile.preferredTypes.any(wsTypes.contains)
          ? 1.0
          : 0.4;

      double priceSimilarity = 0.5;
      if (profile.avgPricePaid > 0) {
        final diff = (ws.pricePerDay - profile.avgPricePaid).abs();
        priceSimilarity =
            (1.0 - diff / profile.avgPricePaid.clamp(500, maxPrice))
                .clamp(0.0, 1.0);
      }

      final wsAmenities =
          ws.amenities.map((a) => a.toLowerCase()).toSet();
      double amenityOverlap = 0.0;
      if (profile.preferredAmenities.isNotEmpty) {
        final overlap =
            profile.preferredAmenities.where(wsAmenities.contains).length;
        amenityOverlap = overlap / profile.preferredAmenities.length;
      }

      final rating = ((ws.rating ?? 3.5) / 5.0).clamp(0.0, 1.0);
      final affordability = profile.prefersAffordable
          ? (1.0 - ws.pricePerDay / maxPrice)
          : rating;

      var interactionBoost = 0.0;
      if (viewedIds.contains(ws.id) && !bookedIds.contains(ws.id)) {
        interactionBoost = 0.08;
      }
      if (bookedIds.contains(ws.id)) {
        interactionBoost = 0.05;
      }

      final hourlyFit = profile.prefersHourly && ws.pricePerHour > 0
          ? 0.1
          : (!profile.prefersHourly ? 0.05 : 0.0);

      final score = cityMatch * 0.22 +
          typeMatch * 0.18 +
          priceSimilarity * 0.20 +
          amenityOverlap * 0.12 +
          rating * 0.10 +
          affordability * 0.10 +
          hourlyFit +
          interactionBoost;

      final reason = _reasonFor(ws, profile, cityMatch, typeMatch,
          priceSimilarity, bookedIds.contains(ws.id));

      return WorkspaceRecommendation(
        workspace: ws,
        score: score,
        reason: reason,
      );
    }).toList();
  }

  String _reasonFor(
    WorkspaceModel ws,
    _UserTasteProfile profile,
    double cityMatch,
    double typeMatch,
    double priceSimilarity,
    bool bookedBefore,
  ) {
    if (bookedBefore) return 'Book again';
    if (cityMatch >= 0.99 && profile.preferredCities.isNotEmpty) {
      return 'In your area';
    }
    if (typeMatch >= 0.99 && profile.preferredTypes.isNotEmpty) {
      return 'Matches your style';
    }
    if (priceSimilarity >= 0.75) return 'In your budget';
    if (profile.prefersAffordable && ws.pricePerDay < profile.avgPricePaid) {
      return 'Affordable';
    }
    if ((ws.rating ?? 0) >= 4.0) return 'Highly rated';
    return 'For you';
  }
}
