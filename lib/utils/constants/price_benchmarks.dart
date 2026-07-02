import 'package:cwc/utils/constants/app_constants.dart';

/// City economic tier for cold-start pricing when platform data is sparse.
enum CityTier { metro, tier2, tier3 }

/// How the suggested price was derived.
enum PriceSuggestionSource {
  platformData,
  blended,
  cityOverride,
  tierBenchmark,
}

/// Confidence level shown to the owner.
enum PriceConfidence { high, medium, low }

class PriceTierRates {
  final double pricePerDay;
  final double pricePerHour;

  const PriceTierRates({
    required this.pricePerDay,
    required this.pricePerHour,
  });
}

/// Pakistan coworking market benchmarks for cold-start price prediction.
class PriceBenchmarks {
  PriceBenchmarks._();

  static const metroCities = {'Lahore', 'Karachi', 'Islamabad'};

  static const tier2Cities = {
    'Rawalpindi',
    'Faisalabad',
    'Peshawar',
    'Multan',
    'Gujranwala',
    'Sialkot',
    'Hyderabad',
    'Quetta',
    'Sargodha',
    'Bahawalpur',
  };

  /// Fine-tuned overrides for cities in the app dropdown.
  static const Map<String, Map<String, PriceTierRates>> cityOverrides = {
    'Lahore': {
      AppConstants.workspaceTypeShared: PriceTierRates(pricePerDay: 800, pricePerHour: 100),
      AppConstants.workspaceTypePrivate: PriceTierRates(pricePerDay: 3500, pricePerHour: 450),
      AppConstants.workspaceTypeMeetingRoom: PriceTierRates(pricePerDay: 4000, pricePerHour: 600),
    },
    'Karachi': {
      AppConstants.workspaceTypeShared: PriceTierRates(pricePerDay: 900, pricePerHour: 110),
      AppConstants.workspaceTypePrivate: PriceTierRates(pricePerDay: 4000, pricePerHour: 500),
      AppConstants.workspaceTypeMeetingRoom: PriceTierRates(pricePerDay: 4500, pricePerHour: 650),
    },
    'Islamabad': {
      AppConstants.workspaceTypeShared: PriceTierRates(pricePerDay: 1000, pricePerHour: 125),
      AppConstants.workspaceTypePrivate: PriceTierRates(pricePerDay: 5000, pricePerHour: 600),
      AppConstants.workspaceTypeMeetingRoom: PriceTierRates(pricePerDay: 5500, pricePerHour: 750),
    },
    'Rawalpindi': {
      AppConstants.workspaceTypeShared: PriceTierRates(pricePerDay: 750, pricePerHour: 95),
      AppConstants.workspaceTypePrivate: PriceTierRates(pricePerDay: 3000, pricePerHour: 400),
      AppConstants.workspaceTypeMeetingRoom: PriceTierRates(pricePerDay: 3500, pricePerHour: 550),
    },
    'Faisalabad': {
      AppConstants.workspaceTypeShared: PriceTierRates(pricePerDay: 500, pricePerHour: 70),
      AppConstants.workspaceTypePrivate: PriceTierRates(pricePerDay: 2000, pricePerHour: 280),
      AppConstants.workspaceTypeMeetingRoom: PriceTierRates(pricePerDay: 2500, pricePerHour: 400),
    },
    'Peshawar': {
      AppConstants.workspaceTypeShared: PriceTierRates(pricePerDay: 550, pricePerHour: 75),
      AppConstants.workspaceTypePrivate: PriceTierRates(pricePerDay: 2200, pricePerHour: 300),
      AppConstants.workspaceTypeMeetingRoom: PriceTierRates(pricePerDay: 2800, pricePerHour: 450),
    },
  };

