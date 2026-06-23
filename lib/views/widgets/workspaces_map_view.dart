import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:cwc/models/workspace_model.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/views/screens/user/workspace_detail_screen.dart';

/// Interactive map showing all workspaces with valid coordinates.
class WorkspacesMapView extends StatefulWidget {
  final List<WorkspaceModel> workspaces;

  const WorkspacesMapView({super.key, required this.workspaces});

  @override
  State<WorkspacesMapView> createState() => _WorkspacesMapViewState();
}

class _WorkspacesMapViewState extends State<WorkspacesMapView> {
  final MapController _mapController = MapController();
  WorkspaceModel? _selected;

  List<WorkspaceModel> get _locatedWorkspaces => widget.workspaces
      .where((w) => w.latitude != 0 || w.longitude != 0)
      .toList();

  @override
  void didUpdateWidget(covariant WorkspacesMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaces != widget.workspaces) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
  }

  void _fitBounds() {
    final located = _locatedWorkspaces;
    if (located.isEmpty) return;

    if (located.length == 1) {
      _mapController.move(
        LatLng(located.first.latitude, located.first.longitude),
        14,
      );
      return;
    }

    final points = located
        .map((w) => LatLng(w.latitude, w.longitude))
        .toList();
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)),
    );
  }

  void _showWorkspaceSheet(WorkspaceModel workspace) {
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
    final located = _locatedWorkspaces;

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

    final initialCenter = LatLng(located.first.latitude, located.first.longitude);

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: 12,
            onTap: (_, __) => setState(() => _selected = null),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.cwc',
            ),
            MarkerLayer(
              markers: located.map((ws) {
                final point = LatLng(ws.latitude, ws.longitude);
                final isSelected = _selected?.id == ws.id;
                return Marker(
                  point: point,
                  width: isSelected ? 52 : 44,
                  height: isSelected ? 52 : 44,
                  child: GestureDetector(
                    onTap: () => _showWorkspaceSheet(ws),
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
                const Icon(Icons.map_rounded,
                    size: 18, color: CAppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${located.length} workspace${located.length == 1 ? '' : 's'} on map — tap a pin',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: CAppTheme.textSecondary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.my_location_rounded, size: 20),
                  tooltip: 'Fit all',
                  onPressed: _fitBounds,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
