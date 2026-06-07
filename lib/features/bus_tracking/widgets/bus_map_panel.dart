import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_dimensions.dart';
import '../models/bus_location.dart';
import '../models/campus_bus.dart';
import '../services/bus_tracking_service.dart';
import '../utils/bus_tracking_helpers.dart';

class BusMapPanel extends StatelessWidget {
  const BusMapPanel({
    super.key,
    required this.buses,
    required this.locations,
    this.selectedBusId,
    this.currentPosition,
    this.onLocate,
    this.isLocating = false,
  });

  final List<CampusBus> buses;
  final List<BusLocation> locations;
  final String? selectedBusId;
  final BusPosition? currentPosition;
  final VoidCallback? onLocate;
  final bool isLocating;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);
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
    final selectedBus = selectedBusId == null ? null : busById[selectedBusId];
    final visibleBusLocations = activeLocations
        .where((location) => location.busId == selectedBusId)
        .toList();
    final firstActiveLocation = activeLocations.isNotEmpty
        ? activeLocations.first
        : null;
    final center = _mapCenter(
      selectedLocation: selectedLocation,
      selectedBus: selectedBus,
      firstActiveLocation: firstActiveLocation,
    );
    final featuredBus = selectedBus ?? (buses.isNotEmpty ? buses.first : null);

    final polylines = <Polyline<Object>>[
      if (selectedBus != null && selectedBus.hasRouteGeometry)
        Polyline(
          points: [
            for (final point in selectedBus.routePoints)
              LatLng(point.latitude, point.longitude),
          ],
          color: colors.brandMaroon,
          strokeWidth: 5,
        ),
    ];

    return Semantics(
      label: 'OpenStreetMap live bus map',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        child: SizedBox(
          key: const Key('busTrackingMapPanel'),
          height: 360,
          child: Stack(
            children: [
              FlutterMap(
                key: ValueKey(
                  '${selectedBusId ?? ''}-${currentPosition?.latitude ?? ''}-${currentPosition?.longitude ?? ''}',
                ),
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: currentPosition != null
                      ? 16
                      : activeLocations.isEmpty
                      ? 15
                      : 16,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.utmgo',
                  ),
                  if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
                  MarkerLayer(
                    markers: [
                      for (final location in visibleBusLocations)
                        Marker(
                          point: LatLng(location.latitude, location.longitude),
                          width: 54,
                          height: 54,
                          child: _BusMarker(
                            bus: busById[location.busId]!,
                            isSelected: location.busId == selectedBusId,
                          ),
                        ),
                      if (currentPosition != null)
                        Marker(
                          point: LatLng(
                            currentPosition!.latitude,
                            currentPosition!.longitude,
                          ),
                          width: 44,
                          height: 44,
                          child: const _UserLocationMarker(),
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
              if (featuredBus != null)
                Positioned(
                  left: AppDimensions.spacingSmall,
                  top: AppDimensions.spacingSmall,
                  child: _RouteMapLabel(bus: featuredBus),
                ),
              Positioned(
                right: AppDimensions.spacingSmall,
                bottom: AppDimensions.spacingSmall,
                child: FloatingActionButton.small(
                  key: const Key('busMapLocateButton'),
                  heroTag: null,
                  tooltip: 'Locate current location',
                  onPressed: isLocating ? null : onLocate,
                  child: isLocating
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onBrand,
                          ),
                        )
                      : const Icon(Icons.my_location_rounded),
                ),
              ),
              if (currentPosition != null)
                Positioned(
                  left: AppDimensions.spacingSmall,
                  bottom: AppDimensions.spacingSmall,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.glassStrong,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusMedium,
                      ),
                      border: Border.all(color: colors.glassBorder),
                      boxShadow: [
                        BoxShadow(
                          color: colors.shadow,
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacingSmall,
                        vertical: AppDimensions.spacingTiny,
                      ),
                      child: Text(
                        'You are here',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  LatLng _mapCenter({
    required BusLocation? selectedLocation,
    required CampusBus? selectedBus,
    required BusLocation? firstActiveLocation,
  }) {
    if (currentPosition != null) {
      return LatLng(currentPosition!.latitude, currentPosition!.longitude);
    }

    if (selectedLocation != null) {
      return LatLng(selectedLocation.latitude, selectedLocation.longitude);
    }

    if (selectedBus != null && selectedBus.routePoints.isNotEmpty) {
      final point = selectedBus.routePoints.first;
      return LatLng(point.latitude, point.longitude);
    }

    if (firstActiveLocation != null) {
      return LatLng(
        firstActiveLocation.latitude,
        firstActiveLocation.longitude,
      );
    }

    for (final bus in buses) {
      if (bus.routePoints.isNotEmpty) {
        final point = bus.routePoints.first;
        return LatLng(point.latitude, point.longitude);
      }
    }

    return const LatLng(campusDefaultLatitude, campusDefaultLongitude);
  }
}

class _RouteMapLabel extends StatelessWidget {
  const _RouteMapLabel({required this.bus});

  final CampusBus bus;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.glassStrong,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: colors.glassBorder),
        boxShadow: [
          BoxShadow(color: colors.shadow, blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingSmall,
          vertical: AppDimensions.spacingTiny,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route_rounded, color: colors.brandMaroon, size: 18),
            const SizedBox(width: AppDimensions.spacingTiny),
            Text(
              bus.routeName,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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
    final colors = UtmThemeColors.of(context);

    return Tooltip(
      message: bus.routeName,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isSelected ? colors.brandMaroon : colors.glassStrong,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.brandMaroon, width: 2),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          Icons.directions_bus_filled_rounded,
          color: isSelected ? colors.onBrand : colors.brandMaroon,
          size: 24,
        ),
      ),
    );
  }
}

class _UserLocationMarker extends StatelessWidget {
  const _UserLocationMarker();

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);

    return Tooltip(
      message: 'Your current location',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.brandGoldSoft,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: colors.glassBorder, width: 2),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          Icons.person_pin_circle_rounded,
          color: colors.warning,
          size: 22,
        ),
      ),
    );
  }
}
