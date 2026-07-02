import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:cwc/models/workspace_model.dart';
import 'package:cwc/services/location_service.dart';
import 'package:cwc/services/route_distance_service.dart';
import 'package:cwc/utils/helpers/geo_utils.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/views/screens/user/workspace_detail_screen.dart';

class _LocatedWorkspace {
  final WorkspaceModel workspace;
  final double? straightKm;
  final double? roadKm;

  const _LocatedWorkspace({
    required this.workspace,
    this.straightKm,
    this.roadKm,
  });

  double? get displayKm => roadKm ?? straightKm;
  bool get isRoadDistance => roadKm != null;
}

/// Interactive map showing workspaces; centers on user and highlights nearby pins.
class WorkspacesMapView extends StatefulWidget {
  final List<WorkspaceModel> workspaces;
  final String? fallbackCity;

  const WorkspacesMapView({
    super.key,
    required this.workspaces,
    this.fallbackCity,
  });

  @override
  State<WorkspacesMapView> createState() => _WorkspacesMapViewState();
}

class _WorkspacesMapViewState extends State<WorkspacesMapView> {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService.instance;

  WorkspaceModel? _selected;
  UserLocation? _userGpsLocation;
  LatLng? _mapCenter;
  bool _isLocating = true;
  bool _loadingRoadDistances = false;
  bool _roadDistancesFailed = false;
  Map<String, double> _roadDistancesKm = {};
  String? _locationMessage;

  bool get _hasGps => _userGpsLocation != null;

  List<WorkspaceModel> get _locatedWorkspaces => widget.workspaces
      .where((w) => hasValidWorkspaceCoords(w.latitude, w.longitude))
      .toList();

  List<_LocatedWorkspace> get _sortedWorkspaces {
    final located = _locatedWorkspaces;
    if (!_hasGps) {
      return located
          .map((w) => _LocatedWorkspace(workspace: w))
          .toList();
    }

    final user = _userGpsLocation!;
    final withDistance = located.map((w) {
      final straight = distanceKm(
        user.latitude,
        user.longitude,
        w.latitude,
        w.longitude,
      );
      return _LocatedWorkspace(
        workspace: w,
        straightKm: straight,
        roadKm: _roadDistancesKm[w.id],
      );
    }).toList()
      ..sort((a, b) => (a.displayKm ?? double.infinity)
          .compareTo(b.displayKm ?? double.infinity));

    return withDistance;
  }

  String? _distanceLabel(_LocatedWorkspace entry) {
    if (entry.isRoadDistance) {
      return formatRoadDistanceKm(entry.roadKm!);
    }
    if (_loadingRoadDistances) return 'Calculating route…';
    if (entry.straightKm != null) {
      return _roadDistancesFailed
          ? '${formatDistanceKm(entry.straightKm!)} (approx)'
          : formatDistanceKm(entry.straightKm!);
    }
    return null;
  }

  List<_LocatedWorkspace> get _nearbyWorkspaces {
    const nearbyRadiusKm = 25.0;
    return _sortedWorkspaces
        .where((e) =>
            e.displayKm == null || e.displayKm! <= nearbyRadiusKm)
        .toList();
  }

