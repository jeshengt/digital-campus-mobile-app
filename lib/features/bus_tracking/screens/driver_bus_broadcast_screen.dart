import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/errors/app_exception.dart';
import '../../../shared/layouts/utm_background_scaffold.dart';
import '../../../shared/widgets/utm_top_app_bar.dart';
import '../models/bus_location.dart';
import '../models/campus_bus.dart';
import '../services/bus_tracking_service.dart';
import '../utils/bus_admin_validation.dart';
import '../utils/bus_tracking_helpers.dart';

class DriverBusBroadcastScreen extends StatefulWidget {
  const DriverBusBroadcastScreen({
    super.key,
    BusTrackingService? busTrackingService,
    BusLocationProvider? locationProvider,
  }) : _busTrackingService = busTrackingService,
       _locationProvider = locationProvider;

  final BusTrackingService? _busTrackingService;
  final BusLocationProvider? _locationProvider;

  @override
  State<DriverBusBroadcastScreen> createState() =>
      _DriverBusBroadcastScreenState();
}

class _DriverBusBroadcastScreenState extends State<DriverBusBroadcastScreen> {
  late final BusTrackingService _busTrackingService;
  late final BusLocationProvider _locationProvider;
  Timer? _broadcastTimer;
  CampusBus? _selectedBus;
  BusPosition? _currentPosition;
  bool _isBroadcasting = false;
  bool _isUpdating = false;
  bool _isPublishInFlight = false;

  @override
  void initState() {
    super.initState();
    _busTrackingService =
        widget._busTrackingService ?? FirebaseBusTrackingService();
    _locationProvider =
        widget._locationProvider ?? const GeolocatorBusLocationProvider();
  }

