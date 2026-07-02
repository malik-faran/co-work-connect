import 'package:cwc/models/price_suggestion.dart';
import 'package:cwc/services/supabase_service.dart';
import 'package:cwc/utils/constants/app_constants.dart';
import 'package:cwc/utils/constants/price_benchmarks.dart';

double _roundPrice(double value) =>
    double.parse(value.toStringAsFixed(0));

class PricePredictionService {
  final _supabase = SupabaseService.client;

  Future<PriceSuggestion> predict({
    required String city,
    required String workspaceType,
    required int capacity,
    required List<String> amenities,
    String? excludeWorkspaceId,
  }) async {
    final normalizedCity = PriceBenchmarks.normalizeCity(city);
    final marketRows = await _fetchMarketPrices(
      city: normalizedCity,
      workspaceType: workspaceType,
      excludeWorkspaceId: excludeWorkspaceId,
    );

    final dayPrices = marketRows
        .map((r) => r.dayPrice)
        .where((p) => p > 0)
        .toList(growable: false);
    final hourPrices = marketRows
        .map((r) => r.hourPrice)
        .where((p) => p > 0)
        .toList(growable: false);

    final benchmark = PriceBenchmarks.benchmarkFor(
      city: normalizedCity,
      workspaceType: workspaceType,
    );

    final sampleSize = dayPrices.length;
    late double baseDay;
    late double baseHour;
    late PriceSuggestionSource source;
    late PriceConfidence confidence;

    if (sampleSize >= 5) {
      baseDay = PriceBenchmarks.median(dayPrices);
      baseHour = hourPrices.isNotEmpty
          ? PriceBenchmarks.median(hourPrices)
          : baseDay / 8;
      source = PriceSuggestionSource.platformData;
      confidence = sampleSize >= 10 ? PriceConfidence.high : PriceConfidence.medium;
    } else if (sampleSize >= 1) {
      final dbDay = PriceBenchmarks.median(dayPrices);
      final dbHour = hourPrices.isNotEmpty
          ? PriceBenchmarks.median(hourPrices)
          : dbDay / 8;
      baseDay = dbDay * 0.5 + benchmark.pricePerDay * 0.5;
      baseHour = dbHour * 0.5 + benchmark.pricePerHour * 0.5;
      source = PriceSuggestionSource.blended;
      confidence = PriceConfidence.medium;
    } else if (PriceBenchmarks.cityOverrides.containsKey(normalizedCity)) {
      baseDay = benchmark.pricePerDay;
      baseHour = benchmark.pricePerHour;
      source = PriceSuggestionSource.cityOverride;
      confidence = PriceConfidence.low;
    } else {
      baseDay = benchmark.pricePerDay;
      baseHour = benchmark.pricePerHour;
      source = PriceSuggestionSource.tierBenchmark;
      confidence = PriceConfidence.low;
    }

    final capFactor = PriceBenchmarks.capacityFactor(workspaceType, capacity);
    final amenityFactor = PriceBenchmarks.amenityMultiplier(amenities);

    final suggestedDay = _roundPrice(baseDay * capFactor * amenityFactor);
    final suggestedHour = hourPrices.isNotEmpty && sampleSize >= 5
        ? _roundPrice(baseHour * capFactor * amenityFactor)
        : _roundPrice(suggestedDay / 8);

    final rangeFactor = confidence == PriceConfidence.high ? 0.12 : 0.18;
    final dayMin = _roundPrice(suggestedDay * (1 - rangeFactor));
    final dayMax = _roundPrice(suggestedDay * (1 + rangeFactor));
    final hourMin = _roundPrice(suggestedHour * (1 - rangeFactor));
    final hourMax = _roundPrice(suggestedHour * (1 + rangeFactor));

    final reason = _buildReason(
      city: normalizedCity,
      workspaceType: workspaceType,
      sampleSize: sampleSize,
      source: source,
      confidence: confidence,
      amenities: amenities,
      capacity: capacity,
    );

    return PriceSuggestion(
      pricePerDayMin: dayMin,
      pricePerDayMax: dayMax,
      pricePerDaySuggested: suggestedDay,
      pricePerHourMin: hourMin,
      pricePerHourMax: hourMax,
      pricePerHourSuggested: suggestedHour,
      reason: reason,
      confidence: confidence,
      sampleSize: sampleSize,
      source: source,
    );
  }

  Future<List<_MarketPriceRow>> _fetchMarketPrices({
    required String city,
    required String workspaceType,
    String? excludeWorkspaceId,
  }) async {
    try {
      var query = _supabase
          .from('workspaces')
          .select('id, price_per_day, price_per_hour, city')
          .eq('is_available', true)
          .eq('workspace_type', workspaceType)
          .gt('price_per_day', 0);

      if (excludeWorkspaceId != null) {
        query = query.neq('id', excludeWorkspaceId);
      }

      final rows = await query;
      final cityLower = city.toLowerCase();

      return rows
          .where((row) {
            final rowCity =
                (row['city'] as String? ?? '').toLowerCase().trim();
            return rowCity == cityLower ||
                rowCity.contains(cityLower) ||
                cityLower.contains(rowCity);
          })
          .map(
            (row) => _MarketPriceRow(
              dayPrice: _toDouble(row['price_per_day']),
              hourPrice: _toDouble(row['price_per_hour']),
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String _buildReason({
    required String city,
    required String workspaceType,
    required int sampleSize,
    required PriceSuggestionSource source,
    required PriceConfidence confidence,
    required List<String> amenities,
    required int capacity,
  }) {
    final typeLabel = _typeLabel(workspaceType);
    final tier = PriceBenchmarks.tierForCity(city);
    final tierLabel = PriceBenchmarks.tierLabel(tier);

    final buffer = StringBuffer();

    switch (source) {
      case PriceSuggestionSource.platformData:
        buffer.write(
          'From $sampleSize similar $typeLabel spaces in $city.',
        );
        break;
      case PriceSuggestionSource.blended:
        buffer.write(
          'From $sampleSize local listing${sampleSize == 1 ? '' : 's'} plus '
          'standard rates for $city.',
        );
        break;
      case PriceSuggestionSource.cityOverride:
        buffer.write(
          'From standard rates for $city (not many listings yet).',
        );
        break;
      case PriceSuggestionSource.tierBenchmark:
        buffer.write(
          'From $tierLabel city rates for $city (no local listings yet).',
        );
        break;
    }

    if (capacity > 0) {
      buffer.write(' Adjusted for capacity ($capacity).');
    }

    final premiumAmenities = amenities.where((a) {
      final boost = PriceBenchmarks.amenityBoosts[a.toLowerCase()] ?? 0;
      return boost > 0;
    }).toList();

    if (premiumAmenities.isNotEmpty) {
      buffer.write(' Includes ${premiumAmenities.join(', ')}.');
    }

    if (confidence == PriceConfidence.low) {
      buffer.write(' You can change this after you start getting bookings.');
    }

    return buffer.toString().trim();
  }

  String _typeLabel(String workspaceType) {
    switch (workspaceType) {
      case AppConstants.workspaceTypePrivate:
        return 'private office';
      case AppConstants.workspaceTypeMeetingRoom:
        return 'meeting room';
      case AppConstants.workspaceTypeShared:
      default:
        return 'shared desk';
    }
  }
}

class _MarketPriceRow {
  final double dayPrice;
  final double hourPrice;

  const _MarketPriceRow({
    required this.dayPrice,
    required this.hourPrice,
  });
}