  static const Map<CityTier, Map<String, PriceTierRates>> tierRates = {
    CityTier.metro: {
      AppConstants.workspaceTypeShared: PriceTierRates(pricePerDay: 900, pricePerHour: 110),
      AppConstants.workspaceTypePrivate: PriceTierRates(pricePerDay: 4500, pricePerHour: 550),
      AppConstants.workspaceTypeMeetingRoom: PriceTierRates(pricePerDay: 5000, pricePerHour: 650),
    },
    CityTier.tier2: {
      AppConstants.workspaceTypeShared: PriceTierRates(pricePerDay: 550, pricePerHour: 75),
      AppConstants.workspaceTypePrivate: PriceTierRates(pricePerDay: 2500, pricePerHour: 350),
      AppConstants.workspaceTypeMeetingRoom: PriceTierRates(pricePerDay: 3000, pricePerHour: 450),
    },
    CityTier.tier3: {
      AppConstants.workspaceTypeShared: PriceTierRates(pricePerDay: 350, pricePerHour: 50),
      AppConstants.workspaceTypePrivate: PriceTierRates(pricePerDay: 1500, pricePerHour: 200),
      AppConstants.workspaceTypeMeetingRoom: PriceTierRates(pricePerDay: 2000, pricePerHour: 300),
    },
  };

  static const Map<String, double> amenityBoosts = {
    'wifi': 0.0,
    'air conditioning': 0.08,
    'parking': 0.10,
    'security': 0.05,
    'kitchen': 0.05,
    'coffee': 0.03,
    'tea': 0.02,
    'restroom': 0.0,
  };

  static String normalizeCity(String city) {
    var normalized = city.trim();
    if (normalized.isEmpty) return normalized;

    normalized = normalized.split(',').first.trim();
    normalized = normalized
        .replaceAll(RegExp(r'\bdistrict\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bcity\b', caseSensitive: false), '')
        .trim();

    for (final known in {...metroCities, ...tier2Cities, ...cityOverrides.keys}) {
      if (normalized.toLowerCase() == known.toLowerCase()) {
        return known;
      }
    }

    for (final known in {...metroCities, ...tier2Cities, ...cityOverrides.keys}) {
      if (normalized.toLowerCase().contains(known.toLowerCase())) {
        return known;
      }
    }

    return normalized.isEmpty ? city.trim() : normalized;
  }

  static CityTier tierForCity(String city) {
    final normalized = normalizeCity(city);
    if (metroCities.contains(normalized)) return CityTier.metro;
    if (tier2Cities.contains(normalized)) return CityTier.tier2;
    if (cityOverrides.containsKey(normalized)) {
      return metroCities.contains(normalized)
          ? CityTier.metro
          : CityTier.tier2;
    }
    return CityTier.tier3;
  }

  static PriceTierRates benchmarkFor({
    required String city,
    required String workspaceType,
  }) {
    final normalized = normalizeCity(city);
    final override = cityOverrides[normalized]?[workspaceType];
    if (override != null) return override;

    final tier = tierForCity(normalized);
    return tierRates[tier]![workspaceType] ??
        tierRates[CityTier.tier3]![AppConstants.workspaceTypeShared]!;
  }

  static double capacityFactor(String workspaceType, int capacity) {
    if (capacity <= 0) return 1.0;

    switch (workspaceType) {
      case AppConstants.workspaceTypePrivate:
        if (capacity <= 1) return 1.0;
        if (capacity <= 3) return 1.05;
        if (capacity <= 8) return 1.10;
        return 1.15;
      case AppConstants.workspaceTypeMeetingRoom:
        if (capacity <= 5) return 0.95;
        if (capacity <= 15) return 1.0;
        if (capacity <= 30) return 1.08;
        return 1.15;
      case AppConstants.workspaceTypeShared:
      default:
        if (capacity <= 5) return 0.90;
        if (capacity <= 15) return 1.0;
        if (capacity <= 30) return 1.10;
        return 1.20;
    }
  }

  static double amenityMultiplier(List<String> amenities) {
    var boost = 0.0;
    for (final amenity in amenities) {
      boost += amenityBoosts[amenity.toLowerCase()] ?? 0.0;
    }
    return 1.0 + boost.clamp(0.0, 0.35);
  }

  static double median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = List<double>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }

  static String tierLabel(CityTier tier) {
    switch (tier) {
      case CityTier.metro:
        return 'major city';
      case CityTier.tier2:
        return 'regional city';
      case CityTier.tier3:
        return 'smaller city';
    }
  }
}
