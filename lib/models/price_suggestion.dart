import 'package:cwc/utils/constants/price_benchmarks.dart';

class PriceSuggestion {
  final double pricePerDayMin;
  final double pricePerDayMax;
  final double pricePerDaySuggested;
  final double pricePerHourMin;
  final double pricePerHourMax;
  final double pricePerHourSuggested;
  final String reason;
  final PriceConfidence confidence;
  final int sampleSize;
  final PriceSuggestionSource source;

  const PriceSuggestion({
    required this.pricePerDayMin,
    required this.pricePerDayMax,
    required this.pricePerDaySuggested,
    required this.pricePerHourMin,
    required this.pricePerHourMax,
    required this.pricePerHourSuggested,
    required this.reason,
    required this.confidence,
    required this.sampleSize,
    required this.source,
  });
}
