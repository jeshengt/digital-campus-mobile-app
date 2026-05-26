import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../models/bus_location.dart';
import '../models/campus_bus.dart';
import '../utils/bus_tracking_helpers.dart';

class BusMapPanel extends StatelessWidget {
  const BusMapPanel({
    super.key,
    required this.buses,
    required this.locations,
    this.selectedBusId,
  });

  final List<CampusBus> buses;
  final List<BusLocation> locations;
  final String? selectedBusId;

  @override
  Widget build(BuildContext context) {
    final busById = {for (final bus in buses) bus.busId: bus};
    final activeLocations = locations
        .where((location) => busById.containsKey(location.busId))
        .toList();
    BusLocation? selectedLocation;
    for (final location in activeLocations) {
      if (selectedBusId != null && location.busId == selectedBusId) {
        selectedLocation = location;
        break;
      }
    }
    final centerLocation =
        selectedLocation ??
        (activeLocations.isNotEmpty ? activeLocations.first : null);
    final center = centerLocation == null
        ? const LatLng(campusDefaultLatitude, campusDefaultLongitude)
        : LatLng(centerLocation.latitude, centerLocation.longitude);

    final polylines = <Polyline<Object>>[];
    for (final bus in buses) {
      if (!bus.hasRouteGeometry) {
        continue;
      }

      polylines.add(
        Polyline(
          points: [
            for (final point in bus.routePoints)
              LatLng(point.latitude, point.longitude),
          ],
          color: bus.busId == selectedBusId
              ? AppColors.utmMaroon
              : AppColors.utmGold,
          strokeWidth: bus.busId == selectedBusId ? 5 : 3,
        ),
      );
    }

    return Semantics(
      label: 'OpenStreetMap live bus map',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        child: SizedBox(
          height: 360,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: activeLocations.isEmpty ? 15 : 16,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.utmgo',
              ),
              if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
              MarkerLayer(
                markers: [
                  for (final location in activeLocations)
                    Marker(
                      point: LatLng(location.latitude, location.longitude),
                      width: 54,
                      height: 54,
                      child: _BusMarker(
                        bus: busById[location.busId]!,
                        isSelected: location.busId == selectedBusId,
                      ),
                    ),
                ],
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusMarker extends StatelessWidget {
  const _BusMarker({required this.bus, required this.isSelected});

  final CampusBus bus;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: bus.routeName,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isSelected ? AppColors.utmMaroon : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.utmMaroon, width: 2),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          Icons.directions_bus_filled_rounded,
          color: isSelected ? Colors.white : AppColors.utmMaroon,
          size: 24,
        ),
      ),
    );
  }
}
