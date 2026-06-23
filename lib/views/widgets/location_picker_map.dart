import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:cwc/models/location_pick_result.dart';
import 'package:cwc/services/geocoding_service.dart';
import 'package:cwc/utils/constants/app_constants.dart';
import 'package:cwc/utils/themes/theme.dart';

const Map<String, LatLng> kCityMapCenters = {
  'Islamabad': LatLng(33.6844, 73.0479),
  'Lahore': LatLng(31.5204, 74.3587),
  'Karachi': LatLng(24.8607, 67.0011),
  'Rawalpindi': LatLng(33.5651, 73.0169),
  'Faisalabad': LatLng(31.4504, 73.1350),
  'Peshawar': LatLng(34.0151, 71.5249),
};

/// Full-screen map picker with search + reverse geocoding for owners.
class LocationPickerMap extends StatefulWidget {
  final double initialLatitude;
  final double initialLongitude;
  final String? city;

  const LocationPickerMap({
    super.key,
    required this.initialLatitude,
    required this.initialLongitude,
    this.city,
  });

  @override
  State<LocationPickerMap> createState() => _LocationPickerMapState();
}

class _LocationPickerMapState extends State<LocationPickerMap> {
  late LatLng _selected;
  late final MapController _mapController;
  final _searchController = TextEditingController();
  final _geocoding = GeocodingService.instance;

  List<GeocodingPlace> _searchResults = [];
  GeocodingPlace? _resolvedPlace;
  bool _isSearching = false;
  bool _isResolving = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    if (widget.initialLatitude != 0 || widget.initialLongitude != 0) {
      _selected = LatLng(widget.initialLatitude, widget.initialLongitude);
      _resolveLocation(_selected);
    } else if (widget.city != null && kCityMapCenters.containsKey(widget.city)) {
      _selected = kCityMapCenters[widget.city]!;
    } else {
      _selected = kCityMapCenters['Islamabad']!;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _resolveLocation(LatLng point) async {
    setState(() => _isResolving = true);
    try {
      final place = await _geocoding.reverse(point.latitude, point.longitude);
      if (!mounted) return;
      setState(() {
        _resolvedPlace = place;
        _isResolving = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      if (value.trim().length < 2) {
        if (mounted) setState(() => _searchResults = []);
        return;
      }
      setState(() => _isSearching = true);
      try {
        final results = await _geocoding.search(value, city: widget.city);
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  void _selectSearchResult(GeocodingPlace place) {
    final point = LatLng(place.latitude, place.longitude);
    setState(() {
      _selected = point;
      _resolvedPlace = place;
      _searchResults = [];
      _searchController.text = place.placeName ?? place.address.split(',').first;
    });
    _mapController.move(point, 16);
    FocusScope.of(context).unfocus();
  }

  void _onMapTap(TapPosition _, LatLng point) {
    setState(() {
      _selected = point;
      _searchResults = [];
    });
    _resolveLocation(point);
  }

  void _confirm() {
    final place = _resolvedPlace;
    final address = place?.address ??
        '${_selected.latitude.toStringAsFixed(5)}, ${_selected.longitude.toStringAsFixed(5)}';

    Navigator.pop(
      context,
      LocationPickResult(
        latitude: _selected.latitude,
        longitude: _selected.longitude,
        address: address,
        city: place?.city ?? widget.city,
        placeName: place?.placeName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayAddress = _resolvedPlace?.address;
    final displayName = _resolvedPlace?.placeName;

    return Scaffold(
      backgroundColor: CAppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Search & Pick Location',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: CAppTheme.textPrimary,
        elevation: 0,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selected,
              initialZoom: 14,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.cwc',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selected,
                    width: 48,
                    height: 48,
                    child: const Icon(
                      Icons.location_pin,
                      color: CAppTheme.primaryColor,
                      size: 48,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Search bar
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search place, street, area...',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 13,
                        color: CAppTheme.textTertiary,
                      ),
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchResults = []);
                                  },
                                )
                              : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(CAppTheme.radiusLarge),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(CAppTheme.radiusMedium),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final place = _searchResults[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined,
                              color: CAppTheme.primaryColor, size: 22),
                          title: Text(
                            place.placeName ??
                                place.address.split(',').first.trim(),
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            place.address,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: CAppTheme.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _selectSearchResult(place),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Bottom panel
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: _isResolving
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Getting address...',
                              style: GoogleFonts.poppins(fontSize: 13),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (displayName != null) ...[
                              Text(
                                displayName,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: CAppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                            Text(
                              displayAddress ??
                                  'Tap map or search to set location',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: CAppTheme.textSecondary,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_selected.latitude.toStringAsFixed(5)}, ${_selected.longitude.toStringAsFixed(5)}',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: CAppTheme.textTertiary,
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isResolving ? null : _confirm,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(
                      'Use This Location',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(CAppTheme.radiusLarge),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact read-only map shown on workspace detail / add form preview.
class WorkspaceMapView extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String? label;

  const WorkspaceMapView({
    super.key,
    required this.latitude,
    required this.longitude,
    this.label,
  });

  bool get _hasValidLocation => latitude != 0 || longitude != 0;

  @override
  Widget build(BuildContext context) {
    if (!_hasValidLocation) return const SizedBox.shrink();

    final point = LatLng(latitude, longitude);

    return ClipRRect(
      borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
      child: SizedBox(
        height: 180,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: point,
            initialZoom: 15,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.cwc',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: point,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.location_pin,
                    color: CAppTheme.primaryColor,
                    size: 40,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

LatLng defaultCenterForCity(String? city) {
  if (city != null && kCityMapCenters.containsKey(city)) {
    return kCityMapCenters[city]!;
  }
  return kCityMapCenters[AppConstants.cities.first]!;
}
