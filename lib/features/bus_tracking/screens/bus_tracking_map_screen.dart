import 'package:flutter/material.dart';

import '../../../core/constants/app_dimensions.dart';
import '../../../core/errors/app_exception.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/layouts/utm_background_scaffold.dart';
import '../../../shared/widgets/utm_feature_header.dart';
import '../../../shared/widgets/utm_top_app_bar.dart';
import '../models/bus_location.dart';
import '../models/campus_bus.dart';
import '../services/bus_tracking_service.dart';
import '../widgets/bus_map_panel.dart';
import '../widgets/bus_status_card.dart';

class BusTrackingMapScreen extends StatefulWidget {
  const BusTrackingMapScreen({
    super.key,
    this.title = 'Live bus tracking',
    BusTrackingService? busTrackingService,
    BusLocationProvider? locationProvider,
  }) : _busTrackingService = busTrackingService,
       _locationProvider = locationProvider;

  final String title;
  final BusTrackingService? _busTrackingService;
  final BusLocationProvider? _locationProvider;

  @override
  State<BusTrackingMapScreen> createState() => _BusTrackingMapScreenState();
}

class _BusTrackingMapScreenState extends State<BusTrackingMapScreen> {
  late final BusTrackingService _busTrackingService;
  late final BusLocationProvider _locationProvider;
  String? _selectedBusId;
  BusPosition? _currentPosition;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _busTrackingService =
        widget._busTrackingService ?? FirebaseBusTrackingService();
    _locationProvider =
        widget._locationProvider ?? const GeolocatorBusLocationProvider();
  }

  @override
  Widget build(BuildContext context) {
    return UtmBackgroundScaffold(
      appBar: UtmTopAppBar(title: widget.title),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimensions.maxDashboardWidth,
            ),
            child: StreamBuilder<List<CampusBus>>(
              stream: _busTrackingService.watchVisibleBuses(),
              builder: (context, busSnapshot) {
                if (busSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (busSnapshot.hasError) {
                  return _BusMessageState(
                    icon: Icons.error_outline_rounded,
                    title: 'Could not load buses',
                    message: busSnapshot.error.toString(),
                  );
                }

                final buses = busSnapshot.data ?? const <CampusBus>[];
                if (buses.isEmpty) {
                  return const _BusMessageState(
                    icon: Icons.directions_bus_filled_outlined,
                    title: 'No buses yet',
                    message:
                        'Campus bus routes will appear after an admin adds buses.',
                  );
                }

                return StreamBuilder<List<BusLocation>>(
                  stream: _busTrackingService.watchLiveLocations(),
                  builder: (context, locationSnapshot) {
                    if (locationSnapshot.connectionState ==
                            ConnectionState.waiting &&
                        !locationSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (locationSnapshot.hasError) {
                      return _BusMessageState(
                        icon: Icons.error_outline_rounded,
                        title: 'Could not load live locations',
                        message: locationSnapshot.error.toString(),
                      );
                    }

                    final locations =
                        locationSnapshot.data ?? const <BusLocation>[];
                    final locationByBusId = {
                      for (final location in locations)
                        location.busId: location,
                    };
                    final busIds = {for (final bus in buses) bus.busId};
                    final liveBusIds = locationByBusId.keys
                        .where(busIds.contains)
                        .toSet();
                    final selectedBusId = _resolveSelectedBusId(
                      buses: buses,
                      liveBusIds: liveBusIds,
                    );
                    final selectedBus = buses.firstWhere(
                      (bus) => bus.busId == selectedBusId,
                    );

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(AppDimensions.spacingLarge),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _MapHeader(liveCount: liveBusIds.length),
                          const SizedBox(height: AppDimensions.spacingMedium),
                          _RouteDropdown(
                            buses: buses,
                            locationByBusId: locationByBusId,
                            selectedBusId: selectedBusId,
                            onChanged: (busId) {
                              setState(() {
                                _selectedBusId = busId;
                              });
                            },
                          ),
                          const SizedBox(height: AppDimensions.spacingMedium),
                          BusMapPanel(
                            buses: buses,
                            locations: locations,
                            selectedBusId: selectedBusId,
                            currentPosition: _currentPosition,
                            isLocating: _isLocating,
                            onLocate: _locateCurrentPosition,
                          ),
                          const SizedBox(height: AppDimensions.spacingMedium),
                          BusStatusCard(
                            bus: selectedBus,
                            location: locationByBusId[selectedBusId],
                          ),
                          if (liveBusIds.isEmpty) ...[
                            const SizedBox(height: AppDimensions.spacingMedium),
                            const _BusMessageCard(
                              icon: Icons.location_off_outlined,
                              title: 'No live buses',
                              message:
                                  'A bus will appear on the map when a driver starts broadcasting.',
                            ),
                          ],
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

  Future<void> _locateCurrentPosition() async {
    setState(() {
      _isLocating = true;
    });

    try {
      final position = await _locationProvider.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLocating = false;
        });
      }
    } on AppException catch (error) {
      _showLocationError(error.message);
    } catch (error) {
      _showLocationError(error.toString());
    }
  }

  void _showLocationError(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLocating = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _resolveSelectedBusId({
    required List<CampusBus> buses,
    required Set<String> liveBusIds,
  }) {
    if (buses.any((bus) => bus.busId == _selectedBusId)) {
      return _selectedBusId!;
    }

    for (final bus in buses) {
      if (liveBusIds.contains(bus.busId)) {
        return bus.busId;
      }
    }

    return buses.first.busId;
  }
}

class _RouteDropdown extends StatelessWidget {
  const _RouteDropdown({
    required this.buses,
    required this.locationByBusId,
    required this.selectedBusId,
    required this.onChanged,
  });

  final List<CampusBus> buses;
  final Map<String, BusLocation> locationByBusId;
  final String selectedBusId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: const Key('busRouteDropdown'),
      initialValue: selectedBusId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Select route',
        prefixIcon: Icon(Icons.route_rounded),
      ),
      items: [
        for (final bus in buses)
          DropdownMenuItem(
            value: bus.busId,
            child: Text(
              '${bus.routeName} - ${_routeStatusLabel(bus)}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (busId) {
        if (busId != null) {
          onChanged(busId);
        }
      },
    );
  }

  String _routeStatusLabel(CampusBus bus) {
    final location = locationByBusId[bus.busId];
    return location?.isBroadcasting ?? false ? 'Live' : 'Offline';
  }
}

class _MapHeader extends StatelessWidget {
  const _MapHeader({required this.liveCount});

  final int liveCount;

  @override
  Widget build(BuildContext context) {
    return UtmFeatureHeader(
      icon: Icons.map_outlined,
      title: 'Campus shuttle map',
      subtitle: '$liveCount live bus${liveCount == 1 ? '' : 'es'} now',
    );
  }
}

class _BusMessageState extends StatelessWidget {
  const _BusMessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLarge),
        child: _BusMessageContent(icon: icon, title: title, message: message),
      ),
    );
  }
}

class _BusMessageCard extends StatelessWidget {
  const _BusMessageCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLarge),
        child: _BusMessageContent(icon: icon, title: title, message: message),
      ),
    );
  }
}

class _BusMessageContent extends StatelessWidget {
  const _BusMessageContent({
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

    return Column(
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
    );
  }
}
