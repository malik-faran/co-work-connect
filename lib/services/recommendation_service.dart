import 'package:cwc/models/booking_model.dart';
import 'package:cwc/models/workspace_model.dart';
import 'package:cwc/models/workspace_recommendation.dart';
import 'package:cwc/services/booking_service.dart';
import 'package:cwc/services/route_distance_service.dart';
import 'package:cwc/services/workspace_interaction_service.dart';
import 'package:cwc/utils/constants/app_constants.dart';
import 'package:cwc/utils/helpers/geo_utils.dart';

class _UserTasteProfile {
  final Set<String> preferredCities;
  final Set<String> preferredTypes;
  final Set<String> preferredAmenities;
  final double avgPricePaid;
  final bool prefersAffordable;
  final bool prefersHourly;
  final double totalWeight;

  const _UserTasteProfile({
    required this.preferredCities,
    required this.preferredTypes,
    required this.preferredAmenities,
    required this.avgPricePaid,
    required this.prefersAffordable,
    required this.prefersHourly,
    required this.totalWeight,
  });
}

class RecommendationService {
  final BookingService _bookingService = BookingService();
  final WorkspaceInteractionService _interactionService =
      WorkspaceInteractionService();

  /// Only recommend workspaces within this radius of the user's GPS fix.
  static const double nearbyRadiusKm = 50.0;

