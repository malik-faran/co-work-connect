import 'dart:convert';
import 'package:cwc/utils/constants/app_constants.dart';
import 'package:http/http.dart' as http;

class GeocodingPlace {
  final String displayName;
  final String address;
  final String? city;
  final String? placeName;
  final double latitude;
  final double longitude;

  const GeocodingPlace({
    required this.displayName,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.city,
    this.placeName,
  });
}

class GeocodingService {
  GeocodingService._();
  static final GeocodingService instance = GeocodingService._();

  static const _baseUrl = 'https://nominatim.openstreetmap.org';
  static const _headers = {
    'User-Agent': 'CWC-CoworkConnect/1.0 (FYP mobile app)',
    'Accept-Language': 'en',
  };

  Future<List<GeocodingPlace>> search(String query, {String? city}) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return [];

    final searchQuery = city != null && city.isNotEmpty
        ? '$trimmed, $city, Pakistan'
        : '$trimmed, Pakistan';

    final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: {
      'q': searchQuery,
      'format': 'json',
      'limit': '8',
      'countrycodes': 'pk',
      'addressdetails': '1',
    });

    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) return [];

    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => _fromSearchJson(e as Map<String, dynamic>))
        .whereType<GeocodingPlace>()
        .toList();
  }

  Future<GeocodingPlace?> reverse(double latitude, double longitude) async {
    final uri = Uri.parse('$_baseUrl/reverse').replace(queryParameters: {
      'lat': latitude.toString(),
      'lon': longitude.toString(),
      'format': 'json',
      'addressdetails': '1',
    });

    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return _fromReverseJson(data);
  }

  GeocodingPlace? _fromSearchJson(Map<String, dynamic> json) {
    final lat = double.tryParse(json['lat']?.toString() ?? '');
    final lon = double.tryParse(json['lon']?.toString() ?? '');
    if (lat == null || lon == null) return null;

    final addressMap = json['address'] as Map<String, dynamic>?;
    final displayName = json['display_name']?.toString() ?? '';
    final city = _extractCity(addressMap);
    final placeName = _extractPlaceName(addressMap, json['name']?.toString());

    return GeocodingPlace(
      displayName: displayName,
      address: _buildAddress(addressMap, displayName),
      city: city,
      placeName: placeName,
      latitude: lat,
      longitude: lon,
    );
  }

  GeocodingPlace? _fromReverseJson(Map<String, dynamic> json) {
    final lat = double.tryParse(json['lat']?.toString() ?? '');
    final lon = double.tryParse(json['lon']?.toString() ?? '');
    if (lat == null || lon == null) return null;

    final addressMap = json['address'] as Map<String, dynamic>?;
    final displayName = json['display_name']?.toString() ?? '';
    final city = _extractCity(addressMap);
    final placeName = _extractPlaceName(addressMap, json['name']?.toString());

    return GeocodingPlace(
      displayName: displayName,
      address: _buildAddress(addressMap, displayName),
      city: city,
      placeName: placeName,
      latitude: lat,
      longitude: lon,
    );
  }

  String? _extractCity(Map<String, dynamic>? address) {
    if (address == null) return null;

    final candidates = [
      address['city'],
      address['town'],
      address['municipality'],
      address['county'],
      address['state_district'],
      address['suburb'],
    ];

    for (final c in candidates) {
      final value = c?.toString();
      if (value != null && AppConstants.cities.contains(value)) {
        return value;
      }
    }

    for (final c in candidates) {
      final value = c?.toString();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  String? _extractPlaceName(Map<String, dynamic>? address, String? name) {
    if (name != null && name.isNotEmpty) return name;
    if (address == null) return null;

    for (final key in ['amenity', 'building', 'shop', 'office', 'commercial', 'tourism']) {
      final v = address[key]?.toString();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  String _buildAddress(Map<String, dynamic>? address, String fallback) {
    if (address == null) return fallback;

    final parts = <String>[];
    for (final key in [
      'house_number',
      'road',
      'neighbourhood',
      'suburb',
      'city',
      'town',
      'state',
    ]) {
      final v = address[key]?.toString();
      if (v != null && v.isNotEmpty && !parts.contains(v)) {
        parts.add(v);
      }
    }

    if (parts.isEmpty) {
      final segments = fallback.split(',');
      return segments.take(3).join(', ').trim();
    }
    return parts.join(', ');
  }
}