  @override
  void didUpdateWidget(covariant WorkspacesMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaces != widget.workspaces) {
      if (_hasGps) _loadRoadDistances();
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapView());
    }
  }

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final gps = await _locationService.getCurrentLocation();

    LatLng? mapCenter;
    UserLocation? gpsLocation;
    String? message;

    if (gps != null) {
      gpsLocation = gps;
      mapCenter = LatLng(gps.latitude, gps.longitude);
      if (gps.accuracyMeters != null && gps.accuracyMeters! > 150) {
        message =
            'GPS approximate (±${gps.accuracyMeters!.round()} m) — tap ↻ to refine';
      }
    } else if (widget.fallbackCity != null &&
        kCityMapCenters.containsKey(widget.fallbackCity)) {
      final center = kCityMapCenters[widget.fallbackCity]!;
      mapCenter = LatLng(center.latitude, center.longitude);
      message =
          'Location off — map centered on ${widget.fallbackCity}. Enable GPS for real distance.';
    } else {
      message = 'Location off — enable GPS to see distance from you';
    }

    if (!mounted) return;

    setState(() {
      _userGpsLocation = gpsLocation;
      _mapCenter = mapCenter;
      _isLocating = false;
      _locationMessage = message;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapView());

    if (gpsLocation != null) {
      _loadRoadDistances();
    }
  }

  Future<void> _loadRoadDistances() async {
    if (!_hasGps) return;
    final located = _locatedWorkspaces;
    if (located.isEmpty) return;

    setState(() {
      _loadingRoadDistances = true;
      _roadDistancesFailed = false;
    });

    final user = _userGpsLocation!;
    final destinations = located
        .map(
          (w) => RouteDestination(
            id: w.id,
            latitude: w.latitude,
            longitude: w.longitude,
          ),
        )
        .toList();

    try {
      final map = await RouteDistanceService.instance.roadDistancesKm(
        userLat: user.latitude,
        userLng: user.longitude,
        destinations: destinations,
      );
      if (!mounted) return;
      setState(() {
        _roadDistancesKm = map;
        _loadingRoadDistances = false;
        _roadDistancesFailed = map.isEmpty;
      });
      if (map.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapView());
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingRoadDistances = false;
        _roadDistancesFailed = true;
      });
    }
  }

  Future<void> _refreshLocation() async {
    setState(() {
      _isLocating = true;
      _locationMessage = null;
    });
    await _initLocation();
  }

  void _centerOnUser() {
    if (!_hasGps) {
      _refreshLocation();
      return;
    }
    final user = _userGpsLocation!;
    _mapController.move(LatLng(user.latitude, user.longitude), 14);
  }

  void _fitMapView() {
    final located = _locatedWorkspaces;
    if (located.isEmpty) return;

    if (_mapCenter != null) {
      final userPoint = _mapCenter!;
      final nearby = _nearbyWorkspaces;
      final points = <LatLng>[userPoint];
      if (nearby.isNotEmpty) {
        points.addAll(
          nearby.map((e) => LatLng(e.workspace.latitude, e.workspace.longitude)),
        );
      } else {
        points.addAll(located.map((w) => LatLng(w.latitude, w.longitude)));
      }

      if (points.length == 1) {
        _mapController.move(userPoint, 14);
        return;
      }

      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.fromLTRB(48, 80, 48, 160),
        ),
      );
      return;
    }

    if (located.length == 1) {
      _mapController.move(
        LatLng(located.first.latitude, located.first.longitude),
        14,
      );
      return;
    }

    final points =
        located.map((w) => LatLng(w.latitude, w.longitude)).toList();
    _mapController.fitCamera(
      CameraFit.bounds(bounds: LatLngBounds.fromPoints(points), padding: const EdgeInsets.all(48)),
    );
  }

  void _showWorkspaceSheet(_LocatedWorkspace entry) {
    final workspace = entry.workspace;
    setState(() => _selected = workspace);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(CAppTheme.radiusXL),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: CAppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.workspaces_outlined,
                      color: CAppTheme.primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workspace.name,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        workspace.city,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: CAppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_distanceLabel(entry) != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    entry.isRoadDistance
                        ? Icons.directions_car_rounded
                        : Icons.near_me_rounded,
                    size: 16,
                    color: CAppTheme.accentColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${_distanceLabel(entry)!}${workspace.city.isNotEmpty ? ' · ${workspace.city}' : ''}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CAppTheme.accentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 16, color: CAppTheme.primaryColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    workspace.address,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: CAppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Rs. ${workspace.pricePerDay.toStringAsFixed(0)}/day',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: CAppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          WorkspaceDetailScreen(workspaceId: workspace.id),
                    ),
                  );
                },
                child: Text(
                  'View Details',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sortedWorkspaces;
    final located = sorted.map((e) => e.workspace).toList();

    if (located.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 56, color: CAppTheme.textTertiary),
              const SizedBox(height: 12),
              Text(
                'No workspaces with map location yet',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: CAppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final initialCenter = _mapCenter ??
        LatLng(located.first.latitude, located.first.longitude);

    final bannerText = _isLocating
        ? 'Getting your location…'
        : _hasGps
            ? '${_nearbyWorkspaces.length} nearby workspace${_nearbyWorkspaces.length == 1 ? '' : 's'} — tap a pin'
            : _locationMessage ??
                '${located.length} workspace${located.length == 1 ? '' : 's'} on map — tap a pin';

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: 13,
            onTap: (_, __) => setState(() => _selected = null),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.cwc',
            ),
            if (_hasGps &&
                _userGpsLocation!.accuracyMeters != null &&
                _userGpsLocation!.accuracyMeters! <= 500)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: LatLng(
                      _userGpsLocation!.latitude,
                      _userGpsLocation!.longitude,
                    ),
                    radius: _userGpsLocation!.accuracyMeters!,
                    useRadiusInMeter: true,
                    color: Colors.blue.withValues(alpha: 0.12),
                    borderColor: Colors.blue.withValues(alpha: 0.35),
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),
            if (_hasGps)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(
                      _userGpsLocation!.latitude,
                      _userGpsLocation!.longitude,
                    ),
                    width: 36,
                    height: 36,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blue, width: 3),
                        boxShadow: CAppTheme.softShadow,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.person_pin_circle_rounded,
                          color: Colors.blue,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            MarkerLayer(
              markers: sorted.map((entry) {
                final ws = entry.workspace;
                final point = LatLng(ws.latitude, ws.longitude);
                final isSelected = _selected?.id == ws.id;
                return Marker(
                  point: point,
                  width: isSelected ? 52 : 44,
                  height: isSelected ? 52 : 44,
                  child: GestureDetector(
                    onTap: () => _showWorkspaceSheet(entry),
                    child: Icon(
                      Icons.location_pin,
                      color: isSelected
                          ? CAppTheme.accentColor
                          : CAppTheme.primaryColor,
                      size: isSelected ? 52 : 44,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
              boxShadow: CAppTheme.softShadow,
            ),
            child: Row(
              children: [
                if (_isLocating)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    _hasGps ? Icons.near_me_rounded : Icons.map_rounded,
                    size: 18,
                    color: CAppTheme.primaryColor,
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    bannerText,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: CAppTheme.textSecondary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  tooltip: 'Refresh GPS',
                  onPressed: _isLocating ? null : _refreshLocation,
                ),
                IconButton(
                  icon: const Icon(Icons.my_location_rounded, size: 20),
                  tooltip: 'My location',
                  onPressed: _centerOnUser,
                ),
                IconButton(
                  icon: const Icon(Icons.fit_screen_rounded, size: 20),
                  tooltip: 'Fit all',
                  onPressed: _fitMapView,
                ),
              ],
            ),
          ),
        ),
        if (_hasGps && sorted.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: sorted.length.clamp(0, 8),
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final entry = sorted[index];
                  final ws = entry.workspace;
                  return GestureDetector(
                    onTap: () {
                      _mapController.move(
                        LatLng(ws.latitude, ws.longitude),
                        15,
                      );
                      _showWorkspaceSheet(entry);
                    },
                    child: Container(
                      width: 200,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(CAppTheme.radiusMedium),
                        boxShadow: CAppTheme.softShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ws.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ws.city,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: CAppTheme.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          if (_distanceLabel(entry) != null)
                            Text(
                              _distanceLabel(entry)!,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: CAppTheme.accentColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