  Future<List<WorkspaceRecommendation>> getRecommendations({
    required String userId,
    required List<WorkspaceModel> workspaces,
    int limit = 6,
    double? userLat,
    double? userLng,
  }) async {
    final available =
        workspaces.where((w) => w.isAvailable).toList(growable: false);
    if (available.isEmpty) return [];

    final hasUserLocation = userLat != null &&
        userLng != null &&
        isValidCoords(userLat, userLng);

    if (!hasUserLocation) return [];

    final bookings = await _bookingService.getUserBookings(userId);
    final meaningful = bookings
        .where((b) =>
            b.status == AppConstants.bookingStatusConfirmed ||
            b.status == AppConstants.bookingStatusCompleted)
        .toList();

    final viewedIds =
        await _interactionService.getRecentlyViewedWorkspaceIds(userId);
    final viewCounts = await _interactionService.getUserViewCounts(userId);

    final distances = await _resolveDistances(
      available,
      userLat: userLat,
      userLng: userLng,
    );

    final candidates = _filterNearby(available, distances);

    if (candidates.isEmpty) return [];

    final scored = meaningful.isEmpty
        ? _scoreColdStart(candidates, distances, true)
        : _scoreWarmStart(
            candidates,
            _buildTasteProfile(meaningful, available),
            viewedIds,
            viewCounts,
            meaningful,
            distances,
            true,
          );

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final aDist = a.distanceKm ?? double.infinity;
      final bDist = b.distanceKm ?? double.infinity;
      return aDist.compareTo(bDist);
    });
    return _applyDiversity(scored, limit);
  }

  List<WorkspaceModel> _filterNearby(
    List<WorkspaceModel> workspaces,
    Map<String, double> distances,
  ) {
    return workspaces.where((w) {
      if (!hasValidWorkspaceCoords(w.latitude, w.longitude)) return false;
      final km = distances[w.id];
      return km != null && km <= nearbyRadiusKm;
    }).toList(growable: false);
  }

  Future<Map<String, double>> _resolveDistances(
    List<WorkspaceModel> workspaces, {
    double? userLat,
    double? userLng,
  }) async {
    if (userLat == null ||
        userLng == null ||
        !isValidCoords(userLat, userLng)) {
      return {};
    }

    final withCoords = workspaces
        .where((w) => hasValidWorkspaceCoords(w.latitude, w.longitude))
        .toList();
    if (withCoords.isEmpty) return {};

    final destinations = withCoords
        .map(
          (w) => RouteDestination(
            id: w.id,
            latitude: w.latitude,
            longitude: w.longitude,
          ),
        )
        .toList();

    var distances = await RouteDistanceService.instance.roadDistancesKm(
      userLat: userLat,
      userLng: userLng,
      destinations: destinations,
    );

    for (final w in withCoords) {
      distances.putIfAbsent(
        w.id,
        () => distanceKm(userLat, userLng, w.latitude, w.longitude),
      );
    }
    return distances;
  }

  double _recencyWeight(DateTime createdAt) {
    final days = DateTime.now().difference(createdAt).inDays;
    if (days <= 30) return 2.0;
    if (days <= 90) return 1.5;
    if (days <= 180) return 1.0;
    return 0.5;
  }

  double _distanceScore(double? km, {required bool hasUserLocation}) {
    if (km == null) return hasUserLocation ? 0.0 : 0.5;
    if (km <= 5) return 1.0;
    if (km <= 15) return 0.85;
    if (km <= 30) return 0.65;
    if (km <= nearbyRadiusKm) return 0.45;
    return 0.0;
  }

  List<WorkspaceRecommendation> _applyDiversity(
    List<WorkspaceRecommendation> sorted,
    int limit,
  ) {
    final picked = <WorkspaceRecommendation>[];
    final cityCount = <String, int>{};
    const maxPerCity = 3;

    for (final rec in sorted) {
      if (picked.length >= limit) break;
      final city = rec.workspace.city;
      if ((cityCount[city] ?? 0) >= maxPerCity) continue;
      cityCount[city] = (cityCount[city] ?? 0) + 1;
      picked.add(rec);
    }

    if (picked.length < limit) {
      final pickedIds = picked.map((r) => r.workspace.id).toSet();
      for (final rec in sorted) {
        if (picked.length >= limit) break;
        if (!pickedIds.contains(rec.workspace.id)) {
          picked.add(rec);
        }
      }
    }
    return picked;
  }

  List<WorkspaceRecommendation> _scoreColdStart(
    List<WorkspaceModel> workspaces,
    Map<String, double> distances,
    bool hasUserLocation,
  ) {
    final maxPrice = workspaces
        .map((w) => w.pricePerDay)
        .reduce((a, b) => a > b ? a : b)
        .clamp(1.0, double.infinity);

    return workspaces.map((ws) {
      final rating = ((ws.rating ?? 3.5) / 5.0).clamp(0.0, 1.0);
      final reviewBoost = ((ws.totalReviews ?? 0) / 10.0).clamp(0.0, 1.0);
      final affordability = 1.0 - (ws.pricePerDay / maxPrice);
      final distKm = distances[ws.id];
      final distScore = _distanceScore(distKm, hasUserLocation: hasUserLocation);
      final verified = ws.workspaceApproved == true ? 0.06 : 0.0;

      final distanceWeight = hasUserLocation ? 0.40 : 0.15;
      final score = rating * 0.26 +
          affordability * 0.28 +
          reviewBoost * 0.16 +
          distScore * distanceWeight +
          verified +
          0.05;

      final reasons = <String>[];
      String reason;
      if (distKm != null && distScore >= 0.85) {
        reason = 'Near you';
        reasons.add(formatRoadDistanceKm(distKm));
      } else if (affordability >= 0.7) {
        reason = 'Affordable';
        reasons.add('Lower price than most workspaces');
      } else if (rating >= 0.8) {
        reason = 'Top rated';
        reasons.add('${(ws.rating ?? 0).toStringAsFixed(1)} star rating');
      } else if ((ws.totalReviews ?? 0) >= 3) {
        reason = 'Popular';
        reasons.add('${ws.totalReviews} reviews');
      } else {
        reason = 'Great value';
        reasons.add('Good balance of price and quality');
      }
      if (ws.workspaceApproved == true) {
        reasons.add('Verified by admin');
      }
      if (distKm != null && reason != 'Near you') {
        reasons.add(formatRoadDistanceKm(distKm));
      }

      return WorkspaceRecommendation(
        workspace: ws,
        score: score,
        reason: reason,
        reasons: reasons,
        distanceKm: distKm,
      );
    }).toList();
  }

  _UserTasteProfile _buildTasteProfile(
    List<BookingModel> bookings,
    List<WorkspaceModel> workspaces,
  ) {
    final byId = {for (final w in workspaces) w.id: w};

    final cities = <String, double>{};
    final types = <String, double>{};
    final amenities = <String, double>{};
    final prices = <double>[];
    var hourlyWeight = 0.0;
    var totalWeight = 0.0;

    for (final b in bookings) {
      final w = _recencyWeight(b.createdAt);
      totalWeight += w;
      if (b.isHourlyBooking) hourlyWeight += w;
      if (b.categoryType != null && b.categoryType!.isNotEmpty) {
        types[b.categoryType!] = (types[b.categoryType!] ?? 0) + w;
      }
      final ws = byId[b.workspaceId];
      if (ws != null) {
        cities[ws.city] = (cities[ws.city] ?? 0) + w;
        types[ws.workspaceType] = (types[ws.workspaceType] ?? 0) + w;
        prices.add(ws.pricePerDay);
        for (final a in ws.amenities) {
          amenities[a.toLowerCase()] = (amenities[a.toLowerCase()] ?? 0) + w;
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

    final threshold = (totalWeight * 0.2).clamp(1.0, double.infinity);

    return _UserTasteProfile(
      preferredCities: cities.entries
          .where((e) => e.value >= threshold)
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
      prefersHourly: totalWeight > 0 && hourlyWeight > totalWeight / 2,
      totalWeight: totalWeight,
    );
  }

  List<WorkspaceRecommendation> _scoreWarmStart(
    List<WorkspaceModel> workspaces,
    _UserTasteProfile profile,
    Set<String> viewedIds,
    Map<String, int> viewCounts,
    List<BookingModel> bookings,
    Map<String, double> distances,
    bool hasUserLocation,
  ) {
    final bookedIds = bookings.map((b) => b.workspaceId).toSet();
    final maxPrice = workspaces
        .map((w) => w.pricePerDay)
        .reduce((a, b) => a > b ? a : b)
        .clamp(1.0, double.infinity);

    return workspaces.map((ws) {
      final distKm = distances[ws.id];
      final distScore = _distanceScore(distKm, hasUserLocation: hasUserLocation);

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

      final wsAmenities = ws.amenities.map((a) => a.toLowerCase()).toSet();
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
      final views = viewCounts[ws.id] ?? 0;
      if (views >= 2 && !bookedIds.contains(ws.id)) {
        interactionBoost = 0.10;
      } else if (viewedIds.contains(ws.id) && !bookedIds.contains(ws.id)) {
        interactionBoost = 0.06;
      }
      if (bookedIds.contains(ws.id)) {
        interactionBoost = 0.05;
      }

      final hourlyFit = profile.prefersHourly && ws.pricePerHour > 0
          ? 0.08
          : (!profile.prefersHourly ? 0.04 : 0.0);

      final verified = ws.workspaceApproved == true ? 0.06 : 0.0;

      final distanceWeight = hasUserLocation ? 0.28 : 0.14;

      final score = cityMatch * 0.16 +
          typeMatch * 0.14 +
          priceSimilarity * 0.16 +
          amenityOverlap * 0.10 +
          rating * 0.08 +
          affordability * 0.08 +
          distScore * distanceWeight +
          hourlyFit +
          interactionBoost +
          verified;

      final reasonData = _buildReasons(
        ws,
        profile,
        cityMatch,
        typeMatch,
        priceSimilarity,
        amenityOverlap,
        bookedIds.contains(ws.id),
        distKm,
        views,
      );

      return WorkspaceRecommendation(
        workspace: ws,
        score: score,
        reason: reasonData.$1,
        reasons: reasonData.$2,
        distanceKm: distKm,
      );
    }).toList();
  }

  (String, List<String>) _buildReasons(
    WorkspaceModel ws,
    _UserTasteProfile profile,
    double cityMatch,
    double typeMatch,
    double priceSimilarity,
    double amenityOverlap,
    bool bookedBefore,
    double? distKm,
    int viewCount,
  ) {
    final reasons = <String>[];

    if (bookedBefore) {
      reasons.add('You booked here before');
    }
    if (distKm != null) {
      reasons.add(formatRoadDistanceKm(distKm));
    }
    if (cityMatch >= 0.99 && profile.preferredCities.isNotEmpty) {
      reasons.add('Same city as your recent bookings (${ws.city})');
    }
    if (typeMatch >= 0.99 && profile.preferredTypes.isNotEmpty) {
      reasons.add('Matches workspace types you often book');
    }
    if (priceSimilarity >= 0.75 && profile.avgPricePaid > 0) {
      reasons.add(
        'Near your usual budget (avg Rs. ${profile.avgPricePaid.round()}/day)',
      );
    }
    if (amenityOverlap >= 0.4 && profile.preferredAmenities.isNotEmpty) {
      final shared = profile.preferredAmenities
          .where((a) => ws.amenities.map((x) => x.toLowerCase()).contains(a))
          .take(3)
          .map((a) => a[0].toUpperCase() + a.substring(1))
          .join(', ');
      if (shared.isNotEmpty) {
        reasons.add('Has amenities you use: $shared');
      }
    }
    if (viewCount >= 2) {
      reasons.add('You viewed this workspace $viewCount times');
    }
    if (ws.workspaceApproved == true) {
      reasons.add('Verified by admin');
    }
    if ((ws.rating ?? 0) >= 4.0) {
      reasons.add('${(ws.rating ?? 0).toStringAsFixed(1)} star rating');
    }

    String primary;
    if (bookedBefore) {
      primary = 'Book again';
    } else if (distKm != null && _distanceScore(distKm, hasUserLocation: true) >= 0.85) {
      primary = 'Near you';
    } else if (cityMatch >= 0.99 && profile.preferredCities.isNotEmpty) {
      primary = 'In your area';
    } else if (typeMatch >= 0.99 && profile.preferredTypes.isNotEmpty) {
      primary = 'Matches your style';
    } else if (priceSimilarity >= 0.75) {
      primary = 'In your budget';
    } else if (profile.prefersAffordable &&
        ws.pricePerDay < profile.avgPricePaid) {
      primary = 'Affordable';
    } else if ((ws.rating ?? 0) >= 4.0) {
      primary = 'Highly rated';
    } else if (ws.workspaceApproved == true) {
      primary = 'Verified';
    } else {
      primary = 'For you';
    }

    if (reasons.isEmpty) {
      reasons.add('Picked based on your booking history and preferences');
    }

    return (primary, reasons);
  }
}
