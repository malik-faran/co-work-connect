import 'package:cwc/utils/constants/app_constants.dart';
import 'package:latlong2/latlong.dart';

const _distance = Distance();

const Map<String, LatLng> kCityMapCenters = {
  'Islamabad': LatLng(33.6844, 73.0479),
  'Lahore': LatLng(31.5204, 74.3587),
  'Karachi': LatLng(24.8607, 67.0011),
  'Rawalpindi': LatLng(33.5651, 73.0169),
  'Faisalabad': LatLng(31.4504, 73.1350),
  'Peshawar': LatLng(34.0151, 71.5249),
  'Abbottabad': LatLng(34.1688, 73.2215),
};

bool isValidCoords(double lat, double lng) {
  if (!lat.isFinite || !lng.isFinite) return false;
  if (lat == 0 && lng == 0) return false;
  if (lat.abs() > 90 || lng.abs() > 180) return false;
  return true;
}

bool hasValidWorkspaceCoords(double lat, double lng) => isValidCoords(lat, lng);

LatLng defaultCenterForCity(String? city) {
  if (city != null && kCityMapCenters.containsKey(city)) {
    return kCityMapCenters[city]!;
  }
  return kCityMapCenters[AppConstants.cities.first]!;
}

/// Nearest supported service city for a map pin.
String nearestCity(double lat, double lng) {
  var best = AppConstants.cities.first;
  var bestKm = double.infinity;
  for (final city in AppConstants.cities) {
    final center = kCityMapCenters[city];
    if (center == null) continue;
    final km = distanceKm(lat, lng, center.latitude, center.longitude);
    if (km < bestKm) {
      bestKm = km;
      best = city;
    }
  }
  return best;
}

/// City label saved on the workspace — prefers reverse-geocoded locality.
String resolveCityFromMap({
  required double lat,
  required double lng,
  String? geocodedCity,
}) {
  final trimmed = geocodedCity?.trim();
  if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  return nearestCity(lat, lng);
}

/// Nearest supported city for pricing when [city] is outside the preset list.
String serviceCityForPricing(String? city, double lat, double lng) {
  if (city != null && AppConstants.cities.contains(city)) return city;
  return nearestCity(lat, lng);
}

/// Normalize geocoded city to one of the supported service cities.
String resolveSupportedCity({
  required double lat,
  required double lng,
  String? geocodedCity,
}) {
  if (geocodedCity != null && AppConstants.cities.contains(geocodedCity)) {
    return geocodedCity;
  }
  return nearestCity(lat, lng);
}

/// Distance in kilometers between two coordinates.
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  return _distance.as(
    LengthUnit.Kilometer,
    LatLng(lat1, lng1),
    LatLng(lat2, lng2),
  );
}

/// Human-readable distance label (meters under 1 km, otherwise km).
String formatDistanceKm(double km) {
  if (km < 1) {
    return '${(km * 1000).round()} m away';
  }
  if (km < 10) {
    return '${km.toStringAsFixed(1)} km away';
  }
  return '${km.round()} km away';
}

/// Driving / route distance (from OSRM).
String formatRoadDistanceKm(double km) {
  if (km < 1) {
    return '${(km * 1000).round()} m by road';
  }
  if (km < 10) {
    return '${km.toStringAsFixed(1)} km by road';
  }
  return '${km.round()} km by road';
}