  @override
  void dispose() {
    _broadcastTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UtmBackgroundScaffold(
      appBar: const UtmTopAppBar(title: 'Driver broadcast'),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimensions.maxDashboardWidth,
            ),
            child: StreamBuilder<List<CampusBus>>(
              stream: _busTrackingService.watchAssignedBuses(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _DriverMessageState(
                    icon: Icons.error_outline_rounded,
                    title: 'Could not load assigned buses',
                    message: snapshot.error.toString(),
                  );
                }

                final buses = snapshot.data ?? const <CampusBus>[];
                if (buses.isEmpty) {
                  return const _DriverMessageState(
                    icon: Icons.directions_bus_filled_outlined,
                    title: 'No assigned bus',
                    message:
                        'An admin needs to assign a bus route before broadcasting can start.',
                  );
                }

                _selectedBus ??= buses.first;
                final selectedBus =
                    buses.any((bus) => bus.busId == _selectedBus?.busId)
                    ? _selectedBus!
                    : buses.first;

                return StreamBuilder<BusLocation?>(
                  stream: _busTrackingService.watchBusLocation(
                    selectedBus.busId,
                  ),
                  builder: (context, locationSnapshot) {
                    final location = locationSnapshot.data;
                    final isLive =
                        _isBroadcasting || (location?.isBroadcasting ?? false);
                    final canBroadcast = selectedBus.status == busStatusActive;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(AppDimensions.spacingLarge),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _BroadcastHero(isLive: isLive, location: location),
                          const SizedBox(height: AppDimensions.spacingLarge),
                          Text(
                            'Assigned route',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppDimensions.spacingMedium),
                          if (buses.length > 1)
                            _BusSelector(
                              buses: buses,
                              selectedBus: selectedBus,
                              onChanged: _isBroadcasting
                                  ? null
                                  : (bus) {
                                      setState(() {
                                        _selectedBus = bus;
                                      });
                                    },
                            )
                          else
                            _AssignedBusCard(bus: selectedBus),
                          const SizedBox(height: AppDimensions.spacingLarge),
                          Text(
                            'Route map',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppDimensions.spacingMedium),
                          _DriverMapSection(
                            bus: selectedBus,
                            broadcastLocation: location,
                            currentPosition: _currentPosition,
                            onLocate: _isUpdating
                                ? null
                                : _locateCurrentPosition,
                          ),
                          const SizedBox(height: AppDimensions.spacingLarge),
                          _BroadcastControls(
                            isLive: isLive,
                            isUpdating: _isUpdating,
                            onToggle: canBroadcast
                                ? () => isLive
                                      ? _stopBroadcast(selectedBus)
                                      : _startBroadcast(selectedBus)
                                : null,
                            onRefresh: isLive
                                ? () => _refreshBroadcast(selectedBus)
                                : null,
                          ),
                          const SizedBox(height: AppDimensions.spacingMedium),
                          Text(
                            'Broadcast are updated every 10 seconds while live.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startBroadcast(CampusBus bus) async {
    await _runWithFeedback(() async {
      await _publishCurrentLocation(bus);
      _broadcastTimer?.cancel();
      _broadcastTimer = Timer.periodic(busBroadcastInterval, (_) {
        _publishCurrentLocation(bus).catchError((Object error) {
          _showSnack(error.toString());
        });
      });
      setState(() {
        _isBroadcasting = true;
      });
      _showSnack('Location broadcasting started.');
    });
  }

  Future<void> _stopBroadcast(CampusBus bus) async {
    await _runWithFeedback(() async {
      _broadcastTimer?.cancel();
      _broadcastTimer = null;
      await _busTrackingService.stopBroadcast(bus);
      setState(() {
        _isBroadcasting = false;
      });
      _showSnack('Location broadcasting stopped.');
    });
  }

  Future<void> _refreshBroadcast(CampusBus bus) async {
    await _runWithFeedback(() async {
      await _publishCurrentLocation(bus);
      _showSnack('Location updated.');
    });
  }

  Future<void> _publishCurrentLocation(CampusBus bus) async {
    if (_isPublishInFlight) {
      return;
    }

    _isPublishInFlight = true;
    try {
      final position = await _locationProvider.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
      await _busTrackingService.publishLocation(bus: bus, position: position);
    } finally {
      _isPublishInFlight = false;
    }
  }

  Future<void> _locateCurrentPosition() async {
    await _runWithFeedback(() async {
      final position = await _locationProvider.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });
      _showSnack('Current location updated.');
    });
  }

  Future<void> _runWithFeedback(Future<void> Function() action) async {
    if (_isUpdating) {
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      await action();
    } on AppException catch (error) {
      _showSnack(error.message);
    } catch (error) {
      _showSnack(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _BroadcastHero extends StatelessWidget {
  const _BroadcastHero({required this.isLive, required this.location});

  final bool isLive;
  final BusLocation? location;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);

    return Card(
      color: isLive ? colors.brandMaroonSoft : colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLarge),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: isLive
                    ? colors.brandMaroon.withValues(alpha: 0.16)
                    : colors.brandMaroonSoft,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              ),
              child: Icon(
                isLive ? Icons.radio_button_checked : Icons.radio_button_off,
                color: isLive ? colors.brandMaroon : colors.brandMaroon,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isLive ? 'Broadcasting live' : 'Broadcast paused',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingTiny),
                  Text(
                    location == null
                        ? 'No recent location update'
                        : 'Last update ${formatUpdatedAt(location!.updatedAt)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BusSelector extends StatelessWidget {
  const _BusSelector({
    required this.buses,
    required this.selectedBus,
    required this.onChanged,
  });

  final List<CampusBus> buses;
  final CampusBus selectedBus;
  final ValueChanged<CampusBus>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: selectedBus.busId,
      decoration: const InputDecoration(labelText: 'Bus route'),
      items: [
        for (final bus in buses)
          DropdownMenuItem(
            value: bus.busId,
            child: Text('${bus.routeName} - ${bus.status}'),
          ),
      ],
      onChanged: onChanged == null
          ? null
          : (busId) {
              final bus = buses.firstWhere((item) => item.busId == busId);
              onChanged!(bus);
            },
    );
  }
}

class _AssignedBusCard extends StatelessWidget {
  const _AssignedBusCard({required this.bus});

  final CampusBus bus;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppDimensions.spacingMedium),
        leading: CircleAvatar(
          backgroundColor: colors.brandGoldSoft,
          foregroundColor: colors.warning,
          child: const Icon(Icons.route_rounded),
        ),
        title: Text(bus.routeName),
        subtitle: Text(bus.status),
      ),
    );
  }
}

