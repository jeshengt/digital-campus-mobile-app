import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
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
  }) : _busTrackingService = busTrackingService;

  final String title;
  final BusTrackingService? _busTrackingService;

  @override
  State<BusTrackingMapScreen> createState() => _BusTrackingMapScreenState();
}

class _BusTrackingMapScreenState extends State<BusTrackingMapScreen> {
  late final BusTrackingService _busTrackingService;
  String? _selectedBusId;

  @override
  void initState() {
    super.initState();
    _busTrackingService =
        widget._busTrackingService ?? FirebaseBusTrackingService();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
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
                    final liveBusIds = locationByBusId.keys.toSet();
                    final selectedBusId =
                        _selectedBusId ??
                        (liveBusIds.isNotEmpty ? liveBusIds.first : null);

                    return ListView(
                      padding: const EdgeInsets.all(AppDimensions.spacingLarge),
                      children: [
                        _MapHeader(liveCount: liveBusIds.length),
                        const SizedBox(height: AppDimensions.spacingMedium),
                        if (liveBusIds.isEmpty)
                          const _BusMessageCard(
                            icon: Icons.location_off_outlined,
                            title: 'No live buses',
                            message:
                                'A bus will appear on the map when a driver starts broadcasting.',
                          )
                        else
                          BusMapPanel(
                            buses: buses,
                            locations: locations,
                            selectedBusId: selectedBusId,
                          ),
                        const SizedBox(height: AppDimensions.spacingLarge),
                        Text(
                          'Routes',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppDimensions.spacingMedium),
                        for (final bus in buses)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppDimensions.spacingMedium,
                            ),
                            child: BusStatusCard(
                              bus: bus,
                              location: locationByBusId[bus.busId],
                              isSelected: bus.busId == selectedBusId,
                              onTap: () {
                                setState(() {
                                  _selectedBusId = bus.busId;
                                });
                              },
                            ),
                          ),
                      ],
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
}

class _MapHeader extends StatelessWidget {
  const _MapHeader({required this.liveCount});

  final int liveCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.utmMaroon,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLarge),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              ),
              child: const Icon(
                Icons.map_outlined,
                color: AppColors.utmGoldTint,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Campus shuttle map',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingTiny),
                  Text(
                    '$liveCount live bus${liveCount == 1 ? '' : 'es'} now',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.utmGoldTint,
                      fontWeight: FontWeight.w700,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 42, color: AppColors.utmMaroon),
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
