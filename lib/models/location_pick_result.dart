class LocationPickResult {
  final double latitude;
  final double longitude;
  final String address;
  final String? city;
  final String? placeName;

  const LocationPickResult({
    required this.latitude,
    required this.longitude,
    required this.address,
    this.city,
    this.placeName,
  });
}
