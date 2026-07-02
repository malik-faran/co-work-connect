import 'dart:convert';

import 'package:http/http.dart' as http;

class RouteDestination {
  final String id;
  final double latitude;
  final double longitude;

  const RouteDestination({
    required this.id,
    required this.latitude,
    required this.longitude,
  });
}

/// Driving distances via OSRM (open-source routing).
class RouteDistanceService {
  RouteDistanceService._();
  static final RouteDistanceService instance = RouteDistanceService._();

  static const _baseUrl = 'https://router.project-osrm.org';
  static const _chunkSize = 40;

  /// Returns workspace id → road distance in km from [userLat]/[userLng].
  Future<Map<String, double>> roadDistancesKm({
    required double userLat,
    required double userLng,
    required List<RouteDestination> destinations,
  }) async {
    final result = <String, double>{};
    if (destinations.isEmpty) return result;

    for (var i = 0; i < destinations.length; i += _chunkSize) {
      final end = (i + _chunkSize < destinations.length)
          ? i + _chunkSize
          : destinations.length;
      final chunk = destinations.sublist(i, end);
      try {
        final batch = await _fetchBatch(
          userLat: userLat,
          userLng: userLng,
          chunk: chunk,
        );
        result.addAll(batch);
      } catch (_) {
        // Skip failed chunk; caller may fall back to straight-line.
      }
    }
    return result;
  }

  Future<Map<String, double>> _fetchBatch({
    required double userLat,
    required double userLng,
    required List<RouteDestination> chunk,
  }) async {
    final coords = <String>['$userLng,$userLat'];
    for (final d in chunk) {
      coords.add('${d.longitude},${d.latitude}');
    }

    final destIndices = List.generate(chunk.length, (i) => i + 1).join(';');
    final uri = Uri.parse(
      '$_baseUrl/table/v1/driving/${coords.join(';')}'
      '?sources=0&destinations=$destIndices&annotations=distance',
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) return {};

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['code'] != 'Ok') return {};

    final matrix = data['distances'] as List<dynamic>?;
    if (matrix == null || matrix.isEmpty) return {};

    final row = matrix.first as List<dynamic>;
    final map = <String, double>{};

    for (var j = 0; j < chunk.length; j++) {
      final meters = row[j];
      if (meters is num && meters > 0) {
        map[chunk[j].id] = meters / 1000.0;
      }
    }
    return map;
  }
}