class _DriverMapSection extends StatelessWidget {
  const _DriverMapSection({
    required this.bus,
    required this.broadcastLocation,
    required this.currentPosition,
    required this.onLocate,
  });

  final CampusBus bus;
  final BusLocation? broadcastLocation;
  final BusPosition? currentPosition;
  final VoidCallback? onLocate;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _DriverRouteMap(
          bus: bus,
          broadcastLocation: broadcastLocation,
          currentPosition: currentPosition,
        ),
        Positioned(
          left: currentPosition == null ? AppDimensions.spacingSmall : null,
          right: AppDimensions.spacingSmall,
          bottom: AppDimensions.spacingSmall,
          child: _CurrentLocationCard(
            currentPosition: currentPosition,
            onLocate: onLocate,
          ),
        ),
      ],
    );
  }
}

class _DriverRouteMap extends StatelessWidget {
  const _DriverRouteMap({
    required this.bus,
    required this.broadcastLocation,
    required this.currentPosition,
  });

  final CampusBus bus;
  final BusLocation? broadcastLocation;
  final BusPosition? currentPosition;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);
    final routePoints = [
      for (final point in bus.routePoints)
        LatLng(point.latitude, point.longitude),
    ];
    final center = _mapCenter(routePoints);
    final mapKey = ValueKey(
      '${bus.busId}-${currentPosition?.latitude}-${currentPosition?.longitude}-${broadcastLocation?.latitude}-${broadcastLocation?.longitude}',
    );

    return Semantics(
      label: 'Driver route map',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        child: SizedBox(
          key: const Key('driverBroadcastMap'),
          height: 320,
          child: FlutterMap(
            key: mapKey,
            options: MapOptions(
              initialCenter: center,
              initialZoom: bus.hasRouteGeometry ? 15 : 16,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.utmgo',
              ),
              if (routePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      color: colors.brandMaroon,
                      strokeWidth: 4,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (broadcastLocation != null)
                    Marker(
                      point: LatLng(
                        broadcastLocation!.latitude,
                        broadcastLocation!.longitude,
                      ),
                      width: 48,
                      height: 48,
                      child: _DriverMapMarker(
                        icon: Icons.directions_bus_filled_rounded,
                        tooltip: 'Latest broadcast location',
                        backgroundColor: colors.brandMaroon,
                        foregroundColor: colors.onBrand,
                      ),
                    ),
                  if (currentPosition != null)
                    Marker(
                      point: LatLng(
                        currentPosition!.latitude,
                        currentPosition!.longitude,
                      ),
                      width: 42,
                      height: 42,
                      child: _DriverMapMarker(
                        icon: Icons.my_location_rounded,
                        tooltip: 'Current GPS location',
                        backgroundColor: colors.brandGoldSoft,
                        foregroundColor: colors.warning,
                      ),
                    ),
                  if (broadcastLocation == null && currentPosition == null)
                    Marker(
                      point: center,
                      width: 42,
                      height: 42,
                      child: _DriverMapMarker(
                        icon: Icons.route_rounded,
                        tooltip: 'Route preview',
                        backgroundColor: colors.glassStrong,
                        foregroundColor: colors.brandMaroon,
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

  LatLng _mapCenter(List<LatLng> routePoints) {
    if (currentPosition != null) {
      return LatLng(currentPosition!.latitude, currentPosition!.longitude);
    }

    if (broadcastLocation != null) {
      return LatLng(broadcastLocation!.latitude, broadcastLocation!.longitude);
    }

    if (routePoints.isNotEmpty) {
      return routePoints.first;
    }

    return const LatLng(campusDefaultLatitude, campusDefaultLongitude);
  }
}

class _DriverMapMarker extends StatelessWidget {
  const _DriverMapMarker({
    required this.icon,
    required this.tooltip,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final String tooltip;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);

    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.glassBorder, width: 2),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, color: foregroundColor, size: 22),
      ),
    );
  }
}

class _CurrentLocationCard extends StatelessWidget {
  const _CurrentLocationCard({
    required this.currentPosition,
    required this.onLocate,
  });

  final BusPosition? currentPosition;
  final VoidCallback? onLocate;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final hasPosition = currentPosition != null;
    final radius = BorderRadius.circular(
      hasPosition ? AppDimensions.radiusLarge : AppDimensions.radiusExtraLarge,
    );

    final locateButton = hasPosition
        ? Semantics(
            label: 'Locate',
            button: true,
            child: IconButton.filled(
              key: const Key('driverLocateButton'),
              tooltip: 'Locate',
              onPressed: onLocate,
              style: IconButton.styleFrom(
                backgroundColor: colors.brandMaroon,
                foregroundColor: colors.onBrand,
                disabledBackgroundColor: colors.mutedSurface,
                disabledForegroundColor: colors.textTertiary,
                fixedSize: const Size.square(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusMedium,
                  ),
                ),
              ),
              icon: const Icon(Icons.my_location_rounded),
            ),
          )
        : FilledButton.icon(
            key: const Key('driverLocateButton'),
            onPressed: onLocate,
            style: FilledButton.styleFrom(
              minimumSize: const Size(104, 48),
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacingMedium,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            icon: const Icon(Icons.my_location_rounded),
            label: const Text('Locate'),
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: hasPosition
                ? colors.brandMaroon.withValues(alpha: 0.12)
                : colors.shadow,
            blurRadius: hasPosition ? 22 : 34,
            offset: Offset(0, hasPosition ? 10 : 16),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                if (hasPosition) ...[
                  colors.brandGoldSoft.withValues(alpha: 0.76),
                  colors.glassStrong.withValues(alpha: 0.86),
                ] else ...[
                  colors.glassStrong.withValues(alpha: 0.9),
                  colors.glass.withValues(alpha: 0.78),
                ],
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              hasPosition ? 14 : 13,
              hasPosition ? 8 : 13,
              hasPosition ? 8 : 13,
              hasPosition ? 8 : 13,
            ),
            child: hasPosition
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ready',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          height: 1.08,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacingMedium),
                      locateButton,
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current location unavailable',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                height: 1.08,
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spacingTiny),
                            Text(
                              'Tap Locate to show your GPS position on the map.',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.textSecondary,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacingSmall),
                      locateButton,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _BroadcastControls extends StatelessWidget {
  const _BroadcastControls({
    required this.isLive,
    required this.isUpdating,
    required this.onToggle,
    required this.onRefresh,
  });

  final bool isLive;
  final bool isUpdating;
  final VoidCallback? onToggle;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            key: const Key('driverBroadcastToggleButton'),
            onPressed: isUpdating ? null : onToggle,
            icon: Icon(
              isLive
                  ? Icons.stop_circle_outlined
                  : Icons.play_circle_outline_rounded,
            ),
            label: Text(isLive ? 'Stop broadcast' : 'Start broadcast'),
          ),
        ),
        const SizedBox(width: AppDimensions.spacingMedium),
        Semantics(
          label: 'Refresh location now',
          button: true,
          child: IconButton(
            tooltip: 'Refresh location',
            onPressed: isUpdating ? null : onRefresh,
            icon: const Icon(Icons.my_location_rounded),
          ),
        ),
      ],
    );
  }
}

class _DriverMessageState extends StatelessWidget {
  const _DriverMessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: colors.brandMaroon),
            const SizedBox(height: AppDimensions.spacingMedium),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppDimensions.spacingSmall),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
